class CartItem {
  final int id;
  final String name;
  final int price;
  final int quantity;
  final String image;
  final String? instructions;
  final List<int>? addons;
  final List<Map<String, dynamic>>? modifiers;
  final bool isCancelled;
  final String? cancellationReason;
  final String? cancelledBy;
  final int? cancelledAt;

  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.image,
    this.instructions,
    this.addons,
    this.modifiers,
    this.isCancelled = false,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
  });

  CartItem copyWith({
    int? quantity,
    String? instructions,
    List<int>? addons,
    List<Map<String, dynamic>>? modifiers,
    bool? isCancelled,
    String? cancellationReason,
    String? cancelledBy,
    int? cancelledAt,
  }) =>
      CartItem(
        id: id,
        name: name,
        price: price,
        quantity: quantity ?? this.quantity,
        image: image,
        instructions: instructions ?? this.instructions,
        addons: addons ?? this.addons,
        modifiers: modifiers ?? this.modifiers,
        isCancelled: isCancelled ?? this.isCancelled,
        cancellationReason: cancellationReason ?? this.cancellationReason,
        cancelledBy: cancelledBy ?? this.cancelledBy,
        cancelledAt: cancelledAt ?? this.cancelledAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'quantity': quantity,
        'image': image,
        'instructions': instructions,
        'addons': addons,
        'modifiers': modifiers,
        'isCancelled': isCancelled,
        'cancellationReason': cancellationReason,
        'cancelledBy': cancelledBy,
        'cancelledAt': cancelledAt,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'],
        name: json['name'],
        price: json['price'],
        quantity: json['quantity'],
        image: json['image'],
        instructions: json['instructions'],
        addons: (json['addons'] as List?)?.map((e) => e as int).toList(),
        modifiers: (json['modifiers'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        isCancelled: json['isCancelled'] ?? false,
        cancellationReason: json['cancellationReason'],
        cancelledBy: json['cancelledBy'],
        cancelledAt: json['cancelledAt'],
      );
}
