import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../screens/login_screen.dart';
import '../utils/auth_helper.dart';
import '../data/sync_service.dart';
import '../widgets/app_ui_kit.dart';

/// TopNav — logo + connectivity dot + desktop quick-access menus + account.
/// On mobile (< 1024 px) the 3-bar nav shortcuts are hidden —
/// bottom nav handles all navigation on mobile.
/// On desktop (≥ 1024 px) all three popup menus (Ops / Reports / Mgmt) and
/// the Settings icon are kept intact as power-user shortcuts.
class TopNav extends StatelessWidget {
  const TopNav({super.key});

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<RestaurantProvider>();
    final role      = (provider.clientRole ?? '').trim().toLowerCase();
    final allowed   = AuthHelper.allowedViewsForRole(role);
    final roleLabel = role.isEmpty ? 'Live'
        : '${role[0].toUpperCase()}${role.substring(1)}';

    return LayoutBuilder(builder: (context, c) {
      final isMobile = c.maxWidth < 1024;

      PopupMenuItem<String> mi(String v, IconData ic, String lbl) =>
          PopupMenuItem(value: v, child: Row(children: [
            Icon(ic, color: Colors.white70, size: 15),
            const SizedBox(width: 9),
            Text(lbl, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]));

      return Column(children: [
        // ── Acting-as banner ──────────────────────────────────────────────
        if (provider.actingAsRole != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
            color: AppColors.orange,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 16),
              const SizedBox(width: 7),
              Text('ACTING AS: ${provider.actingAsRole!.toUpperCase()}',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 14),
              TextButton(
                onPressed: () => provider.actAsRole(null),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('EXIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

        // ── Main bar ──────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: AppColors.bg1,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 10 : 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [

            // Left: logo + name + sync dot
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.amber, AppColors.orange]),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.restaurant, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 8),
              const Text('The Dish',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: SyncService.instance.connected,
                builder: (_, on, __) => Tooltip(
                  message: on ? 'Synced' : 'Offline',
                  child: Row(children: [
                    Icon(Icons.circle, size: 8, color: on ? AppColors.green : AppColors.red),
                    const SizedBox(width: 4),
                    if (!isMobile)
                      Text(on ? 'Live' : 'Offline',
                          style: TextStyle(
                              color: on ? AppColors.green : AppColors.red,
                              fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),

            // Right: desktop shortcut menus (hidden on mobile) + account
            Row(children: [
              // PWA install button
              if (provider.installAvailable)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final e = provider.installPromptEvent;
                      if (e != null) { e.prompt(); e.userChoice.then((_) {}); }
                    },
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text('Install', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ),

              // ── Desktop-only shortcut menus (hidden on mobile) ─────────
              if (!isMobile) ...[
                // Operations
                PopupMenuButton<String>(
                  tooltip: 'Operations', offset: const Offset(0, 38), color: AppColors.bg1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border)),
                  itemBuilder: (_) {
                    final a = AuthHelper.allowedViewsForRole(provider.clientRole ?? '');
                    return [
                      if (a.contains('tables'))  mi('tables',  Icons.table_bar,            'Tables'),
                      if (a.contains('takeout')) mi('takeout', Icons.shopping_bag_outlined, 'Takeout'),
                      if (a.contains('kitchen')) mi('kitchen', Icons.restaurant_menu,       'Kitchen'),
                    ];
                  },
                  onSelected: (v) => Future.microtask(() => provider.setCurrentView(v)),
                  child: _NavIcon(Icons.workspaces_outlined),
                ),
                const SizedBox(width: 2),

                // Reports
                if (allowed.contains('reports'))
                  PopupMenuButton<String>(
                    tooltip: 'Reports', offset: const Offset(0, 38), color: AppColors.bg1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: AppColors.border)),
                    itemBuilder: (_) => [
                      mi('0', Icons.trending_up,          'Sales'),
                      mi('1', Icons.show_chart,           'Trends'),
                      mi('2', Icons.payments_outlined,    'Payments'),
                      mi('3', Icons.speed,                'Perf'),
                      mi('4', Icons.inventory_2_outlined, 'Stock'),
                      mi('5', Icons.account_balance,      'Finance'),
                    ],
                    onSelected: (v) => Future.microtask(() {
                      provider.setReportsTabIndex(int.tryParse(v) ?? 0);
                      provider.setCurrentView('reports');
                    }),
                    child: _NavIcon(Icons.bar_chart),
                  ),
                const SizedBox(width: 2),

                // Management
                PopupMenuButton<String>(
                  tooltip: 'Management', offset: const Offset(0, 38), color: AppColors.bg1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border)),
                  itemBuilder: (_) {
                    final a = AuthHelper.allowedViewsForRole(provider.clientRole ?? '');
                    return [
                      if (a.contains('tables_manage')) mi('tables_manage', Icons.table_bar,                       'Table Mgmt'),
                      if (a.contains('menu'))          mi('menu',          Icons.menu_book_outlined,              'Menu'),
                      if (a.contains('inventory'))     mi('inventory',     Icons.inventory_2_outlined,            'Inventory'),
                      if (a.contains('expenses'))      mi('expenses',      Icons.account_balance_wallet_outlined, 'Expenses'),
                      if (a.contains('employees'))     mi('employees',     Icons.badge_outlined,                  'Employees'),
                    ];
                  },
                  onSelected: (v) => Future.microtask(() => provider.setCurrentView(v)),
                  child: _NavIcon(Icons.business_center_outlined),
                ),
                const SizedBox(width: 2),

                // Settings
                if (allowed.contains('settings'))
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                    tooltip: 'Settings',
                    padding: const EdgeInsets.all(6),
                    onPressed: () => Future.microtask(() => provider.setCurrentView('settings')),
                  ),
              ],

              // ── Account menu (always visible on all screen sizes) ──────
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Account', offset: const Offset(0, 40), color: AppColors.bg1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(children: const [
                      Icon(Icons.logout, color: Colors.white70, size: 15),
                      SizedBox(width: 9),
                      Text('Logout', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ]),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'logout') {
                    final nav = Navigator.of(context, rootNavigator: true);
                    Future.microtask(() async {
                      await AuthHelper.logout(role: provider.clientRole);
                      nav.pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (r) => false);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_outline, color: Colors.white, size: 15),
                    const SizedBox(width: 5),
                    Text(roleLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
      ]);
    });
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  const _NavIcon(this.icon);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Icon(icon, color: Colors.white70, size: 20),
  );
}
