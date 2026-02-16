import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repository.dart';
import '../data/sync_service.dart';
import '../utils/auth_helper.dart';

class RoleManagementScreen extends StatefulWidget {
  final bool embed;
  const RoleManagementScreen({super.key, this.embed = false});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = false;
  StreamSubscription? _sub;
  // Add form state
  String? _selectedEmployeeId;
  String? _selectedAddRole;
  final TextEditingController _addPinController = TextEditingController();
  String? _addPinError;
  bool _addPinObscure = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _sub = Repository.instance.onDataChanged.listen((_) {
      if (mounted && !_loading) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_loading) return;
    setState(() => _loading = true);
    
    try {
      // Ensure we have all default roles and they are synced from Firebase
      await AuthHelper.refreshRoles();
      
      final roles = await Repository.instance.roles.listRoles();
      // Enforce lowercase names for roles
      for (var r in roles) {
        if (r['name'] != null) r['name'] = r['name'].toString().toLowerCase();
      }

      final employees = await Repository.instance.employees.listEmployees();
      
      if (mounted) {
        setState(() {
          _roles = roles;
          _employees = employees;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateEmployeeRoleAndPin(Map<String, dynamic> employee, String? newRole, String? newPin) async {
    final updatedEmp = Map<String, dynamic>.from(employee);
    if (newRole != null) updatedEmp['role'] = newRole;
    if (newPin != null) updatedEmp['pin'] = newPin;
    updatedEmp['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    await Repository.instance.employees.upsertEmployee(updatedEmp);
    await SyncService.instance.logAuditEvent('employee_security_update', {
      'employee': employee['name'],
      'role_changed': newRole != null,
      'pin_changed': newPin != null,
    });
    _loadData();
  }
  
  bool _pinInUse(String pin, {String? exceptId}) {
    final p = pin.trim();
    if (p.isEmpty) return false;
    return _employees.any((e) => (e['pin']?.toString() ?? '') == p && (exceptId == null || e['id'] != exceptId));
  }
  bool _hasAdminAssigned({String? exceptId}) {
    return _employees.any((e) {
      final isAdmin = (e['role']?.toString().toLowerCase() ?? '') == 'admin';
      if (!isAdmin) return false;
      if (exceptId != null && e['id'] == exceptId) return false;
      return true;
    });
  }
  String _maskPin(String pin) => pin.isEmpty ? '' : '•' * pin.length;
  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return const Color(0xFFEF4444);
      case 'manager': return const Color(0xFF3B82F6);
      case 'chef': return const Color(0xFF10B981);
      case 'waiter': return const Color(0xFFF59E0B);
      default: return const Color(0xFF6B7280);
    }
  }
  Future<void> _showAccessList() async {
    final emps = await Repository.instance.employees.listEmployees();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        bool masked = true;
        return StatefulBuilder(
          builder: (ctx2, setState2) {
            final rows = emps.map((e) {
              final id = e['id']?.toString() ?? '';
              final name = e['name']?.toString() ?? '';
              final role = e['role']?.toString() ?? '';
              final pin = e['pin']?.toString() ?? '';
              return {'id': id, 'name': name, 'role': role, 'pin': pin};
            }).toList();
            final csv = StringBuffer('id,name,role,pin\n');
            for (final r in rows) {
              csv.writeln('${r['id']},${r['name']},${r['role']},${r['pin']}');
            }
            return AlertDialog(
              backgroundColor: const Color(0xFF1F2937),
              title: const Text('Employee Access List', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: MediaQuery.of(ctx).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text('Show PINs', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 8),
                        Switch(
                          value: !masked,
                          onChanged: (v) => setState2(() => masked = !v),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: csv.toString()));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied CSV to clipboard')));
                            }
                          },
                          icon: const Icon(Icons.copy, color: Colors.white70, size: 16),
                          label: const Text('Copy CSV', style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0xFF374151)),
                        itemBuilder: (_, i) {
                          final r = rows[i];
                          final roleColor = _roleColor(r['role'] ?? '');
                          return Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text('${r['name']} (${r['id']})', style: const TextStyle(color: Colors.white)),
                              ),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                  child: Text((r['role']?.toString() ?? '').toUpperCase(), style: TextStyle(color: roleColor, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Tooltip(
                                    message: r['pin'] ?? '',
                                    child: Text(masked ? _maskPin(r['pin'] ?? '') : (r['pin'] ?? ''), style: const TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }
  Future<void> _addToRoster() async {
    final id = _selectedEmployeeId;
    final role = (_selectedAddRole ?? '').trim().toLowerCase();
    final pin = _addPinController.text.trim();
    setState(() => _addPinError = null);
    if (id == null || id.isEmpty) {
      setState(() => _addPinError = 'Select an employee');
      return;
    }
    if (pin.length < 4) {
      setState(() => _addPinError = 'PIN must be at least 4 digits');
      return;
    }
    if (_pinInUse(pin, exceptId: id)) {
      setState(() => _addPinError = 'PIN already in use');
      return;
    }
    if (role == 'admin' && _hasAdminAssigned(exceptId: id)) {
      setState(() => _addPinError = 'Only one admin allowed');
      return;
    }
    final emp = _employees.firstWhere((e) => e['id'] == id, orElse: () => {});
    if (emp.isEmpty) {
      setState(() => _addPinError = 'Employee not found');
      return;
    }
    await _updateEmployeeRoleAndPin(emp, role.isEmpty ? null : role, pin);
    if (mounted) {
      setState(() {
        _selectedEmployeeId = null;
        _selectedAddRole = null;
        _addPinController.clear();
        _addPinError = null;
      });
    }
  }

  Future<void> _updatePermission(Map<String, dynamic> role, String type, String value, bool enabled) async {
    final permissions = Map<String, dynamic>.from(role['permissions'] ?? {});
    final list = List<String>.from(permissions[type] ?? []);
    
    if (enabled) {
      if (!list.contains(value)) list.add(value);
    } else {
      list.remove(value);
    }
    
    permissions[type] = list;
    final updatedRole = Map<String, dynamic>.from(role);
    updatedRole['permissions'] = permissions;
    updatedRole['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    await Repository.instance.roles.upsertRole(updatedRole);
    await SyncService.instance.logAuditEvent('role_permission_update', {
      'role': role['name'],
      'type': type,
      'value': value,
      'enabled': enabled
    });
    
    await AuthHelper.refreshRoles();
    _loadData();
  }

  Future<void> _updatePin(Map<String, dynamic> role, String newPin) async {
    if (newPin.isEmpty) return;
    final updatedRole = Map<String, dynamic>.from(role);
    updatedRole['pin'] = newPin;
    updatedRole['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    await Repository.instance.roles.upsertRole(updatedRole);
    await SyncService.instance.logAuditEvent('role_pin_update', {
      'role': role['name'],
    });
    
    await AuthHelper.refreshRoles();
    _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PIN updated for ${role['name']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = (Repository.instance.clientMeta?['role']?.toString() ?? '').toLowerCase();
    final roleDescriptions = {
      'admin': 'Full access. Locked role.',
      'manager': 'Approve bookings, reports, manage staff.',
      'chef': 'Kitchen view and inventory.',
      'waiter': 'Take orders and view tables.',
    };
    final content = _loading 
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _showAccessList,
                  icon: const Icon(Icons.list_alt, color: Colors.white70),
                  label: const Text('Access List', style: TextStyle(color: Colors.white70)),
                ),
              ),
              Card(
                color: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Employee', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final selected = await showModalBottomSheet<String>(
                            context: context,
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (ctx) {
                              final controller = TextEditingController();
                              List<Map<String, dynamic>> filtered = List.from(_employees);
                              return StatefulBuilder(
                                builder: (c, setState2) => Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: controller,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          hintText: 'Search employee',
                                          hintStyle: const TextStyle(color: Colors.grey),
                                          filled: true,
                                          fillColor: const Color(0xFF111827),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                        ),
                                        onChanged: (q) {
                                          final s = q.toLowerCase();
                                          filtered = _employees.where((e) {
                                            final n = (e['name']?.toString() ?? '').toLowerCase();
                                            final code = (e['employee_code']?.toString() ?? '').toLowerCase();
                                            return n.contains(s) || code.contains(s);
                                          }).toList();
                                          setState2((){});
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      Flexible(
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: filtered.length,
                                          itemBuilder: (ctx, i) {
                                            final e = filtered[i];
                                            return ListTile(
                                              title: Text(e['name']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                                              subtitle: Text('Code: ${e['employee_code'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                                              onTap: () => Navigator.pop(ctx, e['id'] as String),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          );
                          if (selected != null) {
                            setState(() {
                              _selectedEmployeeId = selected;
                              final emp = _employees.firstWhere((e) => e['id'] == selected, orElse: () => {});
                              _selectedAddRole = emp['role']?.toString().toLowerCase();
                              _addPinController.text = emp['pin']?.toString() ?? '';
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.search, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedEmployeeId == null
                                    ? 'Select employee'
                                    : '${_employees.firstWhere((e)=>e['id']==_selectedEmployeeId)['name']} (${_employees.firstWhere((e)=>e['id']==_selectedEmployeeId)['employee_code']})',
                                  style: const TextStyle(color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Role', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedAddRole != null && _roles.map((r)=>r['name'].toString().toLowerCase()).contains(_selectedAddRole) ? _selectedAddRole : null,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1A1A1A),
                            hint: const Text('Select role', style: TextStyle(color: Colors.grey)),
                            items: _roles.map((r) => r['name'].toString().toLowerCase()).map((value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedAddRole = v),
                          ),
                        ),
                      ),
                      if (_selectedAddRole != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            roleDescriptions[_selectedAddRole] ?? '',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      if (_selectedAddRole == 'admin' && _hasAdminAssigned(exceptId: _selectedEmployeeId))
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Admin role is locked. Only one admin allowed.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      const SizedBox(height: 12),
                      const Text('PIN', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _addPinController,
                        obscureText: _addPinObscure,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter PIN',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF1A1A1A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          errorText: _addPinError,
                          suffixIcon: IconButton(
                            icon: Icon(_addPinObscure ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setState(() => _addPinObscure = !_addPinObscure),
                          ),
                        ),
                        onChanged: (v) {
                          setState(() {
                            _addPinError = (v.trim().length >= 4 && !_pinInUse(v.trim(), exceptId: _selectedEmployeeId)) ? null : _addPinError;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final id = _selectedEmployeeId;
                            final pin = _addPinController.text.trim();
                            if (id == null || id.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an employee')));
                              return;
                            }
                            if (pin.length < 4) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be at least 4 digits')));
                              return;
                            }
                            if (_pinInUse(pin, exceptId: id)) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN already in use')));
                              return;
                            }
                            if ((_selectedAddRole ?? '').toLowerCase() == 'admin' && _hasAdminAssigned(exceptId: id)) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only one admin allowed')));
                              return;
                            }
                            await _addToRoster();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  collapsedIconColor: Colors.white,
                  iconColor: Colors.white,
                  title: const Text('Role Permissions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Grant or revoke features by role', style: TextStyle(color: Colors.grey)),
                  children: [
                    ..._roles.map((role) => _RoleCard(
                      role: role,
                      onPermissionChanged: (type, value, enabled) => _updatePermission(role, type, value, enabled),
                      onPinChanged: (pin) => _updatePin(role, pin),
                    )),
                  ],
                ),
              ),
              // Roster list removed per request to keep screen focused on assignment and permissions
            ],
          ),
        );

    if (widget.embed) return content;

    if (currentRole != 'admin') {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(
          title: const Text('Security & Roles'),
          backgroundColor: const Color(0xFF1A1A1A),
        ),
        body: const Center(
          child: Text(
            'Access Denied: Admin Only',
            style: TextStyle(color: Colors.red, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Security & Roles'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: content,
    );
  }
}

class _EmployeeSecurityCard extends StatefulWidget {
  final Map<String, dynamic> employee;
  final List<String> roles;
  final Function(String? role, String? pin) onUpdate;

  const _EmployeeSecurityCard({
    required this.employee,
    required this.roles,
    required this.onUpdate,
  });

  @override
  State<_EmployeeSecurityCard> createState() => _EmployeeSecurityCardState();
}

class _EmployeeSecurityCardState extends State<_EmployeeSecurityCard> {
  late TextEditingController _pinController;
  String? _selectedRole;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController(text: widget.employee['pin']?.toString() ?? '');
    _selectedRole = widget.employee['role']?.toString().toLowerCase();
  }

  @override
  void didUpdateWidget(_EmployeeSecurityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee['pin'] != widget.employee['pin']) {
      _pinController.text = widget.employee['pin']?.toString() ?? '';
    }
    if (oldWidget.employee['role'] != widget.employee['role']) {
      _selectedRole = widget.employee['role']?.toString().toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.employee['name']?.toString() ?? 'Unnamed',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Code: ${widget.employee['employee_code'] ?? 'N/A'}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.employee['role']?.toString().toUpperCase() ?? 'STAFF',
                    style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 560;
                final spacing = 12.0;
                final roleField = Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assigned Role', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: widget.roles.contains(_selectedRole) ? _selectedRole : null,
                            dropdownColor: const Color(0xFF1A1A1A),
                            style: const TextStyle(color: Colors.white),
                            isExpanded: true,
                            hint: const Text('Select Role', style: TextStyle(color: Colors.grey)),
                            items: widget.roles.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedRole = val);
                              widget.onUpdate(val, null);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                final pinField = Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Login PIN', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _pinController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        obscureText: _obscurePin,
                        decoration: InputDecoration(
                          hintText: 'PIN',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF1A1A1A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setState(() => _obscurePin = !_obscurePin),
                          ),
                        ),
                        onSubmitted: (val) => widget.onUpdate(null, val),
                      ),
                    ],
                  ),
                );
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      roleField,
                      SizedBox(height: spacing),
                      pinField,
                    ],
                  );
                }
                return Row(
                  children: [
                    roleField,
                    SizedBox(width: spacing),
                    pinField,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final Map<String, dynamic> role;
  final Function(String type, String value, bool enabled) onPermissionChanged;
  final Function(String pin) onPinChanged;

  const _RoleCard({
    required this.role,
    required this.onPermissionChanged,
    required this.onPinChanged,
  });

  @override
  Widget build(BuildContext context) {
    final permissions = role['permissions'] as Map<String, dynamic>? ?? {};
    final isAdmin = (role['name']?.toString().toLowerCase() ?? '') == 'admin';
    final views = List<String>.from(permissions['views'] ?? []);
    final actions = List<String>.from(permissions['actions'] ?? []);

    final allViews = [
      'dashboard', 'tables', 'tableOrder', 'takeout', 'kitchen', 'menu', 
      'reports', 'inventory', 'tables_manage', 'printer_settings', 'expenses', 'employees', 'settings'
    ];
    
    final allActions = [
      'manage_employees', 'delete_employee', 'system_settings', 
      'manage_inventory', 'take_order', 'view_kitchen', 'view_tables'
    ];

    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          role['name']?.toString().toUpperCase() ?? 'UNKNOWN',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text('PIN: ${role['pin'] ?? 'Not set'}', style: const TextStyle(color: Colors.grey)),
        childrenPadding: const EdgeInsets.all(16),
        collapsedIconColor: Colors.white,
        iconColor: Colors.white,
        children: [
          if (isAdmin)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Admin is locked. Permissions and PIN cannot be changed here.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          const SizedBox(height: 8),
          const Text('View Permissions', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...allViews.map((v) {
            final enabled = views.contains(v);
            return // ignore: deprecated_member_use
            SwitchListTile(
              value: enabled,
              onChanged: isAdmin ? null : (val) => onPermissionChanged('views', v, val),
              title: Text(v, style: const TextStyle(color: Colors.white)),
              activeColor: const Color(0xFF10B981),
              contentPadding: EdgeInsets.zero,
            );
          }),
          const SizedBox(height: 8),
          const Text('Action Permissions', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...allActions.map((a) {
            final enabled = actions.contains(a);
            final label = a.replaceAll('_', ' ');
            return // ignore: deprecated_member_use
            SwitchListTile(
              value: enabled,
              onChanged: isAdmin ? null : (val) => onPermissionChanged('actions', a, val),
              title: Text(label, style: const TextStyle(color: Colors.white)),
              activeColor: const Color(0xFF3B82F6),
              contentPadding: EdgeInsets.zero,
            );
          }),
        ],
      ),
    );
  }
}
