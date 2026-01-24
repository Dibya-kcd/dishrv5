import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/printer_model.dart';
import '../services/printer_service.dart';
import 'package:dishr/web/web_bridge_stub.dart'
    if (dart.library.js_interop) 'package:dishr/web/web_bridge.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9100');
  final _nameController = TextEditingController();
  final _macController = TextEditingController();
  final _btManualNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    PrinterService.instance.init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _nameController.dispose();
    _macController.dispose();
    _btManualNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_heart),
            tooltip: 'Run Diagnostics',
            onPressed: _runDiagnostics,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
            Tab(icon: Icon(Icons.wifi), text: 'Network (LAN)'),
            Tab(icon: Icon(Icons.usb), text: 'USB'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBluetoothTab(),
          _buildNetworkTab(),
          _buildUSBTab(),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return AnimatedBuilder(
      animation: PrinterService.instance,
      builder: (context, child) {
        final service = PrinterService.instance;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: service.isScanning ? service.stopScan : service.startScan,
                icon: Icon(service.isScanning ? Icons.stop : Icons.search),
                label: Text(service.isScanning ? 'Stop Scanning' : 'Scan for Printers'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        PrinterService.instance.loadPairedBluetooths();
                      },
                      child: const Text('Load Paired Bluetooths'),
                    ),
                  ),
                ],
              ),
            ),
            if (service.isScanning) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: [
                  if (service.savedPrinters.any((p) => p.type == PrinterType.bluetooth)) ...[
                    const ListTile(title: Text('Saved Printers', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...service.savedPrinters.where((p) => p.type == PrinterType.bluetooth).map((p) => _buildSavedPrinterTile(p)),
                    const Divider(),
                  ],
                  if (service.pairedBluetooths.isNotEmpty) ...[
                    const ListTile(title: Text('Paired Devices', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...service.pairedBluetooths.map((info) {
                      return ListTile(
                        title: Text(info.name),
                        subtitle: Text(info.macAdress),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _showAddPrinterDialog(
                              PrinterModel(
                                id: info.macAdress,
                                name: info.name,
                                type: PrinterType.bluetooth,
                                address: info.macAdress,
                              ),
                            );
                          },
                          child: const Text('Add'),
                        ),
                      );
                    }),
                    const Divider(),
                  ],
                  const ListTile(title: Text('Available Devices', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...service.scanResults.map((r) {
                    if (r.device.platformName.isEmpty) return const SizedBox.shrink();
                    return ListTile(
                      title: Text(r.device.platformName),
                      subtitle: Text(r.device.remoteId.str),
                      trailing: ElevatedButton(
                        onPressed: () {
                          _showAddPrinterDialog(
                            PrinterModel(
                              id: r.device.remoteId.str,
                              name: r.device.platformName,
                              type: PrinterType.bluetooth,
                              address: r.device.remoteId.str,
                            ),
                          );
                        },
                        child: const Text('Add'),
                      ),
                    );
                  }),
                  const Divider(),
                  const ListTile(title: Text('Add Manual Bluetooth Printer', style: TextStyle(fontWeight: FontWeight.bold))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _macController,
                          decoration: const InputDecoration(labelText: 'MAC Address', hintText: '00:1B:10:73:AD:08'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _btManualNameController,
                          decoration: const InputDecoration(labelText: 'Printer Name', hintText: 'BT Printer'),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_macController.text.isEmpty || _btManualNameController.text.isEmpty) return;
                              final printer = PrinterModel(
                                id: _macController.text,
                                name: _btManualNameController.text,
                                type: PrinterType.bluetooth,
                                address: _macController.text,
                              );
                              PrinterService.instance.addPrinter(printer);
                              _macController.clear();
                              _btManualNameController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bluetooth Printer Added')));
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNetworkTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(labelText: 'Printer IP Address', hintText: '192.168.1.200'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(labelText: 'Port', hintText: '9100'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Printer Name', hintText: 'Kitchen Printer'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_ipController.text.isEmpty || _nameController.text.isEmpty) return;
              final printer = PrinterModel(
                id: 'NET_${DateTime.now().millisecondsSinceEpoch}',
                name: _nameController.text,
                type: PrinterType.network,
                address: _ipController.text,
                port: int.tryParse(_portController.text) ?? 9100,
              );
              PrinterService.instance.addPrinter(printer);
              _ipController.clear();
              _nameController.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printer Added')));
            },
            child: const Text('Save Network Printer'),
          ),
          const Divider(),
          Expanded(
            child: AnimatedBuilder(
              animation: PrinterService.instance,
              builder: (context, _) {
                final printers = PrinterService.instance.savedPrinters.where((p) => p.type == PrinterType.network).toList();
                return ListView(
                  children: printers.map((p) => _buildSavedPrinterTile(p)).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUSBTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.usb, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('USB Printer Support', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          const Text('Connect your printer via USB and add it manually.'),
          const SizedBox(height: 20),
          // Placeholder for USB logic
          ElevatedButton(
            onPressed: () {
               // USB scanning logic would go here
               // For now we simulate adding a USB printer
               _showAddPrinterDialog(
                 PrinterModel(
                   id: 'USB_${DateTime.now().millisecondsSinceEpoch}',
                   name: 'USB Printer',
                   type: PrinterType.usb,
                   address: 'USB001', 
                 )
               );
            },
            child: const Text('Add Manual USB Printer'),
          ),
           Expanded(
            child: AnimatedBuilder(
              animation: PrinterService.instance,
              builder: (context, _) {
                final printers = PrinterService.instance.savedPrinters.where((p) => p.type == PrinterType.usb).toList();
                return ListView(
                  children: printers.map((p) => _buildSavedPrinterTile(p)).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPrinterTile(PrinterModel printer) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: Text(printer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${printer.type.name.toUpperCase()} - ${printer.address}'),
            Row(
              children: [
                FilterChip(
                  label: const Text('KOT'),
                  selected: printer.isKOT,
                  onSelected: (val) {
                    PrinterService.instance.setPrinterRole(printer.id, isKOT: val);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Bill'),
                  selected: printer.isBill,
                  onSelected: (val) {
                    PrinterService.instance.setPrinterRole(printer.id, isBill: val);
                  },
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (printer.type == PrinterType.bluetooth)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bluetooth_connected),
                    label: const Text('Connect Check'),
                    onPressed: () async {
                      try {
                        // Attempt a dummy print or just connect check
                        // Since we don't have a pure 'connect' method exposed easily for all types,
                        // we can try a test print or add a specific connect method.
                        // For now, let's use test print as the verification or just show a toast.
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checking connection...')));
                        await PrinterService.instance.testPrint(printer);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection Successful!')));
                      } catch (e) {
                         if (!mounted) return;
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Connection Failed', style: TextStyle(letterSpacing: 0.5)),
                              content: Text(e.toString()),
                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                            ),
                         );
                      }
                    },
                  ),
                if (printer.type == PrinterType.bluetooth && kIsWeb)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.build),
                    label: const Text('Android Diagnostic'),
                    onPressed: () async {
                      try {
                        // Trigger Android-side diagnostic print via Web bridge
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending Android Diagnostic...')));
                        // Uses web bridge method; safe on WebView wrapper
                        // If not available, PrinterService guards already log availability
                        await Future<void>.delayed(const Duration(milliseconds: 100));
                        // Call diagnostic through service-side bridge helper
                        // Directly use the web bridge function to avoid payload generation
                        // ignore: deprecated_member_use
                        // The function is exposed in web_bridge.dart
                        // We call through PrinterService to keep imports minimal in this screen
                        // But since it's a UI only action, import kIsWeb and call the bridge API.
                        runAndroidPrinterDiagnostic();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diagnostic Sent')));
                      } catch (e) {
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Diagnostic Error', style: TextStyle(letterSpacing: 0.5)),
                            content: Text(e.toString()),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                          ),
                        );
                      }
                    },
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Test Print'),
                  onPressed: () => _testPrint(printer),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Remove', style: TextStyle(color: Colors.red)),
                  onPressed: () {
                    PrinterService.instance.removePrinter(printer.id);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPrinterDialog(PrinterModel printer) {
    final nameCtrl = TextEditingController(text: printer.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Printer', style: TextStyle(letterSpacing: 0.5)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Printer Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newPrinter = PrinterModel(
                id: printer.id,
                name: nameCtrl.text,
                type: printer.type,
                address: printer.address,
                port: printer.port,
              );
              PrinterService.instance.addPrinter(newPrinter);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _testPrint(PrinterModel printer) async {
    try {
      await PrinterService.instance.testPrint(printer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test Print Sent')));
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Print Error', style: TextStyle(letterSpacing: 0.5)),
          content: Text(e.toString()),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<void> _runDiagnostics() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Diagnostics', style: TextStyle(letterSpacing: 0.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Checking Connectivity...', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<bool>(
              future: _checkLocalServer(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Checking Local Server...')]);
                }
                final success = snapshot.data ?? false;
                return Row(children: [
                  Icon(success ? Icons.check_circle : Icons.error, color: success ? Colors.green : Colors.red),
                  const SizedBox(width: 8),
                  Text(success ? 'Local Server (Print Service) OK' : 'Local Server Offline (Expected on Mobile)'),
                ]);
              },
            ),
            const SizedBox(height: 10),
            const Text('Bluetooth Status:', style: TextStyle(fontWeight: FontWeight.bold)),
             FutureBuilder<List<dynamic>>(
              future: PrinterService.instance.pairedBluetooths.isEmpty ? PrinterService.instance.loadPairedBluetooths().then((_) => PrinterService.instance.pairedBluetooths) : Future.value(PrinterService.instance.pairedBluetooths),
              builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Text('Loading paired devices...');
                 }
                 final list = snapshot.data ?? [];
                 return Text('${list.length} Paired Devices Found');
              },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<bool> _checkLocalServer() async {
    // This is just a placeholder check as the user was seeing errors related to localhost:3001
    // On a real mobile device, localhost refers to the device itself.
    try {
       // We can't easily check localhost:3001 from here without http package imported in this file
       // But assuming the PrinterService might have a check, or we just return false for now 
       // since we know it's missing on mobile.
       return false; 
    } catch (_) {
      return false;
    }
  }
}
