import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/employee_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/page_scaffold.dart';

class EmployeeScreen extends StatelessWidget {
  const EmployeeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isMobile = width < 768;
      final isTablet = width >= 768 && width < 1024;
      final isLaptop = width >= 1024 && width < 1440;
      final cols = isMobile ? 1 : isTablet ? 2 : isLaptop ? 3 : 4;
      final scale = width < 360 ? 0.85 : width > 1728 ? 1.2 : (width / 1024).clamp(0.85, 1.2);
      final provider = context.watch<EmployeeProvider>();
      final employees = provider.employees;

      final maxContentWidth = isLaptop || !isDesktop(width) ? width : 1280.0;
      final horizontalPadding = 16.0 * scale;
      final gutter = 12.0 * scale;
      final usableWidth = (maxContentWidth - (horizontalPadding * 2));
      final cardWidth = cols == 1 ? usableWidth : ((usableWidth - gutter * (cols - 1)) / cols).floorToDouble();

      return PageScaffold(
        title: 'Employees',
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showAddEmployeeDialog(context, scale),
            icon: Icon(Icons.add, size: 16 * scale),
            label: Text('Add Employee', style: TextStyle(fontSize: 12 * scale)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 10 * scale),
              minimumSize: Size(isMobile ? 44 * scale : 0, 44 * scale),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                children: [
                  SizedBox(height: 12 * scale),
                  Wrap(
                    spacing: gutter,
                    runSpacing: gutter,
                    children: employees.map((e) => SizedBox(width: cardWidth, child: _EmployeeCard(emp: e, scale: scale))).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
  bool isDesktop(double width) => width >= 1440;
}

class _EmployeeCard extends StatefulWidget {
  final Map<String, dynamic> emp;
  final double scale;
  const _EmployeeCard({required this.emp, required this.scale});
  @override
  State<_EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<_EmployeeCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final e = widget.emp;
    final name = e['name']?.toString() ?? '';
    final role = e['role']?.toString() ?? '';
    final code = e['employee_code']?.toString() ?? '';
    final net = (e['net_salary'] as num?)?.toDouble() ?? 0.0;
    final photo = e['photo']?.toString() ?? '';
    final color = const Color(0xFFF59E0B);
    final scale = widget.scale;

    Widget avatar;
    if (photo.startsWith('data:image/')) {
      try {
        final baseStr = photo.split(',').last;
        final bytes = base64Decode(baseStr);
        avatar = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(Uint8List.fromList(bytes), width: 56 * scale, height: 56 * scale, fit: BoxFit.cover),
        );
      } catch (_) {
        avatar = _fallbackAvatar(scale);
      }
    } else {
      avatar = _fallbackAvatar(scale);
    }

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      transform: Matrix4.identity()..scaleByDouble(_hover ? 1.02 : 1.0),
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hover ? color : const Color(0xFF27272A)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _hover ? 0.6 : 0.4), blurRadius: _hover ? 10 : 6)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              avatar,
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2 * scale),
                  Text('$role • $code', style: TextStyle(color: const Color(0xFFA1A1AA), fontSize: 11 * scale)),
                ]),
              ),
              Text('₹${net.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 16 * scale, fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 10 * scale),
          Builder(builder: (context) {
            final provider = context.watch<ExpenseProvider>();
            final now = DateTime.now();
            final year = now.year;
            final month = now.month;
            final lastDayThisMonth = DateTime(year, month + 1, 0).day;
            final employment = Map<String, dynamic>.from(e['employment'] as Map? ?? {});
            final payment = Map<String, dynamic>.from(e['payment'] as Map? ?? {});
            final sched = Map<String, dynamic>.from(employment['salary_schedule'] as Map? ?? {});
            final salaryType = (employment['salary_type']?.toString() ?? '').toLowerCase();
            final payDayStr = sched['pay_day']?.toString().trim().isNotEmpty == true ? sched['pay_day'].toString().trim() : (payment['payment_day']?.toString().trim() ?? '');
            final payDayParsed = int.tryParse(payDayStr.isEmpty ? '30' : payDayStr) ?? 30;
            final targetDayThis = payDayParsed > lastDayThisMonth ? lastDayThisMonth : payDayParsed;
            final thisMonthPay = DateTime(year, month, targetDayThis);
            final lastDayNextMonth = DateTime(year, month + 2, 0).day;
            final targetDayNext = payDayParsed > lastDayNextMonth ? lastDayNextMonth : payDayParsed;
            final nextPay = now.isBefore(thisMonthPay) ? thisMonthPay : DateTime(year, month + 1, targetDayNext);
            final y = nextPay.year.toString();
            final m = nextPay.month.toString().padLeft(2, '0');
            final d = nextPay.day.toString().padLeft(2, '0');
            final startOfMonthMs = DateTime(year, month, 1).millisecondsSinceEpoch;
            final startNextMonthMs = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
            final nameStr = e['name']?.toString() ?? '';
            final recorded = provider.expenses.any((x) {
              final ts = (x['timestamp'] as int?) ?? 0;
              if (ts < startOfMonthMs || ts >= startNextMonthMs) return false;
              if ((x['category']?.toString() ?? '') != 'Staff Salaries & Wages') return false;
              final note = (x['note']?.toString() ?? '');
              return note.contains(nameStr);
            });
            final pillColor = recorded ? const Color(0xFF10B981) : const Color(0xFFFF9500);
            final pillText = recorded ? 'This Month Paid' : 'This Month Pending';
            return Row(
              children: [
                Icon(Icons.event, color: Colors.white, size: 16 * scale),
                SizedBox(width: 6 * scale),
                Expanded(child: Text('Next Pay: $y-$m-$d${salaryType == 'monthly' ? '' : ' • $salaryType'}', style: TextStyle(color: const Color(0xFFA1A1AA), fontSize: 11 * scale))),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
                  decoration: BoxDecoration(color: pillColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: pillColor)),
                  child: Text(pillText, style: TextStyle(color: pillColor, fontSize: 11 * scale, fontWeight: FontWeight.w600)),
                ),
              ],
            );
          }),
          SizedBox(height: 10 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionButton(label: 'View', icon: Icons.visibility_outlined, scale: scale, onTap: () => _showViewEmployee(context, e, scale)),
              SizedBox(width: 8 * scale),
              _ActionButton(label: 'Edit', icon: Icons.edit_outlined, scale: scale, onTap: () => _showAddEmployeeDialog(context, scale, existing: e)),
              SizedBox(width: 8 * scale),
              _ActionButton(label: 'Pay', icon: Icons.payments_outlined, scale: scale, onTap: () async {
                final res = await context.read<ExpenseProvider>().recordEmployeeSalary(e);
                if (context.mounted) {
                  context.read<RestaurantProvider>().showToast(res, icon: res.contains('recorded') ? '✅' : '⚠️');
                }
              }),
            ],
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hover = true),
        onTapCancel: () => setState(() => _hover = false),
        onTap: () => _showViewEmployee(context, e, scale),
        child: card,
      ),
    );
  }

  Widget _fallbackAvatar(double scale) {
    return Container(
      width: 56 * scale,
      height: 56 * scale,
      decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Icon(Icons.person, color: Colors.white, size: 24 * scale),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final double scale;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.scale, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
        decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF3F3F46))),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 16 * scale),
          SizedBox(width: 6 * scale),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 12 * scale, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

