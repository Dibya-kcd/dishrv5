import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/menu_item.dart';
 

class TableOrderScreen extends StatelessWidget {
  const TableOrderScreen({super.key});

  void _showCancelOrderDialog(BuildContext context, String? orderId) {
    if (orderId == null) return;
    
    final reasons = ['Customer left', 'Emergency', 'Service too slow', 'Mistake', 'Other'];
    String selectedReason = reasons.first;
    bool isWastage = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          title: const Text('Cancel Entire Order?', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will cancel all items in the order. This action cannot be undone.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setState(() => selectedReason = v!),
                dropdownColor: const Color(0xFF27272A),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Mark as Wastage', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Ingredients will be deducted', style: TextStyle(color: Colors.grey)),
                value: isWastage,
                onChanged: (v) => setState(() => isWastage = v!),
                activeColor: Colors.red,
                checkColor: Colors.white,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                ctx.read<RestaurantProvider>().cancelOrder(orderId, selectedReason, isWastage);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Confirm Cancel Order'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final selectedTable = provider.selectedTable;
    final cart = provider.cart;
    final menuItems = provider.menuItems;
    final activeItems = provider.getActiveTableItems(selectedTable?.orderId);
    final cancelledItems = provider.getCancelledItems(selectedTable?.orderId);
 

    Color getStatusColor(String status) {
      switch (status) {
        case 'available': return const Color(0xFF10B981);
        case 'occupied': return const Color(0xFFF59E0B);
        case 'preparing': return const Color(0xFFEAB308);
        case 'serving': return const Color(0xFF3B82F6);
        case 'billing': return const Color(0xFFA855F7);
        default: return const Color(0xFF71717A);
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      Widget cartPanel = Container(
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          border: Border(left: BorderSide(color: const Color(0xFF27272A))),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF27272A)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Table ${selectedTable?.number} Order', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('${activeItems.length + cart.length} items', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                    ],
                  ),
                  if (activeItems.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      tooltip: 'Cancel Entire Order',
                      onPressed: () => _showCancelOrderDialog(context, selectedTable?.orderId),
                    ),
                ],
              ),
            ),
            Expanded(
              child: (cart.isEmpty && activeItems.isEmpty)
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.shopping_bag_outlined, color: Color(0xFF71717A), size: 48), SizedBox(height: 8), Text('No items added', style: TextStyle(color: Color(0xFFA1A1AA)))]))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (activeItems.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text('Ordered Items', style: TextStyle(color: Color(0xFF71717A), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          ...activeItems.map((item) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Row(children: [
                                        Text(item.name, style: const TextStyle(color: Colors.white)),
                                        const SizedBox(width: 8),
                                        IconButton(onPressed: () => provider.removeActiveItem(item.id), icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18)),
                                      ]),
                                      Row(children: [
                                        Container(
                                          decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(8)),
                                          child: Row(children: [
                                            IconButton(onPressed: () => provider.updateActiveItemQuantity(item.id, -1), icon: const Icon(Icons.remove, color: Colors.white), constraints: const BoxConstraints.tightFor(width: 32, height: 32)),
                                            SizedBox(width: 32, child: Center(child: Text('${item.quantity}', style: const TextStyle(color: Colors.white)))),
                                            IconButton(onPressed: () => provider.updateActiveItemQuantity(item.id, 1), icon: const Icon(Icons.add, color: Colors.white), constraints: const BoxConstraints.tightFor(width: 32, height: 32)),
                                          ]),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('₹${item.price * item.quantity}', style: const TextStyle(color: Colors.white)),
                                      ]),
                                    ]),
                                    const SizedBox(height: 8),
                                    TextField(
                                      onChanged: (v) => provider.updateActiveItemInstructions(item.id, v),
                                      decoration: const InputDecoration(hintText: 'Cooking instructions (e.g., no onions)'),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Modifiers', style: const TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                                    ),
                                    const SizedBox(height: 6),
                                    Builder(builder: (_) {
                                      final mi = provider.menuItems.firstWhere((m) => m.id == item.id, orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''));
                                      final mods = mi.id != -1 ? mi.modifiers : <Map<String, dynamic>>[];
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: mods.map((m) {
                                          final selected = (item.modifiers ?? []).any((mm) => (mm['name']?.toString() ?? '') == (m['name']?.toString() ?? '') && (mm['priceDelta']?.toString() ?? '') == (m['priceDelta']?.toString() ?? ''));
                                          final label = '${m['name'] ?? ''} ${((int.tryParse((m['priceDelta'] ?? '0').toString()) ?? 0) >= 0) ? '+' : ''}${m['priceDelta'] ?? 0}';
                                          return ChoiceChip(
                                            label: Text(label),
                                            selected: selected,
                                            onSelected: (_) => provider.toggleActiveModifierForItem(item.id, m),
                                          );
                                        }).toList(),
                                      );
                                    }),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Add-ons', style: const TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: provider.getTopUpSuggestionsForItem(item.id).map((s) {
                                        final selected = (item.addons ?? []).contains(s.id);
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: selected ? const Color(0xFF10B981) : const Color(0xFF18181B),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: const Color(0xFF27272A)),
                                          ),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            Text(s.name, style: TextStyle(color: selected ? Colors.white : const Color(0xFFA1A1AA))),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              onPressed: () => provider.toggleActiveAddonForItem(item.id, s.id),
                                              icon: Icon(selected ? Icons.check_circle : Icons.add_circle, size: 16, color: selected ? Colors.white : const Color(0xFFA1A1AA)),
                                              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                                              padding: EdgeInsets.zero,
                                            ),
                                          ]),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(color: Color(0xFF27272A)),
                        ],
                        if (cancelledItems.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Cancelled Items', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          ...cancelledItems.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27272A).withValues(alpha: 0.5), 
                              borderRadius: BorderRadius.circular(8), 
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3))
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(item.name, style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                  Text('x${item.quantity}', style: const TextStyle(color: Colors.grey)),
                                ]),
                                if (item.cancellationReason != null)
                                  Text('Reason: ${item.cancellationReason}', style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                              ],
                            ),
                          )),
                          const Divider(color: Color(0xFF27272A)),
                        ],
                        if (cart.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('New Items', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          ...cart.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(item.name, style: const TextStyle(color: Colors.white)),
                                  IconButton(onPressed: () => provider.removeFromCart(item.id), icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18)),
                                ]),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Container(
                                    decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(8)),
                                    child: Row(children: [
                                      IconButton(onPressed: () => provider.updateQuantity(item.id, -1), icon: const Icon(Icons.remove, color: Colors.white), constraints: const BoxConstraints.tightFor(width: 32, height: 32)),
                                      SizedBox(width: 32, child: Center(child: Text('${item.quantity}', style: const TextStyle(color: Colors.white)))),
                                      IconButton(onPressed: () => provider.updateQuantity(item.id, 1), icon: const Icon(Icons.add, color: Colors.white), constraints: const BoxConstraints.tightFor(width: 32, height: 32)),
                                    ]),
                                  ),
                                  Text('₹${item.price * item.quantity}', style: const TextStyle(color: Colors.white)),
                                ]),
                                const SizedBox(height: 8),
                                TextField(
                                  onChanged: (v) => provider.updateItemInstructions(item.id, v),
                                  decoration: const InputDecoration(hintText: 'Cooking instructions (e.g., no onions)'),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Templates', style: const TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                                ),
                                const SizedBox(height: 6),
                                Builder(builder: (_) {
                                  final mi = provider.menuItems.firstWhere((m) => m.id == item.id, orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''));
                                  final templates = mi.id != -1 ? mi.instructionTemplates : <String>[];
                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: templates.map((t) {
                                      return ChoiceChip(
                                        label: Text(t),
                                        selected: false,
                                        onSelected: (_) {
                                          final base = (item.instructions ?? '').trim();
                                          final next = base.isEmpty ? t : '$base | $t';
                                          provider.updateItemInstructions(item.id, next);
                                        },
                                      );
                                    }).toList(),
                                  );
                                }),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Suggestions', style: const TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Modifiers', style: const TextStyle(color: Color(0xFF71717A), fontSize: 12)),
                                ),
                                const SizedBox(height: 6),
                                Builder(builder: (_) {
                                  final mi = provider.menuItems.firstWhere((m) => m.id == item.id, orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''));
                                  final mods = mi.id != -1 ? mi.modifiers : <Map<String, dynamic>>[];
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: mods.map((m) {
                                      final selected = (item.modifiers ?? []).any((mm) => (mm['name']?.toString() ?? '') == (m['name']?.toString() ?? '') && (mm['priceDelta']?.toString() ?? '') == (m['priceDelta']?.toString() ?? ''));
                                      final label = '${m['name'] ?? ''} ${((int.tryParse((m['priceDelta'] ?? '0').toString()) ?? 0) >= 0) ? '+' : ''}${m['priceDelta'] ?? 0}';
                                      return ChoiceChip(
                                        label: Text(label),
                                        selected: selected,
                                        onSelected: (_) => provider.toggleModifierForItem(item.id, m),
                                      );
                                    }).toList(),
                                  );
                                }),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: provider.getTopUpSuggestionsForItem(item.id).map((s) {
                                    final selected = (item.addons ?? []).contains(s.id);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: selected ? const Color(0xFF10B981) : const Color(0xFF18181B),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFF27272A)),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Text(s.name, style: TextStyle(color: selected ? Colors.white : const Color(0xFFA1A1AA))),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          onPressed: () => provider.addUpsellToCart(s),
                                          icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                                          constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                                          padding: EdgeInsets.zero,
                                        ),
                                        IconButton(
                                          onPressed: () => provider.toggleAddonForItem(item.id, s.id),
                                          icon: Icon(selected ? Icons.check_circle : Icons.add_circle, size: 16, color: selected ? Colors.white : const Color(0xFFA1A1AA)),
                                          constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ]),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          )),
                        ],
                        if (cancelledItems.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Cancelled Items', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          ...cancelledItems.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFF27272A).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(item.name, style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                  Text('₹${item.price * item.quantity}', style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                ]),
                                if (item.cancellationReason != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('Reason: ${item.cancellationReason}', style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                                  ),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
            ),
            if (cart.isNotEmpty || activeItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF27272A)))),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('₹${((provider.cartTotal(cart) + provider.cartTotal(activeItems)) * 1.05).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (cart.isNotEmpty)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (selectedTable?.status == 'billing') ? null : () => provider.generateKOT(cart, 'Table ${selectedTable?.number}', true, context),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white),
                        child: const Text('Send KOT'),
                      ),
                    ),
                    if (cart.isNotEmpty && (activeItems.isNotEmpty || cart.isNotEmpty))
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (selectedTable?.status == 'billing') ? () => provider.openPaymentModal(activeItems, 'Table ${selectedTable?.number}', true) : null,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                        child: const Text('Payment'),
                      ),
                    ),
                  ]),
                ]),
              ),
          ],
        ),
      );
      if (width < 600) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Table ${selectedTable?.number}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: getStatusColor(selectedTable?.status ?? 'available').withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: getStatusColor(selectedTable?.status ?? 'available')),
                              ),
                              child: Text(
                                (selectedTable?.status ?? 'available').toUpperCase(),
                                style: TextStyle(
                                  color: getStatusColor(selectedTable?.status ?? 'available'),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text('Take order for ${selectedTable?.capacity} guests', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                      ],
                    ),
                    Row(children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                useRootNavigator: true,
                                isScrollControlled: true,
                                backgroundColor: const Color(0xFF18181B),
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                                builder: (_) {
                                  return SafeArea(
                                    child: SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.7,
                                      child: cartPanel,
                                    ),
                                  );
                                },
                              );
                            },
                            tooltip: 'Open Cart',
                          ),
                          if (cart.fold<int>(0, (s, i) => s + i.quantity) > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(color: Color(0xFFEF4444), borderRadius: BorderRadius.all(Radius.circular(10))),
                                child: Text(
                                  '${cart.fold<int>(0, (s, i) => s + i.quantity)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          provider.setCurrentView('tables');
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF27272A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Back'),
                      ),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: provider.categories.map((c) {
                      final active = provider.selectedCategory == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton(
                          onPressed: () => provider.setSelectedCategory(c),
                          style: TextButton.styleFrom(
                            backgroundColor: active ? const Color(0xFFF59E0B) : const Color(0xFF18181B),
                            foregroundColor: active ? Colors.white : const Color(0xFFA1A1AA),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(c),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, c) {
                  final cross = 2;
                  final baseItems = provider.selectedCategory == 'All' ? menuItems : menuItems.where((m) => m.category == provider.selectedCategory).toList();
                  bool isAvailable(item) {
                    if (item.soldOut == true) return false;
                    final now = DateTime.now();
                    final days = item.availableDays;
                    final dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
                    final today = dayMap[now.weekday]!;
                    if (!days.contains(today)) return false;
                    if (item.availableStart != null && item.availableEnd != null && item.availableStart!.isNotEmpty && item.availableEnd!.isNotEmpty) {
                      final partsS = item.availableStart!.split(':');
                      final partsE = item.availableEnd!.split(':');
                      final sH = int.tryParse(partsS[0]) ?? 0;
                      final sM = int.tryParse(partsS.length > 1 ? partsS[1] : '0') ?? 0;
                      final eH = int.tryParse(partsE[0]) ?? 23;
                      final eM = int.tryParse(partsE.length > 1 ? partsE[1] : '59') ?? 59;
                      final start = TimeOfDay(hour: sH, minute: sM);
                      final end = TimeOfDay(hour: eH, minute: eM);
                      final nowTod = TimeOfDay.fromDateTime(now);
                      final nowMin = nowTod.hour * 60 + nowTod.minute;
                      final sMin = start.hour * 60 + start.minute;
                      final eMin = end.hour * 60 + end.minute;
                      if (nowMin < sMin || nowMin > eMin) return false;
                    }
                    return true;
                  }
                  final items = baseItems.where(isAvailable).toList();
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return InkWell(
                        onTap: () => provider.addToCart(item),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF27272A)),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.image, style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 6),
                              Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('₹${item.price}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      } else {
        final isDesktop = width >= 1024;
        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Table ${selectedTable?.number}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(selectedTable?.status ?? 'available').withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: getStatusColor(selectedTable?.status ?? 'available')),
                                    ),
                                    child: Text(
                                      (selectedTable?.status ?? 'available').toUpperCase(),
                                      style: TextStyle(
                                        color: getStatusColor(selectedTable?.status ?? 'available'),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: const Color(0xFF18181B),
                                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                                        builder: (_) {
                                          final cats = context.read<RestaurantProvider>().categories;
                                          final current = context.read<RestaurantProvider>().selectedCategory;
                                          return Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Category Filter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: cats.map((c) {
                                                    final selected = c == current;
                                                    return FilterChip(
                                                      selected: selected,
                                                      label: Text(c),
                                                      onSelected: (_) {
                                                        context.read<RestaurantProvider>().setSelectedCategory(c);
                                                        Navigator.pop(context);
                                                      },
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    icon: const Icon(Icons.tune, color: Colors.white),
                                    tooltip: 'Filters',
                                  ),
                                ],
                              ),
                              Text('Take order for ${selectedTable?.capacity} guests', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              provider.setCurrentView('tables');
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF27272A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Back'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(builder: (context, c) {
                          final centerWidth = c.maxWidth;
                          final minTile = 180.0;
                          final cross = (centerWidth / minTile).floor().clamp(3, 6);
                          final baseItems = provider.selectedCategory == 'All' ? menuItems : menuItems.where((m) => m.category == provider.selectedCategory).toList();
                          bool isAvailable(item) {
                            if (item.soldOut == true) return false;
                            final now = DateTime.now();
                            final days = item.availableDays;
                            final dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
                            final today = dayMap[now.weekday]!;
                            if (!days.contains(today)) return false;
                            if (item.availableStart != null && item.availableEnd != null && item.availableStart!.isNotEmpty && item.availableEnd!.isNotEmpty) {
                              final partsS = item.availableStart!.split(':');
                              final partsE = item.availableEnd!.split(':');
                              final sH = int.tryParse(partsS[0]) ?? 0;
                              final sM = int.tryParse(partsS.length > 1 ? partsS[1] : '0') ?? 0;
                              final eH = int.tryParse(partsE[0]) ?? 23;
                              final eM = int.tryParse(partsE.length > 1 ? partsE[1] : '59') ?? 59;
                              final start = TimeOfDay(hour: sH, minute: sM);
                              final end = TimeOfDay(hour: eH, minute: eM);
                              final nowTod = TimeOfDay.fromDateTime(now);
                              final nowMin = nowTod.hour * 60 + nowTod.minute;
                              final sMin = start.hour * 60 + start.minute;
                              final eMin = end.hour * 60 + end.minute;
                              if (nowMin < sMin || nowMin > eMin) return false;
                            }
                            return true;
                          }
                          final items = baseItems.where(isAvailable).toList();
                          return GridView.builder(
                            shrinkWrap: false,
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cross,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];
                              return InkWell(
                                onTap: () => provider.addToCart(item),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF18181B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF27272A)),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.image, style: const TextStyle(fontSize: 32)),
                                      const SizedBox(height: 6),
                                      Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('₹${item.price}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 360, child: cartPanel),
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Table ${selectedTable?.number}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(selectedTable?.status ?? 'available').withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: getStatusColor(selectedTable?.status ?? 'available')),
                                    ),
                                    child: Text(
                                      (selectedTable?.status ?? 'available').toUpperCase(),
                                      style: TextStyle(
                                        color: getStatusColor(selectedTable?.status ?? 'available'),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text('Take order for ${selectedTable?.capacity} guests', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              provider.setCurrentView('tables');
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF27272A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Back'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: provider.categories.map((c) {
                            final active = provider.selectedCategory == c;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: TextButton(
                                onPressed: () => provider.setSelectedCategory(c),
                                style: TextButton.styleFrom(
                                  backgroundColor: active ? const Color(0xFFF59E0B) : const Color(0xFF18181B),
                                  foregroundColor: active ? Colors.white : const Color(0xFFA1A1AA),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(c),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                      child: LayoutBuilder(builder: (context, c) {
                        final centerWidth = c.maxWidth;
                        final minTile = 200.0;
                        final cross = (centerWidth / minTile).floor().clamp(1, 3);
                        final baseItems = provider.selectedCategory == 'All' ? menuItems : menuItems.where((m) => m.category == provider.selectedCategory).toList();
                        bool isAvailable(item) {
                          if (item.soldOut == true) return false;
                          final now = DateTime.now();
                          final days = item.availableDays;
                          final dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
                          final today = dayMap[now.weekday]!;
                          if (!days.contains(today)) return false;
                          if (item.availableStart != null && item.availableEnd != null && item.availableStart!.isNotEmpty && item.availableEnd!.isNotEmpty) {
                            final partsS = item.availableStart!.split(':');
                            final partsE = item.availableEnd!.split(':');
                            final sH = int.tryParse(partsS[0]) ?? 0;
                            final sM = int.tryParse(partsS.length > 1 ? partsS[1] : '0') ?? 0;
                            final eH = int.tryParse(partsE[0]) ?? 23;
                            final eM = int.tryParse(partsE.length > 1 ? partsE[1] : '59') ?? 59;
                            final start = TimeOfDay(hour: sH, minute: sM);
                            final end = TimeOfDay(hour: eH, minute: eM);
                            final nowTod = TimeOfDay.fromDateTime(now);
                            final nowMin = nowTod.hour * 60 + nowTod.minute;
                            final sMin = start.hour * 60 + start.minute;
                            final eMin = end.hour * 60 + end.minute;
                            if (nowMin < sMin || nowMin > eMin) return false;
                          }
                          return true;
                        }
                        final items = baseItems.where(isAvailable).toList();
                        return GridView.builder(
                          shrinkWrap: false,
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return InkWell(
                              onTap: () => provider.addToCart(item),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF18181B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF27272A)),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.image, style: const TextStyle(fontSize: 32)),
                                    const SizedBox(height: 6),
                                    Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('₹${item.price}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 320, child: cartPanel),
            ],
          );
        }
      }
    });
  }
}
