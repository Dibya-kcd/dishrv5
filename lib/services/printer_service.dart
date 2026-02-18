import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, Socket;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_model.dart';
import '../utils/ticket_generator.dart';

class PrinterService extends ChangeNotifier {
  static final PrinterService instance = PrinterService._();
  PrinterService._();

  List<PrinterModel> _savedPrinters = [];
  List<ScanResult> _scanResults = [];
  List<BluetoothInfo> _pairedBluetooths = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;

  List<PrinterModel> get savedPrinters => _savedPrinters;
  List<ScanResult> get scanResults => _scanResults;
  List<BluetoothInfo> get pairedBluetooths => _pairedBluetooths;
  bool get isScanning => _isScanning;

  final TicketGenerator _ticketGenerator = TicketGenerator();

  Future<void> init() async {
    await _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final String? printersJson = prefs.getString('saved_printers');
    if (printersJson != null) {
      final List<dynamic> decoded = jsonDecode(printersJson);
      _savedPrinters = decoded.map((e) => PrinterModel.fromJson(e)).toList();
      notifyListeners();
    }
  }

  Future<void> _savePrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_savedPrinters.map((e) => e.toJson()).toList());
    await prefs.setString('saved_printers', encoded);
    notifyListeners();
  }

  Future<void> loadPairedBluetooths() async {
    try {
      final list = await PrintBluetoothThermal.pairedBluetooths;
      _pairedBluetooths = list;
      notifyListeners();
    } catch (e) {
      // Error loading paired bluetooths
    }
  }
  void addPrinter(PrinterModel printer) {
    _savedPrinters.removeWhere((p) => p.id == printer.id);
    _savedPrinters.add(printer);
    _savePrinters();
  }

  void removePrinter(String id) {
    _savedPrinters.removeWhere((p) => p.id == id);
    _savePrinters();
  }

  void setPrinterRole(String id, {bool? isKOT, bool? isBill}) {
    final index = _savedPrinters.indexWhere((p) => p.id == id);
    if (index != -1) {
      final printer = _savedPrinters[index];
      // If setting as default KOT, remove KOT flag from others
      if (isKOT == true) {
        for (var p in _savedPrinters) {
          p.isKOT = false;
        }
      }
      // If setting as default Bill, remove Bill flag from others
      if (isBill == true) {
        for (var p in _savedPrinters) {
          p.isBill = false;
        }
      }
      
      printer.isKOT = isKOT ?? printer.isKOT;
      printer.isBill = isBill ?? printer.isBill;
      _savePrinters();
    }
  }

  // Common Service UUIDs for Thermal Printers
  final List<Guid> _printerServices = [
    Guid("000018f0-0000-1000-8000-00805f9b34fb"), // Common Printer Service
    Guid("e7810a71-73ae-499d-8c15-faa9aef0c3f2"), // Star Micronics
    Guid("49535343-fe7d-4ae5-8fa9-9fafd205e455"), // Transparent UART
    Guid("0000fff0-0000-1000-8000-00805f9b34fb"), // ISSC
    Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e"), // Nordic UART
    Guid("0000af30-0000-1000-8000-00805f9b34fb"), // Generic
    Guid("00001800-0000-1000-8000-00805f9b34fb"), // Generic Access
    Guid("00001801-0000-1000-8000-00805f9b34fb"), // Generic Attribute
    Guid("0000ff00-0000-1000-8000-00805f9b34fb"), // Common POS (Xprinter/Gprinter)
    Guid("0000ae30-0000-1000-8000-00805f9b34fb"), // Aircomm/Generic
    Guid("00001101-0000-1000-8000-00805f9b34fb"), // Serial Port Profile (SPP)
    Guid("0000ff02-0000-1000-8000-00805f9b34fb"), // Another common POS variant
  ];

  // Bluetooth Scanning
  Future<void> startScan() async {
    if (_isScanning) return;
    _scanResults.clear();
    _isScanning = true;
    notifyListeners();

    try {
      // Check if Bluetooth is supported/on
      if (await FlutterBluePlus.isSupported == false) {
        _isScanning = false;
        notifyListeners();
        return;
      }

      // Start scanning
      // On Web, we MUST provide withServices to access them later
      await FlutterBluePlus.startScan(
        withServices: kIsWeb ? _printerServices : [],
        timeout: const Duration(seconds: 10)
      );
      
      FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        notifyListeners();
      });

      // Stop after timeout
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Error scanning
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // Printing Logic
  Future<void> printKOT(Map<String, dynamic> order, String tableId, String type) async {
    final printer = _savedPrinters.firstWhere((p) => p.isKOT, orElse: () => throw Exception("No KOT Printer Assigned"));
    final bytes = await _ticketGenerator.generateKOT(order, tableId, type);
    await _printBytes(printer, bytes);
  }

  Future<void> printBill(Map<String, dynamic> order, String tableId, double sub, double tax, double total) async {
    final printer = _savedPrinters.firstWhere((p) => p.isBill, orElse: () => throw Exception("No Bill Printer Assigned"));
    final bytes = await _ticketGenerator.generateBill(order, tableId, sub, tax, total);
    await _printBytes(printer, bytes);
  }

  Future<void> testPrint(PrinterModel printer) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes += generator.text('TEST PRINT SUCCESS', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.feed(2);
    bytes += generator.cut();
    await _printBytes(printer, bytes);
  }

  Future<void> _printBytes(PrinterModel printer, List<int> bytes) async {
    try {
      if (printer.type == PrinterType.network) {
        if (kIsWeb) {
          throw Exception("Network printing not supported on Web directly");
        }
        await _printNetwork(printer, bytes);
      } else if (printer.type == PrinterType.bluetooth) {
        await _printBluetooth(printer, bytes);
      } else {
        throw Exception("USB Printing not fully implemented yet");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _printNetwork(PrinterModel printer, List<int> bytes) async {
    // Basic TCP Socket implementation
    // Note: This won't work on Web
    try {
      final socket = await Socket.connect(printer.address, printer.port ?? 9100, timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } catch (e) {
      throw Exception("Could not connect to Network Printer: $e");
    }
  }

  Future<void> _printBluetooth(PrinterModel printer, List<int> bytes) async {
    // Classic BT path (Android): MAC addresses contain ':' (e.g., 00:1B:10:73:AD:08)
    if (!kIsWeb && Platform.isAndroid && printer.address.contains(':')) {
      bool isConnected = false;
      try {
        isConnected = await PrintBluetoothThermal.connectionStatus;
        if (isConnected) {
          try {
            await PrintBluetoothThermal.disconnect;
          } catch (_) {}
          isConnected = false;
        }
      } catch (_) {
        isConnected = false;
      }

      try {
        if (!isConnected) {
          final connected = await PrintBluetoothThermal.connect(
            macPrinterAddress: printer.address,
          );
          if (!connected) {
            throw Exception("Failed to connect to Classic BT printer");
          }
        }
      } catch (e) {
        throw Exception("Failed to connect to Classic BT printer: $e");
      }
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (ok != true) {
        throw Exception("Write failed on Classic BT printer");
      }
      return;
    }

    // BLE path
    final device = BluetoothDevice.fromId(printer.address);
    try {
      await device.connect();
    } catch (e) {
      // If we can't connect, we can't discover services.
      throw Exception("Could not connect to BLE printer: $e");
    }

    if (device.isConnected == false) {
       // Double check connection status
       try {
          await device.connect();
       } catch (e) {
          throw Exception("Could not connect to BLE printer (retry failed): $e");
       }
    }
    
    List<BluetoothService> services = await device.discoverServices();
    BluetoothCharacteristic? targetChar;
    for (var service in services) {
      for (var char in service.characteristics) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          targetChar = char;
          break;
        }
      }
      if (targetChar != null) break;
    }
    if (targetChar == null) {
      throw Exception("No writable characteristic found on printer");
    }
    const int chunkSize = 20;
    for (var i = 0; i < bytes.length; i += chunkSize) {
      var end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      await targetChar.write(bytes.sublist(i, end), withoutResponse: targetChar.properties.writeWithoutResponse);
    }
    try { await device.disconnect(); } catch (_) {}
  }
}
