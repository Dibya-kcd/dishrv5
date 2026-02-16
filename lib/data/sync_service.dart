import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'repository.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/table_info.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();
  static const bool enabled = true;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Repository _repo = Repository.instance;

  void _logRoleSync(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  bool _initialized = false;
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  // Use root path for shared data access (no device binding)
  String _clientPath(String node) => node;
  String _menuKey(int id) => 'MENU${id.toString().padLeft(3, '0')}';

  void init() {
    if (!enabled) return;
    if (_initialized) return;
    _initialized = true;

    // Monitor connection status
    _dbRef.child('.info/connected').onValue.listen((event) {
      connected.value = event.snapshot.value == true;
    });

    _syncMenuItems();
    _syncOrders();
    _syncTables();
    _syncExpenses();
    _syncEmployees();
    _syncIngredients();
    _syncRecipes();
    _syncInventoryTxns();
    _syncRoleConfigs();

    
    // Attempt initial upload after a short delay to ensure DB is ready
    Future.delayed(const Duration(seconds: 2), () {
      initialUpload();
    });
  }

  Future<void> logAuditEvent(String event, Map<String, dynamic> data) async {
    if (!enabled) return;
    final user = FirebaseAuth.instance.currentUser;
    final payload = {
      'event': event,
      'data': data,
      'timestamp': ServerValue.timestamp,
      'user_id': user?.uid,
    };
    await _dbRef.child('audit_log').push().set(payload);
  }

  // --- Menu Items ---
  void _syncMenuItems() {
    _dbRef.child(_clientPath('menu_items')).onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return; // For menu items, we can keep the simple return or handle similarly
        
        final database = await _repo.database;
        await database.transaction((txn) async {
          if (data is List) {
            final items = <MenuItem>[];
            for (var item in data) {
              if (item != null) {
                items.add(MenuItem.fromJson(Map<String, dynamic>.from(item)));
              }
            }
            await _repo.menu.upsertMenuItems(items, fromSync: true, notify: false, txn: txn);
          } else if (data is Map) {
            for (final entry in (data).entries) {
              final node = Map<String, dynamic>.from(entry.value as Map);
              // Upsert menu item
              final menu = MenuItem.fromJson(node);
              await _repo.menu.upsertMenuItems([menu], fromSync: true, notify: false, txn: txn);
              // If nested recipe exists, sync it to local DB
              if (node['recipe'] is Map && node['recipe']['items'] is List) {
                final items = List<Map<String, dynamic>>.from((node['recipe']['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
                await _repo.ingredients.setRecipeForMenuItem(menu.id, items, fromSync: true, notify: false, txn: txn);
              }
            }
          }
        });
        _repo.notifyDataChanged();
      } catch (e) {
        // Error syncing menu items
      }
    });
  }

  Future<void> updateMenuItem(MenuItem item) async {
    final meta = _repo.clientMeta;
    final payload = item.toJson();
    if (meta != null) payload['_client'] = meta;
    final key = _menuKey(item.id);
    await _dbRef.child(_clientPath('menu_items/$key')).set(payload);
    // Also clean up old numeric key, if exists
    await _dbRef.child(_clientPath('menu_items/${item.id}')).remove();
  }
  
  Future<void> deleteMenuItem(int id) async {
    final key = _menuKey(id);
    await _dbRef.child(_clientPath('menu_items/$key')).remove();
    await _dbRef.child(_clientPath('menu_items/$id')).remove();
  }

  // --- Orders ---
  void _syncOrders() {
    bool initialSyncDone = false;
    
    // Listen for the entire orders node once to handle initial state efficiently
    _dbRef.child(_clientPath('orders')).onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        if (data is Map && !initialSyncDone) {
          final ordersData = Map<String, dynamic>.from(data);
          final database = await _repo.database;
          await database.transaction((txn) async {
            for (var key in ordersData.keys) {
              final orderData = Map<String, dynamic>.from(ordersData[key] as Map);
              final order = Order.fromJson(orderData);
              final tbl = order.table.trim();
              final unlabeled = tbl.isEmpty || tbl.toLowerCase() == 'unknown';
              if (unlabeled && order.items.isEmpty) continue;
              await _repo.orders.insertOrder(order, order.items, fromSync: true, notify: false, txn: txn);
            }
          });
          _repo.notifyDataChanged();
          initialSyncDone = true;
        }
      } catch (e) {
        // Error in initial orders sync
      }
    });

    // Then listen for child events for real-time updates
    Future<void> handler(DatabaseEvent event) async {
       if (!initialSyncDone) return; // Skip if initial sync is still processing
       try {
         final data = event.snapshot.value;
         if (data != null && data is Map) {
             final orderData = Map<String, dynamic>.from(data);
             final order = Order.fromJson(orderData);
             final tbl = order.table.trim();
             final unlabeled = tbl.isEmpty || tbl.toLowerCase() == 'unknown';
             if (unlabeled && order.items.isEmpty) return;
             await _repo.orders.insertOrder(order, order.items, fromSync: true, notify: true);
         }
      } catch (e) {
        // Error syncing order update
      }
    }
    _dbRef.child(_clientPath('orders')).onChildAdded.listen(handler);
    _dbRef.child(_clientPath('orders')).onChildChanged.listen(handler);
  }
  
  Future<void> updateOrder(Order order) async {
    final meta = _repo.clientMeta;
    final payload = order.toJson();
    if (meta != null) payload['_client'] = meta;
    await _dbRef.child(_clientPath('orders/${order.id}')).set(payload);
  }
  Future<void> deleteAllOrders() async {
    await _dbRef.child(_clientPath('orders')).remove();
  }
  Future<void> deleteAllData() async {
    await _dbRef.child(_clientPath('menu_items')).remove();
    await _dbRef.child(_clientPath('orders')).remove();
    await _dbRef.child(_clientPath('tables')).remove();
    await _dbRef.child(_clientPath('expenses')).remove();
    await _dbRef.child(_clientPath('employees')).remove();
    await _dbRef.child(_clientPath('ingredients')).remove();
    await _dbRef.child(_clientPath('recipes')).remove();
    await _dbRef.child(_clientPath('inventory_txns')).remove();
    await _dbRef.child(_clientPath('role_configs')).remove();
  }


  // --- Tables ---
  void _syncTables() {
    _dbRef.child(_clientPath('tables')).onValue.listen((event) async {
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
        
        final database = await _repo.database;
        await database.transaction((txn) async {
          for (var t in tables) {
            await _repo.tables.upsertTable(t.id, t.number, t.status, t.capacity, orderId: t.orderId, fromSync: true, notify: false, txn: txn); 
          }
        });
        _repo.notifyDataChanged();
      } catch (e) {
        // debugPrint('Error syncing tables: $e');
      }
    });
  }

  Future<void> updateTable(TableInfo table) async {
    final meta = _repo.clientMeta;
    final payload = table.toJson();
    if (meta != null) payload['_client'] = meta;
    await _dbRef.child(_clientPath('tables/${table.id}')).set(payload);
  }

  // --- Expenses ---
  void _syncExpenses() {
    _dbRef.child(_clientPath('expenses')).onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        if (data is Map) {
          final database = await _repo.database;
          await database.transaction((txn) async {
            for (var key in data.keys) {
              final expenseData = Map<String, dynamic>.from(data[key] as Map);
              await _repo.expenses.insertExpense(expenseData, fromSync: true, notify: false, txn: txn);
            }
          });
          _repo.notifyDataChanged();
        }
      } catch (e) {
        // debugPrint('Error syncing expenses: $e');
      }
    });
  }

  Future<void> updateExpense(Map<String, dynamic> expense) async {
    final meta = _repo.clientMeta;
    final payload = Map<String, dynamic>.from(expense);
    if (meta != null) payload['_client'] = meta;
    await _dbRef.child(_clientPath('expenses/${expense['id']}')).set(payload);
  }

  Future<void> deleteExpense(String id) async {
    await _dbRef.child(_clientPath('expenses/$id')).remove();
  }

  // --- Ingredients ---
  void _syncIngredients() {
    _dbRef.child(_clientPath('ingredients')).onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        if (data is Map) {
          final database = await _repo.database;
          await database.transaction((txn) async {
            for (var key in data.keys) {
               final ingData = Map<String, dynamic>.from(data[key] as Map);
               if (ingData['id'] == null || ingData['id'].toString().isEmpty) {
                 ingData['id'] = key.toString();
               }
               await _repo.ingredients.upsertIngredient(ingData, fromSync: true, notify: false, txn: txn);
            }
          });
          _repo.notifyDataChanged();
        }
      } catch (e) {
        // debugPrint('Error syncing ingredients: $e');
      }
    });
  }

  // --- Employees ---
  void _syncEmployees() {
    _dbRef.child(_clientPath('employees')).onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) {
          // If remote is null, it means the node is missing in Firebase.
          // DO NOT wipe local data; instead, let initialUpload handle it later.
          return;
        }
        if (data is Map) {
          final remoteData = Map<String, dynamic>.from(data);
          
          // Get all local employee IDs
          final localEmps = await _repo.employees.listEmployees();
          final localIds = localEmps.map((e) => e['id'].toString()).toSet();
          final remoteIds = remoteData.keys.map((k) => k.toString()).toSet();

          final database = await _repo.database;
          await database.transaction((txn) async {
            for (var key in remoteData.keys) {
              final empData = Map<String, dynamic>.from(remoteData[key] as Map);
              final id = key.toString();
              
              // Normalize employee role to lowercase
              if (empData['role'] != null) {
                empData['role'] = empData['role'].toString().toLowerCase();
              }
              
              // Step 3: Prevent Restoration - Check for deleted flag
              if (empData['deleted'] == true) {
                await _repo.employees.deleteEmployee(id, fromSync: true, notify: false, txn: txn);
              } else {
                await _repo.employees.upsertEmployee(empData, fromSync: true, notify: false, txn: txn);
              }
            }

            // Also handle cases where records were completely removed from Firebase (hard delete)
            for (final localId in localIds) {
              if (!remoteIds.contains(localId)) {
                await _repo.employees.deleteEmployee(localId, fromSync: true, notify: false, txn: txn);
              }
            }
          });
        }
        _repo.notifyDataChanged();
      } catch (e) {
        // Error syncing employees
      }
    });
  }

  Future<void> updateEmployee(Map<String, dynamic> employee) async {
    final id = employee['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final meta = _repo.clientMeta;
    final payload = Map<String, dynamic>.from(employee);
    // Normalize employee role to lowercase
    if (payload['role'] != null) {
      payload['role'] = payload['role'].toString().toLowerCase();
    }
    if (meta != null) payload['_client'] = meta;
    // Keep the deleted flag if provided, otherwise default to false
    payload['deleted'] = employee['deleted'] == true;
    await _dbRef.child(_clientPath('employees/$id')).set(payload);
  }

  Future<void> deleteEmployee(String id) async {
    // Check for Firebase Auth before attempting write
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Firebase Authentication required. Please sign in via Admin Panel.');
    }

    // Step 1: Use Online (Firebase) as Master - Soft Delete first
    final meta = _repo.clientMeta;
    await _dbRef.child(_clientPath('employees/$id')).update({
      'deleted': true,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      if (meta != null) '_client': meta,
    });
  }

  Future<void> updateIngredient(Map<String, dynamic> ingredient) async {
    final meta = _repo.clientMeta;
    final payload = Map<String, dynamic>.from(ingredient);
    final name = (payload['name']?.toString() ?? '').trim();
    final mapping = <String, String>{
      'Paneer': 'ING001',
      'Curd': 'ING002',
      'Spice Mix': 'ING003',
      'Oil': 'ING004',
      'Rice': 'ING005',
      'Chicken': 'ING006',
      'Biryani Masala': 'ING007',
      'Dosa Batter': 'ING008',
      'Potato Masala': 'ING009',
      'Flour': 'ING010',
      'Butter': 'ING011',
      'Yeast': 'ING012',
      'Khoya Mix': 'ING013',
      'Sugar Syrup': 'ING014',
      'Milk': 'ING015',
      'Coffee': 'ING016',
      'Sugar': 'ING017',
      'Black Lentils': 'ING018',
      'Cream': 'ING019',
      'Roll Wrapper': 'ING020',
      'Veg Mix': 'ING021',
    };
    final canon = mapping[name];
    if (canon != null) {
      payload['id'] = canon;
    }
    if (meta != null) payload['_client'] = meta;
    await _dbRef.child(_clientPath('ingredients/${payload['id']}')).set(payload);
  }
  Future<void> deleteIngredient(String id) async {
    await _dbRef.child(_clientPath('ingredients/$id')).remove();
  }
  Future<int> purgeNonSeedIngredientsRemote() async {
    final allowed = <String>{
      'ING001','ING002','ING003','ING004','ING005','ING006','ING007',
      'ING008','ING009','ING010','ING011','ING012','ING013','ING014',
      'ING015','ING016','ING017','ING018','ING019','ING020','ING021'
    };
    final snap = await _dbRef.child(_clientPath('ingredients')).get();
    if (!snap.exists) return 0;
    final data = snap.value;
    int removed = 0;
    if (data is Map) {
      for (final key in data.keys) {
        final k = key.toString();
        if (!allowed.contains(k)) {
          await _dbRef.child(_clientPath('ingredients/$k')).remove();
          removed++;
        }
      }
    }
    return removed;
  }
  Future<void> scrubIngredientFromRecipes(String ingredientId) async {
    final snapshot = await _dbRef.child(_clientPath('recipes')).get();
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
          await _dbRef.child(_clientPath('recipes/$key')).set(filtered);
        }
      }
    }
  }

  // --- Recipes ---
  void _syncRecipes() {
    _dbRef.child(_clientPath('recipes')).onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        if (data is Map) {
          final database = await _repo.database;
          await database.transaction((txn) async {
            for (var key in data.keys) {
               final menuItemId = int.tryParse(key.toString());
               if (menuItemId != null) {
                 final node = data[key];
                 if (node is Map && node['items'] is List) {
                   final itemsList = node['items'] as List;
                   final mapped = itemsList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                   await _repo.ingredients.setRecipeForMenuItem(menuItemId, mapped, fromSync: true, notify: false, txn: txn);
                 } else if (node is List) {
                   final mapped = node.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                   await _repo.ingredients.setRecipeForMenuItem(menuItemId, mapped, fromSync: true, notify: false, txn: txn);
                 }
               }
            }
          });
          _repo.notifyDataChanged();
        }
      } catch (e) {
        // debugPrint('Error syncing recipes: $e');
      }
    });
  }

  Future<void> updateRecipe(int menuItemId, List<Map<String, dynamic>> items) async {
    final meta = _repo.clientMeta;
    final payload = {
      'items': items.map((e) => Map<String, dynamic>.from(e)).toList(),
      if (meta != null) '_client': meta,
    };
    // Write nested under menu item canonical key
    final key = _menuKey(menuItemId);
    await _dbRef.child(_clientPath('menu_items/$key/recipe')).set(payload);
    // Remove old flat recipe path to enforce the new structure
    await _dbRef.child(_clientPath('recipes/$menuItemId')).remove();
  }

  // --- Inventory Transactions ---
  void _syncInventoryTxns() {
    _dbRef.child(_clientPath('inventory_txns')).onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        
        if (data is Map) {
          final database = await _repo.database;
          await database.transaction((txn) async {
            for (var key in data.keys) {
               final txnData = Map<String, dynamic>.from(data[key] as Map);
               await _repo.ingredients.insertTxn(txnData, fromSync: true, notify: false, txn: txn);
            }
          });
          _repo.notifyDataChanged();
        }
      } catch (e) {
        debugPrint('Error syncing inventory txns: $e');
      }
    });
  }
  
  Future<void> updateInventoryTxn(Map<String, dynamic> txn) async {
    try {
      final meta = _repo.clientMeta;
      final payload = Map<String, dynamic>.from(txn);
      if (meta != null) payload['_client'] = meta;
      await _dbRef.child(_clientPath('inventory_txns/${payload['id']}')).set(payload);
    } catch (e) {
      // debugPrint('Error updating inventory txn: $e');
    }
  }

  Future<void> addInventoryTxn(Map<String, dynamic> txn) async {
    final meta = _repo.clientMeta;
    final payload = Map<String, dynamic>.from(txn);
    if (meta != null) payload['_client'] = meta;
    await _dbRef.child(_clientPath('inventory_txns/${payload['id']}')).set(payload);
  }
  
  // --- Role Configs ---
  void _syncRoleConfigs() {
    _dbRef.child(_clientPath('role_configs')).onValue.listen((event) async {
      try {
        final data = event.snapshot.value;
        if (data == null) return;
        if (data is Map) {
          final configs = Map<String, dynamic>.from(data);
          final database = await _repo.database;
          await database.transaction((txn) async {
            for (var entry in configs.entries) {
              final config = Map<String, dynamic>.from(entry.value as Map);
              if (config['name'] != null) {
                config['name'] = config['name'].toString().toLowerCase();
              }
              await _repo.roles.upsertRole(config, fromSync: true, notify: false, txn: txn);
            }
          });
          _repo.notifyDataChanged();
        }
      } catch (e) {
        // debugPrint('Error syncing role configs: $e');
      }
    });
  }

  Future<void> updateRoleConfig(Map<String, dynamic> config) async {
    final id = config['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final meta = _repo.clientMeta;
    final payload = Map<String, dynamic>.from(config);
    // Normalize role name to lowercase
    if (payload['name'] != null) {
      payload['name'] = payload['name'].toString().toLowerCase();
    }
    if (meta != null) payload['_client'] = meta;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _logRoleSync('[ROLE_SYNC] updateRoleConfig id=$id role=${payload['name']} uid=${uid ?? 'null'} path=${_clientPath('role_configs/$id')}');
    if (uid != null) {
      try {
        final snap = await _dbRef.child('roles/$uid/role').get();
        _logRoleSync('[ROLE_SYNC] firebaseRoleForUid=$uid value=${snap.value}');
      } catch (e) {
        _logRoleSync('[ROLE_SYNC] firebaseRoleLookupError uid=$uid error=$e');
      }
    }
    try {
      await _dbRef.child(_clientPath('role_configs/$id')).set(payload);
      _logRoleSync('[ROLE_SYNC] updateRoleConfig success id=$id');
    } catch (e) {
      _logRoleSync('[ROLE_SYNC] updateRoleConfig error id=$id error=$e');
      rethrow;
    }
  }

  Future<void> deleteRoleConfig(String id) async {
    await _dbRef.child(_clientPath('role_configs/$id')).remove();
  }

  // Initial Upload

  Future<void> initialUpload() async {
    try {
      final meta = _repo.clientMeta;
      if (meta == null) {
        // Skip initial upload until a PIN session is set
        return;
      }

      // Check current user role from Firebase to ensure we have permission to seed
      final userRole = await getCurrentUserRole();
      if (userRole != 'admin' && userRole != 'manager') {
        // Only admins or managers should perform initial seeding of critical data
        // Waiters and others only sync their own orders/tables usually
        // But for this simple app, we only allow admin/manager to populate Firebase
        return;
      }

      final snapshot = await _dbRef.child(_clientPath('menu_items')).get();
      if (!snapshot.exists) {
        final menuItems = await _repo.menu.listMenu();
        for (var m in menuItems) {
          final payload = m.toJson();
          payload['_client'] = meta;
          final key = _menuKey(m.id);
          await _dbRef.child(_clientPath('menu_items/$key')).set(payload);
          final recipes = await _repo.ingredients.getRecipeForMenuItem(m.id);
          if (recipes.isNotEmpty) {
            await _dbRef.child(_clientPath('menu_items/$key/recipe')).set({
              'items': recipes.map((e) => Map<String, dynamic>.from(e)).toList(),
              '_client': meta,
            });
          }
        }
      }

      final tablesSnapshot = await _dbRef.child(_clientPath('tables')).get();
      if (!tablesSnapshot.exists) {
        // debugPrint('Uploading initial tables...');
        final tables = await _repo.tables.listTables();
        for (var t in tables) {
          final payload = t.toJson();
          payload['_client'] = meta;
          await _dbRef.child(_clientPath('tables/${t.id}')).set(payload);
        }
      }
      
      // Upload orders if missing? Maybe not needed for initial setup if empty.
      // But if user has existing offline data and wants to sync it up:
      final ordersSnapshot = await _dbRef.child(_clientPath('orders')).get();
      if (!ordersSnapshot.exists) {
         final orders = await _repo.orders.listOrdersWithItems();
         for (var o in orders) {
           final payload = o.toJson();
           payload['_client'] = meta;
           await _dbRef.child(_clientPath('orders/${o.id}')).set(payload);
         }
      }

      final expensesSnapshot = await _dbRef.child(_clientPath('expenses')).get();
      if (!expensesSnapshot.exists) {
         // debugPrint('Uploading initial expenses...');
         final expenses = await _repo.expenses.listExpenses();
         for (var e in expenses) {
            final payload = Map<String, dynamic>.from(e);
            payload['_client'] = meta;
            await _dbRef.child(_clientPath('expenses/${payload['id']}')).set(payload);
         }
      }

      final ingredientsSnapshot = await _dbRef.child(_clientPath('ingredients')).get();
      if (!ingredientsSnapshot.exists) {
         // debugPrint('Uploading initial ingredients...');
         final ingredients = await _repo.ingredients.listIngredients();
         for (var i in ingredients) {
            final payload = Map<String, dynamic>.from(i);
            payload['_client'] = meta;
            await _dbRef.child(_clientPath('ingredients/${payload['id']}')).set(payload);
         }
      }

      // No need to seed flat 'recipes' path; recipes are nested under each menu item

      final txnsSnapshot = await _dbRef.child(_clientPath('inventory_txns')).get();
      if (!txnsSnapshot.exists) {
         // debugPrint('Uploading initial inventory transactions...');
         final txns = await _repo.ingredients.listTransactions(limit: 1000); // Upload last 1000
         for (var t in txns) {
            final payload = Map<String, dynamic>.from(t);
            payload['_client'] = meta;
            await _dbRef.child(_clientPath('inventory_txns/${payload['id']}')).set(payload);
         }
      }

      final rolesSnapshot = await _dbRef.child(_clientPath('role_configs')).get();
      if (!rolesSnapshot.exists) {
        final roles = await _repo.roles.listRoles();
        for (var r in roles) {
          final payload = Map<String, dynamic>.from(r);
          payload['_client'] = meta;
          await _dbRef.child(_clientPath('role_configs/${r['id']}')).set(payload);
        }
      }

      final employeesSnapshot = await _dbRef.child(_clientPath('employees')).get();
      if (!employeesSnapshot.exists) {
        final emps = await _repo.employees.listEmployees();
        for (var e in emps) {
          final payload = Map<String, dynamic>.from(e);
          payload['_client'] = meta;
          final id = payload['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            await _dbRef.child(_clientPath('employees/$id')).set(payload);
          }
        }
      }
      
    } catch (e) {
      // debugPrint('Initial upload failed: $e');
    }
  }

  // Migration: move menu_items numeric keys to MENU### and nest recipes
  Future<Map<String, int>> migrateMenusToCanonicalAndNest() async {
    int migrated = 0;
    int removedLegacy = 0;
    final result = <String, int>{'migrated': 0, 'removed_legacy': 0};
    final menuSnap = await _dbRef.child(_clientPath('menu_items')).get();
    final recipeSnap = await _dbRef.child(_clientPath('recipes')).get();
    final meta = _repo.clientMeta;
    final recipesMap = <String, dynamic>{};
    if (recipeSnap.exists && recipeSnap.value is Map) {
      recipesMap.addAll(Map<String, dynamic>.from(recipeSnap.value as Map));
    }
    if (menuSnap.exists) {
      final data = menuSnap.value;
      if (data is Map) {
        for (final entry in (data).entries) {
          final key = entry.key.toString();
          final value = Map<String, dynamic>.from(entry.value as Map);
          final id = int.tryParse(key);
          if (id == null) {
            // Already canonical; also ensure nested recipe from flat path if exists
            final flat = recipesMap[key] ?? recipesMap[id?.toString() ?? ''];
            if (flat is Map && flat['items'] is List) {
              await _dbRef.child(_clientPath('menu_items/$key/recipe')).set({
                'items': List<Map<String, dynamic>>.from((flat['items'] as List).map((e) => Map<String, dynamic>.from(e as Map))),
                if (meta != null) '_client': meta,
              });
            } else if (flat is List) {
              await _dbRef.child(_clientPath('menu_items/$key/recipe')).set({
                'items': List<Map<String, dynamic>>.from(flat.map((e) => Map<String, dynamic>.from(e as Map))),
                if (meta != null) '_client': meta,
              });
            }
            continue;
          }
          final newKey = _menuKey(id);
          await _dbRef.child(_clientPath('menu_items/$newKey')).set({
            ...value,
            if (meta != null) '_client': meta,
          });
          // Attach recipes
          final node = recipesMap[key];
          if (node is Map && node['items'] is List) {
            await _dbRef.child(_clientPath('menu_items/$newKey/recipe')).set({
              'items': List<Map<String, dynamic>>.from((node['items'] as List).map((e) => Map<String, dynamic>.from(e as Map))),
              if (meta != null) '_client': meta,
            });
          } else if (node is List) {
            await _dbRef.child(_clientPath('menu_items/$newKey/recipe')).set({
              'items': List<Map<String, dynamic>>.from(node.map((e) => Map<String, dynamic>.from(e as Map))),
              if (meta != null) '_client': meta,
            });
          }
          // Remove old numeric
          await _dbRef.child(_clientPath('menu_items/$key')).remove();
          migrated++;
        }
      } else if (data is List) {
        for (var i = 0; i < data.length; i++) {
          final item = data[i];
          if (item == null) continue;
          final m = Map<String, dynamic>.from(item as Map);
          final id = int.tryParse(m['id']?.toString() ?? '');
          if (id == null) continue;
          final newKey = _menuKey(id);
          await _dbRef.child(_clientPath('menu_items/$newKey')).set({
            ...m,
            if (meta != null) '_client': meta,
          });
          final node = recipesMap[id.toString()];
          if (node is Map && node['items'] is List) {
            await _dbRef.child(_clientPath('menu_items/$newKey/recipe')).set({
              'items': List<Map<String, dynamic>>.from((node['items'] as List).map((e) => Map<String, dynamic>.from(e as Map))),
              if (meta != null) '_client': meta,
            });
          } else if (node is List) {
            await _dbRef.child(_clientPath('menu_items/$newKey/recipe')).set({
              'items': List<Map<String, dynamic>>.from(node.map((e) => Map<String, dynamic>.from(e as Map))),
              if (meta != null) '_client': meta,
            });
          }
          migrated++;
        }
        // Remove list form entirely
        await _dbRef.child(_clientPath('menu_items')).remove();
        // We just removed the whole node; re-create canonical entries are already set above
      }
    }
    // Remove flat recipes path entirely
    if (recipeSnap.exists) {
      await _dbRef.child(_clientPath('recipes')).remove();
      removedLegacy++;
    }
    result['migrated'] = migrated;
    result['removed_legacy'] = removedLegacy;
    return result;
  }

  // Deduplication & Cleanup

  Future<Map<String, int>> deduplicateAllNodes() async {
    final results = <String, int>{};
    try {
      results['ingredients'] = await deduplicateNode('ingredients', 'name', mergeIngredients: true);
      results['menu_items'] = await deduplicateNode('menu_items', 'name');
      results['employees'] = await deduplicateNode('employees', 'name');
      results['tables'] = await deduplicateNode('tables', 'number');
      results['role_configs'] = await deduplicateNode('role_configs', 'name');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during deduplication: $e');
      }
    }
    return results;
  }

  Future<int> deduplicateNode(String node, String identityField, {bool mergeIngredients = false}) async {
    final snapshot = await _dbRef.child(_clientPath(node)).get();
    if (!snapshot.exists) return 0;
    
    final data = snapshot.value;
    if (data is! Map) return 0;

    final items = Map<String, dynamic>.from(data);
    final groups = <String, List<String>>{}; // identity -> list of IDs

    items.forEach((id, value) {
      if (value is Map) {
        final identity = value[identityField]?.toString().toLowerCase().trim() ?? '';
        if (identity.isNotEmpty) {
          groups.putIfAbsent(identity, () => []).add(id.toString());
        }
      }
    });

    int removedCount = 0;
    for (final entry in groups.entries) {
      final ids = entry.value;
      if (ids.length > 1) {
        // Keep the first one, delete the rest
        // We sort them so that we hopefully keep the one with more data or the "best" ID
        ids.sort(); 
        final masterId = ids.first;
        final duplicates = ids.sublist(1);

        for (final dupId in duplicates) {
          if (mergeIngredients && node == 'ingredients') {
             await _mergeIngredient(dupId, masterId);
          }
          await _dbRef.child(_clientPath('$node/$dupId')).remove();
          removedCount++;
        }
      }
    }
    return removedCount;
  }

  Future<void> _mergeIngredient(String oldId, String newId) async {
    // 1. Update recipes
    final recipesSnap = await _dbRef.child(_clientPath('recipes')).get();
    if (recipesSnap.exists && recipesSnap.value is Map) {
      final recipes = Map<String, dynamic>.from(recipesSnap.value as Map);
      for (final menuItemId in recipes.keys) {
        final node = recipes[menuItemId];
        if (node is Map && node['items'] is List) {
          final items = List<Map<String, dynamic>>.from((node['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
          bool changed = false;
          for (final item in items) {
            if (item['ingredient_id']?.toString() == oldId) {
              item['ingredient_id'] = newId;
              changed = true;
            }
          }
          if (changed) {
            await _dbRef.child(_clientPath('recipes/$menuItemId/items')).set(items);
          }
        } else if (node is List) {
           final items = List<Map<String, dynamic>>.from(node.map((e) => Map<String, dynamic>.from(e as Map)));
           bool changed = false;
           for (final item in items) {
             if (item['ingredient_id']?.toString() == oldId) {
               item['ingredient_id'] = newId;
               changed = true;
             }
           }
           if (changed) {
             await _dbRef.child(_clientPath('recipes/$menuItemId')).set(items);
           }
        }
      }
    }

    // 2. Update inventory transactions
    final txnsSnap = await _dbRef.child(_clientPath('inventory_txns')).get();
    if (txnsSnap.exists && txnsSnap.value is Map) {
      final txns = Map<String, dynamic>.from(txnsSnap.value as Map);
      for (final txnId in txns.keys) {
        final txn = Map<String, dynamic>.from(txns[txnId] as Map);
        if (txn['ingredient_id']?.toString() == oldId) {
          await _dbRef.child(_clientPath('inventory_txns/$txnId/ingredient_id')).set(newId);
        }
      }
    }
  }

  Future<String?> getCurrentUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await _dbRef.child('roles/$uid/role').get();
    if (!snap.exists) return null;
    final v = snap.value;
    return v?.toString();
  }
  Future<void> setCurrentUserRole(String role) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final normalized = role.toLowerCase();
    if (normalized != 'admin' && normalized != 'manager') {
      _logRoleSync('[ROLE_SYNC] setCurrentUserRole skip persist role=$normalized');
      return;
    }
    String? current;
    try {
      final snap = await _dbRef.child('roles/$uid/role').get();
      if (snap.exists) {
        current = snap.value?.toString().toLowerCase();
      }
    } catch (_) {}
    String next;
    if (normalized == 'admin') {
      next = 'admin';
    } else {
      if (current == 'admin') {
        _logRoleSync('[ROLE_SYNC] setCurrentUserRole keep existing admin, requested=$normalized');
        return;
      }
      next = 'manager';
    }
    await _dbRef.child('roles/$uid').set({'role': next});
    _logRoleSync('[ROLE_SYNC] setCurrentUserRole uid=$uid role=$next');
  }
}
