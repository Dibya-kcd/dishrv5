import 'package:flutter/foundation.dart';
import '../data/repository.dart';
import '../models/menu_item.dart';

Future<void> ensureSampleEmployees() async {
  try {
    final db = await Repository.instance.database;
    await db.transaction((txn) async {
      final existingEmployees = (await Repository.instance.employees.listEmployees(txn: txn))
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['deleted_at'] == null)
          .toList();

      if (existingEmployees.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('Employees already exist, skipping sample generation.');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('Ensuring sample employees exist...');
      }

      final samples = [
      {
        'name': 'Manager User',
        'employee_code': 'MGR001',
        'role': 'manager',
        'status': 'Active',
        'pin': '5678',
        'gross_salary': 40000.0,
        'net_salary': 36000.0,
        'personal': {'email': 'manager@example.com', 'phone': '8888888888'},
        'salary': {'basic': 25000, 'hra': 8000, 'allowances': 7000},
        'deductions': {'pf': 1500, 'tax': 2500},
        'payment': {'method': 'Bank Transfer'},
        'employment': {'type': 'Permanent', 'salary_type': 'monthly'},
        'documents': {},
      },
      {
        'name': 'Waiter User',
        'employee_code': 'WTR001',
        'role': 'waiter',
        'status': 'Active',
        'pin': '0000',
        'gross_salary': 20000.0,
        'net_salary': 18000.0,
        'personal': {'email': 'waiter@example.com', 'phone': '7777777777'},
        'salary': {'basic': 12000, 'hra': 4000, 'allowances': 4000},
        'deductions': {'pf': 1000, 'tax': 1000},
        'payment': {'method': 'Cash'},
        'employment': {'type': 'Contract', 'salary_type': 'monthly'},
        'documents': {},
      },
      {
        'name': 'Chef User',
        'employee_code': 'CHF001',
        'role': 'chef',
        'status': 'Active',
        'pin': '1111',
        'gross_salary': 35000.0,
        'net_salary': 32000.0,
        'personal': {'email': 'chef@example.com', 'phone': '6666666666'},
        'salary': {'basic': 20000, 'hra': 7000, 'allowances': 8000},
        'deductions': {'pf': 1500, 'tax': 1500},
        'payment': {'method': 'Bank Transfer'},
        'employment': {'type': 'Permanent', 'salary_type': 'monthly'},
        'documents': {},
      },
    ];

    for (final sample in samples) {
      final code = sample['employee_code'];
      final matches = existingEmployees.where((e) => (e['employee_code']?.toString() ?? '') == code).toList();

      if (matches.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('Sample employee $code already exists, skipping overwrite.');
        }
        continue;
      }

      final data = Map<String, dynamic>.from(sample);
      final id = 'EMP${DateTime.now().millisecondsSinceEpoch}-$code';
      data['id'] = id;
      if (kDebugMode) {
        debugPrint('Creating sample employee: $code');
      }
      
      await Repository.instance.employees.upsertEmployee(data, txn: txn);
      await Future.delayed(const Duration(milliseconds: 10));
    }

    if (kDebugMode) {
      debugPrint('Sample employees verification completed.');
    }
    });
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error generating sample employees: $e');
    }
  }
}

Future<void> seedDemoData() async {
  final menu = await Repository.instance.menu.listMenu();
  if (menu.isEmpty) {
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
  }

  await Repository.instance.ingredients.resetToCanonicalSeed(notify: false);

  final menuItems = await Repository.instance.menu.listMenu();
  final byName = {for (final m in menuItems) m.name.toLowerCase(): m};

  Future<void> setRecipe(String itemName, List<Map<String, dynamic>> items) async {
    final m = byName[itemName.toLowerCase()];
    if (m == null) return;
    await Repository.instance.ingredients.setRecipeForMenuItem(m.id, items, notify: false);
  }

  await setRecipe('Paneer Tikka', [
    {'ingredient_id': 'ING001', 'qty': 150.0, 'unit': 'g'},
    {'ingredient_id': 'ING002', 'qty': 50.0, 'unit': 'g'},
    {'ingredient_id': 'ING003', 'qty': 10.0, 'unit': 'g'},
    {'ingredient_id': 'ING004', 'qty': 10.0, 'unit': 'ml'},
  ]);
  await setRecipe('Chicken Biryani', [
    {'ingredient_id': 'ING005', 'qty': 200.0, 'unit': 'g'},
    {'ingredient_id': 'ING006', 'qty': 150.0, 'unit': 'g'},
    {'ingredient_id': 'ING007', 'qty': 8.0, 'unit': 'g'},
    {'ingredient_id': 'ING004', 'qty': 15.0, 'unit': 'ml'},
  ]);
  await setRecipe('Masala Dosa', [
    {'ingredient_id': 'ING008', 'qty': 200.0, 'unit': 'g'},
    {'ingredient_id': 'ING009', 'qty': 120.0, 'unit': 'g'},
    {'ingredient_id': 'ING004', 'qty': 10.0, 'unit': 'ml'},
  ]);
  await setRecipe('Butter Naan', [
    {'ingredient_id': 'ING010', 'qty': 120.0, 'unit': 'g'},
    {'ingredient_id': 'ING011', 'qty': 10.0, 'unit': 'g'},
    {'ingredient_id': 'ING012', 'qty': 2.0, 'unit': 'g'},
  ]);
  await setRecipe('Gulab Jamun', [
    {'ingredient_id': 'ING013', 'qty': 100.0, 'unit': 'g'},
    {'ingredient_id': 'ING014', 'qty': 50.0, 'unit': 'ml'},
  ]);
  await setRecipe('Cold Coffee', [
    {'ingredient_id': 'ING015', 'qty': 200.0, 'unit': 'ml'},
    {'ingredient_id': 'ING016', 'qty': 10.0, 'unit': 'g'},
    {'ingredient_id': 'ING017', 'qty': 15.0, 'unit': 'g'},
  ]);
  await setRecipe('Dal Makhani', [
    {'ingredient_id': 'ING018', 'qty': 150.0, 'unit': 'g'},
    {'ingredient_id': 'ING019', 'qty': 20.0, 'unit': 'ml'},
    {'ingredient_id': 'ING011', 'qty': 10.0, 'unit': 'g'},
  ]);
  await setRecipe('Spring Rolls', [
    {'ingredient_id': 'ING020', 'qty': 2.0, 'unit': 'pc'},
    {'ingredient_id': 'ING021', 'qty': 100.0, 'unit': 'g'},
    {'ingredient_id': 'ING004', 'qty': 15.0, 'unit': 'ml'},
  ]);

  final tables = await Repository.instance.tables.listTables();
  if (tables.isEmpty) {
    for (var n = 1; n <= 8; n++) {
      await Repository.instance.tables.upsertTable(n, n, 'available', 4, orderId: null, notify: false);
    }
  }

  await ensureSampleEmployees();
  Repository.instance.notifyDataChanged();
}
