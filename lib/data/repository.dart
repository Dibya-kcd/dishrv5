import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqlite_api.dart';
import '../data/db.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../models/table_info.dart';
import 'sync_service.dart';

class Repository {
  Repository._();
  static final Repository instance = Repository._();
  final AppDatabase _db = AppDatabase();
  final menu = MenuDao();
  final orders = OrderDao();
  final tables = TablesDao();
  final expenses = ExpensesDao();
  final settings = SettingsDao();
  final ingredients = IngredientsDao();
  final employees = EmployeesDao();
  Future<void> clearAllLocalData() async {
    final db = await _db.database;
    await db.delete('order_items');
    await db.delete('order_events');
    await db.delete('orders');
    await db.delete('tables');
    await db.delete('menu_items');
    await db.delete('expenses');
    await db.delete('employees');
    await db.delete('recipes');
    await db.delete('inventory_txns');
    await db.delete('ingredients');
    await db.delete('settings');
    await settings.set('seed_vmo', '1');
    notifyDataChanged();
  }

  final _controller = StreamController<void>.broadcast();
  Stream<void> get onDataChanged => _controller.stream;

  void notifyDataChanged() {
    _controller.add(null);
  }


  Future<void> init() async {
    await _db.database;
    SyncService.instance.init();
    final seeded = await settings.get('seed_vmo');
    if (seeded != '1') {
      // No dummy ingredients inserted
      await settings.set('seed_vmo', '1');
    }
    // No dummy employees inserted
  }
}

