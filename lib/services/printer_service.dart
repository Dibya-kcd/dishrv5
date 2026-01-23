import 'dart:async';
import 'dart:convert';
import 'dart:io' show Socket;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_model.dart';
import '../utils/ticket_generator.dart';
import 'package:dishr/web/web_bridge_stub.dart'
    if (dart.library.js_interop) 'package:dishr/web/web_bridge.dart';

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
  static final RegExp _classicMacRegex = RegExp(r'^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}$');

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

  PrinterType _detectPrinterType(String address) {
    final upper = address.toUpperCase();
    debugPrint('=== Detecting printer type ===');
    debugPrint('Address: $upper');
    final isClassic = _classicMacRegex.hasMatch(upper);
    final detected = isClassic ? PrinterType.bluetooth : PrinterType.ble;
    debugPrint('Detected type: ${isClassic ? "Classic Bluetooth" : "BLE"}');
    debugPrint('Will use: ${isClassic ? "Android bridge" : "flutter_blue_plus"}');
    return detected;
  }

  Future<List<PrinterModel>> _scanClassicBluetooth() async {
    debugPrint('=== Scanning Classic Bluetooth (paired devices) ===');
    try {
      if (kIsWeb) {
        final list = getAndroidPairedPrinters();
        final printers = list
            .map((info) => PrinterModel(
                  id: info['address'] ?? '',
                  name: info['name'] ?? '',
                  type: PrinterType.bluetooth,
                  address: info['address'] ?? '',
                ))
            .toList();
        debugPrint('Classic scan (web bridge) found: ${printers.length} devices');
        return printers;
      }
      final list = await PrintBluetoothThermal.pairedBluetooths;
      final printers = list
          .map((info) => PrinterModel(
                id: info.macAdress,
                name: info.name,
                type: PrinterType.bluetooth,
                address: info.macAdress,
              ))
          .toList();
      debugPrint('Classic scan found: ${printers.length} devices');
      return printers;
    } catch (e) {
      debugPrint('Classic scan error: $e');
      return [];
    }
  }

  Future<List<PrinterModel>> _scanBLE() async {
    debugPrint('=== Scanning BLE via flutter_blue_plus ===');
    final List<PrinterModel> result = [];
    try {
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint('BLE not supported on this platform');
        return [];
      }
      await FlutterBluePlus.startScan(
        withServices: kIsWeb ? _printerServices : [],
        timeout: const Duration(seconds: 8),
      );
      final sub = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        notifyListeners();
      });
      await Future.delayed(const Duration(seconds: 8));
      await FlutterBluePlus.stopScan();
      await sub.cancel();
      for (final r in _scanResults) {
        final name = r.device.platformName;
        final id = r.device.remoteId.str;
        if (name.isEmpty) continue;
        // Treat as BLE route by address format (non classic MAC)
        if (!_classicMacRegex.hasMatch(id.toUpperCase())) {
          result.add(PrinterModel(
            id: id,
            name: name,
            type: PrinterType.ble,
            address: id,
          ));
        }
      }
      debugPrint('BLE scan found: ${result.length} devices');
    } catch (e) {
      debugPrint('BLE scan error: $e');
    }
    return result;
  }

  Future<List<PrinterModel>> scanForAllPrinters() async {
    debugPrint('=== Dual scanning: Classic + BLE ===');
    final classic = await _scanClassicBluetooth();
    final ble = await _scanBLE();
    final merged = [...classic];
    // Avoid duplicates: prefer classic entries for MAC-matching addresses
    for (final p in ble) {
      final isDup = classic.any((c) => c.address == p.address);
      if (!isDup) merged.add(p);
    }
    debugPrint('Merged scan total: ${merged.length}');
    return merged;
  }

  // Bluetooth Scanning (kept for UI compatibility)
  Future<void> startScan() async {
    if (_isScanning) return;
    _scanResults.clear();
    _isScanning = true;
    notifyListeners();

    try {
      // Use unified dual scan for better UX; keep internal scanResults for BLE view
      final merged = await scanForAllPrinters();
      // Update paired list for classic display
      if (!kIsWeb) {
        _pairedBluetooths = await PrintBluetoothThermal.pairedBluetooths;
      } else {
        _pairedBluetooths = [];
      }
      // Also keep BLE scanResults so existing UI shows raw BLE results
      // (already updated by _scanBLE listener)
      // Expose merged printers to saved list preview if needed
      debugPrint('Dual scan completed. classic=${_pairedBluetooths.length}, ble=${_scanResults.length}, merged=${merged.length}');
    } catch (e) {
      debugPrint('startScan error: $e');
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

  Future<void> testPrint(PrinterModel printer) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes += generator.text('TEST PRINT SUCCESS', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.feed(2);
    bytes += generator.cut();
    await _printBytes(printer, bytes);
  }

  // Unified byte generation wrappers
  Future<List<int>> _generateKOTBytes(Map<String, dynamic> order, String tableId, String type) async {
    debugPrint('=== Generating KOT bytes ===');
    return await _ticketGenerator.generateKOT(order, tableId, type);
  }

  Future<List<int>> _generateBillBytes(Map<String, dynamic> order, String tableId, double sub, double tax, double total) async {
    debugPrint('=== Generating Bill bytes ===');
    return await _ticketGenerator.generateBill(order, tableId, sub, tax, total);
  }

  Future<bool> connectToPrinter(PrinterModel printer) async {
    debugPrint('=== Connecting to printer ===');
    debugPrint('Name: ${printer.name}');
    debugPrint('Address: ${printer.address}');
    final detected = _detectPrinterType(printer.address);
    debugPrint('Printer.type: ${printer.type} • Detected: $detected');
    if (printer.type == PrinterType.bluetooth) {
      return await _connectClassicBluetooth(printer);
    } else if (printer.type == PrinterType.ble) {
      return await _connectBLE(printer);
    } else if (printer.type == PrinterType.network) {
      // network connection is done during print
      return true;
    } else {
      return false;
    }
  }

  Future<bool> _connectClassicBluetooth(PrinterModel printer) async {
    debugPrint('Route: Android bridge (Classic BT)');
    try {
      if (kIsWeb) {
        setAndroidPrinterMac(printer.address);
        connectToAndroidPrinter(printer.address);
        final ok = checkAndroidPrinterConnection();
        debugPrint('Classic connect (web bridge) result: $ok');
        return ok;
      }
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: printer.address);
      debugPrint('Classic connect result: $ok');
      return ok == true;
    } catch (e) {
      debugPrint('Classic connect error: $e');
      return false;
    }
  }

  Future<bool> _connectBLE(PrinterModel printer) async {
    debugPrint('Route: flutter_blue_plus (BLE)');
    try {
      final device = BluetoothDevice.fromId(printer.address);
      await device.connect();
      final connected = device.isConnected;
      debugPrint('BLE connect result: $connected');
      return connected;
    } catch (e) {
      debugPrint('BLE connect error: $e');
      return false;
    }
  }

  Future<void> _printBytes(PrinterModel printer, List<int> bytes) async {
    try {
      if (printer.type == PrinterType.network) {
        if (kIsWeb) {
          throw Exception("Network printing not supported on Web directly");
        }
        await _printNetwork(printer, bytes);
      } else if (printer.type == PrinterType.bluetooth) {
        debugPrint('=== Printing (Classic Bluetooth) ===');
        debugPrint('Data length: ${bytes.length} bytes');
        debugPrint('Printer address: ${printer.address}');
        final b64 = base64Encode(bytes);
        debugPrint('Using Android bridge • payload (base64) size: ${b64.length}');
        await _printViaAndroidBridgeBase64(printer, b64);
      } else if (printer.type == PrinterType.ble) {
        debugPrint('=== Printing (BLE) ===');
        debugPrint('Data length: ${bytes.length} bytes');
        debugPrint('Printer address: ${printer.address}');
        debugPrint('Using flutter_blue_plus');
        await _printViaBLE(printer, bytes);
      } else {
        throw Exception("USB Printing not fully implemented yet");
      }
    } catch (e) {
      debugPrint('Print error: $e');
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

  Future<void> _printViaAndroidBridgeBase64(PrinterModel printer, String base64Data) async {
    if (kIsWeb) {
      setAndroidPrinterMac(printer.address);
      printToAndroidPrinterBase64(base64Data);
      return;
    }
    try {
      final connected = await PrintBluetoothThermal.connect(macPrinterAddress: printer.address);
      if (connected != true) {
        throw Exception("Classic BT connect failed");
      }
      final bytes = base64Decode(base64Data);
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (ok != true) {
        throw Exception("Classic BT write failed");
      }
    } catch (e) {
      throw Exception("Android bridge print error: $e");
    }
  }

  Future<void> _printViaBLE(PrinterModel printer, List<int> bytes) async {
    final device = BluetoothDevice.fromId(printer.address);
    try {
      await device.connect();
      debugPrint('BLE connected: ${device.isConnected}');
    } catch (e) {
      throw Exception("Could not connect to BLE printer: $e");
    }
    try {
      List<BluetoothService> services = await device.discoverServices();
      debugPrint('BLE services discovered: ${services.length}');
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
        final chunk = bytes.sublist(i, end);
        await targetChar.write(chunk, withoutResponse: targetChar.properties.writeWithoutResponse);
      }
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  Future<void> printKOT(Map<String, dynamic> order, String tableId, String type) async {
    final printer = _savedPrinters.firstWhere((p) => p.isKOT, orElse: () => throw Exception("No KOT Printer Assigned"));
    final bytes = await _generateKOTBytes(order, tableId, type);
    await _printBytes(printer, bytes);
  }

  Future<void> printBill(Map<String, dynamic> order, String tableId, double sub, double tax, double total) async {
    final printer = _savedPrinters.firstWhere((p) => p.isBill, orElse: () => throw Exception("No Bill Printer Assigned"));
    final bytes = await _generateBillBytes(order, tableId, sub, tax, total);
    await _printBytes(printer, bytes);
  }
}
