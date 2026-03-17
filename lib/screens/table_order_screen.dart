import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import '../widgets/app_ui_kit.dart';

class TableOrderScreen extends StatefulWidget {
  const TableOrderScreen({super.key});
  @override
  State<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends State<TableOrderScreen> {
  String _searchQuery = '';

  // ── Menu filtering (single source of truth) ──────────────────────────────
  List<MenuItem> _filtered(List<MenuItem> all, String category) {
    final base = category == 'All'
        ? all
        : all.where((m) => m.category == category).toList();
    final available = base.where(menuIsAvailable).toList();
    if (_searchQuery.isEmpty) return available;
    final q = _searchQuery.toLowerCase();
    return available
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.category.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider      = context.watch<RestaurantProvider>();
    final selectedTable = provider.selectedTable;
    final cart          = provider.cart;
    final activeItems   = provider.getActiveTableItems(selectedTable?.orderId);
    final cancelledItems= provider.getCancelledItems(selectedTable?.orderId);
    final items         = _filtered(provider.menuItems, provider.selectedCategory);

    // ── Cart panel (shared between all breakpoints) ───────────────────────
    Widget cartPanel = _CartPanel(
      selectedTable: selectedTable,
      cart: cart,
      activeItems: activeItems,
      cancelledItems: cancelledItems,
      provider: provider,
    );

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;

      // ── Header bar ──────────────────────────────────────────────────────
      Widget header({bool showBack = true}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                'Table ${selectedTable?.number}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
              const SizedBox(width: 10),
              StatusBadge.tableStatus(selectedTable?.status ?? 'available'),
            ]),
            Text(
              'Take order · ${selectedTable?.capacity} guests',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ]),
          if (showBack)
            AppButton.ghost(
              'Back',
              onPressed: () => provider.setCurrentView('tables'),
            ),
        ],
      );

      // ── Filter bar ──────────────────────────────────────────────────────
      Widget filterBar() => MenuFilterBar(
        categories: provider.categories,
        selectedCategory: provider.selectedCategory,
        onCategoryChanged: provider.setSelectedCategory,
        searchQuery: _searchQuery,
        onSearchChanged: (q) => setState(() => _searchQuery = q),
      );

      // ── Menu grid ───────────────────────────────────────────────────────
      Widget menuGrid({required int crossAxisCount, double aspectRatio = 0.9}) {
        if (items.isEmpty) {
          return const EmptyState(
              message: 'No items match', icon: Icons.search_off_outlined);
        }
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: aspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _MenuTile(
            item: items[i],
            onTap: () => provider.addToCart(items[i]),
          ),
        );
      }

      // ─────────────────────────────────────────────────────────────────────
      // MOBILE  (< 600)
      // ─────────────────────────────────────────────────────────────────────
      if (width < 600) {
        final cartCount = cart.fold<int>(0, (s, i) => s + i.quantity);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(children: [
            header(showBack: true),
            const SizedBox(height: 12),

            // Filter bar + cart icon inline
            Row(children: [
              Expanded(child: filterBar()),
              const SizedBox(width: 8),
              _CartBadgeButton(
                count: cartCount,
                onTap: () => _openCartSheet(context, cartPanel),
              ),
            ]),
            const SizedBox(height: 12),

            Expanded(
              child: menuGrid(
                crossAxisCount: 2,
                aspectRatio: 0.95,
              ),
            ),
          ]),
        );
      }

      // ─────────────────────────────────────────────────────────────────────
      // TABLET / DESKTOP  (>= 600)
      // ─────────────────────────────────────────────────────────────────────
      final cartWidth = width >= 1024 ? 360.0 : 300.0;
      final crossAxis = ((width - cartWidth - 32) / 180).floor().clamp(2, 6);

      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Left: menu
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              header(),
              const SizedBox(height: 14),
              filterBar(),
              const SizedBox(height: 12),
              Expanded(child: menuGrid(crossAxisCount: crossAxis)),
            ]),
          ),
        ),
        // Right: cart
        SizedBox(width: cartWidth, child: cartPanel),
      ]);
    });
  }

  void _openCartSheet(BuildContext context, Widget cartPanel) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bg1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: cartPanel,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu tile
