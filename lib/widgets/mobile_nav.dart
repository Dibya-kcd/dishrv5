import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../utils/auth_helper.dart';

class MobileNav extends StatelessWidget {
  final double width;
  const MobileNav({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final isMobile = width < 1024;
    final rawRole = (provider.clientRole ?? '').trim().toLowerCase();
    final roleLabel = rawRole.isEmpty ? 'Live' : '${rawRole[0].toUpperCase()}${rawRole.substring(1)}';
    
    if (!isMobile) return const SizedBox.shrink();
    
    final items = [
      {'id': 'dashboard', 'label': '$roleLabel Services', 'icon': Icons.wifi_tethering},
      {'id': 'tables', 'label': 'Tables', 'icon': Icons.table_bar},
      {'id': 'takeout', 'label': 'Takeout', 'icon': Icons.shopping_bag_outlined},
      {'id': 'kitchen', 'label': 'Kitchen', 'icon': Icons.restaurant_menu},
      {'id': 'menu', 'label': 'Menu', 'icon': Icons.menu_book_outlined},
      {'id': 'reports', 'label': 'Reports', 'icon': Icons.bar_chart},
      {'id': 'inventory', 'label': 'Inventory', 'icon': Icons.inventory_2_outlined},
      {'id': 'expenses', 'label': 'Expenses', 'icon': Icons.account_balance_wallet_outlined},
      {'id': 'employees', 'label': 'Employees', 'icon': Icons.badge_outlined},
      {'id': 'settings', 'label': 'Settings', 'icon': Icons.settings_outlined},
    ];

    final visibleItems = items.where((it) {
      final allowed = AuthHelper.allowedViewsForRole(rawRole);
      final view = it['id'] as String;
      return allowed.contains(view);
    }).toList()
      ..sort((a, b) {
        final order = {
          'dashboard': 0,
          'tables': 1,
          'takeout': 2,
          'kitchen': 3,
          'menu': 4,
          'inventory': 5,
          'reports': 6,
          'expenses': 7,
          'employees': 8,
          'settings': 9,
        };
        final ai = order[a['id']] ?? 999;
        final bi = order[b['id']] ?? 999;
        return ai.compareTo(bi);
      });

    if (visibleItems.isEmpty) return const SizedBox.shrink();

    final primary = visibleItems.length > 3 ? visibleItems.take(3).toList() : visibleItems;
    final hasOverflow = visibleItems.length > 3;
    final barItems = List<Map<String, Object>>.from(primary.cast<Map<String, Object>>());
    if (hasOverflow) {
      barItems.add({'id': '_more', 'label': 'More', 'icon': Icons.apps});
    }

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          border: Border(top: BorderSide(color: Color(0xFF27272A))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: barItems.map((it) {
            final view = it['id'] as String;
            final active = provider.currentView == view || (view == '_more' && hasOverflow && provider.currentView != (primary.isNotEmpty ? primary.first['id'] : null));
            return Expanded(
              child: TextButton(
                onPressed: () async {
                  if (view == '_more') {
                    await showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF18181B),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      builder: (ctx) {
                        return SafeArea(
                          top: false,
                          child: ListView(
                            shrinkWrap: true,
                            children: visibleItems.map((v) {
                              final id = v['id'] as String;
                              final activeView = provider.currentView == id;
                              return ListTile(
                                leading: Icon(v['icon'] as IconData, color: Colors.white),
                                title: Text(v['label'] as String, style: const TextStyle(color: Colors.white)),
                                trailing: activeView ? const Icon(Icons.check, color: Color(0xFFF59E0B)) : null,
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  provider.setCurrentView(id);
                                },
                              );
                            }).toList(),
                          ),
                        );
                      },
                    );
                  } else {
                    provider.setCurrentView(view);
                    provider.setMobileMenuOpen(false);
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: active ? const Color(0xFFF59E0B) : const Color(0xFFA1A1AA),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  minimumSize: const Size(0, 44),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: Icon(it['icon'] as IconData, size: 22),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
