import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/top_nav.dart';
import '../widgets/mobile_nav.dart';
import '../widgets/kot_preview_modal.dart';
import '../widgets/bill_preview_modal.dart';
import '../widgets/payment_modal.dart';
import '../widgets/app_ui_kit.dart';

import 'dashboard_screen.dart';
import 'table_order_screen.dart';
import 'kitchen_screen.dart';
import 'takeout_screen.dart';
import 'menu_screen.dart';
import 'reports_screen.dart';
import 'inventory_screen.dart';
import 'expense_screen.dart';
import 'settings_screen.dart';
import 'tables_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? initialView;
  const HomeScreen({super.key, this.initialView});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialView != null) {
        context.read<RestaurantProvider>().setCurrentView(widget.initialView!, updateUrl: false);
      }
    });
  }

  Widget _resolveScreen(String view) {
    switch (view) {
      // ── Primary screens ─────────────────────────────────────────
      case 'tables':        return const TablesScreen();
      case 'tableOrder':    return const TableOrderScreen();
      case 'kitchen':       return const KitchenScreen();
      case 'takeout':       return const TakeoutScreen();
      case 'menu':          return const MenuScreen();
      case 'reports':       return const ReportsScreen();
      case 'inventory':     return const InventoryScreen();
      case 'expenses':      return const ExpenseScreen();

      // ── Settings hub (with deep-link to a section) ───────────────
      case 'settings':
      case 'admin':
        return const SettingsScreen();

      // Deep-link into a specific Settings tab
      case 'tables_manage':    return const SettingsScreen(initialSection: 'tables_manage');
      case 'employees':        return const SettingsScreen(initialSection: 'employees');
      case 'tax':              return const SettingsScreen(initialSection: 'tax');
      case 'printer_settings': return const SettingsScreen(initialSection: 'printer');
      case 'roles':            return const SettingsScreen(initialSection: 'roles');
      case 'simulation':       return const SettingsScreen(initialSection: 'simulation');
      case 'debug':            return const SettingsScreen(initialSection: 'debug');

      case 'dashboard':
      default:              return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isCompact = width < 1024;

      return Scaffold(
        backgroundColor: AppColors.bg0,
        body: Stack(children: [
          // ── Main content ──────────────────────────────────────
          Column(children: [
            const TopNav(),
            Expanded(child: _resolveScreen(provider.currentView)),
          ]),

          // ── Modals ────────────────────────────────────────────
          const KOTPreviewModal(),
          const BillPreviewModal(),
          const PaymentModal(),

          // ── Toast notifications ───────────────────────────────
          _ToastStack(width: width, toasts: provider.toasts),

          // ── Mobile / tablet bottom nav ────────────────────────
          if (isCompact)
            Align(
              alignment: Alignment.bottomCenter,
              child: MobileNav(width: width),
            ),
        ]),
      );
    });
  }
}

class _ToastStack extends StatelessWidget {
  final double width;
  final List<Map<String, dynamic>> toasts;

  const _ToastStack({required this.width, required this.toasts});

  @override
  Widget build(BuildContext context) {
    if (toasts.isEmpty) return const SizedBox.shrink();
    final isCompact = width < 1024;

    return Align(
      alignment: isCompact ? Alignment.bottomCenter : Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(
          right: isCompact ? 0 : 16,
          left: isCompact ? 16 : 0,
          bottom: isCompact ? 80 : 0, // above mobile nav
          top: isCompact ? 0 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.end,
          children: toasts.map((t) => _ToastChip(t: t, maxWidth: isCompact ? width - 64 : 320)).toList(),
        ),
      ),
    );
  }
}

class _ToastChip extends StatelessWidget {
  final Map<String, dynamic> t;
  final double maxWidth;

  const _ToastChip({required this.t, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(t['icon'] as String? ?? '✅', style: const TextStyle(fontSize: 17)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            t['message'] as String? ?? '',
            style: AppTextStyles.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}