// ─────────────────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;
  const _MenuTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildMenuImage(item.image, size: 34),
            const SizedBox(height: 6),
            Text(item.name,
                style: AppTextStyles.h3,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text('₹${item.price}',
                style: const TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart badge icon button (mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _CartBadgeButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CartBadgeButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
        onPressed: onTap,
        tooltip: 'Cart',
      ),
      if (count > 0)
        Positioned(
          right: 4,
          top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: const BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.all(Radius.circular(10))),
            child: Text(
              '$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart panel
// ─────────────────────────────────────────────────────────────────────────────

class _CartPanel extends StatelessWidget {
  final dynamic selectedTable;
  final List<CartItem> cart;
  final List<CartItem> activeItems;
  final List<CartItem> cancelledItems;
  final RestaurantProvider provider;

  const _CartPanel({
    required this.selectedTable,
    required this.cart,
    required this.activeItems,
    required this.cancelledItems,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final total = provider.taxSettings.totalFor(
      provider.cartTotal(cart) + provider.cartTotal(activeItems),
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Table ${selectedTable?.number} Order',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text('${activeItems.length + cart.length} items',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]),
              if (activeItems.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.cancel, color: AppColors.red),
                  tooltip: 'Cancel Entire Order',
                  onPressed: () => showCancelOrderDialog(
                      context, selectedTable?.orderId ?? ''),
                ),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: (cart.isEmpty && activeItems.isEmpty)
              ? const EmptyState(
                  message: 'No items added',
                  icon: Icons.shopping_bag_outlined)
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (activeItems.isNotEmpty) ...[
                      _sectionLabel('Ordered Items', AppColors.textSecondary),
                      ...activeItems.map((item) => _ActiveItemCard(
                          item: item, provider: provider)),
                      const Divider(color: AppColors.border),
                    ],
                    if (cancelledItems.isNotEmpty) ...[
                      _sectionLabel('Cancelled', AppColors.red),
                      ...cancelledItems.map((item) => _CancelledItemCard(item: item)),
                      const Divider(color: AppColors.border),
                    ],
                    if (cart.isNotEmpty) ...[
                      _sectionLabel('New Items', AppColors.green),
                      ...cart.map((item) =>
                          _CartItemCard(item: item, provider: provider)),
                    ],
                  ],
                ),
        ),

        // Footer: total + actions
        if (cart.isNotEmpty || activeItems.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text('₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                if (cart.isNotEmpty) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedTable?.status == 'billing'
                          ? null
                          : () => provider.generateKOT(
                              cart, 'Table ${selectedTable?.number}', true, context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white),
                      child: const Text('Send KOT'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedTable?.status == 'billing'
                        ? () => provider.openPaymentModal(
                            activeItems, 'Table ${selectedTable?.number}', true)
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white),
                    child: const Text('Payment'),
                  ),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart item cards
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveItemCard extends StatelessWidget {
  final dynamic item;
  final RestaurantProvider provider;
  const _ActiveItemCard({required this.item, required this.provider});

  @override
  Widget build(BuildContext context) {
    final mi = provider.menuItems.firstWhere((m) => m.id == item.id,
        orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''));
    final mods = mi.id != -1 ? mi.modifiers : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.bg2, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Text(item.name,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => provider.removeActiveItem(item.id),
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.red, size: 18),
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              padding: EdgeInsets.zero,
            ),
          ]),
          Row(children: [
            _QtyControl(
              qty: item.quantity,
              onDec: () => provider.updateActiveItemQuantity(item.id, -1),
              onInc: () => provider.updateActiveItemQuantity(item.id, 1),
            ),
            const SizedBox(width: 10),
            Text('₹${item.price * item.quantity}',
                style: const TextStyle(color: Colors.white)),
          ]),
        ]),
        const SizedBox(height: 8),
        _InstructionsField(
          initial: item.instructions ?? '',
          onChanged: (v) => provider.updateActiveItemInstructions(item.id, v),
        ),
        if (mods.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ChipsRow(
            label: 'Modifiers',
            chips: mods.map((m) {
              final sel = (item.modifiers ?? []).any((mm) =>
                  mm['name']?.toString() == m['name']?.toString() &&
                  mm['priceDelta']?.toString() == m['priceDelta']?.toString());
              final delta = int.tryParse(m['priceDelta']?.toString() ?? '0') ?? 0;
              return _Chip(
                label: '${m['name']} ${delta >= 0 ? '+' : ''}$delta',
                selected: sel,
                onTap: () => provider.toggleActiveModifierForItem(item.id, m),
              );
            }).toList(),
          ),
        ],
        _AddonsRow(
          suggestions: provider.getTopUpSuggestionsForItem(item.id),
          addons: item.addons ?? [],
          onToggle: (id) => provider.toggleActiveAddonForItem(item.id, id),
        ),
      ]),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final dynamic item;
  final RestaurantProvider provider;
  const _CartItemCard({required this.item, required this.provider});

  @override
  Widget build(BuildContext context) {
    final mi = provider.menuItems.firstWhere((m) => m.id == item.id,
        orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''));
    final mods      = mi.id != -1 ? mi.modifiers : <Map<String, dynamic>>[];
    final templates = mi.id != -1 ? mi.instructionTemplates : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.bg2, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(item.name, style: const TextStyle(color: Colors.white)),
          IconButton(
            onPressed: () => provider.removeFromCart(item.id),
            icon: const Icon(Icons.delete_outline, color: AppColors.red, size: 18),
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            padding: EdgeInsets.zero,
          ),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _QtyControl(
            qty: item.quantity,
            onDec: () => provider.updateQuantity(item.id, -1),
            onInc: () => provider.updateQuantity(item.id, 1),
          ),
          Text('₹${item.price * item.quantity}',
              style: const TextStyle(color: Colors.white)),
        ]),
        const SizedBox(height: 8),
        _InstructionsField(
          initial: item.instructions ?? '',
          onChanged: (v) => provider.updateItemInstructions(item.id, v),
        ),
        if (templates.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ChipsRow(
            label: 'Templates',
            chips: templates.map((t) => _Chip(
              label: t,
              selected: false,
              onTap: () {
                final base = (item.instructions ?? '').trim();
                provider.updateItemInstructions(
                    item.id, base.isEmpty ? t : '$base | $t');
              },
            )).toList(),
          ),
        ],
        if (mods.isNotEmpty) ...[
          const SizedBox(height: 6),
          _ChipsRow(
            label: 'Modifiers',
            chips: mods.map((m) {
              final sel = (item.modifiers ?? []).any((mm) =>
                  mm['name']?.toString() == m['name']?.toString() &&
                  mm['priceDelta']?.toString() == m['priceDelta']?.toString());
              final delta = int.tryParse(m['priceDelta']?.toString() ?? '0') ?? 0;
              return _Chip(
                label: '${m['name']} ${delta >= 0 ? '+' : ''}$delta',
                selected: sel,
                onTap: () => provider.toggleModifierForItem(item.id, m),
              );
            }).toList(),
          ),
        ],
        _AddonsRow(
          suggestions: provider.getTopUpSuggestionsForItem(item.id),
          addons: item.addons ?? [],
          onToggle: (id) => provider.toggleAddonForItem(item.id, id),
          onUpsell: (s) => provider.addUpsellToCart(s),
        ),
      ]),
    );
  }
}