class MenuDao {
  Future<void> insertMenuItem(MenuItem m, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.insert('menu_items', {
      'id': m.id,
      'name': m.name,
      'category': m.category,
      'price': m.price,
      'image': m.image,
      'sold_out': m.soldOut ? 1 : 0,
      'modifiers': jsonEncode(m.modifiers),
      'upsell_ids': jsonEncode(m.upsellIds),
      'instruction_templates': jsonEncode(m.instructionTemplates),
      'special_flags': jsonEncode(m.specialFlags),
      'available_days': jsonEncode(m.availableDays),
      'available_start': m.availableStart,
      'available_end': m.availableEnd,
      'stock': m.stock,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (!fromSync) await SyncService.instance.updateMenuItem(m);
  }
  Future<void> updateMenuItem(MenuItem m, {bool fromSync = false}) => insertMenuItem(m, fromSync: fromSync);
  Future<void> deleteMenuItem(int id, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.delete('menu_items', where: 'id = ?', whereArgs: [id]);
    if (!fromSync) await SyncService.instance.deleteMenuItem(id);
  }
  Future<void> toggleSoldOut(int id, bool value, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.update('menu_items', {'sold_out': value ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    
    if (!fromSync) {
      final rows = await db.query('menu_items', where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        final m = _fromRow(rows.first);
        await SyncService.instance.updateMenuItem(m);
      }
    }
  }
  Future<void> upsertMenuItems(List<MenuItem> items, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    final batch = db.batch();
    for (final m in items) {
      batch.insert('menu_items', {
        'id': m.id,
        'name': m.name,
        'category': m.category,
        'price': m.price,
        'image': m.image,
        'sold_out': m.soldOut ? 1 : 0,
        'modifiers': jsonEncode(m.modifiers),
        'upsell_ids': jsonEncode(m.upsellIds),
        'instruction_templates': jsonEncode(m.instructionTemplates),
        'special_flags': jsonEncode(m.specialFlags),
        'available_days': jsonEncode(m.availableDays),
        'available_start': m.availableStart,
        'available_end': m.availableEnd,
        'stock': m.stock,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    if (!fromSync) {
      for(var m in items) {
          await SyncService.instance.updateMenuItem(m);
      }
    }
  }

  Future<List<MenuItem>> listMenu() async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('menu_items');
    return rows.map(_fromRow).toList();
  }
  MenuItem _fromRow(Map<String, Object?> row) {
    return MenuItem(
      id: row['id'] as int,
      name: row['name'] as String? ?? '',
      category: row['category'] as String? ?? '',
      price: (row['price'] as num?)?.toInt() ?? 0,
      image: row['image'] as String? ?? '',
      soldOut: (row['sold_out'] as int?) == 1,
      modifiers: _parseListMap(row['modifiers']),
      upsellIds: _parseIntList(row['upsell_ids']),
      instructionTemplates: _parseStringList(row['instruction_templates']),
      specialFlags: _parseStringList(row['special_flags']),
      availableDays: _parseStringList(row['available_days']),
      availableStart: row['available_start'] as String?,
      availableEnd: row['available_end'] as String?,
      seasonal: false,
      ingredients: const [],
      stock: row['stock'] as int?,
    );
  }

  List<Map<String, dynamic>> _parseListMap(Object? val) {
    try {
      if (val == null) return const [];
      final s = val as String;
      if (s.isEmpty) return const [];
      final decoded = jsonDecode(s);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  List<int> _parseIntList(Object? val) {
    try {
      if (val == null) return const [];
      final s = val as String;
      if (s.isEmpty) return const [];
      final decoded = jsonDecode(s);
      if (decoded is List) {
        return decoded.map((e) => int.tryParse(e.toString()) ?? -1).where((v) => v >= 0).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  List<String> _parseStringList(Object? val) {
    try {
      if (val == null) return const [];
      final s = val as String;
      if (s.isEmpty) return const [];
      final decoded = jsonDecode(s);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}

class SettingsDao {
  Future<void> set(String key, String value) async {
    final db = await Repository.instance._db.database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<String?> get(String key) async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }
}
class OrderDao {
  int _getPrio(String s) {
    if (s == 'Settled' || s == 'Cancelled') return 5;
    if (s == 'Completed') return 4;
    if (s == 'Ready') return 3;
    if (s == 'Preparing') return 2;
    return 1;
  }

  Future<void> logEvent(String orderId, String event, {Map<String, dynamic>? data}) async {
    final db = await Repository.instance._db.database;
    await db.insert('order_events', {
      'order_id': orderId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'event': event,
      'data': data != null ? jsonEncode(data) : null,
    });
  }
  Future<void> insertOrder(Order order, List<CartItem> items, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.transaction((txn) async {
      await txn.insert('orders', {
        'id': order.id,
        'table_label': order.table,
        'status': order.status,
        'total': order.total,
        'time': order.time,
        'payment_method': order.paymentMethod,
        'created_at': order.createdAt,
        'ready_at': order.readyAt,
        'settled_at': order.settledAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [order.id]);

      final batch = txn.batch();
      for (final it in items) {
        batch.insert('order_items', {
          'order_id': order.id,
          'menu_item_id': it.id,
          'name_snapshot': it.name,
          'price_snapshot': it.price,
          'quantity': it.quantity,
          'instructions': it.instructions,
          'addons': jsonEncode(it.addons ?? []),
          'modifiers': jsonEncode(it.modifiers ?? []),
        });
      }
      await batch.commit(noResult: true);
    });
    
    final fullOrder = Order(
        id: order.id,
        table: order.table,
        status: order.status,
        items: items,
        total: order.total,
        time: order.time,
        paymentMethod: order.paymentMethod,
        createdAt: order.createdAt,
        readyAt: order.readyAt,
    );
    if (!fromSync) await SyncService.instance.updateOrder(fullOrder);
    await logEvent(order.id, 'sent_to_kitchen', data: {
      'items': items.map((i) => {'id': i.id, 'q': i.quantity}).toList(),
      'table': order.table,
    });
    Repository.instance.notifyDataChanged();
  }
  Future<void> clearAll() async {
    final db = await Repository.instance._db.database;
    await db.delete('order_items');
    await db.delete('orders');
    Repository.instance.notifyDataChanged();
  }
  Future<void> clearAllSynced() async {
    final db = await Repository.instance._db.database;
    await db.delete('order_items');
    await db.delete('orders');
    await SyncService.instance.deleteAllOrders();
    Repository.instance.notifyDataChanged();
  }
  Future<void> deleteOrdersByTableLabel(String tableLabel) async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('orders', where: 'table_label = ?', whereArgs: [tableLabel]);
    for (final r in rows) {
      final id = r['id'] as String;
      await db.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
      await db.delete('orders', where: 'id = ?', whereArgs: [id]);
    }
    Repository.instance.notifyDataChanged();
  }
  Future<void> updateOrderItems(String orderId, List<CartItem> items, double total, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.transaction((txn) async {
      await txn.update('orders', {
        'total': total,
      }, where: 'id = ?', whereArgs: [orderId]);
      await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      final batch = txn.batch();
      for (final it in items) {
        batch.insert('order_items', {
          'order_id': orderId,
          'menu_item_id': it.id,
          'name_snapshot': it.name,
          'price_snapshot': it.price,
          'quantity': it.quantity,
          'instructions': it.instructions,
          'addons': jsonEncode(it.addons ?? []),
          'modifiers': jsonEncode(it.modifiers ?? []),
        });
      }
      await batch.commit(noResult: true);
    });
    
    final orderRow = await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
    if (orderRow.isNotEmpty) {
      final r = orderRow.first;
      final order = Order(
        id: r['id'] as String,
        table: r['table_label'] as String,
        status: r['status'] as String,
        items: items,
        total: (r['total'] as num?)?.toDouble() ?? total,
        time: r['time'] as String? ?? '',
        paymentMethod: r['payment_method'] as String?,
        createdAt: r['created_at'] as int?,
        readyAt: r['ready_at'] as int?,
      );
      if (!fromSync) await SyncService.instance.updateOrder(order);
    }
    Repository.instance.notifyDataChanged();
  }

  Future<void> updateOrderStatus(String id, String status, {String? paymentMethod, int? readyAtMs, bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    final updateMap = <String, Object?>{
      'status': status,
      'payment_method': paymentMethod,
    };
    if (readyAtMs != null) {
      updateMap['ready_at'] = readyAtMs;
    }
    if (status == 'Settled') {
      updateMap['settled_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    await db.update('orders', updateMap, where: 'id = ?', whereArgs: [id]);
    
    // Fetch full order to sync
    // This is expensive but needed for simple sync implementation
    // Ideally we would have partial update in SyncService
    // Optimized fetch:
    if (!fromSync) {
      final orderRow = await db.query('orders', where: 'id = ?', whereArgs: [id]);
      if (orderRow.isNotEmpty) {
           final itemsRows = await db.query('order_items', where: 'order_id = ?', whereArgs: [id]);
           final items = itemsRows.map((r) => CartItem(
              id: (r['menu_item_id'] as num).toInt(),
              name: r['name_snapshot'] as String? ?? '',
              price: (r['price_snapshot'] as num?)?.toInt() ?? 0,
              quantity: (r['quantity'] as num?)?.toInt() ?? 1,
              image: '',
              instructions: r['instructions'] as String?,
              addons: List<int>.from(jsonDecode(r['addons'] as String? ?? '[]') as List),
              modifiers: (jsonDecode(r['modifiers'] as String? ?? '[]') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
           )).toList();
           
           final r = orderRow.first;
           final order = Order(
              id: r['id'] as String,
              table: r['table_label'] as String,
              status: r['status'] as String,
              items: items,
              total: (r['total'] as num?)?.toDouble() ?? 0.0,
              time: r['time'] as String? ?? '',
              paymentMethod: r['payment_method'] as String?,
              createdAt: r['created_at'] as int?,
              readyAt: r['ready_at'] as int?,
              settledAt: r['settled_at'] as int?,
           );
           await SyncService.instance.updateOrder(order);
      }
    }
    Repository.instance.notifyDataChanged();
  }

  Future<List<Order>> listActiveOrders() async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('orders', where: 'status != ?', whereArgs: ['Settled']);
    return rows.map((r) {
      return Order(
        id: r['id'] as String,
        table: r['table_label'] as String,
        status: r['status'] as String,
        items: const [],
        total: (r['total'] as num?)?.toDouble() ?? 0.0,
        time: r['time'] as String? ?? '',
        paymentMethod: r['payment_method'] as String?,
        createdAt: r['created_at'] as int?,
        readyAt: r['ready_at'] as int?,
        settledAt: r['settled_at'] as int?,
      );
    }).toList();
  }
  Future<List<Order>> listOrdersWithItems() async {
    final db = await Repository.instance._db.database;
    final ordersRows = await db.query('orders');
    final itemsRows = await db.query('order_items');
    final itemsByOrder = <String, List<CartItem>>{};
    for (final r in itemsRows) {
      final oid = r['order_id'] as String;
      final list = itemsByOrder.putIfAbsent(oid, () => []);
      list.add(CartItem(
        id: (r['menu_item_id'] as num).toInt(),
        name: r['name_snapshot'] as String? ?? '',
        price: (r['price_snapshot'] as num?)?.toInt() ?? 0,
        quantity: (r['quantity'] as num?)?.toInt() ?? 1,
        image: '',
        instructions: r['instructions'] as String?,
        addons: List<int>.from(jsonDecode(r['addons'] as String? ?? '[]') as List),
        modifiers: (jsonDecode(r['modifiers'] as String? ?? '[]') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      ));
    }
    return ordersRows.map((r) {
      final id = r['id'] as String;
      return Order(
        id: id,
        table: r['table_label'] as String,
        status: r['status'] as String,
        items: itemsByOrder[id] ?? const [],
        total: (r['total'] as num?)?.toDouble() ?? 0.0,
        time: r['time'] as String? ?? '',
        paymentMethod: r['payment_method'] as String?,
        createdAt: r['created_at'] as int?,
        readyAt: r['ready_at'] as int?,
        settledAt: r['settled_at'] as int?,
      );
    }).toList();
  }
  Future<List<Order>> listClosedOrders({int limit = 10}) async {
    final db = await Repository.instance._db.database;
    final rows = await db.query(
      'orders',
      where: 'status = ? OR status = ?',
      whereArgs: ['Settled', 'Completed'],
      orderBy: 'settled_at DESC, created_at DESC',
      limit: limit,
    );
    return rows.map((r) {
      return Order(
        id: r['id'] as String,
        table: r['table_label'] as String,
        status: r['status'] as String,
        items: const [],
        total: (r['total'] as num?)?.toDouble() ?? 0.0,
        time: r['time'] as String? ?? '',
        paymentMethod: r['payment_method'] as String?,
        createdAt: r['created_at'] as int?,
        readyAt: r['ready_at'] as int?,
        settledAt: r['settled_at'] as int?,
      );
    }).toList();
  }
}

class TablesDao {
  Future<void> upsertTable(int id, int number, String status, int capacity, {String? orderId, bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.insert('tables', {
      'id': id,
      'number': number,
      'status': status,
      'capacity': capacity,
      'order_id': orderId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    if (!fromSync) {
      await SyncService.instance.updateTable(TableInfo(
          id: id,
          number: number,
          status: status,
          capacity: capacity,
          orderId: orderId,
      ));
    }
  }
  Future<List<TableInfo>> listTables() async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('tables', where: 'status != ?', whereArgs: ['deleted']);
    return rows.map((r) => TableInfo(
      id: (r['id'] as num).toInt(),
      number: (r['number'] as num).toInt(),
      status: r['status'] as String,
      capacity: (r['capacity'] as num).toInt(),
      orderId: r['order_id'] as String?,
    )).toList();
  }
}

class ExpensesDao {
  Future<void> insertExpense(Map<String, dynamic> e, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    dynamic ts = e['timestamp'];
    int finalTs = 0;
    if (ts is int) {
      finalTs = ts < 1000000000000 ? ts * 1000 : ts;
    } else if (ts is String) {
      final parsed = int.tryParse(ts) ?? 0;
      finalTs = parsed < 1000000000000 ? parsed * 1000 : parsed;
    }
    
    await db.insert('expenses', {
      'id': e['id'],
      'amount': e['amount'],
      'category': e['category'],
      'note': e['note'],
      'timestamp': finalTs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (!fromSync) await SyncService.instance.updateExpense(e);
  }
  Future<List<Map<String, dynamic>>> listExpenses() async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('expenses', orderBy: 'timestamp DESC');
    return rows.map((r) => {
      'id': r['id'] as String,
      'amount': (r['amount'] as num?)?.toDouble() ?? 0.0,
      'category': r['category'] as String? ?? '',
      'note': r['note'] as String? ?? '',
      'timestamp': r['timestamp'] as int? ?? 0,
    }).toList();
  }
  Future<void> deleteExpense(String id, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    if (!fromSync) await SyncService.instance.deleteExpense(id);
  }
}
class EmployeesDao {
  Future<void> upsertEmployee(Map<String, dynamic> e, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    final id = (e['id']?.toString().trim().isNotEmpty == true) ? e['id'].toString() : 'EMP${DateTime.now().millisecondsSinceEpoch}';
    final code = (e['employee_code']?.toString() ?? '').trim();
    final name = (e['name']?.toString() ?? '').trim();
    final role = (e['role']?.toString() ?? '').trim();
    final status = (e['status']?.toString() ?? 'Active').trim();
    final photo = (e['photo']?.toString() ?? '').trim();
    final salaryMap = Map<String, dynamic>.from(e['salary'] as Map? ?? {});
    final deductionsMap = Map<String, dynamic>.from(e['deductions'] as Map? ?? {});
    double gross = 0.0;
    for (final v in salaryMap.values) {
      final n = (v as num?)?.toDouble() ?? 0.0;
      gross += n;
    }
    double totalDed = 0.0;
    for (final v in deductionsMap.values) {
      final n = (v as num?)?.toDouble() ?? 0.0;
      totalDed += n;
    }
    final net = (gross - totalDed).clamp(0.0, double.infinity);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('employees', {
      'id': id,
      'employee_code': code,
      'name': name,
      'role': role,
      'status': status,
      'photo': photo,
      'gross_salary': gross,
      'net_salary': net,
      'personal': jsonEncode(e['personal'] ?? {}),
      'salary': jsonEncode(salaryMap),
      'deductions': jsonEncode(deductionsMap),
      'payment': jsonEncode(e['payment'] ?? {}),
      'employment': jsonEncode(e['employment'] ?? {}),
      'documents': jsonEncode(e['documents'] ?? {}),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (!fromSync) {
      try {
        final payload = {
          'id': id,
          'employee_code': code,
          'name': name,
          'role': role,
          'status': status,
          'photo': photo,
          'gross_salary': gross,
          'net_salary': net,
          'personal': e['personal'] ?? {},
          'salary': salaryMap,
          'deductions': deductionsMap,
          'payment': e['payment'] ?? {},
          'employment': e['employment'] ?? {},
          'documents': e['documents'] ?? {},
          'created_at': now,
          'updated_at': now,
        };
        await SyncService.instance.updateEmployee(payload);
      } catch (_) {}
    }
    Repository.instance.notifyDataChanged();
  }
  Future<void> updateEmployee(Map<String, dynamic> e, {bool fromSync = false}) async => upsertEmployee(e, fromSync: fromSync);
  Future<void> deleteEmployee(String id, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.delete('employees', where: 'id = ?', whereArgs: [id]);
    if (!fromSync) {
      try {
        await SyncService.instance.deleteEmployee(id);
      } catch (_) {}
    }
    Repository.instance.notifyDataChanged();
  }
  Future<List<Map<String, dynamic>>> listEmployees() async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('employees', orderBy: 'updated_at DESC');
    return rows.map((r) => {
      'id': r['id'] as String,
      'employee_code': r['employee_code'] as String? ?? '',
      'name': r['name'] as String? ?? '',
      'role': r['role'] as String? ?? '',
      'status': r['status'] as String? ?? 'Active',
      'photo': r['photo'] as String? ?? '',
      'gross_salary': (r['gross_salary'] as num?)?.toDouble() ?? 0.0,
      'net_salary': (r['net_salary'] as num?)?.toDouble() ?? 0.0,
      'personal': jsonDecode(r['personal'] as String? ?? '{}') as Map<String, dynamic>,
      'salary': jsonDecode(r['salary'] as String? ?? '{}') as Map<String, dynamic>,
      'deductions': jsonDecode(r['deductions'] as String? ?? '{}') as Map<String, dynamic>,
      'payment': jsonDecode(r['payment'] as String? ?? '{}') as Map<String, dynamic>,
      'employment': jsonDecode(r['employment'] as String? ?? '{}') as Map<String, dynamic>,
      'documents': jsonDecode(r['documents'] as String? ?? '{}') as Map<String, dynamic>,
      'created_at': r['created_at'] as int? ?? 0,
      'updated_at': r['updated_at'] as int? ?? 0,
    }).toList();
  }
}
class IngredientsDao {
  double _convertQty(String from, String to, double qty) {
    final f = from.toLowerCase();
    final t = to.toLowerCase();
    if (f == t) return qty;
    if (f == 'kg' && t == 'g') return qty * 1000.0;
    if (f == 'g' && t == 'kg') return qty / 1000.0;
    if (f == 'liter' && t == 'ml') return qty * 1000.0;
    if (f == 'l' && t == 'ml') return qty * 1000.0;
    if (f == 'ml' && t == 'l') return qty / 1000.0;
    return qty;
  }
  Future<void> upsertIngredient(Map<String, dynamic> ing, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    final nameIn = (ing['name']?.toString() ?? '').trim();
    final nameKey = nameIn.toLowerCase();
    final existingRows = await db.query('ingredients', where: 'LOWER(name) = ?', whereArgs: [nameKey], limit: 1);
    if (existingRows.isNotEmpty) {
      final existing = existingRows.first;
      final existingId = existing['id'] as String;
      final incomingId = ing['id']?.toString() ?? existingId;
      if (existingId != incomingId) {
        final existingStock = (existing['stock'] as num?)?.toDouble() ?? 0.0;
        final incomingStock = (ing['stock'] as num?)?.toDouble() ?? 0.0;
        final merged = {
          'name': nameIn.isEmpty ? (existing['name']?.toString() ?? '') : nameIn,
          'category': (ing['category']?.toString() ?? '').trim().isEmpty ? (existing['category']?.toString() ?? '') : ing['category'],
          'base_unit': (ing['base_unit']?.toString() ?? '').trim().isEmpty ? (existing['base_unit']?.toString() ?? '') : ing['base_unit'],
          'stock': existingStock + incomingStock,
          'min_threshold': (ing['min_threshold'] as num?) ?? (existing['min_threshold'] as num? ?? 0.0),
          'supplier': (ing['supplier']?.toString() ?? '').trim().isEmpty ? (existing['supplier']?.toString() ?? '') : ing['supplier'],
        };
        await db.update('ingredients', {
          'name': merged['name'],
          'category': merged['category'],
          'base_unit': merged['base_unit'],
          'stock': (merged['stock'] as num).toDouble(),
          'min_threshold': (merged['min_threshold'] as num).toDouble(),
          'supplier': merged['supplier'],
        }, where: 'id = ?', whereArgs: [existingId]);
        await db.update('inventory_txns', {'ingredient_id': existingId}, where: 'ingredient_id = ?', whereArgs: [incomingId]);
        await db.update('recipes', {'ingredient_id': existingId}, where: 'ingredient_id = ?', whereArgs: [incomingId]);
        await db.delete('ingredients', where: 'id = ?', whereArgs: [incomingId]);
        
        if (!fromSync) {
          await SyncService.instance.deleteIngredient(incomingId);
          await SyncService.instance.updateIngredient({
            'id': existingId,
            'name': merged['name'],
            'category': merged['category'],
            'base_unit': merged['base_unit'],
            'stock': (merged['stock'] as num).toDouble(),
            'min_threshold': (merged['min_threshold'] as num).toDouble(),
            'supplier': merged['supplier'],
          });
        }
        Repository.instance.notifyDataChanged();
        return;
      }
    }
    await db.insert('ingredients', {
      'id': ing['id'],
      'name': nameIn,
      'category': ing['category'],
      'base_unit': ing['base_unit'],
      'stock': ing['stock'] ?? 0.0,
      'min_threshold': ing['min_threshold'] ?? 0.0,
      'supplier': ing['supplier'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    if (!fromSync) {
      await SyncService.instance.updateIngredient({
        'id': ing['id'],
        'name': nameIn,
        'category': ing['category'],
        'base_unit': ing['base_unit'],
        'stock': ing['stock'] ?? 0.0,
        'min_threshold': ing['min_threshold'] ?? 0.0,
        'supplier': ing['supplier'],
      });
    }
    Repository.instance.notifyDataChanged();
  }
  Future<List<Map<String, dynamic>>> listIngredients() async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('ingredients');
    return rows.map((r) => {
      'id': r['id'] as String,
      'name': r['name'] as String? ?? '',
      'category': r['category'] as String? ?? '',
      'base_unit': r['base_unit'] as String? ?? 'g',
      'stock': (r['stock'] as num?)?.toDouble() ?? 0.0,
      'min_threshold': (r['min_threshold'] as num?)?.toDouble() ?? 0.0,
      'supplier': r['supplier'] as String? ?? '',
    }).toList();
  }
  Future<int?> getLastUpdatedTs(String ingredientId) async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('inventory_txns', columns: ['MAX(timestamp) AS ts'], where: 'ingredient_id = ?', whereArgs: [ingredientId]);
    if (rows.isEmpty) return null;
    final ts = rows.first['ts'] as int?;
    return ts;
  }
  Future<void> setRecipeForMenuItem(int menuItemId, List<Map<String, dynamic>> items, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.delete('recipes', where: 'menu_item_id = ?', whereArgs: [menuItemId]);
    final batch = db.batch();
    for (final it in items) {
      batch.insert('recipes', {
        'menu_item_id': menuItemId,
        'ingredient_id': it['ingredient_id'],
        'qty': (it['qty'] as num).toDouble(),
        'unit': it['unit'],
      });
    }
    await batch.commit(noResult: true);
    if (!fromSync) await SyncService.instance.updateRecipe(menuItemId, items);
    Repository.instance.notifyDataChanged();
  }
  Future<List<Map<String, dynamic>>> getRecipeForMenuItem(int menuItemId) async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('recipes', where: 'menu_item_id = ?', whereArgs: [menuItemId]);
    return rows.map((r) => {
      'ingredient_id': r['ingredient_id'] as String,
      'qty': (r['qty'] as num?)?.toDouble() ?? 0.0,
      'unit': r['unit'] as String? ?? '',
    }).toList();
  }
  Future<void> _adjustStock(String ingredientId, double deltaInBaseUnit, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
    if (rows.isEmpty) return;
    final cur = (rows.first['stock'] as num?)?.toDouble() ?? 0.0;
    final next = cur + deltaInBaseUnit;
    await db.update('ingredients', {'stock': next}, where: 'id = ?', whereArgs: [ingredientId]);

    if (!fromSync) {
      final updatedRows = await db.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
      if (updatedRows.isNotEmpty) {
        final r = updatedRows.first;
        final ing = {
          'id': r['id'] as String,
          'name': r['name'] as String? ?? '',
          'category': r['category'] as String? ?? '',
          'base_unit': r['base_unit'] as String? ?? 'g',
          'stock': (r['stock'] as num?)?.toDouble() ?? 0.0,
          'min_threshold': (r['min_threshold'] as num?)?.toDouble() ?? 0.0,
          'supplier': r['supplier'] as String? ?? '',
        };
        await SyncService.instance.updateIngredient(ing);
      }
    }
  }
  Future<void> insertTxn(Map<String, dynamic> t, {bool fromSync = false}) async {
    final db = await Repository.instance._db.database;
    await db.insert('inventory_txns', {
      'id': t['id'],
      'ingredient_id': t['ingredient_id'],
      'type': t['type'],
      'qty': t['qty'],
      'unit': t['unit'],
      'cost_per_unit': t['cost_per_unit'],
      'supplier': t['supplier'],
      'invoice': t['invoice'],
      'note': t['note'],
      'timestamp': t['timestamp'],
      'related_order_id': t['related_order_id'],
      'kot_number': t['kot_number'],
      'reason': t['reason'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (!fromSync) {
      await SyncService.instance.updateInventoryTxn({
        'id': t['id'],
        'ingredient_id': t['ingredient_id'],
        'type': t['type'],
        'qty': t['qty'],
        'unit': t['unit'],
        'cost_per_unit': t['cost_per_unit'],
        'supplier': t['supplier'],
        'invoice': t['invoice'],
        'note': t['note'],
        'timestamp': t['timestamp'],
        'related_order_id': t['related_order_id'],
        'kot_number': t['kot_number'],
        'reason': t['reason'],
      });
    }
  }
  Future<void> applyKOTDeduction(List<CartItem> items, {String? kotNumber, String? orderId}) async {
    final db = await Repository.instance._db.database;
    for (final ci in items) {
      final recipe = await getRecipeForMenuItem(ci.id);
      for (final r in recipe) {
        final ingId = r['ingredient_id'] as String;
        final qtyPerUnit = (r['qty'] as num?)?.toDouble() ?? 0.0;
        final unit = r['unit'] as String? ?? '';
        final total = qtyPerUnit * ci.quantity.toDouble();
        final ingRows = await db.query('ingredients', where: 'id = ?', whereArgs: [ingId], limit: 1);
        if (ingRows.isEmpty) continue;
        final baseUnit = ingRows.first['base_unit'] as String? ?? unit;
        final inBase = _convertQty(unit, baseUnit, total);
        await _adjustStock(ingId, -inBase);
        await insertTxn({
          'id': 'ITX${DateTime.now().millisecondsSinceEpoch}${ingId.hashCode}',
          'ingredient_id': ingId,
          'type': 'deduction',
          'qty': total,
          'unit': unit,
          'cost_per_unit': null,
          'supplier': null,
          'invoice': null,
          'note': null,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'related_order_id': orderId,
          'kot_number': kotNumber,
          'reason': null,
        });
      }
    }
    Repository.instance.notifyDataChanged();
  }
  Future<void> restoreOnCancel(String ingredientId, double qty, String unit, {String? orderId, String? kotNumber}) async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
    if (rows.isEmpty) return;
    final baseUnit = rows.first['base_unit'] as String? ?? unit;
    final inBase = _convertQty(unit, baseUnit, qty);
    await _adjustStock(ingredientId, inBase);
    await insertTxn({
      'id': 'ITX${DateTime.now().millisecondsSinceEpoch}${ingredientId.hashCode}',
      'ingredient_id': ingredientId,
      'type': 'restore',
      'qty': qty,
      'unit': unit,
      'cost_per_unit': null,
      'supplier': null,
      'invoice': null,
      'note': null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'related_order_id': orderId,
      'kot_number': kotNumber,
      'reason': 'cancelled',
    });
    Repository.instance.notifyDataChanged();
  }
  Future<void> recordWastage(String ingredientId, double qty, String unit, String reason) async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
    if (rows.isEmpty) return;
    final baseUnit = rows.first['base_unit'] as String? ?? unit;
    final inBase = _convertQty(unit, baseUnit, qty);
    await _adjustStock(ingredientId, -inBase);
    await insertTxn({
      'id': 'ITX${DateTime.now().millisecondsSinceEpoch}${ingredientId.hashCode}',
      'ingredient_id': ingredientId,
      'type': 'wastage',
      'qty': qty,
      'unit': unit,
      'cost_per_unit': null,
      'supplier': null,
      'invoice': null,
      'note': null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'related_order_id': null,
      'kot_number': null,
      'reason': reason,
    });
    Repository.instance.notifyDataChanged();
  }
  Future<void> insertPurchase(String ingredientId, double qty, String unit, {double? costPerUnit, String? supplier, String? invoice, String? note}) async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
    if (rows.isEmpty) return;
    final baseUnit = rows.first['base_unit'] as String? ?? unit;
    final inBase = _convertQty(unit, baseUnit, qty);
    await _adjustStock(ingredientId, inBase);
    await insertTxn({
      'id': 'ITX${DateTime.now().millisecondsSinceEpoch}${ingredientId.hashCode}',
      'ingredient_id': ingredientId,
      'type': 'purchase',
      'qty': qty,
      'unit': unit,
      'cost_per_unit': costPerUnit,
      'supplier': supplier,
      'invoice': invoice,
      'note': note,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'related_order_id': null,
      'kot_number': null,
      'reason': null,
    });
    Repository.instance.notifyDataChanged();
  }
  Future<double> sumTransactionsToday(String type) async {
    final db = await Repository.instance._db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).millisecondsSinceEpoch;
    final rows = await db.query('inventory_txns', columns: ['qty'], where: 'type = ? AND timestamp BETWEEN ? AND ?', whereArgs: [type, start, end]);
    double sum = 0.0;
    for (final r in rows) {
      sum += (r['qty'] as num?)?.toDouble() ?? 0.0;
    }
    return sum;
  }
  Future<List<Map<String, dynamic>>> listTransactions({String? type, int? fromMs, int? toMs, int limit = 100, bool onlyKOT = false}) async {
    final db = await Repository.instance._db.database;
    final whereParts = <String>[];
    final args = <Object?>[];
    if (type != null) {
      whereParts.add('type = ?');
      args.add(type);
    }
    if (fromMs != null && toMs != null) {
      whereParts.add('timestamp BETWEEN ? AND ?');
      args.add(fromMs);
      args.add(toMs);
    }
    if (onlyKOT) {
      whereParts.add('kot_number IS NOT NULL');
    }
    final where = whereParts.isEmpty ? null : whereParts.join(' AND ');
    final rows = await db.query('inventory_txns', where: where, whereArgs: args, orderBy: 'timestamp DESC', limit: limit);
    return rows.map((r) => {
      'id': r['id'] as String,
      'ingredient_id': r['ingredient_id'] as String? ?? '',
      'type': r['type'] as String? ?? '',
      'qty': (r['qty'] as num?)?.toDouble() ?? 0.0,
      'unit': r['unit'] as String? ?? '',
      'cost_per_unit': (r['cost_per_unit'] as num?)?.toDouble(),
      'supplier': r['supplier'] as String?,
      'invoice': r['invoice'] as String?,
      'note': r['note'] as String?,
      'timestamp': r['timestamp'] as int? ?? 0,
      'related_order_id': r['related_order_id'] as String?,
      'kot_number': r['kot_number'] as String?,
      'reason': r['reason'] as String?,
    }).toList();
  }
  Future<void> applyBatchPrep(List<Map<String, dynamic>> items, {String? note}) async {
    final db = await Repository.instance._db.database;
    for (final it in items) {
      final ingId = it['ingredient_id'] as String;
      final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
      final unit = it['unit'] as String? ?? '';
      final rows = await db.query('ingredients', where: 'id = ?', whereArgs: [ingId], limit: 1);
      if (rows.isEmpty) continue;
      final baseUnit = rows.first['base_unit'] as String? ?? unit;
      final inBase = _convertQty(unit, baseUnit, qty);
      await _adjustStock(ingId, -inBase);
      await insertTxn({
        'id': 'ITX${DateTime.now().millisecondsSinceEpoch}${ingId.hashCode}',
        'ingredient_id': ingId,
        'type': 'deduction',
        'qty': qty,
        'unit': unit,
        'cost_per_unit': null,
        'supplier': null,
        'invoice': null,
        'note': note,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'related_order_id': null,
        'kot_number': null,
        'reason': 'batch_prep',
      });
    }
    Repository.instance.notifyDataChanged();
  }
  Future<void> restoreKOTBatch(List<CartItem> items, {String? kotNumber, String? orderId}) async {
    final db = await Repository.instance._db.database;
    for (final ci in items) {
      final recipe = await getRecipeForMenuItem(ci.id);
      for (final r in recipe) {
        final ingId = r['ingredient_id'] as String;
        final qtyPerUnit = (r['qty'] as num?)?.toDouble() ?? 0.0;
        final unit = r['unit'] as String? ?? '';
        final total = qtyPerUnit * ci.quantity.toDouble();
        final ingRows = await db.query('ingredients', where: 'id = ?', whereArgs: [ingId], limit: 1);
        if (ingRows.isEmpty) continue;
        final baseUnit = ingRows.first['base_unit'] as String? ?? unit;
        final inBase = _convertQty(unit, baseUnit, total);
        await _adjustStock(ingId, inBase);
      await insertTxn({
        'id': 'ITX${DateTime.now().millisecondsSinceEpoch}${ingId.hashCode}',
        'ingredient_id': ingId,
        'type': 'restore',
        'qty': total,
        'unit': unit,
        'cost_per_unit': null,
        'supplier': null,
        'invoice': null,
        'note': null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'related_order_id': orderId,
        'kot_number': kotNumber,
        'reason': 'cancelled',
      });
    }
  }
    Repository.instance.notifyDataChanged();
  }

  Future<void> recordWastageForItems(List<CartItem> items, String reason, {String? orderId}) async {
    final db = await Repository.instance._db.database;
    for (final ci in items) {
      final recipe = await getRecipeForMenuItem(ci.id);
      for (final r in recipe) {
        final ingId = r['ingredient_id'] as String;
        final qtyPerUnit = (r['qty'] as num?)?.toDouble() ?? 0.0;
        final unit = r['unit'] as String? ?? '';
        final total = qtyPerUnit * ci.quantity.toDouble();
        
        final ingRows = await db.query('ingredients', where: 'id = ?', whereArgs: [ingId], limit: 1);
        if (ingRows.isEmpty) continue;
        final baseUnit = ingRows.first['base_unit'] as String? ?? unit;
        final inBase = _convertQty(unit, baseUnit, total);
        
        // Decrease stock (wastage is a loss)
        await _adjustStock(ingId, -inBase);
        
        await insertTxn({
          'id': 'ITX${DateTime.now().millisecondsSinceEpoch}${ingId.hashCode}',
          'ingredient_id': ingId,
          'type': 'wastage',
          'qty': total,
          'unit': unit,
          'cost_per_unit': null,
          'supplier': null,
          'invoice': null,
          'note': null,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'related_order_id': orderId,
          'kot_number': null,
          'reason': reason,
        });
      }
    }
    Repository.instance.notifyDataChanged();
  }
  Future<List<Map<String, dynamic>>> listLowStock() async {
    final db = await Repository.instance._db.database;
    final rows = await db.query('ingredients');
    return rows.where((r) {
      final stock = (r['stock'] as num?)?.toDouble() ?? 0.0;
      final min = (r['min_threshold'] as num?)?.toDouble() ?? 0.0;
      return min > 0.0 && stock <= min;
    }).map((r) => {
      'id': r['id'] as String,
      'name': r['name'] as String? ?? '',
      'stock': (r['stock'] as num?)?.toDouble() ?? 0.0,
      'base_unit': r['base_unit'] as String? ?? '',
      'min_threshold': (r['min_threshold'] as num?)?.toDouble() ?? 0.0,
    }).toList();
  }
  Future<void> deleteIngredient(String id) async {
    final db = await Repository.instance._db.database;
    await db.delete('recipes', where: 'ingredient_id = ?', whereArgs: [id]);
    await db.delete('ingredients', where: 'id = ?', whereArgs: [id]);
    await SyncService.instance.deleteIngredient(id);
    await SyncService.instance.scrubIngredientFromRecipes(id);
    Repository.instance.notifyDataChanged();
  }

  Future<void> fixInventoryDuplicates() async {
    final db = await Repository.instance._db.database;
    final all = await listIngredients();
    final seen = <String, Map<String, dynamic>>{};
    final toDelete = <String>[];

    for (final ing in all) {
      final name = (ing['name'] as String).trim().toLowerCase();
      if (seen.containsKey(name)) {
        // Duplicate found.
        // We keep the one already seen (assuming it's the "first" or we could pick best).
        // Merge stock?
        final kept = seen[name]!;
        final keptId = kept['id'] as String;
        final dupId = ing['id'] as String;

        // Move stock to kept
        final dupStock = (ing['stock'] as num).toDouble();
        if (dupStock > 0) {
          await _adjustStock(keptId, dupStock);
        }

        // Move transactions
        await db.update('inventory_txns', {'ingredient_id': keptId}, where: 'ingredient_id = ?', whereArgs: [dupId]);
        
        // Move recipes
        await db.update('recipes', {'ingredient_id': keptId}, where: 'ingredient_id = ?', whereArgs: [dupId]);

        toDelete.add(dupId);
      } else {
        seen[name] = ing;
      }
    }

    for (final id in toDelete) {
      await db.delete('ingredients', where: 'id = ?', whereArgs: [id]);
      await SyncService.instance.deleteIngredient(id);
    }
    
    if (toDelete.isNotEmpty) {
      Repository.instance.notifyDataChanged();
    }
  }
}
