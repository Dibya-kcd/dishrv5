import 'package:flutter/foundation.dart';
import '../data/repository.dart';

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
        'name': 'Admin User',
        'employee_code': 'ADM001',
        'role': 'admin',
        'status': 'Active',
        'pin': '1234',
        'gross_salary': 50000.0,
        'net_salary': 45000.0,
        'personal': {'email': 'admin@example.com', 'phone': '9999999999'},
        'salary': {'basic': 30000, 'hra': 10000, 'allowances': 10000},
        'deductions': {'pf': 2000, 'tax': 3000},
        'payment': {'method': 'Bank Transfer'},
        'employment': {'type': 'Permanent', 'salary_type': 'monthly'},
        'documents': {},
      },
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
