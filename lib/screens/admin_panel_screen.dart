import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../data/sync_service.dart';
import '../data/repository.dart';
import '../providers/restaurant_provider.dart';
import 'firebase_debug_screen.dart';
import 'role_config_screen.dart';
import '../utils/auth_helper.dart';
import 'login_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  final bool embed;
  const AdminPanelScreen({super.key, this.embed = false});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  String? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    _status = u == null ? 'Not signed in' : 'Signed in';
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );
      // Set local session as admin when signed in via email
      Repository.instance.setClientSession('admin', 'email_auth');
      try {
        SyncService.instance.init();
        await SyncService.instance.setCurrentUserRole('admin');
      } catch (_) {}
      setState(() {
        _status = 'Signed in';
      });
    } catch (e) {
      setState(() {
        _status = 'Auth failed';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      await AuthHelper.firebaseLogout();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _status = 'Sign out failed';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  void _showActAsDialog(BuildContext context, RestaurantProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Act as a Role', style: TextStyle(color: Colors.white)),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: Repository.instance.roles.listRoles(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            final roles = snapshot.data!.where((r) => r['name'].toString().toLowerCase() != 'admin').toList();
            if (roles.isEmpty) return const Text('No roles found', style: TextStyle(color: Colors.grey));
            
            return SizedBox(
              width: 300,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: roles.map((r) {
                    final name = r['name'].toString();
                    return ListTile(
                      title: Text(name.toUpperCase(), style: const TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                      onTap: () {
                        provider.actAsRole(name.toLowerCase());
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final isActing = provider.actingAsRole != null;
    final isSignedIn = FirebaseAuth.instance.currentUser != null;

    // Minimal Role Play content when embedded (Simulation only)
    if (widget.embed) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            width: 560,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isActing) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ACTING AS: ${provider.actingAsRole!.toUpperCase()}',
                          style: GoogleFonts.inter(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => provider.actAsRole(null),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                          child: const Text('Safe Exit to Admin Mode'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text('Role Play (Simulation)', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showActAsDialog(context, provider),
                  icon: const Icon(Icons.theater_comedy),
                  label: const Text('Act as a Role (Simulation)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isActing) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'ACTING AS: ${provider.actingAsRole!.toUpperCase()}',
                        style: GoogleFonts.inter(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => provider.actAsRole(null),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        child: const Text('Safe Exit to Admin Mode'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Text('Role Play (Simulation)', style: GoogleFonts.inter(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              if (!widget.embed) ...[
                // Navigation to Security & Roles
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleManagementScreen()));
                  },
                  icon: const Icon(Icons.security),
                  label: const Text('Security & Role Configuration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Act as a Role
              ElevatedButton.icon(
                onPressed: () => _showActAsDialog(context, provider),
                icon: const Icon(Icons.theater_comedy),
                label: const Text('Act as a Role (Simulation)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFF3F3F46)),
              const SizedBox(height: 24),

              Text('Firebase Authentication', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 12),
              if (!isSignedIn) ...[
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Admin Email',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Admin Password',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (!isSignedIn)
                    ElevatedButton(
                      onPressed: _busy ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sign In to Firebase'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _busy ? null : _signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sign Out from Firebase'),
                    ),
                  const SizedBox(width: 12),
                  Text(_status ?? '', style: TextStyle(color: isSignedIn ? Colors.green : Colors.grey)),
                ],
              ),
              
              if (!widget.embed) ...[
                const SizedBox(height: 24),
                const Divider(color: Color(0xFF3F3F46)),
                const SizedBox(height: 24),
                
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FirebaseDebugScreen()));
                  },
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Open System Diagnostics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B5563),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.embed) return content;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: content,
    );
  }
}
