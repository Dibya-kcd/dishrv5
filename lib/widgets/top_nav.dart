import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';

class TopNav extends StatelessWidget {
  const TopNav({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 1024;
        
        final items = [
          {'id': 'dashboard', 'label': 'Live Services', 'icon': Icons.wifi_tethering},
        ];

        return Column(
          children: [
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
                    Row(children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: provider.isOnline ? (provider.pendingOpsCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)) : const Color(0xFFEF4444),
                          borderRadius: const BorderRadius.all(Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('RestoPOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      if (provider.pendingOpsCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(6)),
                          child: Text('${provider.pendingOpsCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ]),
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
                                  // Handled in provider implicitly or we can notify
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
                    PopupMenuButton<String>(
                      tooltip: 'Operations',
                      offset: const Offset(0, 36),
                      color: const Color(0xFF18181B),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'tables',
                          child: Row(children: const [
                            Icon(Icons.table_bar, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Tables', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'takeout',
                          child: Row(children: const [
                            Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Takeout', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'kitchen',
                          child: Row(children: const [
                            Icon(Icons.restaurant_menu, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Kitchen', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                      ],
                      onSelected: (v) => provider.setCurrentView(v),
                      child: const Icon(Icons.workspaces_outlined, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
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
                        provider.setReportsTabIndex(idx);
                        provider.setCurrentView('reports');
                      },
                      child: const Icon(Icons.bar_chart, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      tooltip: 'Ops Center',
                      offset: const Offset(0, 36),
                      color: const Color(0xFF18181B),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'tables_manage',
                          child: Row(children: const [
                            Icon(Icons.table_bar, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Tables', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'menu',
                          child: Row(children: const [
                            Icon(Icons.menu_book_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Menu', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'inventory',
                          child: Row(children: const [
                            Icon(Icons.inventory_2_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Inventory', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'expenses',
                          child: Row(children: const [
                            Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Expenses', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'employees',
                          child: Row(children: const [
                            Icon(Icons.badge_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Employees', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                      ],
                      onSelected: (v) => provider.setCurrentView(v),
                      child: const Icon(Icons.business_center_outlined, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      tooltip: 'Settings',
                      offset: const Offset(0, 36),
                      color: const Color(0xFF18181B),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'admin',
                          child: Row(children: const [
                            Icon(Icons.person, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Admin', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                        PopupMenuItem(
                          value: 'printer',
                          child: Row(children: const [
                            Icon(Icons.print, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('Printer Settings', style: TextStyle(color: Colors.white)),
                          ]),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == 'admin') {
                          provider.setCurrentView('employees');
                        } else if (v == 'printer') {
                          provider.setCurrentView('printer_settings');
                        }
                      },
                      child: const Icon(Icons.settings, color: Colors.white),
                    ),
                    if (isMobile)
                      IconButton(
                        onPressed: () => provider.setMobileMenuOpen(!provider.mobileMenuOpen),
                        icon: Icon(provider.mobileMenuOpen ? Icons.close : Icons.menu, color: Colors.white),
                      ),
                    if (!isMobile)
                      const SizedBox.shrink(),
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
