class TableInfo {
  final int id;
  final int number;
  String status;
  final int capacity;
  String? orderId;

  TableInfo({
    required this.id,
    required this.number,
    required this.status,
    required this.capacity,
    this.orderId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'status': status,
        'capacity': capacity,
        'orderId': orderId,
      };

  factory TableInfo.fromJson(Map<String, dynamic> json) => TableInfo(
        id: json['id'],
        number: json['number'],
        status: json['status'],
        capacity: json['capacity'],
        orderId: json['orderId'],
      );
}
