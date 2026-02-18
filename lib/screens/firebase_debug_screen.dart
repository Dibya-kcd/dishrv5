import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../data/repository.dart';
import '../data/sync_service.dart';
import '../utils/auth_helper.dart';
import '../utils/sample_data.dart';
import '../providers/restaurant_provider.dart';
import 'login_screen.dart';

class FirebaseDebugScreen extends StatefulWidget {
  final bool embed;
  const FirebaseDebugScreen({super.key, this.embed = false});

  @override
  State<FirebaseDebugScreen> createState() => _FirebaseDebugScreenState();
}

class _FirebaseDebugScreenState extends State<FirebaseDebugScreen> {
  String _log = '';
  bool _busy = false;

  void _addLog(String msg) {
    setState(() {
      _log += '${DateTime.now().toIso8601String().split('T').last.split('.').first} $msg\n';
    });
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _log = '';
      _busy = true;
    });

    try {
      _addLog('Starting diagnostics...');
      
      // 1. Check Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ Auth: Not signed in');
      } else {
        _addLog('✅ Auth: Signed in as ${user.uid}');
        try {
          await user.getIdToken();
          _addLog('✅ Auth: Token obtained');
        } catch (e) {
          _addLog('❌ Auth: Token error: $e');
        }
      }

      // 2. Check Database Connection (Info)
      _addLog('Checking .info/connected...');
      try {
        final infoSnap = await FirebaseDatabase.instance.ref('.info/connected').get();
        final connected = infoSnap.value == true;
        if (connected) {
          _addLog('✅ Database: Connected');
        } else {
          _addLog('⚠️ Database: Not connected (offline?)');
        }
      } catch (e) {
        _addLog('❌ Database: .info/connected failed: $e');
      }

      // 3. Read Test (Root Access)
      _addLog('Reading current session role...');
      try {
        final meta = Repository.instance.clientMeta;
        final currentRole = meta?['role']?.toString();
        if (meta == null) {
          _addLog('ℹ️ Session Role (Local): NULL (User has not logged in with PIN yet)');
        } else {
          _addLog('ℹ️ Session Role (Local): $currentRole');
        }
        
        if (user != null) {
            final roleSnap = await FirebaseDatabase.instance.ref('roles/${user.uid}').get();
            if (roleSnap.exists) {
                 final val = roleSnap.value;
                 String? firebaseRole;
                 if (val is Map) {
                   firebaseRole = val['role']?.toString();
                 } else if (val is String) {
                   firebaseRole = val;
                 }
                 
                 _addLog('✅ Firebase Auth Role: $firebaseRole');
                 if (currentRole != null && firebaseRole != null && currentRole.toLowerCase() != firebaseRole.toLowerCase()) {
                   _addLog('⚠️ Mismatch: Session ($currentRole) vs Firebase Auth ($firebaseRole)');
                   _addLog('Attempting to fix Firebase role...');
                   await SyncService.instance.setCurrentUserRole(currentRole);
                   // Verify fix
                   final verifySnap = await FirebaseDatabase.instance.ref('roles/${user.uid}/role').get();
                   _addLog('✅ Firebase role update attempted. New value: ${verifySnap.value}');
                 }
            } else {
                 _addLog('⚠️ Read: roles/${user.uid} not found. Setting it now...');
                 if (currentRole != null) {
                   await SyncService.instance.setCurrentUserRole(currentRole);
                   _addLog('✅ Firebase role initialized to $currentRole');
                 }
            }
        } else {
          _addLog('ℹ️ Read: Skipped (not signed in)');
        }
      } catch (e) {
        _addLog('❌ Read: Failed: $e');
      }
      
      // 4. Node-wise Access Test
      _addLog('\n--- Node-wise Access Test ---');
      final nodes = [
        {'path': 'menu_items', 'desc': 'Menu Items'},
        {'path': 'expenses', 'desc': 'Expenses'},
        {'path': 'employees', 'desc': 'Employees'},
        {'path': 'counters', 'desc': 'Counters'},
        {'path': 'orders', 'desc': 'Orders'},
        {'path': 'tables', 'desc': 'Tables'},
        {'path': 'role_configs', 'desc': 'Role Configs'},
        {'path': 'ingredients', 'desc': 'Ingredients'},
        {'path': 'inventory_txns', 'desc': 'Inventory Txns'},
      ];

      for (var node in nodes) {
        final path = node['path']!;
        final desc = node['desc']!;
        
        // Read Test
        try {
          final snap = await FirebaseDatabase.instance.ref(path).limitToFirst(1).get();
          _addLog('📖 Read [$desc]: Success (${snap.exists ? "Data found" : "Empty"})');
        } catch (e) {
          _addLog('📖 Read [$desc]: Failed - $e');
        }

        // Write Test
        try {
          final testRef = FirebaseDatabase.instance.ref('$path/debug_probe');
          await testRef.set({'test': true, 'timestamp': ServerValue.timestamp});
          await testRef.remove();
          _addLog('✍️ Write [$desc]: Success');
        } catch (e) {
          _addLog('✍️ Write [$desc]: Failed - $e');
        }
      }

      _addLog('\nDiagnostics complete.');

    } catch (e) {
      _addLog('❌ Critical Error: $e');
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _cleanDuplicates() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deduplication'),
        content: const Text('This will scan all nodes (Ingredients, Menu, Employees, Tables) and merge/remove duplicate entries based on their names/numbers. This action cannot be undone. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('START CLEANUP', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _log = 'Starting Deduplication Cleanup...\n';
    });

    try {
      final results = await SyncService.instance.deduplicateAllNodes();
      _addLog('\n--- Deduplication Results ---');
      results.forEach((node, count) {
        _addLog('🧹 $node: $count duplicates removed');
      });
      _addLog('\nCleanup complete. Database is now optimized.');
    } catch (e) {
      _addLog('❌ Cleanup Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _seedDemoData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed Demo Data'),
        content: const Text('This will insert demo menu, ingredients, recipes, employees and tables. Existing inventory and recipes may be overwritten. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SEED DEMO DATA')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _log = 'Seeding demo data (menu, ingredients, recipes, employees, tables)...\n';
    });

    try {
      await seedDemoData();
      _addLog('✅ Demo data seeded successfully.');
    } catch (e) {
      _addLog('❌ Demo data seeding failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _runDiagnostics,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run Full Diagnostics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _cleanDuplicates,
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Clean Duplicates'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withValues(alpha: 0.2),
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _log = ''),
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                tooltip: 'Clear Logs',
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: SingleChildScrollView(
              child: Text(
                _log.isEmpty ? 'Ready to run diagnostics...' : _log,
                style: GoogleFonts.firaCode(color: Colors.green, fontSize: 13),
              ),
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'CRITICAL ACTIONS',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _busy ? null : _seedDemoData,
                icon: const Icon(Icons.restaurant),
                label: const Text('SEED DEMO DATA (DEMO ONLY)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await context.read<RestaurantProvider>().resetAllDataFresh(context);
                        } finally {
                          if (mounted) {
                            setState(() => _busy = false);
                          }
                        }
                      },
                icon: const Icon(Icons.delete_forever),
                label: const Text('RESET LOCAL + CLOUD DATABASE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context, rootNavigator: true);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirm Firebase Logout'),
                      content: const Text('This will fully disconnect the device from Firebase. Data sync will STOP. Are you sure?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('LOGOUT FIREBASE', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await AuthHelper.firebaseLogout();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('FULL FIREBASE LOGOUT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Only use this for security resets or account changes.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embed) return content;

    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      appBar: AppBar(
        title: const Text('System Diagnostics'),
        backgroundColor: const Color(0xFF18181B),
      ),
      body: content,
    );
  }
}
