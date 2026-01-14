import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/menu_item.dart';
import '../widgets/page_scaffold.dart';

class KitchenScreen extends StatelessWidget {
  final bool embedded;
  const KitchenScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final orders = provider.orders;
    final active = orders.where((o) => o.status == 'Preparing' || o.status == 'Ready').toList();
    final menuItems = provider.menuItems;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final grid = LayoutBuilder(builder: (context, c) {
        final cross = width >= 1024 ? 3 : (width >= 640 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: active.isEmpty ? 1 : active.length,
          itemBuilder: (context, i) {
            if (active.isEmpty) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.restaurant, color: Color(0xFF71717A), size: 64), SizedBox(height: 8), Text('No pending orders', style: TextStyle(color: Color(0xFFA1A1AA)))]));
            }
            final o = active[i];
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B), width: 2),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.table, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        ...o.items.where((x) => !x.isCancelled).map((it) {
                          final addons = (it.addons ?? []).map((id) => menuItems.firstWhere((m) => m.id == id, orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: '')).name).where((n) => n.isNotEmpty).toList();
                          final note = (it.instructions ?? '').trim();
                          final mods = (it.modifiers ?? []).map((m) => m['name'] as String? ?? '').where((n) => n.isNotEmpty).toList();
                          final metaParts = [...addons, ...mods, if (note.isNotEmpty) 'Note: $note'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(it.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                    Row(children: [
                                      Text('x${it.quantity}', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.red), onPressed: () => _showCancelDialog(context, o.id, it), tooltip: 'Cancel Item', padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                    ]),
                                  ],
                                ),
                                if (metaParts.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(metaParts.join(' | '), style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 12)),
                                  ),
                              ],
                            ),
                          );
                        }),
                        // Cancelled items section removed as per requirement
                      ],
                    ),
                  ),
                  if (o.status == 'Preparing')
                    ElevatedButton(onPressed: () => provider.markOrderAsReady(o.id), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white), child: const Text('Mark as Ready')),
                  if (o.status == 'Ready')
                    ElevatedButton(onPressed: () => provider.markOrderAsCompleted(o.id), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white), child: const Text('Complete / Picked Up')),
                ],
              ),
            );
          },
        );
      });
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kitchen', style: TextStyle(color: Color(0xFFA1A1AA))),
              const SizedBox(height: 12),
              grid,
            ],
          ),
        ),
      );
    });
  }

  void _showCancelDialog(BuildContext context, String orderId, dynamic item) {
    final reasons = ['Customer changed mind', 'Item unavailable', 'Wrong entry', 'Kitchen error', 'Other'];
    String selectedReason = reasons.first;
    bool isWastage = true; // Default to wastage as it's in kitchen

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Cancel ${item.name}?'),
          titleTextStyle: const TextStyle(color: Colors.white, letterSpacing: 0.5),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedReason,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => selectedReason = v!),
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Mark as Wastage'),
                subtitle: const Text('Ingredients will be deducted'),
                value: isWastage,
                onChanged: (v) => setState(() => isWastage = v!),
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
                context.read<RestaurantProvider>().cancelOrderedItem(orderId, item, selectedReason, isWastage);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Confirm Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
