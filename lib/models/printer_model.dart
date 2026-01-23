enum PrinterType { bluetooth, ble, network, usb }

class PrinterModel {
  final String id;
  final String name;
  final PrinterType type;
  final String address; // MAC for BT, IP for Network, ID for USB
  final int? port; // For Network
  bool isKOT;
  bool isBill;

  PrinterModel({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.port,
    this.isKOT = false,
    this.isBill = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'address': address,
      'port': port,
      'isKOT': isKOT,
      'isBill': isBill,
    };
  }

  factory PrinterModel.fromJson(Map<String, dynamic> json) {
    return PrinterModel(
      id: json['id'],
      name: json['name'],
      type: PrinterType.values.firstWhere((e) => e.toString() == json['type']),
      address: json['address'],
      port: json['port'],
      isKOT: json['isKOT'] ?? false,
      isBill: json['isBill'] ?? false,
    );
  }
}