Future<void> _showViewEmployee(BuildContext context, Map<String, dynamic> e, double scale) async {
    final net = (e['net_salary'] as num?)?.toDouble() ?? 0.0;
    await showDialog(context: context, builder: (_) {
      return AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: Text('Employee Details', style: TextStyle(color: Colors.white, fontSize: 16 * scale, letterSpacing: 0.5)),
        content: SizedBox(
          width: 540 * scale,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e['name']?.toString() ?? '', style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.w700)),
              SizedBox(height: 6 * scale),
              Text('${e['role'] ?? ''} • ${e['employee_code'] ?? ''}', style: TextStyle(color: const Color(0xFFA1A1AA), fontSize: 12 * scale)),
              SizedBox(height: 12 * scale),
              Text('Take-home: ₹${net.toStringAsFixed(2)}', style: TextStyle(color: const Color(0xFFF59E0B), fontSize: 16 * scale, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      );
    });
}

Future<void> _showAddEmployeeDialog(BuildContext context, double scale, {Map<String, dynamic>? existing}) async {
  final provider = context.read<EmployeeProvider>();
  final rp = context.read<RestaurantProvider>();
  final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
  final codeCtrl = TextEditingController(text: existing?['employee_code']?.toString() ?? '');
  final roleCtrl = ValueNotifier<String>(existing?['role']?.toString() ?? 'Staff');
  final statusCtrl = ValueNotifier<String>(existing?['status']?.toString() ?? 'Active');
  final paymentMethodCtrl = ValueNotifier<String>((existing?['payment']?['method']?.toString()) ?? 'Cash');
  final salaryTypeCtrl = ValueNotifier<String>((existing?['employment']?['salary_type']?.toString()) ?? 'Monthly');
  final dobCtrl = TextEditingController(text: existing?['personal']?['dob']?.toString() ?? '');
  final phoneCtrl = TextEditingController(text: existing?['personal']?['phone']?.toString() ?? '');
  final emailCtrl = TextEditingController(text: existing?['personal']?['email']?.toString() ?? '');
  final addressCtrl = TextEditingController(text: existing?['personal']?['address']?.toString() ?? '');
  final emergencyCtrl = TextEditingController(text: existing?['personal']?['emergency']?.toString() ?? '');
  final joinDateCtrl = TextEditingController(text: existing?['employment']?['joining_date']?.toString() ?? '');
  final probationCtrl = TextEditingController(text: existing?['employment']?['probation']?.toString() ?? '');
  final contractEndCtrl = TextEditingController(text: existing?['employment']?['contract_end']?.toString() ?? '');
  final bankAccCtrl = TextEditingController(text: existing?['payment']?['account_no']?.toString() ?? '');
  final bankIfscCtrl = TextEditingController(text: existing?['payment']?['ifsc']?.toString() ?? '');
  final bankNameCtrl = TextEditingController(text: existing?['payment']?['bank_name']?.toString() ?? '');
  final holderCtrl = TextEditingController(text: existing?['payment']?['holder_name']?.toString() ?? '');
  final paymentDayCtrl = TextEditingController(text: existing?['payment']?['payment_day']?.toString() ?? '');
  final docsState = ValueNotifier<Map<String, Map<String, dynamic>>>(Map<String, Map<String, dynamic>>.from(existing?['documents'] as Map? ?? {}));

  final salaryFields = {
    'basic': TextEditingController(text: _numStr(existing?['salary']?['basic'])),
    'hra': TextEditingController(text: _numStr(existing?['salary']?['hra'])),
    'transport': TextEditingController(text: _numStr(existing?['salary']?['transport'])),
    'meal': TextEditingController(text: _numStr(existing?['salary']?['meal'])),
    'special': TextEditingController(text: _numStr(existing?['salary']?['special'])),
    'bonus': TextEditingController(text: _numStr(existing?['salary']?['bonus'])),
  };
  final dedFields = {
    'pf': TextEditingController(text: _numStr(existing?['deductions']?['pf'])),
    'esi': TextEditingController(text: _numStr(existing?['deductions']?['esi'])),
    'ptax': TextEditingController(text: _numStr(existing?['deductions']?['ptax'])),
    'tds': TextEditingController(text: _numStr(existing?['deductions']?['tds'])),
    'loan': TextEditingController(text: _numStr(existing?['deductions']?['loan'])),
    'other': TextEditingController(text: _numStr(existing?['deductions']?['other'])),
  };
  double gross = _sumCtrls(salaryFields.values);
  double net = gross - _sumCtrls(dedFields.values);

  await showDialog(context: context, builder: (_) {
    return StatefulBuilder(builder: (context, setLocal) {
      void recompute() {
        gross = _sumCtrls(salaryFields.values);
        net = gross - _sumCtrls(dedFields.values);
        setLocal(() {});
      }
      for (final c in [...salaryFields.values, ...dedFields.values]) {
        c.addListener(recompute);
      }
      return AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: Text('Add Employee', style: TextStyle(color: Colors.white, fontSize: 16 * scale, letterSpacing: 0.5)),
        content: SizedBox(
          width: 720 * scale,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Section(title: 'Personal Information', scale: scale, child: Column(children: [
                  Row(children: [
                    Expanded(child: _LabeledField(label: 'Full Name', ctrl: nameCtrl, required: true, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _LabeledField(label: 'Employee ID', ctrl: codeCtrl, scale: scale, hint: 'Auto/Manual')),
                  ]),
                  SizedBox(height: 8 * scale),
                  Row(children: [
                    Expanded(child: _DropdownField(label: 'Role/Designation', valueList: const ['Staff','Chef','Server','Manager','Cashier'], value: roleCtrl, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _DateField(label: 'Date of Birth', ctrl: dobCtrl, scale: scale)),
                  ]),
                  SizedBox(height: 8 * scale),
                  Row(children: [
                    Expanded(child: _LabeledField(label: 'Contact Number', ctrl: phoneCtrl, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _LabeledField(label: 'Email', ctrl: emailCtrl, scale: scale)),
                  ]),
                  SizedBox(height: 8 * scale),
                  _LabeledField(label: 'Current Address', ctrl: addressCtrl, scale: scale, multiline: true),
                  SizedBox(height: 8 * scale),
                  _LabeledField(label: 'Emergency Contact', ctrl: emergencyCtrl, scale: scale),
                ])),
                SizedBox(height: 12 * scale),
                _Section(title: 'Salary Information', scale: scale, child: Column(children: [
                  Row(children: [
                    Expanded(child: _AmountField(label: 'Basic', ctrl: salaryFields['basic']!, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _AmountField(label: 'HRA', ctrl: salaryFields['hra']!, scale: scale)),
                  ]),
                  SizedBox(height: 8 * scale),
                  Row(children: [
                    Expanded(child: _AmountField(label: 'Transport', ctrl: salaryFields['transport']!, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _AmountField(label: 'Meal', ctrl: salaryFields['meal']!, scale: scale)),
                  ]),
                  SizedBox(height: 8 * scale),
                  Row(children: [
                    Expanded(child: _AmountField(label: 'Special Allowance', ctrl: salaryFields['special']!, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _AmountField(label: 'Performance Bonus', ctrl: salaryFields['bonus']!, scale: scale)),
                  ]),
                  SizedBox(height: 8 * scale),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Gross: ₹${gross.toStringAsFixed(2)}', style: TextStyle(color: const Color(0xFF10B981), fontSize: 14 * scale, fontWeight: FontWeight.bold)),
                  ),
                ])),
                SizedBox(height: 12 * scale),
                _Section(title: 'Deductions', scale: scale, child: Column(children: [
                  Row(children: [
                    Expanded(child: _AmountField(label: 'PF', ctrl: dedFields['pf']!, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _AmountField(label: 'ESI', ctrl: dedFields['esi']!, scale: scale)),
                  ]),
                  SizedBox(height: 8 * scale),
                  Row(children: [
                    Expanded(child: _AmountField(label: 'Professional Tax', ctrl: dedFields['ptax']!, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _AmountField(label: 'TDS', ctrl: dedFields['tds']!, scale: scale)),
                  ]),
                  SizedBox(height: 8 * scale),
                  Row(children: [
                    Expanded(child: _AmountField(label: 'Loan/Advance', ctrl: dedFields['loan']!, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _AmountField(label: 'Other deductions', ctrl: dedFields['other']!, scale: scale)),
                  ]),
                  SizedBox(height: 8 * scale),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Take-home salary per month: ₹${net.toStringAsFixed(2)}', style: TextStyle(color: const Color(0xFFF59E0B), fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                  ),
                ])),
                SizedBox(height: 12 * scale),
                _Section(title: 'Salary Type', scale: scale, child: Row(children: [
                  _RadioChip(value: 'Monthly', group: salaryTypeCtrl, scale: scale),
                  SizedBox(width: 8 * scale),
                  _RadioChip(value: 'Daily Wage', group: salaryTypeCtrl, scale: scale),
                  SizedBox(width: 8 * scale),
                  _RadioChip(value: 'Hourly', group: salaryTypeCtrl, scale: scale),
                ])),
                SizedBox(height: 12 * scale),
                _Section(title: 'Payment Details', scale: scale, child: Column(children: [
                  Row(children: [
                    Expanded(child: _DropdownField(label: 'Method', valueList: const ['Cash','Bank','UPI','Cheque'], value: paymentMethodCtrl, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _LabeledField(label: 'Payment Day', ctrl: paymentDayCtrl, scale: scale, hint: 'e.g., 30')),
                  ]),
                  SizedBox(height: 8 * scale),
                  Row(children: [
                    Expanded(child: _LabeledField(label: 'Account No', ctrl: bankAccCtrl, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _LabeledField(label: 'IFSC', ctrl: bankIfscCtrl, scale: scale)),
                  ]),
                  SizedBox(height: 8 * scale),
                  Row(children: [
                    Expanded(child: _LabeledField(label: 'Bank Name', ctrl: bankNameCtrl, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _LabeledField(label: 'Holder Name', ctrl: holderCtrl, scale: scale)),
                  ]),
                ])),
                SizedBox(height: 12 * scale),
                _Section(title: 'Employment Details', scale: scale, child: Column(children: [
                  Row(children: [
                    Expanded(child: _DateField(label: 'Joining Date', ctrl: joinDateCtrl, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _LabeledField(label: 'Probation Period', ctrl: probationCtrl, scale: scale, hint: 'in months')),
                  ]),
                  SizedBox(height: 8 * scale),
                  Row(children: [
                    Expanded(child: _DateField(label: 'Contract End Date', ctrl: contractEndCtrl, scale: scale)),
                    SizedBox(width: 8 * scale),
                    Expanded(child: _DropdownField(label: 'Status', valueList: const ['Active','On Leave','Resigned'], value: statusCtrl, scale: scale)),
                  ]),
                ])),
                SizedBox(height: 12 * scale),
                _Section(title: 'Documents Upload', scale: scale, child: ValueListenableBuilder<Map<String, Map<String, dynamic>>>(
                  valueListenable: docsState,
                  builder: (_, docs, __) {
                    return Wrap(
                      spacing: 8 * scale,
                      runSpacing: 8 * scale,
                      children: ['Aadhar','PAN','Bank Passbook','Certificates','Photo ID'].map((d) {
                        final selected = docs[d] != null;
                        return _DocChip(
                          label: d,
                          scale: scale,
                          selected: selected,
                          onPicked: (m) {
                            final next = Map<String, Map<String, dynamic>>.from(docsState.value);
                            if (m == null) {
                              next.remove(d);
                            } else {
                              next[d] = m;
                            }
                            docsState.value = next;
                          },
                        );
                      }).toList(),
                    );
                  },
                )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = _collectEmployeeData(
                existingId: existing?['id']?.toString(),
                name: nameCtrl.text.trim(),
                code: codeCtrl.text.trim(),
                role: roleCtrl.value,
                status: statusCtrl.value,
                salaryType: salaryTypeCtrl.value,
                personal: {
                  'dob': dobCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'emergency': emergencyCtrl.text.trim(),
                },
                salary: {
                  'basic': _toNum(salaryFields['basic']!.text),
                  'hra': _toNum(salaryFields['hra']!.text),
                  'transport': _toNum(salaryFields['transport']!.text),
                  'meal': _toNum(salaryFields['meal']!.text),
                  'special': _toNum(salaryFields['special']!.text),
                  'bonus': _toNum(salaryFields['bonus']!.text),
                },
                deductions: {
                  'pf': _toNum(dedFields['pf']!.text),
                  'esi': _toNum(dedFields['esi']!.text),
                  'ptax': _toNum(dedFields['ptax']!.text),
                  'tds': _toNum(dedFields['tds']!.text),
                  'loan': _toNum(dedFields['loan']!.text),
                  'other': _toNum(dedFields['other']!.text),
                },
                payment: {
                  'method': paymentMethodCtrl.value,
                  'payment_day': paymentDayCtrl.text.trim(),
                  'account_no': bankAccCtrl.text.trim(),
                  'ifsc': bankIfscCtrl.text.trim(),
                  'bank_name': bankNameCtrl.text.trim(),
                  'holder_name': holderCtrl.text.trim(),
                },
                employment: {
                  'joining_date': joinDateCtrl.text.trim(),
                  'probation': probationCtrl.text.trim(),
                  'contract_end': contractEndCtrl.text.trim(),
                  'salary_type': salaryTypeCtrl.value,
                },
                documents: docsState.value,
              );
              if (data['name'].isEmpty) return;
              provider.addEmployee(data);
              final nav = Navigator.of(context);
              await _showSalaryScheduleDialog(context, scale, data['id']?.toString() ?? '');
              nav.pop();
            },
            child: const Text('Save & Add Salary Schedule'),
          ),
          ElevatedButton(
            onPressed: () {
              final data = _collectEmployeeData(
                existingId: existing?['id']?.toString(),
                name: nameCtrl.text.trim(),
                code: codeCtrl.text.trim(),
                role: roleCtrl.value,
                status: statusCtrl.value,
                salaryType: salaryTypeCtrl.value,
                personal: {
                  'dob': dobCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'emergency': emergencyCtrl.text.trim(),
                },
                salary: {
                  'basic': _toNum(salaryFields['basic']!.text),
                  'hra': _toNum(salaryFields['hra']!.text),
                  'transport': _toNum(salaryFields['transport']!.text),
                  'meal': _toNum(salaryFields['meal']!.text),
                  'special': _toNum(salaryFields['special']!.text),
                  'bonus': _toNum(salaryFields['bonus']!.text),
                },
                deductions: {
                  'pf': _toNum(dedFields['pf']!.text),
                  'esi': _toNum(dedFields['esi']!.text),
                  'ptax': _toNum(dedFields['ptax']!.text),
                  'tds': _toNum(dedFields['tds']!.text),
                  'loan': _toNum(dedFields['loan']!.text),
                  'other': _toNum(dedFields['other']!.text),
                },
                payment: {
                  'method': paymentMethodCtrl.value,
                  'payment_day': paymentDayCtrl.text.trim(),
                  'account_no': bankAccCtrl.text.trim(),
                  'ifsc': bankIfscCtrl.text.trim(),
                  'bank_name': bankNameCtrl.text.trim(),
                  'holder_name': holderCtrl.text.trim(),
                },
                employment: {
                  'joining_date': joinDateCtrl.text.trim(),
                  'probation': probationCtrl.text.trim(),
                  'contract_end': contractEndCtrl.text.trim(),
                  'salary_type': salaryTypeCtrl.value,
                },
                documents: docsState.value,
              );
              if (data['name'].isEmpty) return;
              provider.addEmployee(data);
              Navigator.of(context).pop();
              rp.showToast('Save & Close', icon: '✅');
            },
            child: const Text('Save & Close'),
          ),
        ],
      );
    });
  });
}

String _numStr(dynamic v) {
  if (v == null) return '';
  final n = (v as num?)?.toDouble();
  return n == null ? '' : n.toStringAsFixed(2);
}
double _sumCtrls(Iterable<TextEditingController> ctrls) {
  double sum = 0.0;
  for (final c in ctrls) {
    sum += _toNum(c.text);
  }
  return sum;
}
double _toNum(String s) {
  final v = double.tryParse(s.trim());
  return v ?? 0.0;
}
Map<String, dynamic> _collectEmployeeData({
  String? existingId,
  required String name,
  required String code,
  required String role,
  required String status,
  required String salaryType,
  required Map<String, dynamic> personal,
  required Map<String, dynamic> salary,
  required Map<String, dynamic> deductions,
  required Map<String, dynamic> payment,
  required Map<String, dynamic> employment,
  required Map<String, dynamic> documents,
}) {
  return {
    'id': existingId ?? 'EMP${DateTime.now().millisecondsSinceEpoch}',
    'name': name,
    'employee_code': code,
    'role': role,
    'status': status,
    'personal': personal,
    'salary': salary,
    'deductions': deductions,
    'payment': payment,
    'employment': employment,
    'documents': documents,
  };
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final double scale;
  const _Section({required this.title, required this.child, required this.scale});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: Colors.white, fontSize: 14 * scale, fontWeight: FontWeight.w700)),
        SizedBox(height: 8 * scale),
        child,
      ]),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final double scale;
  final bool required;
  final bool multiline;
  final String? hint;
  const _LabeledField({required this.label, required this.ctrl, required this.scale, this.required = false, this.multiline = false, this.hint});
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3F3F46)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white, fontSize: 12 * scale)),
      SizedBox(height: 4 * scale),
      TextField(
        controller: ctrl,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 5 : 1,
        style: TextStyle(color: Colors.white, fontSize: 12 * scale),
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFF0B0B0E),
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: const BorderSide(color: Color(0xFFF59E0B))),
          errorText: required && ctrl.text.trim().isEmpty ? 'Required' : null,
        ),
        onChanged: (_) {},
      ),
    ]);
  }
}

