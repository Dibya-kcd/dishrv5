import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Future<Database> get database => _db.database;
  String? _clientRole;
  String? _clientPin;
  final menu = MenuDao();
  final orders = OrderDao();
  final tables = TablesDao();
  final expenses = ExpensesDao();
  final settings = SettingsDao();
  final ingredients = IngredientsDao();
  final employees = EmployeesDao();
  final roles = RoleDao();
  Future<void> clearAllLocalData({bool notify = true}) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('order_items');
      await txn.delete('order_events');
      await txn.delete('orders');
      await txn.delete('tables');
      await txn.delete('menu_items');
      await txn.delete('expenses');
      await txn.delete('employees');
      await txn.delete('recipes');
      await txn.delete('inventory_txns');
      await txn.delete('ingredients');
      await txn.delete('settings');
      await settings.set('seed_vmo', '1', txn: txn);
    });
    if (notify) notifyDataChanged();
  }

  final _controller = StreamController<void>.broadcast();
  Stream<void> get onDataChanged => _controller.stream;

  void notifyDataChanged() {
    _controller.add(null);
  }


  Future<void> init() async {
    final db = await _db.database;
    await _ensureDeviceId();
    await _loadSession();
    if (_clientRole != null) {
      if (kDebugMode) {
        debugPrint('Session restored: $_clientRole');
      }
      SyncService.instance.init();
    } else {
      if (kDebugMode) {
        debugPrint('No existing session found');
      }
    }
    
    final seeded = await settings.get('seed_vmo');
    if (seeded != '1') {
      await db.transaction((txn) async {
        final existingIngredients = await ingredients.listIngredients(txn: txn);
        if (existingIngredients.isEmpty) {
          final seed = [
            {'id':'ING001','name':'Paneer','category':'Dairy','base_unit':'g','stock':2000.0,'min_threshold':500.0,'supplier':'Local'},
            {'id':'ING002','name':'Curd','category':'Dairy','base_unit':'g','stock':1500.0,'min_threshold':400.0,'supplier':'Local'},
            {'id':'ING003','name':'Spice Mix','category':'Spices','base_unit':'g','stock':1000.0,'min_threshold':200.0,'supplier':'Local'},
            {'id':'ING004','name':'Oil','category':'Oils','base_unit':'ml','stock':3000.0,'min_threshold':800.0,'supplier':'Local'},
            {'id':'ING005','name':'Rice','category':'Grains','base_unit':'g','stock':5000.0,'min_threshold':1000.0,'supplier':'Local'},
            {'id':'ING006','name':'Chicken','category':'Meat','base_unit':'g','stock':3000.0,'min_threshold':700.0,'supplier':'Local'},
            {'id':'ING007','name':'Biryani Masala','category':'Spices','base_unit':'g','stock':800.0,'min_threshold':200.0,'supplier':'Local'},
            {'id':'ING008','name':'Dosa Batter','category':'Batter','base_unit':'g','stock':4000.0,'min_threshold':1000.0,'supplier':'Local'},
            {'id':'ING009','name':'Potato Masala','category':'Veg','base_unit':'g','stock':2500.0,'min_threshold':600.0,'supplier':'Local'},
            {'id':'ING010','name':'Flour','category':'Bakery','base_unit':'g','stock':4000.0,'min_threshold':900.0,'supplier':'Local'},
            {'id':'ING011','name':'Butter','category':'Dairy','base_unit':'g','stock':1200.0,'min_threshold':300.0,'supplier':'Local'},
            {'id':'ING012','name':'Yeast','category':'Bakery','base_unit':'g','stock':300.0,'min_threshold':50.0,'supplier':'Local'},
            {'id':'ING013','name':'Khoya Mix','category':'Dessert','base_unit':'g','stock':1200.0,'min_threshold':300.0,'supplier':'Local'},
            {'id':'ING014','name':'Sugar Syrup','category':'Dessert','base_unit':'ml','stock':1500.0,'min_threshold':400.0,'supplier':'Local'},
            {'id':'ING015','name':'Milk','category':'Dairy','base_unit':'ml','stock':3000.0,'min_threshold':800.0,'supplier':'Local'},
            {'id':'ING016','name':'Coffee','category':'Beverage','base_unit':'g','stock':500.0,'min_threshold':100.0,'supplier':'Local'},
            {'id':'ING017','name':'Sugar','category':'Beverage','base_unit':'g','stock':2000.0,'min_threshold':500.0,'supplier':'Local'},
            {'id':'ING018','name':'Black Lentils','category':'Legumes','base_unit':'g','stock':2500.0,'min_threshold':600.0,'supplier':'Local'},
            {'id':'ING019','name':'Cream','category':'Dairy','base_unit':'ml','stock':1200.0,'min_threshold':300.0,'supplier':'Local'},
            {'id':'ING020','name':'Roll Wrapper','category':'Bakery','base_unit':'pc','stock':200.0,'min_threshold':50.0,'supplier':'Local'},
            {'id':'ING021','name':'Veg Mix','category':'Veg','base_unit':'g','stock':3000.0,'min_threshold':800.0,'supplier':'Local'},
          ];
          for (final ing in seed) {
            await ingredients.upsertIngredient(ing, notify: false, txn: txn);
          }
          final menuItems = await menu.listMenu(txn: txn);
          final byName = {for (final m in menuItems) m.name.toLowerCase(): m};
          Future<void> setRecipe(String itemName, List<Map<String, dynamic>> items) async {
            final m = byName[itemName.toLowerCase()];
            if (m == null) return;
            await ingredients.setRecipeForMenuItem(m.id, items, notify: false, txn: txn);
          }
          await setRecipe('Paneer Tikka', [
            {'ingredient_id':'ING001','qty':150.0,'unit':'g'},
            {'ingredient_id':'ING002','qty':50.0,'unit':'g'},
            {'ingredient_id':'ING003','qty':10.0,'unit':'g'},
            {'ingredient_id':'ING004','qty':10.0,'unit':'ml'},
          ]);
          await setRecipe('Chicken Biryani', [
            {'ingredient_id':'ING005','qty':200.0,'unit':'g'},
            {'ingredient_id':'ING006','qty':150.0,'unit':'g'},
            {'ingredient_id':'ING007','qty':8.0,'unit':'g'},
            {'ingredient_id':'ING004','qty':15.0,'unit':'ml'},
          ]);
          await setRecipe('Masala Dosa', [
            {'ingredient_id':'ING008','qty':200.0,'unit':'g'},
            {'ingredient_id':'ING009','qty':120.0,'unit':'g'},
            {'ingredient_id':'ING004','qty':10.0,'unit':'ml'},
          ]);
          await setRecipe('Butter Naan', [
            {'ingredient_id':'ING010','qty':120.0,'unit':'g'},
            {'ingredient_id':'ING011','qty':10.0,'unit':'g'},
            {'ingredient_id':'ING012','qty':2.0,'unit':'g'},
          ]);
          await setRecipe('Gulab Jamun', [
            {'ingredient_id':'ING013','qty':100.0,'unit':'g'},
            {'ingredient_id':'ING014','qty':50.0,'unit':'ml'},
          ]);
          await setRecipe('Cold Coffee', [
            {'ingredient_id':'ING015','qty':200.0,'unit':'ml'},
            {'ingredient_id':'ING016','qty':10.0,'unit':'g'},
            {'ingredient_id':'ING017','qty':15.0,'unit':'g'},
          ]);
          await setRecipe('Dal Makhani', [
            {'ingredient_id':'ING018','qty':150.0,'unit':'g'},
            {'ingredient_id':'ING019','qty':20.0,'unit':'ml'},
            {'ingredient_id':'ING011','qty':10.0,'unit':'g'},
          ]);
          await setRecipe('Spring Rolls', [
            {'ingredient_id':'ING020','qty':2.0,'unit':'pc'},
            {'ingredient_id':'ING021','qty':100.0,'unit':'g'},
            {'ingredient_id':'ING004','qty':15.0,'unit':'ml'},
          ]);
        }
        await settings.set('seed_vmo', '1', txn: txn);
      });
      notifyDataChanged();
    }
  }
  Future<void> _ensureDeviceId() async {
    // Device ID is no longer used.
  }

  void setClientSession(String role, String pin) {
    _clientRole = role;
    _clientPin = pin;
    _saveSession();
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_clientRole != null && _clientPin != null) {
      await prefs.setString('session_role', _clientRole!);
      await prefs.setString('session_pin', _clientPin!);
    } else {
      await prefs.remove('session_role');
      await prefs.remove('session_pin');
    }
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _clientRole = prefs.getString('session_role');
    _clientPin = prefs.getString('session_pin');
  }

  void clearSession() {
    _clientRole = null;
    _clientPin = null;
    _saveSession();
  }

  Map<String, dynamic>? get clientMeta {
    if (_clientRole == null || _clientPin == null) return null;
    return {
      'role': _clientRole,
      'pin': _clientPin,
    };
  }

  String? get deviceId => null;
}

