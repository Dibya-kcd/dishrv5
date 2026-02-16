import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../data/repository.dart';
import '../data/sync_service.dart';

class AuthHelper {
  static List<Map<String, dynamic>>? _cachedRoles;
  static Future<void> refreshRoles() async {
    final existing = await Repository.instance.roles.listRoles();
    await _ensureDefaultRoles(existing);
    
    // Also check if we can pull custom roles and employees from Firebase if we are online
    try {
      final roleSnap = await FirebaseDatabase.instance.ref('role_configs').get();
      if (roleSnap.exists && roleSnap.value is Map) {
        final data = roleSnap.value as Map;
        for (var key in data.keys) {
          final config = Map<String, dynamic>.from(data[key] as Map);
          if (config['name'] != null) {
            config['name'] = config['name'].toString().toLowerCase();
          }
          await Repository.instance.roles.upsertRole(config, fromSync: true, notify: false);
        }
        Repository.instance.notifyDataChanged();
      } else if (roleSnap.exists == false) {
        // Only attempt to seed if Firebase role_configs is EMPTY and we are likely an admin
        // Check if current user is admin before attempting write to avoid permission denied spam
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final adminSnap = await FirebaseDatabase.instance.ref('roles/$uid/role').get();
          if (adminSnap.value == 'admin') {
            final currentRoles = await Repository.instance.roles.listRoles();
            for (var r in currentRoles) {
              final payload = Map<String, dynamic>.from(r);
              await FirebaseDatabase.instance.ref('role_configs/${r['id']}').set(payload);
            }
          }
        }
      }

      // Pull employees as well
      final empSnap = await FirebaseDatabase.instance.ref('employees').get();
      if (empSnap.exists && empSnap.value is Map) {
        final data = empSnap.value as Map;
        for (var key in data.keys) {
          final emp = Map<String, dynamic>.from(data[key] as Map);
          if (emp['deleted'] == true) continue;
          if (emp['role'] != null) {
            emp['role'] = emp['role'].toString().toLowerCase();
          }
          await Repository.instance.employees.upsertEmployee(emp, fromSync: true, notify: false);
        }
        Repository.instance.notifyDataChanged();
      }
    } catch (_) {}
    
