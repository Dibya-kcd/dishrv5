import 'dart:async';
import 'dart:convert';
import '../utils/web_adapter.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/table_info.dart';
import '../data/repository.dart';
import '../utils/auth_helper.dart';
import '../data/sync_service.dart';
import '../services/printer_service.dart';
import '../utils/html_ticket_generator.dart';

class RestaurantProvider extends ChangeNotifier {
  String _currentView = 'dashboard';
  TableInfo? _selectedTable;
  List<CartItem> _cart = [];
  List<CartItem> _takeoutCart = [];
  Map<String, int> _sentTakeoutQtyByKey = {};
  Map<String, List<Map<String, dynamic>>> _kotBatchesByOrder = {};
  Map<String, Set<String>> _cancelledKeysByOrder = {};
  final Map<String, Set<String>> _completedKeysByOrder = {};
  List<Order> _orders = [];
  
  // UI State for Modals
  bool showKOTPreview = false;
  bool showBillPreview = false;
  bool showPaymentModal = false;
  Map<String, dynamic>? currentKOT;
  Map<String, dynamic>? currentBill;
  
  // Payment State
  String paymentMode = 'Cash';
  bool splitPayment = false;
  double cashAmount = 0;
  double cardAmount = 0;
  double upiAmount = 0;

  int _takeoutTokenNumber = 1;
  String _takeoutTokenDate = '';
  String _selectedCategory = 'All'; // Added state
  dynamic _installPromptEvent;
  final bool _installAvailable = false;
  bool mobileMenuOpen = false;
  List<Map<String, dynamic>> _toasts = [];
  String analyticsRange = 'Today';
  String analyticsCategoryFilter = 'All';
  String analyticsServiceFilter = 'All'; // All, Dine-In, Take-Out
  int reportsTabIndex = 0;
  StreamSubscription? _dataSubscription;

  List<MenuItem> menuItems = [];
  List<String> _categories = [];

  List<TableInfo> _tables = [];

  // Getters
  String get currentView => _currentView;
  TableInfo? get selectedTable => _selectedTable;
  List<CartItem> get cart => _cart;
  List<CartItem> get takeoutCart => _takeoutCart;
  List<Order> get orders => _orders;
  List<TableInfo> get tables => _tables;
  String get selectedCategory => _selectedCategory; // Added getter
  int get takeoutTokenNumber => _takeoutTokenNumber;
  bool get hasTakeoutChanges {
    final deltas = _computeTakeoutDelta(_takeoutCart);
    return deltas.isNotEmpty;
  }
  String? _temporaryRole;
  String? get actingAsRole => _temporaryRole;

  void actAsRole(String? role) {
    _temporaryRole = role;
    if (role != null) {
      SyncService.instance.logAuditEvent('act_as_role_start', {'target_role': role});
      setCurrentView('dashboard');
    } else {
      SyncService.instance.logAuditEvent('act_as_role_stop', {});
    }
    notifyListeners();
  }

  String? get clientRole => _temporaryRole ?? Repository.instance.clientMeta?['role']?.toString();
  String? get realRole => Repository.instance.clientMeta?['role']?.toString();
  bool get installAvailable => _installAvailable;
  dynamic get installPromptEvent => _installPromptEvent;
  List<String> get categories {
    if (_categories.isEmpty) {
      final setCats = {...menuItems.map((m) => m.category)};
      _categories = ['All', ...setCats];
    }
    return _categories;
  }
  void setReportsTabIndex(int index) {
    reportsTabIndex = index;
    notifyListeners();
  }
  String _todayYYMMDD() {
    final now = DateTime.now();
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '$yy$mm$dd';
  }
  String get takeoutTokenId {
    final today = _todayYYMMDD();
    if (_takeoutTokenDate != today) {
      _takeoutTokenDate = today;
      _takeoutTokenNumber = 1;
    }
    final seq = _takeoutTokenNumber.toString().padLeft(3, '0');
    return 'T#$_takeoutTokenDate-$seq';
  }
  List<Map<String, dynamic>> get toasts => _toasts;
  String get storageOrigin {
    if (kIsWeb) {
      try {
        return web.locationOrigin();
      } catch (_) {
        return '';
      }
    }
    return 'native';
  }
  String get storageBackendLabel => kIsWeb ? 'Web sqlite_ffi_web' : 'Native sqlite_ffi';
  String get storageStatusLabel => '$storageBackendLabel @ $storageOrigin';
  void setAnalyticsRange(String r) {
    analyticsRange = r;
    notifyListeners();
  }
  void setAnalyticsCategoryFilter(String c) {
    analyticsCategoryFilter = c;
    notifyListeners();
  }
  void setAnalyticsServiceFilter(String v) {
    analyticsServiceFilter = v;
    notifyListeners();
  }
  Future<void> resetAllTablesAndOrders() async {
    for (final t in _tables) {
      updateTableStatus(t.id, 'available', null);
    }
    _orders = [];
    _selectedTable = null;
    _cart = [];
    _takeoutCart = [];
    _sentTakeoutQtyByKey = {};
    _kotBatchesByOrder = {};
    _cancelledKeysByOrder = {};
    await Repository.instance.orders.clearAll();
    _saveState();
    showToast('All tables reset and orders cleared.', icon: '✅');
    setCurrentView('dashboard');
    notifyListeners();
  }
  Future<void> resetTableOrder(int tableNumber) async {
    try {
      final t = _tables.firstWhere((x) => x.number == tableNumber);
      final label = 'Table $tableNumber';
      await Repository.instance.orders.deleteOrdersByTableLabel(label);
      _orders = _orders.where((o) => o.table != label).toList();
      updateTableStatus(t.id, 'available', null);
      if (_selectedTable?.number == tableNumber) {
        _selectedTable = null;
        _cart = [];
      }
      _saveState();
      showToast('Table $tableNumber reset and order cleared.', icon: '✅');
      setCurrentView('tables');
      notifyListeners();
    } catch (_) {
      showToast('Table $tableNumber not found.', icon: '⚠️');
    }
  }
  Future<void> resetAllOrdersSync() async {
    _orders = [];
    _selectedTable = null;
    _cart = [];
    _takeoutCart = [];
    _sentTakeoutQtyByKey = {};
    _kotBatchesByOrder = {};
    _cancelledKeysByOrder = {};
    await Repository.instance.orders.clearAllSynced();
    await _ensureTableOrderConsistency();
    _saveState();
    showToast('All orders cleared (offline + online).', icon: '✅');
    setCurrentView('dashboard');
    notifyListeners();
  }
  Future<void> cleanUpBlankOrders() async {
    final orders = await Repository.instance.orders.listOrdersWithItems();
    bool changed = false;
    for (final o in orders) {
      if (o.items.isEmpty && o.status != 'Cancelled' && o.status != 'Settled' && o.status != 'Completed') {
         await Repository.instance.orders.updateOrderStatus(o.id, 'Cancelled', notify: false);
         if (o.table.startsWith('Table ')) {
            // Also release table if needed
            try {
              final t = _tables.firstWhere((x) => x.orderId == o.id);
              updateTableStatus(t.id, 'available', null);
            } catch (_) {}
         }
         changed = true;
      }
    }
    // We don't call _loadState() here because the constructor calls it right after cleanUpBlankOrders()
    // or we can call it if we want to ensure state is fresh, but we should use notify: false if multiple things change.
    if (changed) {
      Repository.instance.notifyDataChanged();
    }
  }

  Future<void> resetAllDataFresh(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Full Reset'),
        content: const Text('This will delete all local and remote data. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _orders = [];
    _selectedTable = null;
    _cart = [];
    _takeoutCart = [];
    _sentTakeoutQtyByKey = {};
    _kotBatchesByOrder = {};
    _cancelledKeysByOrder = {};
    await Repository.instance.clearAllLocalData();
    await SyncService.instance.deleteAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('categories');
    await prefs.remove('orders');
    await prefs.remove('tables');
    await prefs.remove('menuItems');
    await prefs.remove('expenses');
    await prefs.remove('employees');
    await prefs.remove('takeoutTokenNumber');
    await prefs.remove('takeoutTokenDate');
    _tables = [];
    setCurrentView('dashboard');
    notifyListeners();
    if (context.mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full data reset completed. ✅')));
    }
  }

  // Constructor to init
  RestaurantProvider() {
    _initPWA();
    Future.microtask(() async {
      await Repository.instance.init();
      await AuthHelper.refreshRoles();
      await cleanUpBlankOrders();
      await _loadState();
      
      // Listen for sync changes
      _dataSubscription = Repository.instance.onDataChanged.listen((_) {
        _loadState(); // _loadState already calls notifyListeners()
      });
      
      _flushPendingPrints();
      _initRouting();
    });
  }

  void _initPWA() {
    if (!kIsWeb) return;
    // Web-specific PWA events skipped to avoid web-only library usage.
  }

  void _initRouting() {
    if (!kIsWeb) return;
    _applyRoute(web.locationHash());
  }

  void _applyRoute(String hash) {
    final path = hash.startsWith('#') ? hash.substring(1) : hash;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      setCurrentView('dashboard', updateUrl: false);
      return;
    }
    
    final view = parts[0];
    if (view == 'tables' && parts.length > 1) {
      final id = int.tryParse(parts[1]);
      if (id != null) {
        final t = _tables.firstWhere((x) => x.number == id, orElse: () => TableInfo(id: id, number: id, status: 'available', capacity: 4));
        _selectedTable = t;
        setCurrentView('tableOrder', updateUrl: false);
        return;
      }
    }
    
    // Validate view
    if (['dashboard', 'tables', 'takeout', 'kitchen', 'menu'].contains(view)) {
      setCurrentView(view, updateUrl: false);
    } else {
      setCurrentView('dashboard', updateUrl: false);
    }
  }

  void setCurrentView(String view, {int? tableNumber, bool updateUrl = true}) {
    final rawRole = (Repository.instance.clientMeta?['role']?.toString() ?? '').trim().toLowerCase();
    // Use actingAsRole if set, otherwise fallback to the session role
    final role = actingAsRole?.toLowerCase() ?? rawRole;
    
    final allowed = AuthHelper.allowedViewsForRole(role);
    String target = view;

    // Admin always allowed to see everything, but respect the target if it's allowed
    if (role != 'admin' && !allowed.contains(view)) {
      if (role == 'chef') {
        target = 'kitchen';
      } else if (role == 'waiter') {
        target = 'tables';
      } else {
        target = 'dashboard';
      }
    }
    
    _currentView = target;
    if (updateUrl) {
      _pushUrlForView(target, tableNumber: tableNumber);
    }
    if (target == 'dashboard') {
      _ensureTableOrderConsistency();
    }
    notifyListeners();
  }