class _AmountField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final double scale;
  const _AmountField({required this.label, required this.ctrl, required this.scale});
  @override
  Widget build(BuildContext context) {
    return _LabeledField(label: label, ctrl: ctrl, scale: scale, hint: '0.00');
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final double scale;
  const _DateField({required this.label, required this.ctrl, required this.scale});
  @override
  Widget build(BuildContext context) {
    return _LabeledField(label: label, ctrl: ctrl, scale: scale, hint: 'YYYY-MM-DD');
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final List<String> valueList;
  final ValueNotifier<String> value;
  final double scale;
  const _DropdownField({required this.label, required this.valueList, required this.value, required this.scale});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white, fontSize: 12 * scale)),
      SizedBox(height: 4 * scale),
      DropdownButtonHideUnderline(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
          child: ValueListenableBuilder<String>(
            valueListenable: value,
            builder: (_, v, __) {
              return DropdownButton<String>(
                value: v,
                dropdownColor: const Color(0xFF18181B),
                items: valueList.map((x) => DropdownMenuItem(value: x, child: Text(x, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (nv) {
                  if (nv != null) value.value = nv;
                },
              );
            },
          ),
        ),
      ),
    ]);
  }
}

class _RadioChip extends StatelessWidget {
  final String value;
  final ValueNotifier<String> group;
  final double scale;
  const _RadioChip({required this.value, required this.group, required this.scale});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: group,
      builder: (_, v, __) {
        final active = v == value;
        return InkWell(
          onTap: () => group.value = value,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFF59E0B) : const Color(0xFF27272A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: active ? const Color(0xFFF59E0B) : const Color(0xFF3F3F46)),
            ),
            child: Text(value, style: TextStyle(color: Colors.white, fontSize: 12 * scale, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}

class _DocChip extends StatelessWidget {
  final String label;
  final double scale;
  final bool selected;
  final void Function(Map<String, dynamic>?) onPicked;
  const _DocChip({required this.label, required this.scale, this.selected = false, required this.onPicked});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final provider = context.read<RestaurantProvider>();
        final m = await _promptDocumentInput(context, label, scale);
        onPicked(m);
        if (m != null) {
          provider.showToast('$label added.', icon: '📎');
        } else {
          provider.showToast('$label removed.', icon: '🗑️');
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 8 * scale),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1F2937) : const Color(0xFF27272A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFFF59E0B) : const Color(0xFF3F3F46)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.upload_file, color: Colors.white, size: 16),
          SizedBox(width: 6 * scale),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 12 * scale)),
        ]),
      ),
    );
  }
}