    _cachedRoles = await Repository.instance.roles.listRoles();
  }

  static Future<void> _ensureDefaultRoles(List<Map<String, dynamic>> existing) async {
    final defaults = [
      {
        'id': 'admin',
        'name': 'admin',
        'permissions': {
          'views': ['dashboard', 'tables', 'tableOrder', 'takeout', 'kitchen', 'menu', 'reports', 'inventory', 'tables_manage', 'printer_settings', 'expenses', 'employees', 'settings', 'admin'],
          'actions': ['manage_employees', 'delete_employee', 'manage_roles', 'system_settings', 'manage_inventory', 'take_order', 'view_kitchen', 'view_tables']
        },
        'pin': '1234'
      },
      {
        'id': 'manager',
        'name': 'manager',
        'permissions': {
          'views': ['dashboard', 'tables', 'tableOrder', 'takeout', 'kitchen', 'menu', 'reports', 'inventory', 'tables_manage', 'expenses', 'printer_settings', 'employees', 'settings'],
          'actions': ['manage_employees', 'manage_inventory', 'take_order', 'view_kitchen', 'view_tables']
        },
        'pin': '2222'
      },
      {
        'id': 'chef',
        'name': 'chef',
        'permissions': {
          'views': ['kitchen', 'inventory', 'reports'],
          'actions': ['view_kitchen', 'manage_inventory']
        },
        'pin': '3333'
      },
      {
        'id': 'waiter',
        'name': 'waiter',
        'permissions': {
          'views': ['tables', 'tableOrder', 'takeout', 'reports'],
          'actions': ['take_order', 'view_tables']
        },
        'pin': '4444'
      },
      {
        'id': 'staff',
        'name': 'staff',
        'permissions': {
          'views': ['tables', 'tableOrder', 'takeout'],
          'actions': ['take_order']
        },
        'pin': '5555'
      },
    ];

    final existingIds = existing
        .map((r) => r['id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();

    for (var r in defaults) {
      final id = r['id']?.toString() ?? '';
      if (!existingIds.contains(id)) {
        await Repository.instance.roles.upsertRole(r, fromSync: true);
      }
    }
  }

  static Future<Map<String, dynamic>?> login(String code, String pin) async {
    if (_cachedRoles == null) await refreshRoles();
    
    // First check role-based PINs
    final roleMatch = _cachedRoles!.firstWhere(
      (r) => r['name'].toString().toLowerCase() == code.toLowerCase() && r['pin'] == pin,
      orElse: () => {},
    );

    if (roleMatch.isNotEmpty) {
      final role = roleMatch['name'].toString().toLowerCase();
      Repository.instance.setClientSession(role, pin);
      try {
        SyncService.instance.init();
        await SyncService.instance.setCurrentUserRole(role);
        
        // Populate all roles to Firebase if they are missing
        if (role == 'admin') {
          final currentRoles = await Repository.instance.roles.listRoles();
          for (var r in currentRoles) {
            await FirebaseDatabase.instance.ref('role_configs/${r['id']}').set(r);
          }
        }
        
        await SyncService.instance.initialUpload();
      } catch (_) {}
      return {'name': roleMatch['name'], 'role': role, 'is_role_login': true};
    }

    // Then check employee-specific PINs
    final employees = await Repository.instance.employees.listEmployees();
    try {
      final employee = employees.firstWhere(
        (e) => (e['employee_code'] == code || e['name'] == code) && e['pin'] == pin,
      );
      
      final role = (employee['role']?.toString() ?? '').trim().toLowerCase();
      final empPin = (employee['pin']?.toString() ?? '').trim();
      Repository.instance.setClientSession(role, empPin);
      try {
        SyncService.instance.init();
        await SyncService.instance.setCurrentUserRole(role);
        await SyncService.instance.initialUpload();
      } catch (_) {}
      return employee;
    } catch (e) {
      return null;
    }
  }

  static bool hasPermission(String role, String permission) {
    if (role.toLowerCase() == 'admin') {
      return true;
    }
    if (_cachedRoles == null) {
      return false;
    }

    final r = _cachedRoles!.firstWhere(
      (config) => config['name'].toString().toLowerCase() == role.toLowerCase(),
      orElse: () => {},
    );

    if (r.isEmpty) {
      return false;
    }
    final perms = r['permissions'] as Map<String, dynamic>? ?? {};
    final actions = perms['actions'] as List? ?? [];
    final result = actions.contains(permission);
    return result;
  }

  static Set<String> allowedViewsForRole(String role) {
    if (role.toLowerCase() == 'admin') {
      final views = {
        'dashboard','tables','tableOrder','takeout','kitchen','menu','reports',
        'inventory','tables_manage','printer_settings','expenses','employees',
        'settings', 'admin'
      };
      return views;
    }
    if (_cachedRoles == null) {
      return {'dashboard'};
    }

    final r = _cachedRoles!.firstWhere(
      (config) => config['name'].toString().toLowerCase() == role.toLowerCase(),
      orElse: () => {},
    );

    if (r.isEmpty) {
      return {'dashboard'};
    }
    final perms = r['permissions'] as Map<String, dynamic>? ?? {};
    final views = (perms['views'] as List? ?? []).map((e) => e.toString()).toSet();
    
    if (views.isEmpty) {
      return {'dashboard', 'settings'};
    }
    return views;
  }

  static Future<void> logout({String? role}) async {
    Repository.instance.clearSession();
    try {
      // 1. Log the logout event for audit purposes
      if (role != null && role.isNotEmpty) {
        await SyncService.instance.logAuditEvent('logout', {'role': role});
      }

      // 2. Clear local session metadata (Ends the local PIN session)
      Repository.instance.setClientSession('', '');
      
      // Note: We NO LONGER sign out from Firebase here.
      // Firebase stays connected to maintain sync in the background.
      // Full Firebase logout is now handled separately in Admin Panel.
    } catch (_) {
      // Silently fail if any cleanup step fails
    }
  }

  /// Full Firebase Authentication logout. 
  /// Only to be used from the Admin/Auth Panel.
  static Future<void> firebaseLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Repository.instance.setClientSession('', '');
      Repository.instance.clearSession();
    } catch (_) {}
  }
}
