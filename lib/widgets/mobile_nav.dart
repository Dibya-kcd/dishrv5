import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';

class MobileNav extends StatelessWidget {
  final double width;
  const MobileNav({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final isMobile = width < 1024;
    
    if (!isMobile || !provider.mobileMenuOpen) return const SizedBox.shrink();
    
    final items = [
      {'id': 'dashboard', 'label': 'Live Services', 'icon': Icons.wifi_tethering},
      {'id': 'tables', 'label': 'Tables', 'icon': Icons.table_bar},
      {'id': 'takeout', 'label': 'Takeout', 'icon': Icons.shopping_bag_outlined},
      {'id': 'kitchen', 'label': 'Kitchen', 'icon': Icons.restaurant_menu},
      {'id': 'menu', 'label': 'Menu', 'icon': Icons.menu_book_outlined},
      {'id': 'reports', 'label': 'Reports', 'icon': Icons.bar_chart},
      {'id': 'inventory', 'label': 'Inventory', 'icon': Icons.inventory_2_outlined},
      {'id': 'expenses', 'label': 'Expenses', 'icon': Icons.account_balance_wallet_outlined},
      {'id': 'employees', 'label': 'Employees', 'icon': Icons.badge_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: items.map((it) {
          final view = it['id'] as String;
          final active = provider.currentView == view;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton(
              onPressed: () {
                provider.setCurrentView(view);
                provider.setMobileMenuOpen(false);
              },
              style: TextButton.styleFrom(
                backgroundColor: active ? const Color(0xFFF59E0B) : const Color(0xFF27272A),
                foregroundColor: active ? Colors.white : const Color(0xFFA1A1AA),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(children: [
                Icon(it['icon'] as IconData), 
                const SizedBox(width: 8), 
                Text(it['label'] as String)
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}