Future<Map<String, dynamic>?> _promptDocumentInput(BuildContext context, String label, double scale, {Map<String, dynamic>? initial}) async {
  final numberCtrl = TextEditingController(text: initial?['number']?.toString() ?? '');
  final linkCtrl = TextEditingController(text: initial?['link']?.toString() ?? '');
  bool present = initial?['present'] == true;
  return await showDialog<Map<String, dynamic>?>(context: context, builder: (_) {
    return AlertDialog(
      backgroundColor: const Color(0xFF18181B),
      title: Text(label, style: TextStyle(color: Colors.white, fontSize: 16 * scale, letterSpacing: 0.5)),
      content: SizedBox(
        width: 480 * scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Checkbox(
                  value: present,
                  onChanged: (v) {
                    present = v ?? false;
                  },
                ),
                Text('Present', style: TextStyle(color: Colors.white, fontSize: 12 * scale)),
              ],
            ),
            _LabeledField(label: 'Number/ID', ctrl: numberCtrl, scale: scale),
            SizedBox(height: 8 * scale),
            _LabeledField(label: 'Link/URL', ctrl: linkCtrl, scale: scale, hint: 'https://'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Remove')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final m = {
              'present': present,
              'number': numberCtrl.text.trim(),
              'link': linkCtrl.text.trim(),
            };
            Navigator.of(context).pop(m);
          },
          child: const Text('Save'),
        ),
      ],
    );
  });
}

