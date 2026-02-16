import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/auth_helper.dart';
import 'home_screen.dart';
import 'admin_panel_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }


  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final code = _codeController.text.trim();
    final pin = _pinController.text.trim();

    if (code.isEmpty || pin.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Please enter both ID and PIN';
      });
      return;
    }

    try {
      final user = await AuthHelper.login(code, pin);
      if (user != null) {
        if (!mounted) return;
        final role = (user['role']?.toString() ?? '').toLowerCase();
        String initialView = 'dashboard';
        if (role == 'chef') {
          initialView = 'kitchen';
        } else if (role == 'waiter') {
          initialView = 'tables';
        } else if (role == 'manager') {
          initialView = 'dashboard';
        } else if (role == 'admin') {
          initialView = 'dashboard';
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(initialView: initialView)),
        );
      } else {
        if (!mounted) return;
        setState(() {
          _error = 'Invalid credentials';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dishr POS',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF9500),
                ),
                textAlign: TextAlign.center,
              ),
              GestureDetector(
                onLongPress: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Hold here for Admin Panel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Login to continue',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Employee ID',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.person, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'PIN',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                ),
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
