import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/printer_model.dart';
import '../services/printer_service.dart';

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

        // Web/PWA specific UI
        if (kIsWeb) {
             return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      color: Colors.orangeAccent.withValues(alpha: 0.2), 
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "PWA Mode: Bluetooth scanning is not supported in the browser/webview.\n"
                          "Please add your printer manually using its MAC Address (e.g., 00:1B:10:73:AD:08).",
                          style: TextStyle(fontSize: 14),
                        ),
                      )
                    ),
                  ),
                  if (service.savedPrinters.any((p) => p.type == PrinterType.bluetooth)) ...[
                    const ListTile(title: Text('Saved Printers', style: TextStyle(fontWeight: FontWeight.bold))),
                    ...service.savedPrinters.where((p) => p.type == PrinterType.bluetooth).map((p) => _buildSavedPrinterTile(p)),
                    const Divider(),
                  ],
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
                              final mac = _macController.text.trim();
                              final name = _btManualNameController.text.trim();
                              final macRegex = RegExp(r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$');
                              if (mac.isEmpty || name.isEmpty) return;
                              if (!macRegex.hasMatch(mac)) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid MAC Address')));
                                return;
                              }
                              final printer = PrinterModel(
                                id: mac,
                                name: name,
                                type: PrinterType.bluetooth,
                                address: mac,
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
             );
        }

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
                              final mac = _macController.text.trim();
                              final name = _btManualNameController.text.trim();
                              final macRegex = RegExp(r'^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$');
                              if (mac.isEmpty || name.isEmpty) return;
                              if (!macRegex.hasMatch(mac)) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid MAC Address')));
                                return;
                              }
                              final printer = PrinterModel(
                                id: mac,
                                name: name,
                                type: PrinterType.bluetooth,
                                address: mac,
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
      color: printer.isConnected ? Colors.green.withValues(alpha: 0.12) : null,
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
}