  void _pushUrlForView(String view, {int? tableNumber}) {
    if (!kIsWeb) return;
    String path;
    switch (view) {
      case 'dashboard':
        path = '/dashboard';
        break;
      case 'tables':
        path = '/tables';
        break;
      case 'tableOrder':
        path = '/tables/${tableNumber ?? _selectedTable?.number ?? ''}';
        break;
      case 'kitchen':
        path = '/kitchen';
        break;
      case 'takeout':
        path = '/takeout';
        break;
      case 'menu':
        path = '/menu';
        break;
      case 'inventory':
        path = '/inventory';
        break;
      case 'expenses':
        path = '/expenses';
        break;
      case 'employees':
        path = '/employees';
        break;
      default:
        path = '/dashboard';
    }
    final url = '#$path';
    if (web.locationHash() != url) {
      web.historyPush(url);
    }
  }
  Future<void> _ensureTableOrderConsistency() async {
    // 1. Remove empty active orders (no items, not settled/cancelled)
    // Don't auto-cancel 'Preparing' or 'Ready' orders as they might be temporarily empty during sync/load
    final emptyActiveOrders = _orders.where((o) => 
      o.items.isEmpty && 
      o.status != 'Settled' && 
      o.status != 'Cancelled' &&
      o.status != 'Preparing' &&
      o.status != 'Ready'
    ).toList();
    
    if (emptyActiveOrders.isNotEmpty) {
      _orders = _orders.where((o) => !emptyActiveOrders.contains(o)).toList();
      for (final o in emptyActiveOrders) {
        // Use notify: false to avoid infinite loops during cleanup
        await Repository.instance.orders.updateOrderStatus(o.id, 'Cancelled', notify: false);
      }
      notifyListeners();
    }

    // 2. Ensure table status consistency
    bool tableChanged = false;
    for (final t in _tables) {
      if (t.status != 'available') {
        final label = 'Table ${t.number}';
        final hasActive = _orders.any((o) => o.table == label && o.status != 'Settled' && o.status != 'Cancelled');
        if (!hasActive) {
          // Use a direct update or ensure it doesn't notify redundantly
          await updateTableStatus(t.id, 'available', null, notify: false);
          tableChanged = true;
        }
      }
    }
    
    if (tableChanged) {
      // One final notification if tables were cleaned up
      Repository.instance.notifyDataChanged();
    }
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  // State Persistence
  bool _isLoadingState = false;
  Future<void> _loadState() async {
    if (_isLoadingState) return;
    _isLoadingState = true;
    try {
      final s = Repository.instance.settings;
      final prefs = await SharedPreferences.getInstance();

      // --- TAKEOUT TOKEN ---
      final tokenNumStr = await s.get('takeoutTokenNumber');
      if (tokenNumStr != null) {
        final t = int.tryParse(tokenNumStr);
        if (t != null) _takeoutTokenNumber = t;
      } else {
        // Fallback to Prefs
        final token = prefs.getInt('takeoutTokenNumber');
        if (token != null) {
           _takeoutTokenNumber = token;
           await s.set('takeoutTokenNumber', token.toString());
        }
      }

      final tokenDateStr = await s.get('takeoutTokenDate');
      if (tokenDateStr != null) {
        _takeoutTokenDate = tokenDateStr;
      } else {
        // Fallback to Prefs
        final tokenDate = prefs.getString('takeoutTokenDate');
        if (tokenDate != null) {
          _takeoutTokenDate = tokenDate;
          await s.set('takeoutTokenDate', tokenDate);
        }
      }
      
      // Ensure date is today
      if (_takeoutTokenDate != _todayYYMMDD()) {
        _takeoutTokenDate = _todayYYMMDD();
        _takeoutTokenNumber = 1;
        await s.set('takeoutTokenDate', _takeoutTokenDate);
        await s.set('takeoutTokenNumber', '1');
      }

      // --- CATEGORIES ---
      final catsStr = await s.get('categories');
      if (catsStr != null && catsStr.isNotEmpty) {
        try {
          final data = jsonDecode(catsStr) as List<dynamic>;
          _categories = data.map((c) => c.toString()).toList();
        } catch (_) {}
      } else {
        // Fallback to Prefs
        final catsJson = prefs.getString('categories');
        if (catsJson != null) {
           try {
             final data = jsonDecode(catsJson) as List<dynamic>;
             _categories = data.map((c) => c.toString()).toList();
             await s.set('categories', catsJson);
           } catch (_) {}
        }
      }

      // --- MENU ---
      final dbMenu = await Repository.instance.menu.listMenu();
      if (dbMenu.isNotEmpty) {
        menuItems = dbMenu;
      } else {
        final menuJson = prefs.getString('menuItems');
        if (menuJson != null) {
          try {
            final data = jsonDecode(menuJson) as List<dynamic>;
            menuItems = data.map((m) => MenuItem.fromJson(m)).toList();
          } catch (_) {}
        }
        if (menuItems.isEmpty) {
          final defaults = <MenuItem>[
            MenuItem(id: 1, name: 'Paneer Tikka', category: 'Starters', price: 220, image: ''),
            MenuItem(id: 2, name: 'Chicken Biryani', category: 'Main Course', price: 280, image: ''),
            MenuItem(id: 3, name: 'Masala Dosa', category: 'South Indian', price: 160, image: ''),
            MenuItem(id: 4, name: 'Butter Naan', category: 'Breads', price: 60, image: ''),
            MenuItem(id: 5, name: 'Gulab Jamun', category: 'Desserts', price: 120, image: ''),
            MenuItem(id: 6, name: 'Cold Coffee', category: 'Beverages', price: 140, image: ''),
            MenuItem(id: 7, name: 'Dal Makhani', category: 'Main Course', price: 240, image: ''),
            MenuItem(id: 8, name: 'Spring Rolls', category: 'Starters', price: 180, image: ''),
          ];
          await Repository.instance.menu.upsertMenuItems(defaults, notify: false);
          menuItems = await Repository.instance.menu.listMenu();
        } else {
          // If we loaded from legacy prefs but DB was empty, save to DB
          await Repository.instance.menu.upsertMenuItems(menuItems, notify: false);
        }
      }
      // Seed sample recipes if missing
      try {
        final byName = {for (final m in menuItems) m.name.toLowerCase(): m};
        Future<void> ensureRecipe(String itemName, List<Map<String, dynamic>> ingList) async {
          final m = byName[itemName.toLowerCase()];
          if (m == null) return;
          final existing = await Repository.instance.ingredients.getRecipeForMenuItem(m.id);
          if (existing.isNotEmpty) return;
          
          // Use direct repository call instead of provider method to avoid loops
          await Repository.instance.ingredients.setRecipeForMenuItem(m.id, ingList, notify: false);
        }
        await ensureRecipe('Paneer Tikka', [
          {'name':'Paneer','qty':150,'unit':'g'},
          {'name':'Curd','qty':50,'unit':'g'},
          {'name':'Spice Mix','qty':10,'unit':'g'},
          {'name':'Oil','qty':10,'unit':'ml'},
        ]);
        await ensureRecipe('Chicken Biryani', [
          {'name':'Rice','qty':200,'unit':'g'},
          {'name':'Chicken','qty':150,'unit':'g'},
          {'name':'Biryani Masala','qty':8,'unit':'g'},
          {'name':'Oil','qty':15,'unit':'ml'},
        ]);
        await ensureRecipe('Masala Dosa', [
          {'name':'Dosa Batter','qty':200,'unit':'g'},
          {'name':'Potato Masala','qty':120,'unit':'g'},
          {'name':'Oil','qty':10,'unit':'ml'},
        ]);
        await ensureRecipe('Butter Naan', [
          {'name':'Flour','qty':120,'unit':'g'},
          {'name':'Butter','qty':10,'unit':'g'},
          {'name':'Yeast','qty':2,'unit':'g'},
        ]);
        await ensureRecipe('Gulab Jamun', [
          {'name':'Khoya Mix','qty':100,'unit':'g'},
          {'name':'Sugar Syrup','qty':50,'unit':'ml'},
        ]);
        await ensureRecipe('Cold Coffee', [
          {'name':'Milk','qty':200,'unit':'ml'},
          {'name':'Coffee','qty':10,'unit':'g'},
          {'name':'Sugar','qty':15,'unit':'g'},
        ]);
        await ensureRecipe('Dal Makhani', [
          {'name':'Black Lentils','qty':150,'unit':'g'},
          {'name':'Cream','qty':20,'unit':'ml'},
          {'name':'Butter','qty':10,'unit':'g'},
        ]);
        await ensureRecipe('Spring Rolls', [
          {'name':'Roll Wrapper','qty':2,'unit':'pc'},
          {'name':'Veg Mix','qty':100,'unit':'g'},
          {'name':'Oil','qty':15,'unit':'ml'},
        ]);
      } catch (_) {}
      // --- TABLES ---
      final dbTables = await Repository.instance.tables.listTables();
      if (dbTables.isNotEmpty) {
        _tables = dbTables;
      } else {
        final tablesJson = prefs.getString('tables');
        if (tablesJson != null) {
          try {
             final data = jsonDecode(tablesJson) as List<dynamic>;
             _tables = data.map((m) => TableInfo.fromJson(m)).toList();
          } catch (_) {}
        }
        if (_tables.isEmpty) {
          final defaults = List<TableInfo>.generate(8, (i) => TableInfo(id: i + 1, number: i + 1, status: 'available', capacity: 4));
          for (final t in defaults) {
            await Repository.instance.tables.upsertTable(t.id, t.number, t.status, t.capacity, orderId: t.orderId, notify: false);
          }
          _tables = await Repository.instance.tables.listTables();
        } else {
          for (var t in _tables) {
             await Repository.instance.tables.upsertTable(t.id, t.number, t.status, t.capacity, orderId: t.orderId, notify: false);
          }
        }
      }

      // --- ORDERS ---
      final dbOrders = await Repository.instance.orders.listOrdersWithItems();
      if (dbOrders.isNotEmpty) {
        _orders = dbOrders;
      } else {
        // Try Legacy Prefs for Orders
        final ordersJson = prefs.getString('orders');
        if (ordersJson != null) {
          try {
             final data = jsonDecode(ordersJson) as List<dynamic>;
             _orders = data.map((o) => Order.fromJson(o)).toList();
          } catch (_) {}
        }
      }


    } catch (e) {
      // Error loading state
    } finally {
      _isLoadingState = false;
    }
    
    notifyListeners();
  }

  Future<void> _saveState() async {
    // Only save to SharedPreferences what is NOT in DB or for legacy support if needed.
    // Actually, we should stop saving large datasets to SharedPreferences to improve performance.
    // We will only save simple settings.
    
    final prefs = await SharedPreferences.getInstance();
    // Don't save tables, orders, menuItems, expenses, employees to Prefs anymore.
    // They are fully managed by Repository (SQLite).
    
    final catsJson = jsonEncode(categories);
    
    // await prefs.setString('tables', tablesJson);
    // await prefs.setString('orders', ordersJson);
    await prefs.setInt('takeoutTokenNumber', _takeoutTokenNumber);
    await prefs.setString('takeoutTokenDate', _takeoutTokenDate);
    // await prefs.setString('menuItems', menuJson);
    await prefs.setString('categories', catsJson);
    // await prefs.setString('expenses', expensesJson);
    // await prefs.setString('employees', employeesJson);
    
    try {
      await Repository.instance.settings.set('takeoutTokenNumber', _takeoutTokenNumber.toString());
      await Repository.instance.settings.set('takeoutTokenDate', _takeoutTokenDate);
      await Repository.instance.settings.set('categories', catsJson);
    } catch (_) {}
  }

  // Printer Logic
  static const String _printerEndpoint = 'http://localhost:3001/print';

  Future<void> _sendToPrinter(String kind, String htmlDoc) async {
    try {
      final res = await http.post(Uri.parse(_printerEndpoint), 
        headers: {'Content-Type': 'application/json'}, 
        body: jsonEncode({'type': kind, 'html': htmlDoc})
      );
      if (res.statusCode != 200) {
        throw Exception('Printer responded ${res.statusCode}');
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final queueStr = prefs.getString('pending_prints');
      final queue = queueStr != null ? (jsonDecode(queueStr) as List<dynamic>) : <dynamic>[];
      queue.add({'type': kind, 'html': htmlDoc});
      await prefs.setString('pending_prints', jsonEncode(queue));
    }
  }

  Future<void> _flushPendingPrints() async {
    if (!web.isOnline()) return;
    final prefs = await SharedPreferences.getInstance();
    final queueStr = prefs.getString('pending_prints');
    if (queueStr == null) return;
    
    final queue = jsonDecode(queueStr) as List<dynamic>;
    final remaining = <dynamic>[];
    
    for (final job in queue) {
      try {
        final res = await http.post(Uri.parse(_printerEndpoint), 
          headers: {'Content-Type': 'application/json'}, 
          body: jsonEncode({'type': job['type'], 'html': job['html']})
        );
        if (res.statusCode != 200) {
          remaining.add(job);
        }
      } catch (_) {
        remaining.add(job);
      }
    }
    
    if (remaining.isEmpty) {
      await prefs.remove('pending_prints');
    } else {
      await prefs.setString('pending_prints', jsonEncode(remaining));
    }
  }

  // Actions
  void setMobileMenuOpen(bool value) {
    mobileMenuOpen = value;
    notifyListeners();
  }

  Future<void> updateTableStatus(int tableId, String status, String? orderId, {bool notify = true}) async {
    _tables = _tables.map((t) => t.id == tableId ? TableInfo(id: t.id, number: t.number, status: status, capacity: t.capacity, orderId: orderId) : t).toList();
    final tbl = _tables.firstWhere((t) => t.id == tableId, orElse: () => TableInfo(id: tableId, number: tableId, status: status, capacity: 4, orderId: orderId));
    if (notify) notifyListeners();
    await Repository.instance.tables.upsertTable(tbl.id, tbl.number, tbl.status, tbl.capacity, orderId: tbl.orderId, notify: notify);
    _saveState();
  }

  Future<void> addTable(int number, int capacity) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    if (_tables.any((t) => t.status != 'deleted' && t.number == number)) {
      showToast('Table $number already exists', icon: '⚠️');
      return;
    }
    final newTable = TableInfo(
      id: id,
      number: number,
      status: 'available',
      capacity: capacity,
    );
    _tables.add(newTable);
    _tables.sort((a, b) => a.number.compareTo(b.number));
    
    await Repository.instance.tables.upsertTable(id, number, 'available', capacity);
    notifyListeners();
    showToast('Table $number added', icon: '✅');
  }

  Future<void> editTable(int id, int number, int capacity) async {
    final existsOther = _tables.any((t) => t.status != 'deleted' && t.id != id && t.number == number);
    if (existsOther) {
      showToast('Table number already in use', icon: '⚠️');
      return;
    }
    _tables = _tables.map((t) => t.id == id ? TableInfo(id: t.id, number: number, status: t.status, capacity: capacity, orderId: t.orderId) : t).toList();
    await Repository.instance.tables.upsertTable(id, number, _tables.firstWhere((t) => t.id == id).status, capacity, orderId: _tables.firstWhere((t) => t.id == id).orderId);
    _tables.sort((a, b) => a.number.compareTo(b.number));
    notifyListeners();
    showToast('Table updated', icon: '✅');
  }
  Future<void> deleteTable(int id) async {
    try {
      final t = _tables.firstWhere((x) => x.id == id);
      if (t.status != 'available') {
        showToast('Cannot delete occupied table', icon: '⚠️');
        return;
      }
      _tables = _tables.map((x) => x.id == id ? TableInfo(id: x.id, number: x.number, status: 'deleted', capacity: x.capacity, orderId: null) : x).toList();
      await Repository.instance.tables.upsertTable(id, t.number, 'deleted', t.capacity, orderId: null);
      notifyListeners();
      showToast('Table deleted', icon: '🗑️');
    } catch (_) {
      showToast('Table not found', icon: '⚠️');
    }
  }
  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }
  void showToast(String message, {String icon = '✅', int durationMs = 4000}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _toasts = [
      ..._toasts,
      {'id': id, 'message': message, 'icon': icon, 'ts': DateTime.now().millisecondsSinceEpoch}
    ];
    notifyListeners();
    Future.delayed(Duration(milliseconds: durationMs), () {
      _toasts = _toasts.where((t) => t['id'] != id).toList();
      notifyListeners();
    });
  }
  void addCategory(String category) {
    final exists = categories.where((c) => c.toLowerCase() == category.toLowerCase()).isNotEmpty;
    if (!exists) {
      _categories = [...categories, category];
      _saveState();
      notifyListeners();
    }
  }
  void addMenuItem({required String name, required String category, required int price, required String image}) {
    final id = (menuItems.isEmpty ? 0 : menuItems.map((m) => m.id).reduce((a, b) => a > b ? a : b)) + 1;
    final newItem = MenuItem(id: id, name: name, category: category, price: price, image: image);
    menuItems = [...menuItems, newItem];
    Repository.instance.menu.insertMenuItem(newItem);
    addCategory(category);
    _saveState();
    notifyListeners();
  }
  void updateMenuItem(MenuItem updated) {
    menuItems = menuItems.map((m) => m.id == updated.id ? updated : m).toList();
    Repository.instance.menu.updateMenuItem(updated);
    // Don't call _loadState() here as it can cause infinite loops
    // notifyListeners() is called by the repository listener if needed, 
    // but here we manually notify for immediate UI update.
    notifyListeners();
    
    () async {
      final list = await Repository.instance.ingredients.listIngredients();
      final byName = <String, String>{};
      final byId = <String, bool>{for (final r in list) (r['id'] as String): true};
      for (final r in list) {
        final n = (r['name'] as String? ?? '').trim().toLowerCase();
        if (n.isNotEmpty) byName[n] = r['id'] as String;
      }
      final mapped = <Map<String, dynamic>>[];
      for (final e in updated.ingredients) {
        String? id = e['ingredient_id'] as String?;
        String nm = (e['name']?.toString() ?? '').trim();
        final lowerNm = nm.toLowerCase();
        final unit = e['unit']?.toString() ?? 'g';

        if (id == null) {
          if (nm.isEmpty) continue;
          id = byName[lowerNm];
          if (id == null) {
            // Auto-create missing ingredient
            id = '${DateTime.now().millisecondsSinceEpoch}_${nm.hashCode}';
            await Repository.instance.ingredients.upsertIngredient({
              'id': id,
              'name': nm,
              'category': 'Uncategorized',
              'base_unit': unit,
              'stock': 0.0,
              'min_threshold': 0.0,
              'supplier': '',
            });
            byName[lowerNm] = id;
            byId[id] = true;
          }
        } else {
          // Ensure ingredient exists; if not and name present, create it
          if (byId[id] != true) {
            if (nm.isEmpty) nm = id;
            await Repository.instance.ingredients.upsertIngredient({
              'id': id,
              'name': nm,
              'category': 'Uncategorized',
              'base_unit': unit,
              'stock': 0.0,
              'min_threshold': 0.0,
              'supplier': '',
            });
            byId[id] = true;
          }
        }

        final qty = (e['qty'] as num?)?.toDouble() ?? 0.0;
        if (qty > 0 && unit.isNotEmpty) {
          mapped.add({'ingredient_id': id, 'qty': qty, 'unit': unit});
        }
      }
      await Repository.instance.ingredients.setRecipeForMenuItem(updated.id, mapped);
    }();
    addCategory(updated.category);
    _saveState();
    notifyListeners();
  }
  void deleteMenuItem(int id) {
    final removed = menuItems.firstWhere((m) => m.id == id, orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''));
    if (removed.id != -1) {
      menuItems = menuItems.where((m) => m.id != id).toList();
      Repository.instance.menu.deleteMenuItem(id);
      _saveState();
      notifyListeners();
    }
  }
  void toggleSoldOut(int id, bool value) {
    menuItems = menuItems.map((m) => m.id == id ? MenuItem(id: m.id, name: m.name, category: m.category, price: m.price, image: m.image, soldOut: value, modifiers: m.modifiers, upsellIds: m.upsellIds, instructionTemplates: m.instructionTemplates, specialFlags: m.specialFlags, availableDays: m.availableDays, availableStart: m.availableStart, availableEnd: m.availableEnd, seasonal: m.seasonal, ingredients: m.ingredients, stock: m.stock) : m).toList();
    Repository.instance.menu.toggleSoldOut(id, value);
    _saveState();
    notifyListeners();
  }

  void selectTableForOrder(TableInfo table) {
    _selectedTable = _tables.firstWhere((t) => t.id == table.id);
    _cart = [];
    setCurrentView('tableOrder', tableNumber: table.number);
  }

  void addToCart(MenuItem item) {
    final orderId = _selectedTable?.orderId;
    if (_selectedTable?.status == 'billing') {
      showToast('Cannot add items while order is awaiting billing.', icon: '⚠️');
      return;
    }
    if (orderId != null) {
      try {
        final ord = _orders.firstWhere((o) => o.id == orderId);
        if (ord.status == 'Awaiting Payment' || ord.status == 'Completed' || ord.status == 'Settled') {
          showToast('Cannot add items while order is awaiting payment or completed.', icon: '⚠️');
          return;
        }
        // Allow adding when table is available (pre-KOT) or serving (post-ready). Block otherwise.
      } catch (_) {}
    }
    final existing = _cart.where((i) => i.id == item.id).toList();
    if (existing.isNotEmpty) {
      _cart = _cart.map((i) => i.id == item.id ? i.copyWith(quantity: i.quantity + 1) : i).toList();
    } else {
      _cart = [..._cart, CartItem(id: item.id, name: item.name, price: item.price, quantity: 1, image: item.image, instructions: null, addons: [], modifiers: [])];
    }
    notifyListeners();
  }
  void addUpsellToCart(MenuItem item) {
    addToCart(item);
    showToast('${item.name} added to order.', icon: '✅');
  }

  void addToTakeoutCart(MenuItem item) {
    final tableLabel = 'Takeout #$takeoutTokenId';
    try {
      final ord = _orders.firstWhere((o) => o.table == tableLabel && o.status != 'Settled' && o.status != 'Cancelled');
      if (ord.status == 'Awaiting Payment' || ord.status == 'Completed') {
        showToast('Cannot add items while order is awaiting payment or completed.', icon: '⚠️');
        return;
      }
    } catch (_) {}
    final existing = _takeoutCart.where((i) => i.id == item.id).toList();
    if (existing.isNotEmpty) {
      _takeoutCart = _takeoutCart.map((i) => i.id == item.id ? i.copyWith(quantity: i.quantity + 1) : i).toList();
    } else {
      _takeoutCart = [..._takeoutCart, CartItem(id: item.id, name: item.name, price: item.price, quantity: 1, image: item.image, instructions: null, addons: [], modifiers: [])];
    }
    notifyListeners();
  }
  void addUpsellToTakeout(MenuItem item) {
    addToTakeoutCart(item);
    showToast('${item.name} added to order.', icon: '✅');
  }

  // Employee and Expense logic moved to respective providers

  void updateItemInstructions(int itemId, String text, {bool isTakeout = false}) {
    if (isTakeout) {
      _takeoutCart = _takeoutCart.map((i) => i.id == itemId ? i.copyWith(instructions: text) : i).toList();
    } else {
      _cart = _cart.map((i) => i.id == itemId ? i.copyWith(instructions: text) : i).toList();
    }
    notifyListeners();
  }
  void toggleAddonForItem(int itemId, int addonId, {bool isTakeout = false}) {
    List<CartItem> list = isTakeout ? _takeoutCart : _cart;
    list = list.map((i) {
      if (i.id != itemId) return i;
      final current = i.addons ?? [];
      final has = current.contains(addonId);
      final next = has ? current.where((x) => x != addonId).toList() : [...current, addonId];
      return i.copyWith(addons: next);
    }).toList();
    if (isTakeout) {
      _takeoutCart = list;
    } else {
      _cart = list;
    }
    notifyListeners();
  }
  void toggleModifierForItem(int itemId, Map<String, dynamic> modifier, {bool isTakeout = false}) {
    List<CartItem> list = isTakeout ? _takeoutCart : _cart;
    list = list.map((i) {
      if (i.id != itemId) return i;
      final cur = List<Map<String, dynamic>>.from(i.modifiers ?? []);
      final exists = cur.any((m) => (m['name']?.toString() ?? '') == (modifier['name']?.toString() ?? '') && (m['priceDelta']?.toString() ?? '') == (modifier['priceDelta']?.toString() ?? ''));
      final next = exists ? cur.where((m) => !((m['name']?.toString() ?? '') == (modifier['name']?.toString() ?? '') && (m['priceDelta']?.toString() ?? '') == (modifier['priceDelta']?.toString() ?? ''))).toList() : [...cur, modifier];
      return i.copyWith(modifiers: next);
    }).toList();
    if (isTakeout) {
      _takeoutCart = list;
    } else {
      _cart = list;
    }
    notifyListeners();
  }
  List<MenuItem> getTopUpSuggestionsForItem(int itemId) {
    final base = menuItems.firstWhere((m) => m.id == itemId, orElse: () => MenuItem(id: -1, name: '', category: 'All', price: 0, image: ''));
    if (base.id != -1 && base.upsellIds.isNotEmpty) {
      final configured = base.upsellIds.map((id) => menuItems.firstWhere((m) => m.id == id, orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''))).where((m) => m.id != -1).toList();
      if (configured.isNotEmpty) return configured.take(3).toList();
    }
    final inSame = menuItems.where((m) => m.category == base.category && m.id != itemId).take(3).toList();
    if (inSame.isNotEmpty) return inSame;
    final beverages = menuItems.where((m) => m.category == 'Beverages').take(3).toList();
    final desserts = menuItems.where((m) => m.category == 'Desserts').take(3).toList();
    return [...beverages, ...desserts].take(3).toList();
  }

  void removeFromCart(int itemId) {
    _cart = _cart.where((i) => i.id != itemId).toList();
    final orderId = _selectedTable?.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      try {
        final ord = _orders.firstWhere((o) => o.id == orderId && o.status != 'Settled' && o.status != 'Cancelled');
        final candidates = ord.items.where((i) => i.id == itemId).toList();
        for (final it in candidates) {
          cancelOrderedItem(orderId, it, 'removed_from_cart', false);
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  void removeFromTakeoutCart(int itemId) {
    _takeoutCart = _takeoutCart.where((i) => i.id != itemId).toList();
    final tableLabel = 'Takeout #$takeoutTokenId';
    try {
      final ord = _orders.firstWhere((o) => o.table == tableLabel && o.status != 'Settled' && o.status != 'Cancelled');
      final candidates = ord.items.where((i) => i.id == itemId).toList();
      for (final it in candidates) {
        cancelOrderedItem(ord.id, it, 'removed_from_cart', false);
      }
    } catch (_) {}
    notifyListeners();
  }

  void updateQuantity(int itemId, int delta) {
    final orderId = _selectedTable?.orderId;
    if (_selectedTable?.status == 'billing') {
      showToast('Cannot add items while order is awaiting billing.', icon: '⚠️');
      return;
    }
    if (orderId != null) {
      try {
        final ord = _orders.firstWhere((o) => o.id == orderId);
        if (ord.status == 'Awaiting Payment' || ord.status == 'Completed' || ord.status == 'Settled') {
          showToast('Cannot add items while order is awaiting payment or completed.', icon: '⚠️');
          return;
        }
        // Allow adjusting when table is available (pre-KOT) or serving (post-ready). Block otherwise.
      } catch (_) {}
    }
    _cart = _cart.map((i) {
      if (i.id == itemId) {
        final q = i.quantity + delta;
        return q > 0 ? i.copyWith(quantity: q) : i;
      }
      return i;
    }).where((i) => i.quantity > 0).toList();
    notifyListeners();
  }

  void updateTakeoutQuantity(int itemId, int delta) {
    final tableLabel = 'Takeout #$takeoutTokenId';
    try {
      final ord = _orders.firstWhere((o) => o.table == tableLabel && o.status != 'Settled' && o.status != 'Cancelled');
      if (ord.status == 'Awaiting Payment' || ord.status == 'Completed') {
        showToast('Cannot add items while order is awaiting payment or completed.', icon: '⚠️');
        return;
      }
    } catch (_) {}
    _takeoutCart = _takeoutCart.map((i) {
      if (i.id == itemId) {
        final q = i.quantity + delta;
        return q > 0 ? i.copyWith(quantity: q) : i;
      }
      return i;
    }).where((i) => i.quantity > 0).toList();
    notifyListeners();
  }
  
  String _itemKey(CartItem i) {
    final addons = [...(i.addons ?? [])]..sort();
    final mods = (i.modifiers ?? [])
        .map((m) => '${m['name']?.toString() ?? ''}:${m['priceDelta']?.toString() ?? ''}')
        .toList()
      ..sort();
    final note = (i.instructions ?? '').trim();
    return '${i.id}|$note|${addons.join(',')}|${mods.join(',')}';
  }
  Map<String, int> _quantitiesByKey(List<CartItem> items) {
    final map = <String, int>{};
    for (final i in items) {
      final k = _itemKey(i);
      map[k] = (map[k] ?? 0) + i.quantity;
    }
    return map;
  }
  List<CartItem> _computeTakeoutDelta(List<CartItem> items) {
    final cur = _quantitiesByKey(items);
    final deltas = <CartItem>[];
    for (final entry in cur.entries) {
      final sentQ = _sentTakeoutQtyByKey[entry.key] ?? 0;
      final diff = entry.value - sentQ;
      if (diff > 0) {
        final sample = items.firstWhere((x) => _itemKey(x) == entry.key);
        deltas.add(sample.copyWith(quantity: diff));
      }
    }
    return deltas;
  }
  List<Map<String, dynamic>> getKotBatchesForTable(String tableLabel) {
    try {
      final order = _orders.firstWhere((o) => o.table == tableLabel && o.status != 'Settled');
      return _kotBatchesByOrder[order.id] ?? const [];
    } catch (_) {
      return const [];
    }
  }
  List<CartItem> consolidatedItemsForTable(String tableLabel) {
    try {
      // Resolve order: prefer linked orderId from table, otherwise use latest by createdAt
      Order order;
      if (tableLabel.startsWith('Table ')) {
        final numStr = tableLabel.replaceFirst('Table ', '').trim();
        final n = int.tryParse(numStr);
        if (n != null) {
          try {
            final t = _tables.firstWhere((x) => x.number == n);
            final oid = t.orderId;
            if (oid != null && oid.isNotEmpty) {
              order = _orders.firstWhere((o) => o.id == oid, orElse: () => Order(id: '', table: '', status: '', items: const [], total: 0, time: ''));
            } else {
              final candidates = _orders.where((o) => o.table == tableLabel && o.status != 'Settled' && o.status != 'Cancelled').toList();
              candidates.sort((a, b) => ((b.createdAt ?? 0)).compareTo(a.createdAt ?? 0));
              order = candidates.isNotEmpty ? candidates.first : Order(id: '', table: '', status: '', items: const [], total: 0, time: '');
            }
          } catch (_) {
            final candidates = _orders.where((o) => o.table == tableLabel && o.status != 'Settled' && o.status != 'Cancelled').toList();
            candidates.sort((a, b) => ((b.createdAt ?? 0)).compareTo(a.createdAt ?? 0));
            order = candidates.isNotEmpty ? candidates.first : Order(id: '', table: '', status: '', items: const [], total: 0, time: '');
          }
        } else {
          final candidates = _orders.where((o) => o.table == tableLabel && o.status != 'Settled' && o.status != 'Cancelled').toList();
          candidates.sort((a, b) => ((b.createdAt ?? 0)).compareTo(a.createdAt ?? 0));
          order = candidates.isNotEmpty ? candidates.first : Order(id: '', table: '', status: '', items: const [], total: 0, time: '');
        }
      } else {
        final candidates = _orders.where((o) => o.table == tableLabel && o.status != 'Settled' && o.status != 'Cancelled').toList();
        candidates.sort((a, b) => ((b.createdAt ?? 0)).compareTo(a.createdAt ?? 0));
        order = candidates.isNotEmpty ? candidates.first : Order(id: '', table: '', status: '', items: const [], total: 0, time: '');
      }
      final cancelled = _cancelledKeysByOrder[order.id] ?? <String>{};
      final completed = _completedKeysByOrder[order.id] ?? <String>{};
      final itemsForBilling = order.items.where((i) {
        // if (i.isCancelled) return false; // Include cancelled items for display
        final key = _itemKey(i);
        if (cancelled.contains(key) && !i.isCancelled) return false; // Handle legacy cancelled set
        if (completed.isNotEmpty) return completed.contains(key);
        return true;
      }).toList();
      return itemsForBilling;
    } catch (_) {
      return const [];
    }
  }
  List<CartItem> _mergeItemsCumulate(List<CartItem> base, List<CartItem> add) {
    final map = <String, CartItem>{};
    void putAll(List<CartItem> src) {
      for (final i in src) {
        final k = _itemKey(i);
        final existing = map[k];
        if (existing == null) {
          map[k] = i;
        } else {
          map[k] = existing.copyWith(quantity: existing.quantity + i.quantity);
        }
      }
    }
    putAll(base);
    putAll(add);
    return map.values.toList();
  }
  
  void clearCart() {
    _cart = [];
    notifyListeners();
  }
  
  void clearTakeoutCart() {
    _takeoutCart = [];
    notifyListeners();
  }

  double cartTotal(List<CartItem> c) {
    double sum = 0;
    for (final i in c) {
      if (i.isCancelled) continue;
      final base = i.price * i.quantity;
      final mods = (i.modifiers ?? []).fold<int>(0, (s, m) => s + (int.tryParse((m['priceDelta'] ?? '0').toString()) ?? 0));
      sum += base + (mods * i.quantity);
    }
    return sum.toDouble();
  }

  Future<void> markOrderAsReady(String orderId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _orders = _orders.map((o) => o.id == orderId ? Order(id: o.id, table: o.table, status: 'Ready', items: o.items, total: o.total, time: o.time, paymentMethod: o.paymentMethod, createdAt: o.createdAt, readyAt: now) : o).toList();
    notifyListeners();
    
    await Repository.instance.orders.updateOrderStatus(orderId, 'Ready');
    await Repository.instance.orders.logEvent(orderId, 'ready');
    try {
      final ord = _orders.firstWhere((o) => o.id == orderId);
      for (final it in ord.items.where((i) => !i.isCancelled)) {
        await Repository.instance.orders.logEvent(orderId, 'ready_item', data: {'id': it.id, 'q': it.quantity});
      }
    } catch (_) {}

    // Update table status if linked
    try {
      final table = _tables.firstWhere((t) => t.orderId == orderId);
      await updateTableStatus(table.id, 'serving', orderId);
    } catch (_) {
      // Not a table order or table not found
    }
    
    _saveState();
  }

  Future<void> markOrderAsCompleted(String orderId) async {
    _orders = _orders.map((o) => o.id == orderId ? Order(id: o.id, table: o.table, status: 'Completed', items: o.items, total: o.total, time: o.time, paymentMethod: o.paymentMethod) : o).toList();
    notifyListeners();

    await Repository.instance.orders.updateOrderStatus(orderId, 'Completed');
    try {
      final ord = _orders.firstWhere((o) => o.id == orderId);
      final set = _completedKeysByOrder.putIfAbsent(orderId, () => <String>{});
      final batches = _kotBatchesByOrder[orderId] ?? const [];
      if (batches.isNotEmpty) {
        for (final b in batches) {
          final items = List<CartItem>.from(b['items'] as List<CartItem>);
          for (final it in items) {
            final key = _itemKey(it);
            set.add(key);
            await Repository.instance.orders.logEvent(orderId, 'completed', data: {'id': it.id, 'q': it.quantity});
          }
        }
      } else {
        for (final item in ord.items) {
          final key = _itemKey(item);
          set.add(key);
          await Repository.instance.orders.logEvent(orderId, 'completed', data: {'id': item.id, 'q': item.quantity});
        }
      }
    } catch (_) {}
    await Repository.instance.orders.logEvent(orderId, 'awaiting_billing');

    try {
      final table = _tables.firstWhere((t) => t.orderId == orderId);
      await updateTableStatus(table.id, 'billing', orderId);
    } catch (_) {}
    
    _saveState();
  }
 
  void openOrderFromDashboard(Order order) {
    final tbl = order.table;
    if (tbl.startsWith('Table ')) {
       final numStr = tbl.replaceFirst('Table ', '').trim();
       final n = int.tryParse(numStr);
       TableInfo? t;
       try {
         t = _tables.firstWhere((x) => x.orderId == order.id);
       } catch (_) {
         if (n != null) {
           try {
             t = _tables.firstWhere((x) => x.number == n);
           } catch (_) {}
         }
       }
       if (t != null) {
         if ((t.orderId == null || t.orderId!.isEmpty) && n != null) {
           updateTableStatus(t.id, t.status == 'available' ? 'occupied' : t.status, order.id);
           try {
             t = _tables.firstWhere((x) => x.id == t!.id);
           } catch (_) {}
         }
       try {
         getActiveTableItems(t!.orderId);
       } catch (_) {}
        _selectedTable = t;
        _cart = [];
        setCurrentView('tableOrder', tableNumber: t!.number);
      }
    } else if (tbl.startsWith('Takeout #')) {
      final tokenStr = tbl.replaceFirst('Takeout #', '').trim();
      final re = RegExp(r'^T#(\d{6})-(\d{3})$');
      final m = re.firstMatch(tokenStr);
      if (m != null) {
        _takeoutTokenDate = m.group(1) ?? _todayYYMMDD();
        _takeoutTokenNumber = int.tryParse(m.group(2) ?? '1') ?? 1;
      } else {
        final token = int.tryParse(tokenStr);
        if (token != null) {
          _takeoutTokenNumber = token;
          _takeoutTokenDate = _todayYYMMDD();
        }
      }
      _takeoutCart = order.items.map((i) => CartItem(id: i.id, name: i.name, price: i.price, quantity: i.quantity, image: i.image, instructions: i.instructions, addons: i.addons, modifiers: i.modifiers)).toList();
      _sentTakeoutQtyByKey = _quantitiesByKey(_takeoutCart);
      setCurrentView('takeout');
    }
    notifyListeners();
  }
 
   void searchAndOpen(String query) {
     final q = query.trim();
     if (q.isEmpty) return;
     if (q.toLowerCase().startsWith('table')) {
       final n = int.tryParse(q.toLowerCase().replaceAll('table', '').trim());
       if (n != null) {
         final order = _orders.firstWhere((o) => o.table == 'Table $n', orElse: () => Order(id: '', table: '', status: '', items: [], total: 0, time: ''));
         if (order.id.isNotEmpty) {
           openOrderFromDashboard(order);
           return;
         }
       }
     }
     if (q.toLowerCase().startsWith('t')) {
       final token = int.tryParse(q.substring(1));
       if (token != null) {
         final order = _orders.firstWhere((o) => o.table == 'Takeout #$token', orElse: () => Order(id: '', table: '', status: '', items: [], total: 0, time: ''));
         if (order.id.isNotEmpty) {
           openOrderFromDashboard(order);
           return;
         }
       }
     }
     final byId = _orders.firstWhere((o) => o.id == q, orElse: () => Order(id: '', table: '', status: '', items: [], total: 0, time: ''));
     if (byId.id.isNotEmpty) {
       openOrderFromDashboard(byId);
       return;
     }
   }
 
  List<CartItem> getActiveTableItems(String? orderId) {
    final st = _selectedTable;
    if (st != null && st.status == 'available') return [];
    List<CartItem> items = [];
    if (orderId == null || orderId.isEmpty) {
      if (st != null) {
        final label = 'Table ${st.number}';
        try {
          items = _orders
              .where((o) => o.table == label && o.status != 'Settled' && o.status != 'Cancelled')
              .expand((o) => o.items)
              .toList();
        } catch (_) {
          items = [];
        }
      }
    } else {
      items = _orders
          .where((o) => o.id == orderId && o.status != 'Settled' && o.status != 'Cancelled')
          .expand((o) => o.items)
          .toList();
    }
    return items.where((i) => !i.isCancelled).toList();
  }

  List<CartItem> getCancelledItems(String? orderId) {
    final st = _selectedTable;
    if (st != null && st.status == 'available') return [];
    List<CartItem> items = [];
    if (orderId == null || orderId.isEmpty) {
      if (st != null) {
        final label = 'Table ${st.number}';
        try {
          items = _orders
              .where((o) => o.table == label && o.status != 'Settled' && o.status != 'Cancelled')
              .expand((o) => o.items)
              .toList();
        } catch (_) {
          items = [];
        }
      }
    } else {
      items = _orders
          .where((o) => o.id == orderId && o.status != 'Settled' && o.status != 'Cancelled')
          .expand((o) => o.items)
          .toList();
    }
    return items.where((i) => i.isCancelled).toList();
  }
  List<CartItem> getActiveOrderItemsByLabel(String label) {
    try {
      final o = _orders.firstWhere((x) => x.table == label && x.status != 'Settled' && x.status != 'Cancelled');
      return List<CartItem>.from(o.items);
    } catch (_) {
      return [];
    }
  }

  void cancelOrderedItem(String orderId, CartItem item, String reason, bool isWastage) {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      
      // Inventory Sync
      if (isWastage) {
        // Keep KOT deduction; classify via event
        Repository.instance.orders.logEvent(orderId, 'item_marked_wastage', data: {'itemId': item.id, 'q': item.quantity, 'reason': reason});
      } else {
        Repository.instance.ingredients.restoreKOTBatch([item], orderId: orderId);
      }
      
      // Log Event
      Repository.instance.orders.logEvent(orderId, 'item_cancelled', data: {
        'itemId': item.id,
        'name': item.name,
        'reason': reason,
        'isWastage': isWastage
      });

      // Remove item from order
      final updatedItems = order.items.where((i) => i != item && (i.id != item.id || _itemKey(i) != _itemKey(item) || i.isCancelled)).toList();
      
      // Update order
      _orders = _orders.map((o) => o.id == orderId ? o.copyWith(items: updatedItems) : o).toList();
      
      // Recalculate Total
      _recalculateOrderTotal(orderId);

      // Check if order is empty
      if (updatedItems.isEmpty) {
        _orders = _orders.map((x) => x.id == orderId ? x.copyWith(status: 'Cancelled') : x).toList();
        Repository.instance.orders.updateOrderStatus(orderId, 'Cancelled');
        Repository.instance.orders.logEvent(orderId, 'order_auto_cancelled_empty');
        
        if (order.table.startsWith('Table ')) {
          final t = _tables.firstWhere((x) => x.orderId == orderId, orElse: () => TableInfo(id: -1, number: -1, status: '', capacity: 0));
          if (t.id != -1) {
            updateTableStatus(t.id, 'available', null);
            if (_selectedTable?.id == t.id) {
              _selectedTable = null;
              _cart = [];
              setCurrentView('tables');
            }
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      // debugPrint("Error cancelling item: $e");
    }
  }

  void cancelOrder(String orderId, String reason, bool isWastage) {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      final activeItems = order.items.where((i) => !i.isCancelled).toList();
      
      if (activeItems.isEmpty && order.items.isEmpty) {
        // Already empty, just ensure status
         _orders = _orders.map((o) => o.id == orderId ? o.copyWith(status: 'Cancelled') : o).toList();
         Repository.instance.orders.updateOrderStatus(orderId, 'Cancelled');
         if (order.table.startsWith('Table ')) {
            final t = _tables.firstWhere((x) => x.orderId == orderId, orElse: () => TableInfo(id: -1, number: -1, status: '', capacity: 0));
            if (t.id != -1) updateTableStatus(t.id, 'available', null);
         }
         notifyListeners();
         return;
      }

      // Inventory Sync
      if (isWastage) {
        // Keep existing KOT deduction as the loss; classify via event
        Repository.instance.orders.logEvent(orderId, 'order_marked_wastage', data: {'reason': reason});
      } else {
        Repository.instance.ingredients.restoreKOTBatch(activeItems, orderId: orderId);
      }
      
      // Log Event
      Repository.instance.orders.logEvent(orderId, 'order_cancelled', data: {
        'reason': reason,
        'isWastage': isWastage
      });
      
      // Update Order - Remove all items
      _orders = _orders.map((o) => o.id == orderId ? o.copyWith(items: [], status: 'Cancelled') : o).toList();
      
      // Update Total to 0
      _recalculateOrderTotal(orderId);
      
      // Release Table if applicable
      if (order.table.startsWith('Table ')) {
        final t = _tables.firstWhere((x) => x.orderId == orderId, orElse: () => TableInfo(id: -1, number: -1, status: '', capacity: 0));
        if (t.id != -1) {
          updateTableStatus(t.id, 'available', null);
          _selectedTable = null;
          _cart = [];
          setCurrentView('tables');
        }
      } else if (order.table.startsWith('Takeout #')) {
        _takeoutCart = [];
        _sentTakeoutQtyByKey = {};
        final today = _todayYYMMDD();
        if (_takeoutTokenDate != today) {
          _takeoutTokenDate = today;
          _takeoutTokenNumber = 1;
        } else {
          _takeoutTokenNumber = _takeoutTokenNumber + 1;
        }
        setCurrentView('takeout');
      }
      
      Repository.instance.orders.updateOrderStatus(orderId, 'Cancelled');
      
      notifyListeners();
      showToast('Order cancelled successfully.', icon: '🗑️');
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error cancelling order: $e");
      }
      showToast('Failed to cancel order.', icon: '⚠️');
    }
  }

  List<CartItem> getCancelledItemsForTable(String tableLabel) {
    try {
      final order = _orders.firstWhere((o) => o.table == tableLabel && o.status != 'Settled', orElse: () => Order(id: '', table: '', status: '', items: const [], total: 0, time: ''));
      if (order.id.isEmpty) return [];
      return order.items.where((i) => i.isCancelled).toList();
    } catch (_) {
      return [];
    }
  }

  void _recalculateOrderTotal(String orderId) {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      final newTotal = cartTotal(order.items) * 1.05;
      _orders = _orders.map((o) => o.id == orderId ? Order(id: o.id, table: o.table, status: o.status, items: o.items, total: newTotal, time: o.time, paymentMethod: o.paymentMethod, createdAt: o.createdAt, readyAt: o.readyAt) : o).toList();
      Repository.instance.orders.updateOrderItems(orderId, order.items, newTotal);
    } catch (_) {}
  }
  void updateActiveItemQuantity(int itemId, int delta) {
    if (_selectedTable?.status == 'billing') {
      showToast('Cannot modify items while order is awaiting billing.', icon: '⚠️');
      return;
    }
    final orderId = _selectedTable?.orderId;
    if (orderId == null) return;

    final order = _orders.firstWhere((o) => o.id == orderId);
    final item = order.items.firstWhere((i) => i.id == itemId, orElse: () => CartItem(id: -1, name: '', price: 0, quantity: 0, image: ''));
    if (item.id == -1) return;

    final newQty = item.quantity + delta;
    
    if (newQty <= 0) {
      // Treat as removal
      cancelOrderedItem(orderId, item, 'Quantity Reduced to 0', false);
      return; 
    }

    if (delta > 0) {
       // KOT Logic for +delta
       final addedItem = item.copyWith(quantity: delta);
       final kotNum = 'KOT${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-SUP';
       final batch = {'timestamp': DateTime.now().millisecondsSinceEpoch, 'items': [addedItem]};
       
       // Update KOT batches
       final batches = _kotBatchesByOrder[orderId] ?? [];
       _kotBatchesByOrder[orderId] = [...batches, batch];
       
       // Deduct Inventory
       Repository.instance.ingredients.applyKOTDeduction([addedItem], kotNumber: kotNum, orderId: orderId);
       
       // Log
       Repository.instance.orders.logEvent(orderId, 'quantity_increased', data: {'itemId': itemId, 'added': delta});
    } else {
       // Cancel Logic for -delta (partial)
       final removedQty = delta.abs();
       final removedItem = item.copyWith(quantity: removedQty);
       
       // Restore Inventory
       Repository.instance.ingredients.restoreKOTBatch([removedItem]);
       
       // Log
       Repository.instance.orders.logEvent(orderId, 'quantity_decreased', data: {'itemId': itemId, 'removed': removedQty});
    }

    _orders = _orders.map((o) {
      if (o.id != orderId) return o;
      final updatedItems = o.items.map((i) {
        if (i.id == itemId) {
          return i.copyWith(quantity: newQty);
        }
        return i;
      }).toList();
      return o.copyWith(items: updatedItems);
    }).toList();
    _recalculateOrderTotal(orderId);
    notifyListeners();
  }
  void updateActiveItemInstructions(int itemId, String text) {
    if (_selectedTable?.status == 'billing') {
      showToast('Cannot modify items while order is awaiting billing.', icon: '⚠️');
      return;
    }
    final orderId = _selectedTable?.orderId;
    if (orderId == null) return;
    _orders = _orders.map((o) {
      if (o.id != orderId) return o;
      final updatedItems = o.items.map((i) => i.id == itemId ? i.copyWith(instructions: text) : i).toList();
      return Order(id: o.id, table: o.table, status: o.status, items: updatedItems, total: o.total, time: o.time, paymentMethod: o.paymentMethod, createdAt: o.createdAt, readyAt: o.readyAt);
    }).toList();
    _recalculateOrderTotal(orderId);
    notifyListeners();
  }
  void toggleActiveAddonForItem(int itemId, int addonId) {
    if (_selectedTable?.status == 'billing') {
      showToast('Cannot modify items while order is awaiting billing.', icon: '⚠️');
      return;
    }
    final orderId = _selectedTable?.orderId;
    if (orderId == null) return;
    _orders = _orders.map((o) {
      if (o.id != orderId) return o;
      final updatedItems = o.items.map((i) {
        if (i.id != itemId) return i;
        final current = i.addons ?? [];
        final has = current.contains(addonId);
        final next = has ? current.where((x) => x != addonId).toList() : [...current, addonId];
        return i.copyWith(addons: next);
      }).toList();
      return Order(id: o.id, table: o.table, status: o.status, items: updatedItems, total: o.total, time: o.time, paymentMethod: o.paymentMethod, createdAt: o.createdAt, readyAt: o.readyAt);
    }).toList();
    _recalculateOrderTotal(orderId);
    notifyListeners();
  }
  void toggleActiveModifierForItem(int itemId, Map<String, dynamic> modifier) {
    if (_selectedTable?.status == 'billing') {
      showToast('Cannot modify items while order is awaiting billing.', icon: '⚠️');
      return;
    }
    final orderId = _selectedTable?.orderId;
    if (orderId == null) return;
    _orders = _orders.map((o) {
      if (o.id != orderId) return o;
      final updatedItems = o.items.map((i) {
        if (i.id != itemId) return i;
        final cur = List<Map<String, dynamic>>.from(i.modifiers ?? []);
        final exists = cur.any((m) => (m['name']?.toString() ?? '') == (modifier['name']?.toString() ?? '') && (m['priceDelta']?.toString() ?? '') == (modifier['priceDelta']?.toString() ?? ''));
        final next = exists ? cur.where((m) => !((m['name']?.toString() ?? '') == (modifier['name']?.toString() ?? '') && (m['priceDelta']?.toString() ?? '') == (modifier['priceDelta']?.toString() ?? ''))).toList() : [...cur, modifier];
        return i.copyWith(modifiers: next);
      }).toList();
      return Order(id: o.id, table: o.table, status: o.status, items: updatedItems, total: o.total, time: o.time, paymentMethod: o.paymentMethod, createdAt: o.createdAt, readyAt: o.readyAt);
    }).toList();
    _recalculateOrderTotal(orderId);
    notifyListeners();
  }
  void removeActiveItem(int itemId) {
    if (_selectedTable?.status == 'billing') {
      showToast('Cannot modify items while order is awaiting billing.', icon: '⚠️');
      return;
    }
    final orderId = _selectedTable?.orderId;
    if (orderId == null) return;
    try {
      final ord = _orders.firstWhere((o) => o.id == orderId && o.status != 'Settled' && o.status != 'Cancelled');
      final candidates = ord.items.where((i) => i.id == itemId).toList();
      for (final it in candidates) {
        cancelOrderedItem(orderId, it, 'removed_from_cart', false);
      }
    } catch (_) {}
    notifyListeners();
  }

  bool _isProcessingKOT = false;

  Future<void> generateKOT(List<CartItem> items, String tableInfo, bool isTableOrder, BuildContext context) async {
    if (_isProcessingKOT) return;
    final timeStr = TimeOfDay.now().format(context);
    
    // Validate items before processing
    final sendItems = isTableOrder ? items : _computeTakeoutDelta(items);
    if (sendItems.isEmpty) {
      showToast('Cannot send empty order.', icon: '⚠️');
      return;
    }

    _isProcessingKOT = true;
    notifyListeners();

    try {
      currentKOT = {
        'kotNumber': 'KOT${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'timestamp': DateTime.now().toLocal().toString(),
        'table': tableInfo,
        'items': sendItems,
      };
      final kotNum = currentKOT!['kotNumber'].toString();
      showKOTPreview = true;
      notifyListeners();

      final total = cartTotal(sendItems) * 1.05;
      
      // Robust Order ID resolution
      String id;
      if (isTableOrder && _selectedTable != null) {
        if (_selectedTable!.orderId != null) {
          id = _selectedTable!.orderId!;
        } else {
          // Check if an active order exists for this table to prevent duplicates
          final existingOrder = _orders.firstWhere(
            (o) => o.table == tableInfo && o.status != 'Settled' && o.status != 'Completed' && o.status != 'Cancelled',
            orElse: () => Order(id: '', table: '', status: '', items: [], total: 0, time: ''),
          );
          if (existingOrder.id.isNotEmpty) {
            id = existingOrder.id;
            // Update table status to link to this order if missing
            // If the order is active, the table should likely be occupied or related status
            if (_selectedTable!.status == 'available') {
               await updateTableStatus(_selectedTable!.id, 'occupied', id);
            }
             try {
              _selectedTable = _tables.firstWhere((t) => t.id == _selectedTable!.id);
            } catch (_) {}
          } else {
            id = 'ORD${DateTime.now().millisecondsSinceEpoch}';
          }
        }
      } else {
        id = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      }

      final order = Order(
        id: id, 
        table: tableInfo, 
        status: 'Preparing', 
        items: sendItems, 
        total: total, 
        time: timeStr,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      
      if (isTableOrder && _selectedTable != null) {
        int idx = _orders.indexWhere((o) => o.id == id);
        if (idx >= 0) {
          final existing = _orders[idx];
          final mergedItems = _mergeItemsCumulate(existing.items, sendItems);
          final mergedTotal = cartTotal(mergedItems) * 1.05;
          final updated = Order(
            id: existing.id,
            table: existing.table,
            status: 'Preparing',
            items: mergedItems,
            total: mergedTotal,
            time: timeStr,
            paymentMethod: existing.paymentMethod,
            createdAt: existing.createdAt ?? DateTime.now().millisecondsSinceEpoch,
            readyAt: null,
            settledAt: null,
          );
          _orders = [
            ..._orders.take(idx),
            updated,
            ..._orders.skip(idx + 1),
          ];
          await Repository.instance.orders.updateOrderItems(existing.id, mergedItems, mergedTotal);
          await Repository.instance.orders.updateOrderStatus(existing.id, 'Preparing');
          await Repository.instance.orders.logEvent(existing.id, 'sent_to_kitchen', data: {
            'items': sendItems.map((i) => {'id': i.id, 'q': i.quantity}).toList(),
            'table': existing.table,
          });
          final batchList = _kotBatchesByOrder.putIfAbsent(existing.id, () => []);
          batchList.add({'timestamp': DateTime.now().millisecondsSinceEpoch, 'items': sendItems});
          Repository.instance.ingredients.applyKOTDeduction(sendItems, kotNumber: kotNum, orderId: existing.id);
          
          // Ensure table status is updated to Preparing when adding to an existing order
          await updateTableStatus(_selectedTable!.id, 'preparing', existing.id);
        } else {
          _orders = [..._orders, order];
          await Repository.instance.orders.insertOrder(order, sendItems);
          await updateTableStatus(_selectedTable!.id, 'preparing', order.id);
          try {
            _selectedTable = _tables.firstWhere((t) => t.id == _selectedTable!.id);
          } catch (_) {}
          final batchList = _kotBatchesByOrder.putIfAbsent(order.id, () => []);
          batchList.add({'timestamp': DateTime.now().millisecondsSinceEpoch, 'items': sendItems});
          Repository.instance.ingredients.applyKOTDeduction(sendItems, kotNumber: kotNum, orderId: order.id);
        }
        _cart = [];
      } else {
        int idx = _orders.indexWhere((o) => o.table == tableInfo && o.status != 'Completed' && o.status != 'Settled' && o.status != 'Cancelled');
        if (idx >= 0) {
          final existing = _orders[idx];
          final mergedItems = _mergeItemsCumulate(existing.items, sendItems);
          final mergedTotal = cartTotal(mergedItems) * 1.05;
          final updated = Order(
            id: existing.id,
            table: existing.table,
            status: 'Preparing',
            items: mergedItems,
            total: mergedTotal,
            time: timeStr,
            paymentMethod: existing.paymentMethod,
            createdAt: existing.createdAt ?? DateTime.now().millisecondsSinceEpoch,
            readyAt: null,
          );
          _orders = [
            ..._orders.take(idx),
            updated,
            ..._orders.skip(idx + 1),
          ];
          await Repository.instance.orders.updateOrderItems(existing.id, mergedItems, mergedTotal);
          await Repository.instance.orders.updateOrderStatus(existing.id, 'Preparing');
          await Repository.instance.orders.logEvent(existing.id, 'sent_to_kitchen', data: {
            'items': sendItems.map((i) => {'id': i.id, 'q': i.quantity}).toList(),
            'table': existing.table,
          });
          final batchList = _kotBatchesByOrder.putIfAbsent(existing.id, () => []);
          batchList.add({'timestamp': DateTime.now().millisecondsSinceEpoch, 'items': sendItems});
          Repository.instance.ingredients.applyKOTDeduction(sendItems, kotNumber: kotNum, orderId: existing.id);
        } else {
          _orders = [..._orders, order];
          await Repository.instance.orders.insertOrder(order, sendItems);
          final batchList = _kotBatchesByOrder.putIfAbsent(order.id, () => []);
          batchList.add({'timestamp': DateTime.now().millisecondsSinceEpoch, 'items': sendItems});
          Repository.instance.ingredients.applyKOTDeduction(sendItems, kotNumber: kotNum, orderId: order.id);
        }
      }
      if (isTableOrder) {
        showToast('Order sent to kitchen.', icon: '✅');
      } else {
        final tokenLabel = takeoutTokenId;
        showToast('Order sent to kitchen. $tokenLabel assigned.', icon: '✅');
      }
      for (final ci in sendItems) {
        final idx = menuItems.indexWhere((m) => m.id == ci.id);
        if (idx >= 0) {
          final m = menuItems[idx];
          final st = m.stock;
          if (st != null) {
            final next = st - ci.quantity;
            final newStock = next < 0 ? 0 : next;
            final sold = newStock == 0 ? true : m.soldOut;
            menuItems[idx] = MenuItem(id: m.id, name: m.name, category: m.category, price: m.price, image: m.image, soldOut: sold, modifiers: m.modifiers, upsellIds: m.upsellIds, instructionTemplates: m.instructionTemplates, specialFlags: m.specialFlags, availableDays: m.availableDays, availableStart: m.availableStart, availableEnd: m.availableEnd, seasonal: m.seasonal, ingredients: m.ingredients, stock: newStock);
            Repository.instance.menu.updateMenuItem(menuItems[idx]);
          }
        }
      }
      if (!isTableOrder) {
        final cur = _quantitiesByKey(_takeoutCart);
        for (final ci in sendItems) {
          final k = _itemKey(ci);
          final sentQ = _sentTakeoutQtyByKey[k] ?? 0;
          final newSent = sentQ + ci.quantity;
          _sentTakeoutQtyByKey[k] = newSent;
          cur[k] = (cur[k] ?? 0); 
        }
      }
      _saveState();
      notifyListeners();
    } catch (e) {
      // Error generating KOT
      showToast('Failed to send order: $e', icon: '❌');
    } finally {
      _isProcessingKOT = false;
    }
  }

  void printKOT() {
    if (currentKOT == null) return;
    final items = currentKOT!['items'] as List<CartItem>;
    
    final doc = HtmlTicketGenerator.generateKOT(
      kotData: currentKOT!,
      menuItems: menuItems,
    );

    final url = 'data:text/html;charset=utf-8,${Uri.encodeComponent(doc)}';
    if (kIsWeb) {
      web.openNewTab(url, features: 'width=800,height=600');
    }
    _sendToPrinter('kot', doc);
    
    // Dual Printer Integration
    try {
      final kotItems = items.map((i) => {
        'name': i.name,
        'qty': i.quantity,
        'note': i.instructions
      }).toList();
      PrinterService.instance.printKOT(
        {'items': kotItems}, 
        currentKOT!['table']?.toString() ?? 'Unknown', 
        'Order'
      );
    } catch (e) {
      // debugPrint("KOT Print Error: $e");
    }
    
    showKOTPreview = false;
    notifyListeners();
  }
  
  void setShowKOTPreview(bool value) {
    showKOTPreview = value;
    notifyListeners();
  }

  void setShowBillPreview(bool value) {
    showBillPreview = value;
    notifyListeners();
  }

  void setShowPaymentModal(bool value) {
    showPaymentModal = value;
    notifyListeners();
  }

  void closeKOTPreview() {
    showKOTPreview = false;
    notifyListeners();
  }

  void openPaymentModal(List<CartItem> items, String tableInfo, bool isTableOrder) {
    final consolidated = consolidatedItemsForTable(tableInfo).isNotEmpty ? consolidatedItemsForTable(tableInfo) : items;
    final subtotal = consolidated.fold<double>(0, (s, i) => s + (i.isCancelled ? 0 : i.price * i.quantity));
    final gst = subtotal * 0.05;
    
    if (isTableOrder && _selectedTable != null) {
      updateTableStatus(_selectedTable!.id, 'billing', _selectedTable!.orderId);
    } else {
      bool updated = false;
      _orders = _orders.map((o) {
        if (o.table == tableInfo && o.status != 'Settled') {
          updated = true;
          return Order(id: o.id, table: o.table, status: 'Awaiting Payment', items: o.items, total: o.total, time: o.time, paymentMethod: o.paymentMethod, createdAt: o.createdAt, readyAt: o.readyAt);
        }
        return o;
      }).toList();
      if (updated) {
        final orderId = _orders.firstWhere((o) => o.table == tableInfo, orElse: () => Order(id: '', table: '', status: '', items: [], total: 0, time: '')).id;
        if (orderId.isNotEmpty) {
          Repository.instance.orders.updateOrderStatus(orderId, 'Awaiting Payment');
          Repository.instance.orders.logEvent(orderId, 'awaiting_billing');
        }
      }
    }
    
    currentBill = {
      'billNumber': 'BILL${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'timestamp': DateTime.now().toLocal().toString(),
      'table': tableInfo,
      'items': consolidated,
      'subtotal': subtotal,
      'gst': gst,
      'total': subtotal + gst,
      'isTableOrder': isTableOrder,
    };
    paymentMode = 'Cash';
    splitPayment = false;
    cashAmount = 0;
    cardAmount = 0;
    upiAmount = 0;
    showPaymentModal = true;
    if (!isTableOrder) {
      final tokenNum = tableInfo.replaceFirst('Takeout #', '').trim();
      final tokenLabel = tokenNum.isNotEmpty ? 'Token#$tokenNum' : '';
      showToast('Bill generated for $tokenLabel.', icon: '✅');
    } else {
      showToast('Bill generated.', icon: '✅');
    }
    notifyListeners();
  }
  
  void closePaymentModal() {
    showPaymentModal = false;
    notifyListeners();
  }
  
  void updatePaymentDetails({String? mode, bool? split, double? cash, double? card, double? upi}) {
    if (mode != null) paymentMode = mode;
    if (split != null) splitPayment = split;
    if (cash != null) cashAmount = cash;
    if (card != null) cardAmount = card;
    if (upi != null) upiAmount = upi;
    notifyListeners();
  }

  void processPayment() {
    if (currentBill == null) return;
    final method = splitPayment ? 'Split' : paymentMode;
    
    currentBill!['paymentMethod'] = method;
    currentBill!['paymentDetails'] = splitPayment ? {'Cash': cashAmount, 'Card': cardAmount, 'UPI': upiAmount} : null;
    showPaymentModal = false;
    showBillPreview = true;
    _saveState();
    notifyListeners();
  }

  void closeBillPreview() {
    showBillPreview = false;
    notifyListeners();
  }

  void printBill() {
    if (currentBill == null) return;
    final tableLabel = currentBill!['table'] as String;
    List<CartItem> finalItems = consolidatedItemsForTable(tableLabel);
    if (finalItems.isEmpty) {
      finalItems = currentBill!['items'] as List<CartItem>;
    }
    try {
      final existing = _orders.firstWhere((o) => o.table == tableLabel && o.status != 'Settled');
      final cancelled = _cancelledKeysByOrder[existing.id] ?? <String>{};
      if (existing.items.isNotEmpty) {
        finalItems = existing.items.where((i) => !cancelled.contains(_itemKey(i))).toList();
      }
    } catch (_) {}
    final recalculatedSubtotal = cartTotal(finalItems);
    final recalculatedGst = recalculatedSubtotal * 0.05;
    final recalculatedTotal = recalculatedSubtotal + recalculatedGst;
    currentBill!['items'] = finalItems;
    currentBill!['subtotal'] = recalculatedSubtotal;
    currentBill!['gst'] = recalculatedGst;
    currentBill!['total'] = recalculatedTotal;
    final items = finalItems;
    
    final doc = HtmlTicketGenerator.generateBill(
      billData: currentBill!,
    );

    final url = 'data:text/html;charset=utf-8,${Uri.encodeComponent(doc)}';
    if (kIsWeb) {
      web.openNewTab(url, features: 'width=800,height=600');
    }
    _sendToPrinter('bill', doc);

    // Dual Printer Integration
    try {
      final billItems = items.map((i) => {
        'name': i.name,
        'qty': i.quantity,
        'price': i.price
      }).toList();
      PrinterService.instance.printBill(
        {'items': billItems}, 
        currentBill!['table']?.toString() ?? 'Unknown',
        recalculatedSubtotal,
        recalculatedGst,
        recalculatedTotal
      );
    } catch (e) {
      // debugPrint("Bill Print Error: $e");
    }
    
    showBillPreview = false;
    
    final isTableOrder = currentBill!['isTableOrder'] as bool;
    if (isTableOrder && _selectedTable != null) {
      final id = _selectedTable!.orderId;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _orders = _orders.map((o) => o.id == id ? Order(id: o.id, table: o.table, status: 'Settled', items: o.items, total: o.total, time: o.time, paymentMethod: currentBill!['paymentMethod'] as String?, createdAt: o.createdAt, readyAt: o.readyAt, settledAt: nowMs) : o).toList();
      updateTableStatus(_selectedTable!.id, 'available', null);
      Repository.instance.orders.updateOrderStatus(id ?? '', 'Settled', paymentMethod: currentBill!['paymentMethod'] as String?);
      Repository.instance.orders.logEvent(id ?? '', 'paid', data: {
        'method': currentBill!['paymentMethod'],
        'total': currentBill!['total'],
      });
      _selectedTable = null;
      _cart = [];
      showToast('Payment received. Table is now available.', icon: '✅');
      setCurrentView('tables');
    } else {
      final tableLabel = currentBill!['table'] as String;
      final method = currentBill!['paymentMethod'] as String?;
      bool updated = false;
      _orders = _orders.map((o) {
        if (o.table == tableLabel) {
          updated = true;
          final newTotal = cartTotal(o.items) * 1.05;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          return Order(id: o.id, table: o.table, status: 'Settled', items: o.items, total: newTotal, time: o.time, paymentMethod: method, createdAt: o.createdAt, readyAt: o.readyAt, settledAt: nowMs);
        }
        return o;
      }).toList();
      if (!updated) {
        final id = 'ORD${DateTime.now().millisecondsSinceEpoch}';
        final createdAt = DateTime.now().millisecondsSinceEpoch;
        final dt = DateTime.now();
        final timeStr = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
        final itemsList = currentBill!['items'] as List<CartItem>;
        final totalVal = cartTotal(itemsList) * 1.05;
        _orders = [
          ..._orders,
          Order(id: id, table: tableLabel, status: 'Settled', items: itemsList, total: totalVal, time: timeStr, paymentMethod: method, createdAt: createdAt, settledAt: createdAt),
        ];
        Repository.instance.orders.insertOrder(_orders.last, itemsList);
        Repository.instance.orders.logEvent(_orders.last.id, 'paid', data: {
          'method': method,
          'total': totalVal,
        });
      } else {
        final orderId = _orders.firstWhere((o) => o.table == tableLabel, orElse: () => Order(id: '', table: '', status: '', items: [], total: 0, time: '')).id;
        if (orderId.isNotEmpty) {
          Repository.instance.orders.updateOrderStatus(orderId, 'Settled', paymentMethod: method);
          Repository.instance.orders.logEvent(orderId, 'paid', data: {
            'method': method,
            'total': currentBill!['total'],
          });
        }
      }
      _takeoutCart = [];
      _sentTakeoutQtyByKey = {};
      _saveState();
      final tokenLabel = tableLabel.replaceFirst('Takeout #', '').trim();
      showToast('Payment received. $tokenLabel closed.', icon: '✅');
      final today = _todayYYMMDD();
      if (_takeoutTokenDate != today) {
        _takeoutTokenDate = today;
        _takeoutTokenNumber = 1;
      } else {
        _takeoutTokenNumber = _takeoutTokenNumber + 1;
      }
    }
    notifyListeners();
  }
}
