import 'cart_item.dart';

class Order {
  final String id;
  final String table;
  String status;
  final List<CartItem> items;
  final double total;
  final String time;
  String? paymentMethod;
  final int? createdAt;
  final int? readyAt;
  final int? settledAt;

  Order({
    required this.id,
    required this.table,
    required this.status,
    required this.items,
    required this.total,
    required this.time,
    this.paymentMethod,
    this.createdAt,
    this.readyAt,
    this.settledAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'table': table,
        'status': status,
        'items': items.map((i) => i.toJson()).toList(),
        'total': total,
        'time': time,
        'paymentMethod': paymentMethod,
        'createdAt': createdAt,
        'readyAt': readyAt,
        'settledAt': settledAt,
      };

  factory Order.fromJson(Map<String, dynamic> json) {
    int? parseTimestamp(dynamic val) {
      if (val == null) return null;
      if (val is int) return val < 1000000000000 ? val * 1000 : val;
      if (val is String) {
        final parsed = int.tryParse(val);
        if (parsed == null) return null;
        return parsed < 1000000000000 ? parsed * 1000 : parsed;
      }
      return null;
    }
    String parseStringKey(Map<String, dynamic> m, String a, {String? b, String? fallback}) {
      final v = m[a] ?? (b != null ? m[b] : null);
      if (v == null) return fallback ?? '';
      return v.toString();
    }
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }
    List<CartItem> parseItems(dynamic raw) {
      final list = raw is List ? raw : (raw is Map ? raw.values.toList() : const []);
      return list.map((i) => CartItem.fromJson(Map<String, dynamic>.from(i as Map))).toList();
    }

    final created = parseTimestamp(json['createdAt']);
    final ready = parseTimestamp(json['readyAt']);
    final settled = parseTimestamp(json['settledAt']);
    final idStr = parseStringKey(json, 'id', fallback: created != null ? 'ORD$created' : 'ORD${DateTime.now().millisecondsSinceEpoch}');
    final tableStr = parseStringKey(json, 'table', b: 'table_label', fallback: 'Unknown');
    final statusStr = parseStringKey(json, 'status', fallback: (settled != null) ? 'Settled' : 'Preparing');
    final timeStr = parseStringKey(json, 'time', fallback: () {
      final ts = settled ?? ready ?? created ?? DateTime.now().millisecondsSinceEpoch;
      final t = DateTime.fromMillisecondsSinceEpoch(ts);
      return '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
    }());
    final pm = json['paymentMethod'] ?? json['payment_method'];
    return Order(
      id: idStr,
      table: tableStr,
      status: statusStr,
      items: parseItems(json['items']),
      total: parseDouble(json['total']),
      time: timeStr,
      paymentMethod: pm?.toString(),
      createdAt: created,
      readyAt: ready,
      settledAt: settled,
    );
  }

  Order copyWith({
    String? id,
    String? table,
    String? status,
    List<CartItem>? items,
    double? total,
    String? time,
    String? paymentMethod,
    int? createdAt,
    int? readyAt,
    int? settledAt,
  }) {
    return Order(
      id: id ?? this.id,
      table: table ?? this.table,
      status: status ?? this.status,
      items: items ?? this.items,
      total: total ?? this.total,
      time: time ?? this.time,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      readyAt: readyAt ?? this.readyAt,
      settledAt: settledAt ?? this.settledAt,
    );
  }
}
