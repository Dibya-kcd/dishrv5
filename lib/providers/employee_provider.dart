import 'package:flutter/material.dart';
import '../data/repository.dart';
import '../data/sync_service.dart';
import '../utils/auth_helper.dart';

class EmployeeProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _employees = [];

  List<Map<String, dynamic>> get employees => _employees;

  Future<void> loadEmployees() async {
    _employees = await Repository.instance.employees.listEmployees();
    notifyListeners();
  }

  Future<void> addEmployee(Map<String, dynamic> data) async {
    final role = Repository.instance.clientMeta?['role']?.toString().toLowerCase() ?? '';
    if (!AuthHelper.hasPermission(role, 'manage_employees')) return;
    await Repository.instance.employees.upsertEmployee(data);
    await loadEmployees();
  }

  Future<void> updateEmployee(Map<String, dynamic> data) async {
    final role = Repository.instance.clientMeta?['role']?.toString().toLowerCase() ?? '';
    if (!AuthHelper.hasPermission(role, 'manage_employees')) return;
    await Repository.instance.employees.updateEmployee(data);
    await loadEmployees();
  }

  Future<void> deleteEmployee(String id) async {
    final role = Repository.instance.clientMeta?['role']?.toString().toLowerCase() ?? '';
    if (!AuthHelper.hasPermission(role, 'delete_employee')) {
      throw Exception('You do not have permission to delete employees.');
    }

    try {
      // Step 1: Use Online (Firebase) as Master - Soft delete in Firebase
      await SyncService.instance.deleteEmployee(id);

      // Step 2: Propagate Deletion to Offline (SQLite) - Local removal
      // We call with fromSync: true to avoid redundant SyncService calls
      await Repository.instance.employees.deleteEmployee(id, fromSync: true);

      // Step 4: Audit log ensures traceability
      await SyncService.instance.logAuditEvent('employee_deleted', {
        'employee_id': id,
        'deleted_by_role': role,
        'deleted_by_client': Repository.instance.clientMeta?['name'] ?? 'Unknown',
      });

      await loadEmployees();
    } catch (e) {
      if (e.toString().contains('permission_denied')) {
        throw Exception('Firebase Permission Denied: Only authenticated Admins can delete employees. Ensure you are signed in to Firebase in the Admin Panel.');
      }
      rethrow;
    }
  }

  Future<void> checkAndGenerateSalaries() async {
    try {
      // Only admins or managers can generate salaries
      final currentRole = Repository.instance.clientMeta?['role']?.toString().toLowerCase();
      if (currentRole != 'admin' && currentRole != 'manager') return;

      if (_employees.isEmpty) await loadEmployees();
      
      final now = DateTime.now();
      final year = now.year;
      final month = now.month;
      final lastDay = DateTime(year, month + 1, 0).day;
      
      final allExpenses = await Repository.instance.expenses.listExpenses();
      
      for (final e in _employees) {
        final payment = Map<String, dynamic>.from(e['payment'] as Map? ?? {});
        final employment = Map<String, dynamic>.from(e['employment'] as Map? ?? {});
        final sched = Map<String, dynamic>.from(employment['salary_schedule'] as Map? ?? {});
        final salaryType = (employment['salary_type']?.toString() ?? '').trim().toLowerCase();
        
        final payDayStr = sched['pay_day']?.toString().trim().isNotEmpty == true ? sched['pay_day'].toString().trim() : (payment['payment_day']?.toString().trim() ?? '');
        final payDay = int.tryParse(payDayStr.isEmpty ? '30' : payDayStr) ?? 30;
        
        final targetDay = payDay > lastDay ? lastDay : payDay;
        
        if (salaryType != 'monthly') continue;
        if (now.day != targetDay) continue;
        
        final empId = e['id']?.toString() ?? e['employee_code']?.toString() ?? e['name']?.toString() ?? '';
        if (empId.isEmpty) continue;
        
        final expenseId = 'SAL-$empId-$year${month.toString().padLeft(2, '0')}';
        
        final exists = allExpenses.any((x) => (x['id']?.toString() ?? '') == expenseId);
        if (exists) continue;
        
        final net = (e['net_salary'] as num?)?.toDouble();
        if ((net ?? 0.0) <= 0) continue;
        
        final entry = {
          'id': expenseId,
          'amount': net!,
          'category': 'Staff Salaries & Wages',
          'note': 'Salary for ${e['name']?.toString() ?? ''} - $year-${month.toString().padLeft(2, '0')}',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        
        await Repository.instance.expenses.insertExpense(entry);
      }
    } catch (e) {
      // debugPrint('Error generating salaries: $e');
    }
  }
}