class _CancelledItemCard extends StatelessWidget {
  final dynamic item;
  const _CancelledItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(item.name,
              style: const TextStyle(
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough)),
          Text('x${item.quantity}',
              style: const TextStyle(color: Colors.grey)),
        ]),
        if (item.cancellationReason != null)
          Text('Reason: ${item.cancellationReason}',
              style: const TextStyle(color: AppColors.red, fontSize: 10)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _QtyControl extends StatelessWidget {
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _QtyControl({required this.qty, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.bg0, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          onPressed: onDec,
          icon: const Icon(Icons.remove, color: Colors.white),
          constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          padding: EdgeInsets.zero,
        ),
        SizedBox(
          width: 28,
          child: Center(
            child: Text('$qty',
                style: const TextStyle(color: Colors.white)),
          ),
        ),
        IconButton(
          onPressed: onInc,
          icon: const Icon(Icons.add, color: Colors.white),
          constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          padding: EdgeInsets.zero,
        ),
      ]),
    );
  }
}

class _InstructionsField extends StatelessWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  const _InstructionsField({required this.initial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: initial),
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Cooking instructions…',
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: AppColors.bg0,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final String label;
  final List<_Chip> chips;
  const _ChipsRow({required this.label, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 11)),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 4, children: chips),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber.withValues(alpha: 0.2) : AppColors.bg0,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.amber : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.amber : AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _AddonsRow extends StatelessWidget {
  final List suggestions;
  final List addons;
  final ValueChanged<int> onToggle;
  final ValueChanged? onUpsell;
  const _AddonsRow(
      {required this.suggestions,
      required this.addons,
      required this.onToggle,
      this.onUpsell});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      const Text('Add-ons',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: suggestions.map((s) {
          final sel = addons.contains(s.id);
          return GestureDetector(
            onTap: () => onToggle(s.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: sel ? AppColors.green.withValues(alpha: 0.2) : AppColors.bg0,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel ? AppColors.green : AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(s.name,
                    style: TextStyle(
                        color: sel ? AppColors.green : AppColors.textSecondary,
                        fontSize: 11)),
                const SizedBox(width: 4),
                Icon(sel ? Icons.check : Icons.add,
                    size: 12,
                    color: sel ? AppColors.green : AppColors.textSecondary),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}
