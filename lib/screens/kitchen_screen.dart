import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/menu_item.dart';
import '../widgets/app_ui_kit.dart';

class KitchenScreen extends StatelessWidget {
  final bool embedded;
  const KitchenScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final active = provider.orders.where((o) => o.status == 'Preparing' || o.status == 'Ready').toList();
    final menuItems = provider.menuItems;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Kitchen Display', style: AppTextStyles.h2),
          const Spacer(),
          StatusBadge('${active.length} active', color: active.isEmpty ? AppColors.textMuted : AppColors.amber),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: active.isEmpty
              ? const EmptyState(
                  message: 'All clear! No pending orders.',
                  icon: Icons.check_circle_outline,
                )
              : LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth >= 1024 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: active.length,
                    itemBuilder: (_, i) => _KOTCard(
                      order: active[i],
                      menuItems: menuItems,
                    ),
                  );
                }),
        ),
      ]),
    );
  }
}

class _KOTCard extends StatelessWidget {
  final dynamic order;
  final List<MenuItem> menuItems;

  const _KOTCard({required this.order, required this.menuItems});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RestaurantProvider>();
    final isPreparing = order.status == 'Preparing';
    final borderColor = isPreparing ? AppColors.amber : AppColors.cyan;
    final activeItems = (order.items as List).where((x) => !x.isCancelled).toList();

    return AppCard(
      borderColor: borderColor,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────
        Row(children: [
          Expanded(child: Text(order.table as String, style: AppTextStyles.h3.copyWith(color: borderColor))),
          StatusBadge.orderStatus(order.status as String, small: true),
        ]),
        const SizedBox(height: 10),
        const Divider(color: AppColors.border, height: 1),
        const SizedBox(height: 8),

        // ── Items list ─────────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: activeItems.length,
            itemBuilder: (context, i) {
              final it = activeItems[i];
              final addons = ((it.addons ?? []) as List<int>)
                  .map((id) => menuItems.firstWhere((m) => m.id == id,
                      orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: '')).name)
                  .where((n) => n.isNotEmpty)
                  .toList();
              final mods = ((it.modifiers ?? []) as List<Map<String, dynamic>>)
                  .map((m) => m['name']?.toString() ?? '')
                  .where((n) => n.isNotEmpty)
                  .toList();
              final note = (it.instructions ?? '').trim();
              final meta = [...addons, ...mods, if (note.isNotEmpty) 'Note: $note'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  color: AppColors.bg3,
                  padding: const EdgeInsets.all(10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.name as String, style: AppTextStyles.h3),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(meta.join(' · '), style: AppTextStyles.small),
                      ],
                    ])),
                    const SizedBox(width: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('×${it.quantity}', style: TextStyle(color: borderColor, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => showCancelItemDialog(context, order.id as String, it),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.cancel_outlined, color: AppColors.red, size: 18),
                        ),
                      ),
                    ]),
                  ]),
                ),
              );
            },
          ),
        ),

        // ── Action button ──────────────────────────────────
        const SizedBox(height: 8),
        if (isPreparing)
          AppButton.ghost('Mark Ready',
              icon: Icons.check_circle_outline,
              fullWidth: true,
              onPressed: () => provider.markOrderAsReady(order.id as String))
        else
          AppButton('Complete / Picked Up',
              icon: Icons.done_all,
              background: AppColors.blue,
              foreground: Colors.white,
              fullWidth: true,
              onPressed: () => provider.markOrderAsCompleted(order.id as String)),
      ]),
    );
  }
}
