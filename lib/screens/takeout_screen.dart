import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';

class TakeoutScreen extends StatelessWidget {
  final bool embedded;
  const TakeoutScreen({super.key, this.embedded = false});

  void _showCancelOrderDialog(BuildContext context, String orderId) {
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
    final categories = provider.categories;
    final selectedCategory = provider.selectedCategory;
    final menuItems = selectedCategory == 'All' ? provider.menuItems : provider.menuItems.where((m) => m.category == selectedCategory).toList();
    final takeoutCart = provider.takeoutCart;
    final tokenId = provider.takeoutTokenId;
    final activeItems = provider.getActiveOrderItemsByLabel('Takeout #$tokenId');
    final activeOrder = () {
      try {
        return provider.orders.firstWhere((o) => o.table == 'Takeout #$tokenId' && o.status != 'Settled' && o.status != 'Cancelled');
      } catch (_) {
        return null;
      }
    }();
    final kotBatches = provider.getKotBatchesForTable('Takeout #$tokenId');

    bool isAvailable(item) {
      if (item.soldOut == true) return false;
      final now = DateTime.now();
      final days = item.availableDays;
      final dayMap = {
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun',
      };
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
    final filtered = menuItems.where(isAvailable).toList();

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
                      const Text('Takeout Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('${activeItems.length + takeoutCart.length} items', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(tokenId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      if (activeOrder?.status == 'Awaiting Payment')
                        Container(
                          decoration: BoxDecoration(color: const Color(0xFFA855F7), borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: const Text('Awaiting Billing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      if (activeItems.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          tooltip: 'Cancel Entire Order',
                          onPressed: () {
                            try {
                              final ord = provider.orders.firstWhere((o) => o.table == 'Takeout #$tokenId' && o.status != 'Settled' && o.status != 'Cancelled');
                              _showCancelOrderDialog(context, ord.id);
                            } catch (_) {}
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (activeOrder?.status == 'Awaiting Payment' && kotBatches.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF27272A)))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('KOT Batches', style: TextStyle(color: Color(0xFF71717A), fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...kotBatches.map((b) {
                      final items = (b['items'] as List).cast<CartItem>();
                      final tsMs = (b['timestamp'] as int?) ?? 0;
                      final dt = DateTime.fromMillisecondsSinceEpoch(tsMs);
                      final time = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sent at $time', style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: items.map((i) => Text('${i.name} x${i.quantity}', style: const TextStyle(color: Color(0xFFA1A1AA)))).toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            Expanded(
              child: takeoutCart.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.shopping_bag_outlined, color: Color(0xFF71717A), size: 48), SizedBox(height: 8), Text('No items', style: TextStyle(color: Color(0xFFA1A1AA)))]))
                  : ListView.builder(
                    padding: const EdgeInsets.all(12),
                      itemCount: takeoutCart.length,
                      itemBuilder: (context, i) {
                        final item = takeoutCart[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(item.name, style: const TextStyle(color: Colors.white)),
                                IconButton(onPressed: () => provider.removeFromTakeoutCart(item.id), icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18)),
                              ]),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Container(
                                  decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(8)),
                                  child: Row(children: [
                                    IconButton(onPressed: () => provider.updateTakeoutQuantity(item.id, -1), icon: const Icon(Icons.remove, color: Colors.white), constraints: const BoxConstraints.tightFor(width: 32, height: 32)),
                                    SizedBox(width: 32, child: Center(child: Text('${item.quantity}', style: const TextStyle(color: Colors.white)))),
                                    IconButton(onPressed: () => provider.updateTakeoutQuantity(item.id, 1), icon: const Icon(Icons.add, color: Colors.white), constraints: const BoxConstraints.tightFor(width: 32, height: 32)),
                                  ]),
                                ),
                                Text('₹${item.price * item.quantity}', style: const TextStyle(color: Colors.white)),
                              ]),
                              const SizedBox(height: 8),
                              TextField(
                                onChanged: (v) => provider.updateItemInstructions(item.id, v, isTakeout: true),
                                decoration: const InputDecoration(hintText: 'Cooking instructions'),
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
                                        provider.updateItemInstructions(item.id, next, isTakeout: true);
                                      },
                                    );
                                  }).toList(),
                                );
                              }),
                              const SizedBox(height: 6),
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
                                      onSelected: (_) => provider.toggleModifierForItem(item.id, m, isTakeout: true),
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
                                        onPressed: () => provider.addUpsellToTakeout(s),
                                        icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                                        constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                                        padding: EdgeInsets.zero,
                                      ),
                                      IconButton(
                                        onPressed: () => provider.toggleAddonForItem(item.id, s.id, isTakeout: true),
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
                        );
                      },
                    ),
            ),
            if (takeoutCart.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF27272A)))),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Builder(builder: (_) {
                      final consolidated = provider.consolidatedItemsForTable('Takeout #$tokenId');
                      final basis = consolidated.isNotEmpty ? consolidated : takeoutCart;
                      return Text('₹${(provider.cartTotal(basis) * 1.05).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
                    }),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (provider.hasTakeoutChanges)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => provider.generateKOT(takeoutCart, 'Takeout #$tokenId', false, context),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C), foregroundColor: Colors.white),
                        child: const Text('Send KOT'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => provider.openPaymentModal(takeoutCart, 'Takeout #$tokenId', false),
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
      if (embedded) {
        final isWide = width >= 600;
        final minTile = isWide ? 200.0 : 160.0;
        final cross = ((isWide ? width : (width - 32)) / minTile).floor().clamp(isWide ? 2 : 2, isWide ? 6 : 2);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Takeout', style: TextStyle(color: Color(0xFFA1A1AA))),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: categories.contains(selectedCategory) ? selectedCategory : 'All',
                          items: categories.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(color: Colors.white)),
                          )).toList(),
                          onChanged: (v) {
                            if (v != null) provider.setSelectedCategory(v);
                          },
                          dropdownColor: const Color(0xFF27272A),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                              tooltip: 'Open Cart',
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
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
                            ),
                            if (takeoutCart.fold<int>(0, (s, i) => s + i.quantity) > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(color: Color(0xFFEF4444), borderRadius: BorderRadius.all(Radius.circular(10))),
                                  child: Text(
                                    '${takeoutCart.fold<int>(0, (s, i) => s + i.quantity)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return InkWell(
                      onTap: () => provider.addToTakeoutCart(item),
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
                            Text(item.image, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 6),
                            Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('₹${item.price}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }
      if (width < 600) {
        if (!embedded) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Takeout', style: TextStyle(color: Color(0xFFA1A1AA))),
                        Text('Take order for takeout', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                      ],
                    ),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: categories.contains(selectedCategory) ? selectedCategory : 'All',
                          items: categories.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(color: Colors.white)),
                          )).toList(),
                          onChanged: (v) {
                            if (v != null) provider.setSelectedCategory(v);
                          },
                          dropdownColor: const Color(0xFF27272A),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                              tooltip: 'Open Cart',
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
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
                            ),
                            if (takeoutCart.fold<int>(0, (s, i) => s + i.quantity) > 0)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(color: Color(0xFFEF4444), borderRadius: BorderRadius.all(Radius.circular(10))),
                                  child: Text(
                                    '${takeoutCart.fold<int>(0, (s, i) => s + i.quantity)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return InkWell(
                      onTap: () => provider.addToTakeoutCart(item),
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
                            Text(item.image, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 6),
                            Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('₹${item.price}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox.shrink(),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                            tooltip: 'Open Cart',
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
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
                          ),
                          if (takeoutCart.fold<int>(0, (s, i) => s + i.quantity) > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(color: Color(0xFFEF4444), borderRadius: BorderRadius.all(Radius.circular(10))),
                                child: Text(
                                  '${takeoutCart.fold<int>(0, (s, i) => s + i.quantity)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((c) {
                        final active = selectedCategory == c;
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
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return InkWell(
                        onTap: () => provider.addToTakeoutCart(item),
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
                              Text(item.image, style: const TextStyle(fontSize: 28)),
                              const SizedBox(height: 6),
                              Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('₹${item.price}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Take order for takeout', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                            ],
                          ),
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
                      const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(builder: (context, c) {
                          final centerWidth = c.maxWidth;
                          final minTile = 160.0;
                          final cross = (centerWidth / minTile).floor().clamp(3, 6);
                          return GridView.builder(
                            shrinkWrap: false,
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cross,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              return InkWell(
                                onTap: () => provider.addToTakeoutCart(item),
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
                                      Text(item.image, style: const TextStyle(fontSize: 28)),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Take order for takeout', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                            ],
                          ),
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
                      const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(builder: (context, c) {
                          final centerWidth = c.maxWidth;
                          final minTile = 200.0;
                          final cross = (centerWidth / minTile).floor().clamp(1, 3);
                          return GridView.builder(
                            shrinkWrap: false,
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cross,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final item = filtered[i];
                              return InkWell(
                                onTap: () => provider.addToTakeoutCart(item),
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
                                      Text(item.image, style: const TextStyle(fontSize: 28)),
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