class MenuDao {
  Future<void> insertMenuItem(MenuItem m, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.insert('menu_items', {
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
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> updateMenuItem(MenuItem m, {bool fromSync = false, bool notify = true, Transaction? txn}) => insertMenuItem(m, fromSync: fromSync, notify: notify, txn: txn);
  Future<void> deleteMenuItem(int id, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.delete('menu_items', where: 'id = ?', whereArgs: [id]);
    if (!fromSync) await SyncService.instance.deleteMenuItem(id);
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> toggleSoldOut(int id, bool value, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.update('menu_items', {'sold_out': value ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    
    if (!fromSync) {
      final rows = await executor.query('menu_items', where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        final m = _fromRow(rows.first);
        await SyncService.instance.updateMenuItem(m);
      }
    }
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> upsertMenuItems(List<MenuItem> items, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final batch = executor.batch();
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
    if (notify) Repository.instance.notifyDataChanged();
  }

  Future<List<MenuItem>> listMenu({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('menu_items');
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
  Future<void> set(String key, String value, {bool notify = false, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    if (notify) Repository.instance.notifyDataChanged();
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

  Future<void> logEvent(String orderId, String event, {Map<String, dynamic>? data, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.insert('order_events', {
      'order_id': orderId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'event': event,
      'data': data != null ? jsonEncode(data) : null,
    });
  }
  Future<void> insertOrder(Order order, List<CartItem> items, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(Transaction t) async {
      if (fromSync) {
        final rows = await t.query('orders', columns: ['status', 'total'], where: 'id = ?', whereArgs: [order.id]);
        if (rows.isNotEmpty) {
          final cur = rows.first['status'] as String;
          final curTotal = (rows.first['total'] as num?)?.toDouble() ?? 0.0;
          if ((curTotal - order.total).abs() < 0.01) {
            if (_getPrio(cur) > _getPrio(order.status)) return;
          }
        }
      }

      await t.insert('orders', {
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
      
      await t.delete('order_items', where: 'order_id = ?', whereArgs: [order.id]);

      final batch = t.batch();
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

      // Log the event within the same transaction
      await logEvent(order.id, 'sent_to_kitchen', data: {
        'items': items.map((i) => {'id': i.id, 'q': i.quantity}).toList(),
        'table': order.table,
      }, txn: t);
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }
    
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
        settledAt: order.settledAt,
    );
    if (!fromSync) await SyncService.instance.updateOrder(fullOrder);
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> clearAll({bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.delete('order_items');
    await executor.delete('orders');
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> clearAllSynced({bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.delete('order_items');
    await executor.delete('orders');
    await SyncService.instance.deleteAllOrders();
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> deleteOrdersByTableLabel(String tableLabel, {bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(Transaction t) async {
      final rows = await t.query('orders', where: 'table_label = ?', whereArgs: [tableLabel]);
      final batch = t.batch();
      for (final r in rows) {
        final id = r['id'] as String;
        batch.delete('order_items', where: 'order_id = ?', whereArgs: [id]);
        batch.delete('orders', where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }
    
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> updateOrderItems(String orderId, List<CartItem> items, double total, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(Transaction t) async {
      await t.update('orders', {
        'total': total,
      }, where: 'id = ?', whereArgs: [orderId]);
      await t.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      final batch = t.batch();
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
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }
    
    final executor = txn ?? db;
    final orderRow = await executor.query('orders', where: 'id = ?', whereArgs: [orderId]);
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
        settledAt: r['settled_at'] as int?,
      );
      if (!fromSync) await SyncService.instance.updateOrder(order);
    }
    if (notify) Repository.instance.notifyDataChanged();
  }

  Future<void> updateOrderStatus(String id, String status, {String? paymentMethod, int? readyAtMs, bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    
    if (fromSync) {
      final rows = await executor.query('orders', columns: ['status'], where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        final cur = rows.first['status'] as String;
        if (_getPrio(cur) > _getPrio(status)) return;
      }
    }

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
    await executor.update('orders', updateMap, where: 'id = ?', whereArgs: [id]);
    
    if (!fromSync) {
      final orderRow = await executor.query('orders', where: 'id = ?', whereArgs: [id]);
      if (orderRow.isNotEmpty) {
           final itemsRows = await executor.query('order_items', where: 'order_id = ?', whereArgs: [id]);
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
    if (notify) Repository.instance.notifyDataChanged();
  }

  Future<List<Order>> listActiveOrders({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('orders', where: 'status != ?', whereArgs: ['Settled']);
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
  Future<List<Order>> listOrdersWithItems({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final ordersRows = await executor.query('orders');
    final itemsRows = await executor.query('order_items');
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
  Future<List<Order>> listClosedOrders({int limit = 10, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query(
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
  Future<void> upsertTable(int id, int number, String status, int capacity, {String? orderId, bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.insert('tables', {
      'id': id,
      'number': number,
      'status': status,
      'capacity': capacity,
      'order_id': orderId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    if (!fromSync) {
      try {
        await SyncService.instance.updateTable(TableInfo(
          id: id,
          number: number,
          status: status,
          capacity: capacity,
          orderId: orderId,
        ));
      } catch (_) {
        // Ignore sync errors so local table changes always succeed
      }
    }
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<List<TableInfo>> listTables({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('tables', where: 'status != ?', whereArgs: ['deleted']);
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
  Future<void> insertExpense(Map<String, dynamic> e, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    dynamic ts = e['timestamp'];
    int finalTs = 0;
    if (ts is int) {
      finalTs = ts < 1000000000000 ? ts * 1000 : ts;
    } else if (ts is String) {
      final parsed = int.tryParse(ts) ?? 0;
      finalTs = parsed < 1000000000000 ? parsed * 1000 : parsed;
    }
    
    await executor.insert('expenses', {
      'id': e['id'],
      'amount': e['amount'],
      'category': e['category'],
      'note': e['note'],
      'timestamp': finalTs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (!fromSync) await SyncService.instance.updateExpense(e);
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<List<Map<String, dynamic>>> listExpenses({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('expenses', orderBy: 'timestamp DESC');
    return rows.map((r) => {
      'id': r['id'] as String,
      'amount': (r['amount'] as num?)?.toDouble() ?? 0.0,
      'category': r['category'] as String? ?? '',
      'note': r['note'] as String? ?? '',
      'timestamp': r['timestamp'] as int? ?? 0,
    }).toList();
  }
  Future<void> deleteExpense(String id, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.delete('expenses', where: 'id = ?', whereArgs: [id]);
    if (!fromSync) await SyncService.instance.deleteExpense(id);
    if (notify) Repository.instance.notifyDataChanged();
  }
}
class EmployeesDao {
  Future<void> upsertEmployee(Map<String, dynamic> e, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final id = (e['id']?.toString().trim().isNotEmpty == true) ? e['id'].toString() : 'EMP${DateTime.now().millisecondsSinceEpoch}';
    final code = (e['employee_code']?.toString() ?? '').trim();
    final name = (e['name']?.toString() ?? '').trim();
    final role = (e['role']?.toString() ?? '').trim().toLowerCase();
    final status = (e['status']?.toString() ?? 'Active').trim();
    final photo = (e['photo']?.toString() ?? '').trim();
    final pin = (e['pin']?.toString() ?? '').trim();
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
    final deleted = (e['deleted'] == true || e['deleted'] == 1) ? 1 : 0;
    await executor.insert('employees', {
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
      'pin': pin,
      'created_at': now,
      'updated_at': now,
      'deleted': deleted,
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
          'pin': pin,
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
          'deleted': deleted == 1,
        };
        await SyncService.instance.updateEmployee(payload);
      } catch (_) {}
    }
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> updateEmployee(Map<String, dynamic> e, {bool fromSync = false, bool notify = true, Transaction? txn}) async => upsertEmployee(e, fromSync: fromSync, notify: notify, txn: txn);
  Future<void> deleteEmployee(String id, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    // Step 2: Propagate Deletion to Offline (SQLite) - Use soft delete
    await executor.update('employees', {'deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
    
    if (!fromSync) {
      try {
        // Step 1: Use Online (Firebase) as Master - Deletion must start online
        await SyncService.instance.deleteEmployee(id);
      } catch (_) {}
    }
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<List<Map<String, dynamic>>> listEmployees({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    // Only return non-deleted employees by default
    final rows = await executor.query('employees', where: 'deleted = 0 OR deleted IS NULL', orderBy: 'updated_at DESC');
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
      'pin': r['pin'] as String? ?? '',
      'created_at': r['created_at'] as int? ?? 0,
      'updated_at': r['updated_at'] as int? ?? 0,
      'deleted': (r['deleted'] as int? ?? 0) == 1,
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
  Future<void> upsertIngredient(Map<String, dynamic> ing, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final nameIn = (ing['name']?.toString() ?? '').trim();
    final nameKey = nameIn.toLowerCase();
    
    // Ensure we have a valid ID
    String incomingId = ing['id']?.toString() ?? '';
    if (incomingId.isEmpty) {
      incomingId = '${DateTime.now().millisecondsSinceEpoch}_${nameKey.hashCode}';
    }

    Future<void> runBody(Transaction t) async {
      final existingRows = await t.query('ingredients', where: 'LOWER(name) = ?', whereArgs: [nameKey], limit: 1);
      
      if (existingRows.isNotEmpty) {
        final existing = existingRows.first;
        final existingId = existing['id'] as String;
        
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
          await t.update('ingredients', {
            'name': merged['name'],
            'category': merged['category'],
            'base_unit': merged['base_unit'],
            'stock': (merged['stock'] as num).toDouble(),
            'min_threshold': (merged['min_threshold'] as num).toDouble(),
            'supplier': merged['supplier'],
          }, where: 'id = ?', whereArgs: [existingId]);
          await t.update('inventory_txns', {'ingredient_id': existingId}, where: 'ingredient_id = ?', whereArgs: [incomingId]);
          await t.update('recipes', {'ingredient_id': existingId}, where: 'ingredient_id = ?', whereArgs: [incomingId]);
          await t.delete('ingredients', where: 'id = ?', whereArgs: [incomingId]);
          
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
          return;
        }
      }

      await t.insert('ingredients', {
        'id': incomingId,
        'name': nameIn,
        'category': ing['category'],
        'base_unit': ing['base_unit'],
        'stock': ing['stock'] ?? 0.0,
        'min_threshold': ing['min_threshold'] ?? 0.0,
        'supplier': ing['supplier'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }
    
    if (!fromSync) {
      await SyncService.instance.updateIngredient({
        'id': incomingId,
        'name': nameIn,
        'category': ing['category'],
        'base_unit': ing['base_unit'],
        'stock': ing['stock'] ?? 0.0,
        'min_threshold': ing['min_threshold'] ?? 0.0,
        'supplier': ing['supplier'],
      });
    }
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<List<Map<String, dynamic>>> listIngredients({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('ingredients');
    return rows.map((r) => {
      'id': r['id']?.toString() ?? '',
      'name': r['name']?.toString() ?? '',
      'category': r['category']?.toString() ?? '',
      'base_unit': r['base_unit']?.toString() ?? 'g',
      'stock': (r['stock'] as num?)?.toDouble() ?? 0.0,
      'min_threshold': (r['min_threshold'] as num?)?.toDouble() ?? 0.0,
      'supplier': r['supplier']?.toString() ?? '',
    }).toList();
  }
  Future<int?> getLastUpdatedTs(String ingredientId, {Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('inventory_txns', columns: ['MAX(timestamp) AS ts'], where: 'ingredient_id = ?', whereArgs: [ingredientId]);
    if (rows.isEmpty) return null;
    final ts = rows.first['ts'] as int?;
    return ts;
  }
  Future<Map<String, int>> listLastUpdatedByIngredient({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.rawQuery('SELECT ingredient_id, MAX(timestamp) as ts FROM inventory_txns GROUP BY ingredient_id');
    final out = <String, int>{};
    for (final r in rows) {
      final id = r['ingredient_id']?.toString();
      final ts = r['ts'];
      if (id != null && ts is int) out[id] = ts;
    }
    return out;
  }
  Future<void> setRecipeForMenuItem(int menuItemId, List<Map<String, dynamic>> items, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.delete('recipes', where: 'menu_item_id = ?', whereArgs: [menuItemId]);
    final batch = executor.batch();
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
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<List<Map<String, dynamic>>> getRecipeForMenuItem(int menuItemId, {Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('recipes', where: 'menu_item_id = ?', whereArgs: [menuItemId]);
    return rows.map((r) => {
      'ingredient_id': r['ingredient_id']?.toString() ?? '',
      'qty': (r['qty'] as num?)?.toDouble() ?? 0.0,
      'unit': r['unit']?.toString() ?? '',
    }).toList();
  }
  Future<List<Map<String, dynamic>>> getMenuItemsUsingIngredient(String ingredientId, {Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.rawQuery('SELECT mi.id AS id, mi.name AS name FROM menu_items mi INNER JOIN recipes r ON mi.id = r.menu_item_id WHERE r.ingredient_id = ?', [ingredientId]);
    return rows.map((r) => {
      'id': r['id'],
      'name': r['name'],
    }).toList();
  }
  Future<void> _adjustStock(String ingredientId, double deltaInBaseUnit, {bool fromSync = false, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
    if (rows.isEmpty) return;
    final cur = (rows.first['stock'] as num?)?.toDouble() ?? 0.0;
    final next = cur + deltaInBaseUnit;
    await executor.update('ingredients', {'stock': next}, where: 'id = ?', whereArgs: [ingredientId]);

    if (!fromSync) {
      final updatedRows = await executor.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
      if (updatedRows.isNotEmpty) {
        final r = updatedRows.first;
        final ing = {
          'id': r['id']?.toString() ?? '',
          'name': r['name']?.toString() ?? '',
          'category': r['category']?.toString() ?? '',
          'base_unit': r['base_unit']?.toString() ?? 'g',
          'stock': (r['stock'] as num?)?.toDouble() ?? 0.0,
          'min_threshold': (r['min_threshold'] as num?)?.toDouble() ?? 0.0,
          'supplier': r['supplier']?.toString() ?? '',
        };
        await SyncService.instance.updateIngredient(ing);
      }
    }
  }
  Future<void> insertTxn(Map<String, dynamic> t, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.insert('inventory_txns', {
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
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> applyKOTDeduction(List<CartItem> items, {String? kotNumber, String? orderId, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(Transaction t) async {
      for (final ci in items) {
        final recipe = await getRecipeForMenuItem(ci.id, txn: t);
        for (final r in recipe) {
          final ingId = r['ingredient_id'] as String;
          final qtyPerUnit = (r['qty'] as num?)?.toDouble() ?? 0.0;
          final unit = r['unit'] as String? ?? '';
          final total = qtyPerUnit * ci.quantity.toDouble();
          final ingRows = await t.query('ingredients', where: 'id = ?', whereArgs: [ingId], limit: 1);
          if (ingRows.isEmpty) continue;
          final baseUnit = ingRows.first['base_unit'] as String? ?? unit;
          final inBase = _convertQty(unit, baseUnit, total);
          await _adjustStock(ingId, -inBase, txn: t);
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
          }, txn: t);
        }
      }
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }

    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> restoreOnCancel(String ingredientId, double qty, String unit, {String? orderId, String? kotNumber, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(DatabaseExecutor t) async {
      final rows = await t.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
      if (rows.isEmpty) return;
      final baseUnit = rows.first['base_unit'] as String? ?? unit;
      final inBase = _convertQty(unit, baseUnit, qty);
      await _adjustStock(ingredientId, inBase, txn: t is Transaction ? t : null);
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
      }, txn: t is Transaction ? t : null);
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }

    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> recordWastage(String ingredientId, double qty, String unit, String reason, {bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(DatabaseExecutor t) async {
      final rows = await t.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
      if (rows.isEmpty) return;
      final baseUnit = rows.first['base_unit'] as String? ?? unit;
      final inBase = _convertQty(unit, baseUnit, qty);
      await _adjustStock(ingredientId, -inBase, txn: t is Transaction ? t : null);
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
      }, txn: t is Transaction ? t : null);
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }

    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> insertPurchase(String ingredientId, double qty, String unit, {double? costPerUnit, String? supplier, String? invoice, String? note, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(DatabaseExecutor t) async {
      final rows = await t.query('ingredients', where: 'id = ?', whereArgs: [ingredientId], limit: 1);
      if (rows.isEmpty) return;
      final baseUnit = rows.first['base_unit'] as String? ?? unit;
      final inBase = _convertQty(unit, baseUnit, qty);
      await _adjustStock(ingredientId, inBase, txn: t is Transaction ? t : null);
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
      }, txn: t is Transaction ? t : null);
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }

    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<double> sumTransactionsToday(String type, {Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).millisecondsSinceEpoch;
    final rows = await executor.query('inventory_txns', columns: ['qty'], where: 'type = ? AND timestamp BETWEEN ? AND ?', whereArgs: [type, start, end]);
    double sum = 0.0;
    for (final r in rows) {
      sum += (r['qty'] as num?)?.toDouble() ?? 0.0;
    }
    return sum;
  }
  Future<List<Map<String, dynamic>>> listTransactions({String? type, int? fromMs, int? toMs, int limit = 100, bool onlyKOT = false, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
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
    final rows = await executor.query('inventory_txns', where: where, whereArgs: args, orderBy: 'timestamp DESC', limit: limit);
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

  Future<void> applyBatchPrep(List<Map<String, dynamic>> items, {String? note, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(Transaction t) async {
      for (final it in items) {
        final ingId = it['ingredient_id'] as String;
        final qty = (it['qty'] as num?)?.toDouble() ?? 0.0;
        final unit = it['unit'] as String? ?? '';
        final rows = await t.query('ingredients', where: 'id = ?', whereArgs: [ingId], limit: 1);
        if (rows.isEmpty) continue;
        final baseUnit = rows.first['base_unit'] as String? ?? unit;
        final inBase = _convertQty(unit, baseUnit, qty);
        await _adjustStock(ingId, -inBase, txn: t);
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
        }, txn: t);
      }
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }

    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> restoreKOTBatch(List<CartItem> items, {String? kotNumber, String? orderId, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(Transaction t) async {
      for (final ci in items) {
        final recipe = await getRecipeForMenuItem(ci.id, txn: t);
        for (final r in recipe) {
          final ingId = r['ingredient_id'] as String;
          final qtyPerUnit = (r['qty'] as num?)?.toDouble() ?? 0.0;
          final unit = r['unit'] as String? ?? '';
          final total = qtyPerUnit * ci.quantity.toDouble();
          final ingRows = await t.query('ingredients', where: 'id = ?', whereArgs: [ingId], limit: 1);
          if (ingRows.isEmpty) continue;
          final baseUnit = ingRows.first['base_unit'] as String? ?? unit;
          final inBase = _convertQty(unit, baseUnit, total);
          await _adjustStock(ingId, inBase, txn: t);
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
          }, txn: t);
        }
      }
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }

    if (notify) Repository.instance.notifyDataChanged();
  }

  Future<void> recordWastageForItems(List<CartItem> items, String reason, {String? orderId, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    
    Future<void> runBody(Transaction t) async {
      for (final ci in items) {
        final recipe = await getRecipeForMenuItem(ci.id, txn: t);
        for (final r in recipe) {
          final ingId = r['ingredient_id'] as String;
          final qtyPerUnit = (r['qty'] as num?)?.toDouble() ?? 0.0;
          final unit = r['unit'] as String? ?? '';
          final total = qtyPerUnit * ci.quantity.toDouble();
          
          final ingRows = await t.query('ingredients', where: 'id = ?', whereArgs: [ingId], limit: 1);
          if (ingRows.isEmpty) continue;
          final baseUnit = ingRows.first['base_unit'] as String? ?? unit;
          final inBase = _convertQty(unit, baseUnit, total);
          
          // Decrease stock (wastage is a loss)
          await _adjustStock(ingId, -inBase, txn: t);
          
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
          }, txn: t);
        }
      }
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }

    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<List<Map<String, dynamic>>> listLowStock({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('ingredients');
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
  Future<void> deleteIngredient(String id, {bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    Future<void> runBody(DatabaseExecutor t) async {
      await t.delete('recipes', where: 'ingredient_id = ?', whereArgs: [id]);
      await t.delete('ingredients', where: 'id = ?', whereArgs: [id]);
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }

    await SyncService.instance.deleteIngredient(id);
    await SyncService.instance.scrubIngredientFromRecipes(id);
    if (notify) Repository.instance.notifyDataChanged();
  }
  Future<void> fixInventoryDuplicates({bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final all = await listIngredients();
    final seen = <String, Map<String, dynamic>>{};
    final toDelete = <String>[];
    
    Future<void> runBody(Transaction t) async {
      for (final ing in all) {
        final name = (ing['name'] as String).trim().toLowerCase();
        if (seen.containsKey(name)) {
          final kept = seen[name]!;
          final keptId = kept['id'] as String;
          final dupId = ing['id'] as String;

          // Move stock to kept
          final dupStock = (ing['stock'] as num).toDouble();
          if (dupStock > 0) {
            await _adjustStock(keptId, dupStock, txn: t);
          }

          // Move transactions
          await t.update('inventory_txns', {'ingredient_id': keptId}, where: 'ingredient_id = ?', whereArgs: [dupId]);
          
          // Move recipes
          await t.update('recipes', {'ingredient_id': keptId}, where: 'ingredient_id = ?', whereArgs: [dupId]);

          toDelete.add(dupId);
        } else {
          seen[name] = ing;
        }
      }

      for (final id in toDelete) {
        await t.delete('ingredients', where: 'id = ?', whereArgs: [id]);
        await SyncService.instance.deleteIngredient(id);
      }
    }

    if (txn != null) {
      await runBody(txn);
    } else {
      await db.transaction((t) => runBody(t));
    }
    
    if (toDelete.isNotEmpty) {
      if (notify) Repository.instance.notifyDataChanged();
    }
  }
  Future<void> resetToCanonicalSeed({bool notify = true}) async {
    final db = await Repository.instance._db.database;
    final seed = [
      {'id':'ING001','name':'Paneer','category':'Dairy','base_unit':'g','stock':2000.0,'min_threshold':500.0,'supplier':'Local'},
      {'id':'ING002','name':'Curd','category':'Dairy','base_unit':'g','stock':1500.0,'min_threshold':400.0,'supplier':'Local'},
      {'id':'ING003','name':'Spice Mix','category':'Spices','base_unit':'g','stock':1000.0,'min_threshold':200.0,'supplier':'Local'},
      {'id':'ING004','name':'Oil','category':'Oils','base_unit':'ml','stock':3000.0,'min_threshold':800.0,'supplier':'Local'},
      {'id':'ING005','name':'Rice','category':'Grains','base_unit':'g','stock':5000.0,'min_threshold':1000.0,'supplier':'Local'},
      {'id':'ING006','name':'Chicken','category':'Meat','base_unit':'g','stock':3000.0,'min_threshold':700.0,'supplier':'Local'},
      {'id':'ING007','name':'Biryani Masala','category':'Spices','base_unit':'g','stock':800.0,'min_threshold':200.0,'supplier':'Local'},
      {'id':'ING008','name':'Dosa Batter','category':'Batter','base_unit':'g','stock':4000.0,'min_threshold':1000.0,'supplier':'Local'},
      {'id':'ING009','name':'Potato Masala','category':'Veg','base_unit':'g','stock':2500.0,'min_threshold':600.0,'supplier':'Local'},
      {'id':'ING010','name':'Flour','category':'Bakery','base_unit':'g','stock':4000.0,'min_threshold':900.0,'supplier':'Local'},
      {'id':'ING011','name':'Butter','category':'Dairy','base_unit':'g','stock':1200.0,'min_threshold':300.0,'supplier':'Local'},
      {'id':'ING012','name':'Yeast','category':'Bakery','base_unit':'g','stock':300.0,'min_threshold':50.0,'supplier':'Local'},
      {'id':'ING013','name':'Khoya Mix','category':'Dessert','base_unit':'g','stock':1200.0,'min_threshold':300.0,'supplier':'Local'},
      {'id':'ING014','name':'Sugar Syrup','category':'Dessert','base_unit':'ml','stock':1500.0,'min_threshold':400.0,'supplier':'Local'},
      {'id':'ING015','name':'Milk','category':'Dairy','base_unit':'ml','stock':3000.0,'min_threshold':800.0,'supplier':'Local'},
      {'id':'ING016','name':'Coffee','category':'Beverage','base_unit':'g','stock':500.0,'min_threshold':100.0,'supplier':'Local'},
      {'id':'ING017','name':'Sugar','category':'Beverage','base_unit':'g','stock':2000.0,'min_threshold':500.0,'supplier':'Local'},
      {'id':'ING018','name':'Black Lentils','category':'Legumes','base_unit':'g','stock':2500.0,'min_threshold':600.0,'supplier':'Local'},
      {'id':'ING019','name':'Cream','category':'Dairy','base_unit':'ml','stock':1200.0,'min_threshold':300.0,'supplier':'Local'},
      {'id':'ING020','name':'Roll Wrapper','category':'Bakery','base_unit':'pc','stock':200.0,'min_threshold':50.0,'supplier':'Local'},
      {'id':'ING021','name':'Veg Mix','category':'Veg','base_unit':'g','stock':3000.0,'min_threshold':800.0,'supplier':'Local'},
    ];
    final ids = seed.map((e) => e['id']!.toString()).toList();
    final toDelete = <String>[];
    await db.transaction((txn) async {
      final rows = await txn.query('ingredients', columns: ['id']);
      for (final r in rows) {
        final id = r['id']!.toString();
        if (!ids.contains(id)) {
          toDelete.add(id);
        }
      }
      if (toDelete.isNotEmpty) {
        final batch = txn.batch();
        for (final id in toDelete) {
          batch.delete('recipes', where: 'ingredient_id = ?', whereArgs: [id]);
          batch.delete('inventory_txns', where: 'ingredient_id = ?', whereArgs: [id]);
          batch.delete('ingredients', where: 'id = ?', whereArgs: [id]);
        }
        await batch.commit(noResult: true);
      }
      for (final ing in seed) {
        await upsertIngredient(ing, notify: false, txn: txn);
      }
    });
    for (final id in toDelete) {
      await SyncService.instance.deleteIngredient(id);
    }
    for (final ing in seed) {
      await SyncService.instance.updateIngredient(ing);
    }
    if (notify) Repository.instance.notifyDataChanged();
  }
}

class RoleDao {
  Future<void> upsertRole(Map<String, dynamic> data, {bool fromSync = false, bool notify = true, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final toSave = Map<String, dynamic>.from(data);
    toSave.remove('_client');
    if (toSave['name'] != null) {
      toSave['name'] = toSave['name'].toString().toLowerCase();
    }
    if (toSave['permissions'] is! String) {
      toSave['permissions'] = jsonEncode(toSave['permissions'] ?? {});
    }
    await executor.insert('role_configs', toSave, conflictAlgorithm: ConflictAlgorithm.replace);
    if (!fromSync) {
      try {
        await SyncService.instance.updateRoleConfig(toSave);
      } catch (_) {}
    }
    if (notify) Repository.instance.notifyDataChanged();
  }

  Future<List<Map<String, dynamic>>> listRoles({Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('role_configs');
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      if (m['permissions'] is String) {
        try {
          m['permissions'] = jsonDecode(m['permissions'] as String);
        } catch (_) {
          m['permissions'] = {};
        }
      }
      return m;
    }).toList();
  }

  Future<Map<String, dynamic>?> getRole(String id, {Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('role_configs', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final m = Map<String, dynamic>.from(rows.first);
    if (m['permissions'] is String) {
      try {
        m['permissions'] = jsonDecode(m['permissions'] as String);
      } catch (_) {
        m['permissions'] = {};
      }
    }
    return m;
  }

  Future<Map<String, dynamic>?> getRoleByName(String name, {Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    final rows = await executor.query('role_configs', where: 'LOWER(name) = ?', whereArgs: [name.toLowerCase()]);
    if (rows.isEmpty) return null;
    final m = Map<String, dynamic>.from(rows.first);
    if (m['permissions'] is String) {
      try {
        m['permissions'] = jsonDecode(m['permissions'] as String);
      } catch (_) {
        m['permissions'] = {};
      }
    }
    return m;
  }

  Future<void> deleteRole(String id, {bool fromSync = false, Transaction? txn}) async {
    final db = await Repository.instance._db.database;
    final executor = txn ?? db;
    await executor.delete('role_configs', where: 'id = ?', whereArgs: [id]);
    if (!fromSync) await SyncService.instance.deleteRoleConfig(id);
  }
}
