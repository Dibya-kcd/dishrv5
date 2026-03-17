import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/auth_helper.dart';
import 'home_screen.dart';
import 'admin_panel_screen.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _pinController  = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;
  String? _error;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  // ── Admin hold-to-enter ───────────────────────────────────
  late final AnimationController _holdCtrl;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    _holdCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _holdCtrl.reset();
          setState(() => _holding = false);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
          );
        }
      });
  }

  void _onLogoHoldStart(_) {
    setState(() => _holding = true);
    _holdCtrl.forward(from: 0);
  }

  void _onLogoHoldEnd() {
    if (_holdCtrl.status != AnimationStatus.completed) {
      _holdCtrl.reset();
      setState(() => _holding = false);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _holdCtrl.dispose();
    _codeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = null; });
    final code = _codeController.text.trim();
    final pin  = _pinController.text.trim();
    if (code.isEmpty || pin.isEmpty) {
      setState(() { _isLoading = false; _error = 'Please enter both ID and PIN'; });
      return;
    }
    try {
      final user = await AuthHelper.login(code, pin);
      if (user != null) {
        if (!mounted) return;
        final role = (user['role']?.toString() ?? '').toLowerCase();
        final initialView = switch (role) {
          'chef'    => 'kitchen',
          'waiter'  => 'tables',
          _         => 'dashboard',
        };
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(initialView: initialView)),
        );
      } else {
        if (!mounted) return;
        setState(() { _error = 'Invalid credentials'; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'An error occurred. Try again.'; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: Stack(
        children: [
          // Subtle radial glow at top-center
          Positioned(
            top: -120, left: 0, right: 0,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [AppColors.amber.withValues(alpha: 0.08), Colors.transparent],
                  radius: 0.7,
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo + hold-to-enter admin ────────────────────
                      GestureDetector(
                        onLongPressStart: _onLogoHoldStart,
                        onLongPressEnd: (_) => _onLogoHoldEnd(),
                        onLongPressCancel: _onLogoHoldEnd,
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: _holdCtrl,
                              builder: (_, __) => Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Progress ring while holding
                                  if (_holding)
                                    SizedBox(
                                      width: 72, height: 72,
                                      child: CircularProgressIndicator(
                                        value: _holdCtrl.value,
                                        strokeWidth: 3,
                                        color: AppColors.amber,
                                        backgroundColor: AppColors.amber.withValues(alpha: 0.15),
                                      ),
                                    ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 64, height: 64,
                                    decoration: BoxDecoration(
                                      color: _holding
                                          ? AppColors.amber.withValues(alpha: 0.22)
                                          : AppColors.amber.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: _holding
                                            ? AppColors.amber.withValues(alpha: 0.8)
                                            : AppColors.amber.withValues(alpha: 0.3),
                                        width: _holding ? 2 : 1,
                                      ),
                                    ),
                                    child: const Icon(Icons.restaurant, color: AppColors.amber, size: 30),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text('The Dish',
                              style: GoogleFonts.sora(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Text('Staff Portal', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      // Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.bg1,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 12))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DarkField(
                              label: 'Employee ID',
                              controller: _codeController,
                              hint: 'Enter your ID',
                              suffix: const Icon(Icons.badge_outlined, size: 18, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 16),
                            DarkField(
                              label: 'PIN',
                              controller: _pinController,
                              hint: '••••',
                              obscureText: _obscurePin,
                              suffix: IconButton(
                                icon: Icon(_obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppColors.textMuted),
                                onPressed: () => setState(() => _obscurePin = !_obscurePin),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, size: 15, color: AppColors.red),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12))),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.amber,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                    : Text('Login', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Hold the logo for 2s → Owner / Admin Panel',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                        textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
