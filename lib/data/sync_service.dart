import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'repository.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/table_info.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Repository _repo = Repository.instance;

  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _syncMenuItems();
    _syncOrders();
    _syncTables();
    _syncExpenses();
    _syncEmployees();
    _syncIngredients();
    _syncRecipes();
    _syncInventoryTxns();
    
    // Attempt initial upload after a short delay to ensure DB is ready
    Future.delayed(const Duration(seconds: 2), () {
      initialUpload();
    });
  }

  // --- Menu Items ---
  void _syncMenuItems() {
    _dbRef.child('menu_items').onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        List<MenuItem> items = [];
        if (data is List) {
          for (var item in data) {
            if (item != null) {
               items.add(MenuItem.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        } else if (data is Map) {
          data.forEach((key, value) {
            items.add(MenuItem.fromJson(Map<String, dynamic>.from(value as Map)));
          });
        }
        
        await _repo.menu.upsertMenuItems(items, fromSync: true);
        _repo.notifyDataChanged();
      } catch (e) {
        // Error syncing menu items
      }
    });
  }

  Future<void> updateMenuItem(MenuItem item) async {
    // We set _isSyncing to true locally before sending to Firebase to avoid echo loop? 
    // Actually, if we update Firebase, the listener will fire. 
    // But we are using upsert locally which is idempotent-ish. 
    // To be safe, we rely on the fact that if data is identical, maybe it's fine.
    // Or we can rely on _isSyncing flag if we set it here, but that blocks incoming syncs.
    // For now, let's just push.
    await _dbRef.child('menu_items/${item.id}').set(item.toJson());
  }
  
  Future<void> deleteMenuItem(int id) async {
    await _dbRef.child('menu_items/$id').remove();
  }

  // --- Orders ---
  void _syncOrders() {
    Future<void> handler(DatabaseEvent event) async {
       try {
         final data = event.snapshot.value;
         if (data != null && data is Map) {
             final orderData = Map<String, dynamic>.from(data);
             final order = Order.fromJson(orderData);
             await _repo.orders.insertOrder(order, order.items, fromSync: true);
         }
      } catch (e) {
        // Error syncing order
      }
    }
    _dbRef.child('orders').onChildAdded.listen(handler);
    _dbRef.child('orders').onChildChanged.listen(handler);
  }
  
  Future<void> updateOrder(Order order) async {
    await _dbRef.child('orders/${order.id}').set(order.toJson());
  }
  Future<void> deleteAllOrders() async {
    await _dbRef.child('orders').remove();
  }
  Future<void> deleteAllData() async {
    await _dbRef.child('menu_items').remove();
    await _dbRef.child('orders').remove();
    await _dbRef.child('tables').remove();
    await _dbRef.child('expenses').remove();
    await _dbRef.child('employees').remove();
    await _dbRef.child('ingredients').remove();
    await _dbRef.child('recipes').remove();
    await _dbRef.child('inventory_txns').remove();
  }

  // --- Tables ---
  void _syncTables() {
    _dbRef.child('tables').onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        List<TableInfo> tables = [];
        if (data is List) {
          for (var item in data) {
             if (item != null) {
               tables.add(TableInfo.fromJson(Map<String, dynamic>.from(item)));
             }
          }
        } else if (data is Map) {
          data.forEach((key, value) {
             tables.add(TableInfo.fromJson(Map<String, dynamic>.from(value as Map)));
          });
        }
        
        for (var t in tables) {
          await _repo.tables.upsertTable(t.id, t.number, t.status, t.capacity, orderId: t.orderId, fromSync: true); 
        }
        _repo.notifyDataChanged();
      } catch (e) {
        // debugPrint('Error syncing tables: $e');
      }
    });
  }

  Future<void> updateTable(TableInfo table) async {
    await _dbRef.child('tables/${table.id}').set(table.toJson());
  }

  // --- Expenses ---
  void _syncExpenses() {
    _dbRef.child('expenses').onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        if (data is Map) {
          for (var key in data.keys) {
            final expenseData = Map<String, dynamic>.from(data[key] as Map);
            await _repo.expenses.insertExpense(expenseData, fromSync: true);
          }
        }
      } catch (e) {
        // debugPrint('Error syncing expenses: $e');
      }
    });
  }

  Future<void> updateExpense(Map<String, dynamic> expense) async {
    await _dbRef.child('expenses/${expense['id']}').set(expense);
  }

  Future<void> deleteExpense(String id) async {
    await _dbRef.child('expenses/$id').remove();
  }

  // --- Ingredients ---
  void _syncIngredients() {
    _dbRef.child('ingredients').onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        if (data is Map) {
          for (var key in data.keys) {
             final ingData = Map<String, dynamic>.from(data[key] as Map);
             await _repo.ingredients.upsertIngredient(ingData, fromSync: true);
          }
        }
        _repo.notifyDataChanged();
      } catch (e) {
        // debugPrint('Error syncing ingredients: $e');
      }
    });
  }

  // --- Employees ---
  void _syncEmployees() {
    _dbRef.child('employees').onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        if (data is Map) {
          for (var key in data.keys) {
            final empData = Map<String, dynamic>.from(data[key] as Map);
            await _repo.employees.upsertEmployee(empData, fromSync: true);
          }
        }
        _repo.notifyDataChanged();
      } catch (e) {
        // debugPrint('Error syncing employees: $e');
      }
    });
  }
  Future<void> updateEmployee(Map<String, dynamic> employee) async {
    final id = employee['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await _dbRef.child('employees/$id').set(employee);
  }
  Future<void> deleteEmployee(String id) async {
    await _dbRef.child('employees/$id').remove();
  }

  Future<void> updateIngredient(Map<String, dynamic> ingredient) async {
    await _dbRef.child('ingredients/${ingredient['id']}').set(ingredient);
  }
  Future<void> deleteIngredient(String id) async {
    await _dbRef.child('ingredients/$id').remove();
  }
  Future<void> scrubIngredientFromRecipes(String ingredientId) async {
    final snapshot = await _dbRef.child('recipes').get();
    if (!snapshot.exists) return;
    final data = snapshot.value;
    if (data is Map) {
      for (var key in data.keys) {
        final itemsList = data[key];
        if (itemsList is List) {
          final filtered = itemsList.where((e) {
            try {
              final m = Map<String, dynamic>.from(e as Map);
              return m['ingredient_id']?.toString() != ingredientId;
            } catch (_) {
              return true;
            }
          }).toList();
          await _dbRef.child('recipes/$key').set(filtered);
        }
      }
    }
  }

  // --- Recipes ---
  void _syncRecipes() {
    _dbRef.child('recipes').onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        if (data is Map) {
          for (var key in data.keys) {
             final menuItemId = int.tryParse(key.toString());
             if (menuItemId != null) {
               final itemsList = data[key];
               if (itemsList is List) {
                 final mapped = itemsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                 await _repo.ingredients.setRecipeForMenuItem(menuItemId, mapped, fromSync: true);
               }
             }
          }
        }
        _repo.notifyDataChanged();
      } catch (e) {
        // debugPrint('Error syncing recipes: $e');
      }
    });
  }

  Future<void> updateRecipe(int menuItemId, List<Map<String, dynamic>> items) async {
    await _dbRef.child('recipes/$menuItemId').set(items);
  }

  // --- Inventory Transactions ---
  void _syncInventoryTxns() {
    _dbRef.child('inventory_txns').onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        if (data is Map) {
          for (var key in data.keys) {
             final txnData = Map<String, dynamic>.from(data[key] as Map);
             // We need a way to insert txn without triggering loop if we had one?
             // But _insertTxn in repo is what we have. 
             // We can use a raw insert method or just use the existing one if we expose it.
             // _insertTxn is private in IngredientsDao, need to make it public or use reflection?
             // Wait, I can't call _insertTxn. I need to expose it.
             // For now, let's assume I will expose it as insertTxn.
             await _repo.ingredients.insertTxn(txnData, fromSync: true);
          }
        }
        _repo.notifyDataChanged();
      } catch (e) {
        debugPrint('Error syncing inventory txns: $e');
      }
    });
  }
  
  Future<void> updateInventoryTxn(Map<String, dynamic> txn) async {
    try {
      await _dbRef.child('inventory_txns/${txn['id']}').set(txn);
    } catch (e) {
      // debugPrint('Error updating inventory txn: $e');
    }
  }

  Future<void> addInventoryTxn(Map<String, dynamic> txn) async {
    await _dbRef.child('inventory_txns/${txn['id']}').set(txn);
  }

  Future<Map<String, dynamic>?> getTakeoutCounterForDate(String date) async {
    try {
      final snapshot = await _dbRef.child('counters/takeout/$date').get();
      final value = snapshot.value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> incrementTakeoutCounter(String date, int delta) async {
    try {
      final ref = _dbRef.child('counters/takeout/$date');
      final result = await ref.runTransaction((currentData) {
        final currentValue = currentData;
        if (currentValue == null) {
          return Transaction.success({'current': delta});
        }
        if (currentValue is Map) {
          final data = Map<String, dynamic>.from(currentValue);
          final cur = (data['current'] as num?)?.toInt() ?? 0;
          data['current'] = cur + delta;
          return Transaction.success(data);
        }
        return Transaction.success({'current': delta});
      });
      final value = result.snapshot.value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> allocateTakeoutTokenForDate(String date) async {
    try {
      final ref = _dbRef.child('counters/takeout/$date');
      final result = await ref.runTransaction((currentData) {
        final currentValue = currentData;
        if (currentValue == null) {
          return Transaction.success({'current': 1});
        }
        if (currentValue is Map) {
          final data = Map<String, dynamic>.from(currentValue);
          final cur = (data['current'] as num?)?.toInt() ?? 0;
          data['current'] = cur + 1;
          return Transaction.success(data);
        }
        return Transaction.success({'current': 1});
      });
      final value = result.snapshot.value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
  
  // Initial Upload
  Future<void> initialUpload() async {
    try {
      final snapshot = await _dbRef.child('menu_items').get();
      if (!snapshot.exists) {
        // debugPrint('Uploading initial menu items...');
        final menuItems = await _repo.menu.listMenu();
        for (var m in menuItems) {
          await _dbRef.child('menu_items/${m.id}').set(m.toJson());
        }
      }

      final tablesSnapshot = await _dbRef.child('tables').get();
      if (!tablesSnapshot.exists) {
        // debugPrint('Uploading initial tables...');
        final tables = await _repo.tables.listTables();
        for (var t in tables) {
          await _dbRef.child('tables/${t.id}').set(t.toJson());
        }
      }
      
      // Upload orders if missing? Maybe not needed for initial setup if empty.
      // But if user has existing offline data and wants to sync it up:
      final ordersSnapshot = await _dbRef.child('orders').get();
      if (!ordersSnapshot.exists) {
         final orders = await _repo.orders.listOrdersWithItems();
         for (var o in orders) {
           await _dbRef.child('orders/${o.id}').set(o.toJson());
         }
      }

      final expensesSnapshot = await _dbRef.child('expenses').get();
      if (!expensesSnapshot.exists) {
         // debugPrint('Uploading initial expenses...');
         final expenses = await _repo.expenses.listExpenses();
         for (var e in expenses) {
            await _dbRef.child('expenses/${e['id']}').set(e);
         }
      }

      final ingredientsSnapshot = await _dbRef.child('ingredients').get();
      if (!ingredientsSnapshot.exists) {
         // debugPrint('Uploading initial ingredients...');
         final ingredients = await _repo.ingredients.listIngredients();
         for (var i in ingredients) {
            await _dbRef.child('ingredients/${i['id']}').set(i);
         }
      }

      final recipesSnapshot = await _dbRef.child('recipes').get();
      if (!recipesSnapshot.exists) {
         // debugPrint('Uploading initial recipes...');
         // We need to fetch all recipes. Since we don't have listAllRecipes, we might need to iterate menu items or add a method.
         // Or easier: sync recipes when menu items are synced if we structure it that way.
         // But here, let's assume we can't easily list all recipes without a new method.
         // Actually, let's just leave recipes for now or add a method to repo.
         // Better: Let's iterate all ingredients or menu items?
         // Recipes are linked to menu items.
         final menuItems = await _repo.menu.listMenu();
         for (var m in menuItems) {
            final recipes = await _repo.ingredients.getRecipeForMenuItem(m.id);
            if (recipes.isNotEmpty) {
               await _dbRef.child('recipes/${m.id}').set(recipes);
            }
         }
      }

      final txnsSnapshot = await _dbRef.child('inventory_txns').get();
      if (!txnsSnapshot.exists) {
         // debugPrint('Uploading initial inventory transactions...');
         final txns = await _repo.ingredients.listTransactions(limit: 1000); // Upload last 1000
         for (var t in txns) {
            await _dbRef.child('inventory_txns/${t['id']}').set(t);
         }
      }
      
    } catch (e) {
      // debugPrint('Initial upload failed: $e');
    }
  }
}
