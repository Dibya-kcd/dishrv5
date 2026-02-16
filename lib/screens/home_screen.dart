import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/top_nav.dart';
import '../widgets/mobile_nav.dart';
import '../widgets/kot_preview_modal.dart';
import '../widgets/bill_preview_modal.dart';
import '../widgets/payment_modal.dart';

import 'dashboard_screen.dart';
import 'tables_screen.dart';
import 'table_order_screen.dart';
import 'kitchen_screen.dart';
import 'takeout_screen.dart';
import 'menu_screen.dart';
import 'reports_screen.dart';
import 'inventory_screen.dart';
import 'printer_settings_screen.dart';
import 'expense_screen.dart';
import 'employee_screen.dart';
import 'settings_screen.dart';
import 'table_management_screen.dart';
import 'role_config_screen.dart';
import 'admin_panel_screen.dart';
import 'firebase_debug_screen.dart';

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
        final provider = context.read<RestaurantProvider>();
        provider.setCurrentView(widget.initialView!, updateUrl: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final provider = context.watch<RestaurantProvider>();
      
      Widget currentScreen;
      switch (provider.currentView) {
        case 'dashboard':
          currentScreen = const DashboardScreen();
          break;
        case 'tables':
          currentScreen = const TablesScreen();
          break;
        case 'tableOrder':
          currentScreen = const TableOrderScreen();
          break;
        case 'kitchen':
          currentScreen = const KitchenScreen();
          break;
        case 'takeout':
          currentScreen = const TakeoutScreen();
          break;
        case 'menu':
          currentScreen = const MenuScreen();
          break;
        case 'reports':
          currentScreen = const ReportsScreen();
          break;
        case 'inventory':
          currentScreen = const InventoryScreen();
          break;
        case 'tables_manage':
          currentScreen = const TableManagementScreen();
          break;
        case 'printer_settings':
          currentScreen = const PrinterSettingsScreen();
          break;
        case 'roles':
          currentScreen = const RoleManagementScreen();
          break;
        case 'simulation':
          currentScreen = const AdminPanelScreen(embed: true);
          break;
        case 'debug':
          currentScreen = const FirebaseDebugScreen();
          break;
        case 'expenses':
          currentScreen = const ExpenseScreen();
          break;
        case 'employees':
          currentScreen = const EmployeeScreen();
          break;
        case 'settings':
          currentScreen = const SettingsScreen();
          break;
        case 'admin':
          currentScreen = const SettingsScreen();
          break;
        default:
          currentScreen = const DashboardScreen();
      }

      return Scaffold(
        backgroundColor: const Color(0xFF0B0B0E),
        body: Stack(children: [
          Column(children: [
            const TopNav(),
            Expanded(child: currentScreen),
          ]),
          const KOTPreviewModal(),
          const BillPreviewModal(),
          const PaymentModal(),
          Align(
            alignment: width < 600 ? Alignment.bottomCenter : Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: width < 600 ? 0 : 16,
                left: width < 600 ? 16 : 0,
                bottom: width < 600 ? 16 : 0,
                top: width < 600 ? 0 : 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: width < 600 ? CrossAxisAlignment.center : CrossAxisAlignment.end,
                children: provider.toasts.map((t) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF27272A)),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                    ),
                    constraints: BoxConstraints(maxWidth: width < 600 ? (width - 64) : 320),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t['icon'] as String? ?? '✅', style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t['message'] as String? ?? '', style: const TextStyle(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (width < 1024)
            Align(
              alignment: Alignment.bottomCenter,
              child: MobileNav(width: width),
            ),
        ]),
      );
    });
  }
}