Future<void> _showSalaryScheduleDialog(BuildContext context, double scale, String employeeId) async {
  final provider = context.read<EmployeeProvider>();
  final cycle = ValueNotifier<String>('Monthly');
  final payDayCtrl = TextEditingController();
  final startCtrl = TextEditingController();
  await showDialog(context: context, builder: (_) {
    return AlertDialog(
      backgroundColor: const Color(0xFF18181B),
      title: Text('Salary Schedule', style: TextStyle(color: Colors.white, fontSize: 16 * scale, letterSpacing: 0.5)),
      content: SizedBox(
        width: 520 * scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DropdownField(label: 'Cycle', valueList: const ['Monthly','Weekly'], value: cycle, scale: scale),
            SizedBox(height: 8 * scale),
            _LabeledField(label: 'Pay Day', ctrl: payDayCtrl, scale: scale, hint: 'e.g., 30 or Mon'),
            SizedBox(height: 8 * scale),
            _DateField(label: 'Start Date', ctrl: startCtrl, scale: scale),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final emp = provider.employees.firstWhere((e) => e['id']?.toString() == employeeId, orElse: () => {});
            if (emp.isNotEmpty) {
              final updated = Map<String, dynamic>.from(emp);
              final employment = Map<String, dynamic>.from(updated['employment'] as Map? ?? {});
              employment['salary_schedule'] = {
                'cycle': cycle.value,
                'pay_day': payDayCtrl.text.trim(),
                'start_date': startCtrl.text.trim(),
              };
              updated['employment'] = employment;
              provider.updateEmployee(updated);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  });
}
