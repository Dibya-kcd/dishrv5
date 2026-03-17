import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../utils/auth_helper.dart';
import '../widgets/app_ui_kit.dart';

class MobileNav extends StatelessWidget {
  final double width;
  const MobileNav({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    if (width >= 1024) return const SizedBox.shrink();

    final rawRole = (provider.clientRole ?? '').trim().toLowerCase();
    final allowed = AuthHelper.allowedViewsForRole(rawRole);

    // All navigable items in priority order.
    // 'settings' is intentionally included — it surfaces all management screens.
    const allItems = [
      _Item('dashboard', 'Live',        Icons.dashboard_outlined),
      _Item('tables',    'Tables',     Icons.table_bar_outlined),
      _Item('takeout',   'Takeout',    Icons.shopping_bag_outlined),
      _Item('kitchen',   'Kitchen',    Icons.restaurant_menu_outlined),
      _Item('reports',   'Reports',    Icons.bar_chart_outlined),
      _Item('menu',      'Menu',       Icons.menu_book_outlined),
      _Item('inventory', 'Inventory',  Icons.inventory_2_outlined),
      _Item('expenses',  'Expenses',   Icons.account_balance_wallet_outlined),
      _Item('employees', 'Staff',      Icons.badge_outlined),
      _Item('settings',  'Settings',   Icons.settings_outlined),
    ];

    final visible = allItems
        .where((it) => allowed.contains(it.id))
        .toList();

    if (visible.isEmpty) return const SizedBox.shrink();

    // First 4 items go in the bar; the rest go in "More"
    const barMax = 4;
    final barItems  = visible.length <= barMax
        ? visible
        : visible.sublist(0, barMax - 1); // leave room for More
    final moreItems = visible.length <= barMax
        ? <_Item>[]
        : visible.sublist(barMax - 1); // overflow items only

    final showMore = moreItems.isNotEmpty;
    final currentView = provider.currentView;
    final moreActive = showMore &&
        moreItems.any((it) => it.id == currentView);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg1,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            // Fixed bar items
            ...barItems.map((it) {
              final active = currentView == it.id;
              return _NavTab(
                icon: it.icon,
                label: it.label,
                active: active,
                onTap: () {
                  provider.setCurrentView(it.id);
                  provider.setMobileMenuOpen(false);
                },
              );
            }),

            // More button (only shows items NOT already in the bar)
            if (showMore)
              _NavTab(
                icon: Icons.apps_outlined,
                label: 'More',
                active: moreActive,
                onTap: () => _showMoreSheet(
                    context, provider, moreItems, currentView),
              ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(
    BuildContext context,
    RestaurantProvider provider,
    List<_Item> items,
    String currentView,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Grid of overflow items
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: items.map((it) {
                    final active = currentView == it.id;
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        provider.setCurrentView(it.id);
                        provider.setMobileMenuOpen(false);
                      },
                      child: SizedBox(
                        width: (MediaQuery.of(ctx).size.width - 32 - 36) / 4,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.amber.withValues(alpha: 0.15)
                                    : AppColors.bg2,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: active
                                      ? AppColors.amber
                                      : AppColors.border,
                                ),
                              ),
                              child: Icon(
                                it.icon,
                                color: active
                                    ? AppColors.amber
                                    : AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              it.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: active
                                    ? AppColors.amber
                                    : AppColors.textSecondary,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav tab button
// ─────────────────────────────────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active indicator line
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 2,
              width: active ? 20 : 0,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Icon(
              icon,
              size: 22,
              color: active ? AppColors.amber : AppColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active ? AppColors.amber : AppColors.textSecondary,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────────────────────────────────────

class _Item {
  final String id;
  final String label;
  final IconData icon;
  const _Item(this.id, this.label, this.icon);
}
