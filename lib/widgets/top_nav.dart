import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../screens/login_screen.dart';
import '../utils/auth_helper.dart';
import '../data/sync_service.dart';

class TopNav extends StatelessWidget {
  const TopNav({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final role = (provider.clientRole ?? '').trim().toLowerCase();
    final allowed = AuthHelper.allowedViewsForRole(role);
    final roleLabel = role.isEmpty ? 'Live' : '${role[0].toUpperCase()}${role.substring(1)}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 1024;
        
        final items = [
          {'id': 'dashboard', 'label': 'Live Dashboard', 'icon': Icons.wifi_tethering},
        ];

        return Column(
          children: [
            if (provider.actingAsRole != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.orange,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'ACTING AS: ${provider.actingAsRole!.toUpperCase()}',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () => provider.actAsRole(null),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text('EXIT ROLE PLAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                border: const Border(bottom: BorderSide(color: Color(0xFF27272A))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEA580C)]),
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.restaurant, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 8),
                    const Text('The Dish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<bool>(
                      valueListenable: SyncService.instance.connected,
                      builder: (context, isConnected, _) {
                        return Icon(
                          Icons.circle,
                          size: 10,
                          color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    if (!isMobile)
                      Row(children: items.map((it) {
                        final active = provider.currentView == it['id'];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextButton(
                            onPressed: () {
                              provider.setCurrentView(it['id'] as String);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: active ? const Color(0xFFF59E0B) : const Color(0xFF27272A),
                              foregroundColor: active ? Colors.white : const Color(0xFFA1A1AA),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Row(children: [
                              Icon(it['icon'] as IconData, size: 16),
                              const SizedBox(width: 6),
                              Text(it['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        );
                      }).toList()),
                  ]),
                  Row(children: [
                    if (provider.installAvailable)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final event = provider.installPromptEvent;
                            if (event != null) {
                              event.prompt();
                              event.userChoice.then((choice) {
                                if (choice.outcome == 'accepted') {
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Install App'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    if (!isMobile) ...[
                      PopupMenuButton<String>(
                        tooltip: 'Operations',
                        offset: const Offset(0, 36),
                        color: const Color(0xFF18181B),
                        itemBuilder: (context) {
                          final role = provider.clientRole ?? '';
                          final allowed = AuthHelper.allowedViewsForRole(role);
                          final ops = <PopupMenuEntry<String>>[];
                          if (allowed.contains('tables')) {
                            ops.add(
                              PopupMenuItem(
                                value: 'tables',
                                child: Row(children: const [
                                  Icon(Icons.table_bar, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Tables', style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                            );
                          }
                          if (allowed.contains('takeout')) {
                            ops.add(
                              PopupMenuItem(
                                value: 'takeout',
                                child: Row(children: const [
                                  Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Takeout', style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                            );
                          }
                          if (allowed.contains('kitchen')) {
                            ops.add(
                              PopupMenuItem(
                                value: 'kitchen',
                                child: Row(children: const [
                                  Icon(Icons.restaurant_menu, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Kitchen', style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                            );
                          }
                          return ops;
                        },
                        onSelected: (v) {
                          Future.microtask(() => provider.setCurrentView(v));
                        },
                        child: const Icon(Icons.workspaces_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      if (allowed.contains('reports'))
                        PopupMenuButton<String>(
                          tooltip: 'Reports',
                          offset: const Offset(0, 36),
                          color: const Color(0xFF18181B),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: '0',
                              child: Row(children: const [
                                Icon(Icons.trending_up, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Sales', style: TextStyle(color: Colors.white)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: '1',
                              child: Row(children: const [
                                Icon(Icons.receipt_long, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Orders', style: TextStyle(color: Colors.white)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: '2',
                              child: Row(children: const [
                                Icon(Icons.payments_outlined, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Payment', style: TextStyle(color: Colors.white)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: '3',
                              child: Row(children: const [
                                Icon(Icons.speed, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Performance', style: TextStyle(color: Colors.white)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: '4',
                              child: Row(children: const [
                                Icon(Icons.inventory_2_outlined, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Inventory', style: TextStyle(color: Colors.white)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: '5',
                              child: Row(children: const [
                                Icon(Icons.account_balance, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Financial', style: TextStyle(color: Colors.white)),
                              ]),
                            ),
                          ],
                          onSelected: (v) {
                            final idx = int.tryParse(v) ?? 0;
                            Future.microtask(() {
                              provider.setReportsTabIndex(idx);
                              provider.setCurrentView('reports');
                            });
                          },
                          child: const Icon(Icons.bar_chart, color: Colors.white),
                        ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: 'Ops Center',
                        offset: const Offset(0, 36),
                        color: const Color(0xFF18181B),
                        itemBuilder: (context) {
                          final role = provider.clientRole ?? '';
                          final allowed = AuthHelper.allowedViewsForRole(role);
                          final ops = <PopupMenuEntry<String>>[];
                          if (allowed.contains('tables_manage')) {
                            ops.add(
                              PopupMenuItem(
                                value: 'tables_manage',
                                child: Row(children: const [
                                  Icon(Icons.table_bar, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Tables', style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                            );
                          }
                          if (allowed.contains('menu')) {
                            ops.add(
                              PopupMenuItem(
                                value: 'menu',
                                child: Row(children: const [
                                  Icon(Icons.menu_book_outlined, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Menu', style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                            );
                          }
                          if (allowed.contains('inventory')) {
                            ops.add(
                              PopupMenuItem(
                                value: 'inventory',
                                child: Row(children: const [
                                  Icon(Icons.inventory_2_outlined, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Inventory', style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                            );
                          }
                          if (allowed.contains('expenses')) {
                            ops.add(
                              PopupMenuItem(
                                value: 'expenses',
                                child: Row(children: const [
                                  Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Expenses', style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                            );
                          }
                          if (allowed.contains('employees')) {
                            ops.add(
                              PopupMenuItem(
                                value: 'employees',
                                child: Row(children: const [
                                  Icon(Icons.badge_outlined, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Employees', style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                            );
                          }
                          return ops;
                        },
                        onSelected: (v) {
                          Future.microtask(() => provider.setCurrentView(v));
                        },
                        child: const Icon(Icons.business_center_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      if (allowed.contains('settings'))
                        PopupMenuButton<String>(
                          tooltip: 'Settings',
                          offset: const Offset(0, 36),
                          color: const Color(0xFF18181B),
                          itemBuilder: (context) {
                            final isAdmin = provider.realRole == 'admin';
                            return <PopupMenuEntry<String>>[
                              PopupMenuItem(
                                value: 'printer_settings',
                                child: Row(children: const [
                                  Icon(Icons.print, color: Colors.white, size: 16),
                                  SizedBox(width: 8),
                                  Text('Printer Settings', style: TextStyle(color: Colors.white)),
                                ]),
                              ),
                              if (isAdmin)
                                PopupMenuItem(
                                  value: 'roles',
                                  child: Row(children: const [
                                    Icon(Icons.security, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('Role & Permission', style: TextStyle(color: Colors.white)),
                                  ]),
                                ),
                              if (isAdmin)
                                PopupMenuItem(
                                  value: 'simulation',
                                  child: Row(children: const [
                                    Icon(Icons.theater_comedy, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('Role Play', style: TextStyle(color: Colors.white)),
                                  ]),
                                ),
                              if (isAdmin)
                                PopupMenuItem(
                                  value: 'debug',
                                  child: Row(children: const [
                                    Icon(Icons.bug_report, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('System Diagnostics', style: TextStyle(color: Colors.white)),
                                  ]),
                                ),
                            ];
                          },
                          onSelected: (v) {
                            Future.microtask(() => provider.setCurrentView(v));
                          },
                          child: const Icon(Icons.settings, color: Colors.white),
                        ),
                    ],
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Account',
                      offset: const Offset(0, 36),
                      color: const Color(0xFF18181B),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'logout',
                          child: Row(children: const [
                            Icon(Icons.logout, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Logout', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == 'logout') {
                          final r = context.read<RestaurantProvider>().clientRole;
                          final navigator = Navigator.of(context, rootNavigator: true);
                          Future.microtask(() async {
                            await AuthHelper.logout(role: r);
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          });
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            roleLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        );
      }
    );
  }
}
