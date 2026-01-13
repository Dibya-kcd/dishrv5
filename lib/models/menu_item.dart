class MenuItem {
  final int id;
  final String name;
  final String category;
  final int price;
  final String image;
  final bool soldOut;
  final List<Map<String, dynamic>> modifiers;
  final List<int> upsellIds;
  final List<String> instructionTemplates;
  final List<String> specialFlags;
  final List<String> availableDays;
  final String? availableStart;
  final String? availableEnd;
  final bool seasonal;
  final List<Map<String, dynamic>> ingredients;
  final int? stock;

  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.image,
    this.soldOut = false,
    this.modifiers = const [],
    this.upsellIds = const [],
    this.instructionTemplates = const [],
    this.specialFlags = const [],
    this.availableDays = const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
    this.availableStart,
    this.availableEnd,
    this.seasonal = false,
    this.ingredients = const [],
    this.stock,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'price': price,
        'image': image,
        'soldOut': soldOut,
        'modifiers': modifiers,
        'upsellIds': upsellIds,
        'instructionTemplates': instructionTemplates,
        'specialFlags': specialFlags,
        'availableDays': availableDays,
        'availableStart': availableStart,
        'availableEnd': availableEnd,
        'seasonal': seasonal,
        'ingredients': ingredients,
        'stock': stock,
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        price: json['price'],
        image: json['image'],
        soldOut: json['soldOut'] ?? false,
        modifiers: (json['modifiers'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
        upsellIds: (json['upsellIds'] as List?)?.map((e) => int.tryParse(e.toString()) ?? -1).where((v) => v >= 0).toList() ?? const [],
        instructionTemplates: (json['instructionTemplates'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        specialFlags: (json['specialFlags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        availableDays: (json['availableDays'] as List?)?.map((e) => e.toString()).toList() ?? const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
        availableStart: json['availableStart'] as String?,
        availableEnd: json['availableEnd'] as String?,
        seasonal: json['seasonal'] ?? false,
        ingredients: (json['ingredients'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? const [],
        stock: json['stock'] != null ? int.tryParse(json['stock'].toString()) : null,
      );
}
