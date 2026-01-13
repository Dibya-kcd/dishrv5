import 'package:flutter/material.dart';
import '../data/repository.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _expenses = [];

  List<Map<String, dynamic>> get expenses => _expenses;

  Future<void> loadExpenses() async {
    _expenses = await Repository.instance.expenses.listExpenses();
    notifyListeners();
  }

  void addExpense({required double amount, required String category, String? note}) {
    final entry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'amount': amount,
      'category': category,
      'note': note ?? '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _expenses = [..._expenses, entry];
    Repository.instance.expenses.insertExpense(entry);
    notifyListeners();
  }
  
  Future<void> addSalaryExpense(Map<String, dynamic> entry) async {
      await Repository.instance.expenses.insertExpense(entry);
      await loadExpenses();
  }

  Future<String> recordEmployeeSalary(Map<String, dynamic> e) async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final empId = e['id']?.toString().trim().isNotEmpty == true ? e['id'].toString() : (e['employee_code']?.toString().trim().isNotEmpty == true ? e['employee_code'].toString() : e['name']?.toString() ?? '');
    
    if (empId.isEmpty) return 'Missing employee id.';

    final expenseId = 'SAL-$empId-$year$month';
    // Ensure expenses are loaded
    if (_expenses.isEmpty) await loadExpenses();
    
    final exists = _expenses.any((x) => (x['id']?.toString() ?? '') == expenseId);
    if (exists) return 'Salary already recorded this month.';

    double net = (e['net_salary'] as num?)?.toDouble() ?? 0.0;
    if (net <= 0) {
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
      net = (gross - totalDed).clamp(0.0, double.infinity);
      if (net <= 0) return 'Net salary is zero.';
    }

    final entry = {
      'id': expenseId,
      'amount': net,
      'category': 'Staff Salaries & Wages',
      'note': 'Salary for ${e['name']?.toString() ?? ''} - $year-$month',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    await Repository.instance.expenses.insertExpense(entry);
    await loadExpenses();
    return 'Salary recorded.';
  }
}
