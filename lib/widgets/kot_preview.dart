import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/cart_item.dart';

class KOTPreview extends StatelessWidget {
  const KOTPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final showKOTPreview = provider.showKOTPreview;
    final currentKOT = provider.currentKOT;

    if (!showKOTPreview || currentKOT == null) return const SizedBox.shrink();
    
    final items = currentKOT['items'] as List<CartItem>;
    
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black26, style: BorderStyle.solid, width: 2))),
                  child: Column(
                    children: [
                      const Text('KITCHEN ORDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                      Text('KOT #${currentKOT['kotNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.black,
                        child: Center(child: Text('${currentKOT['table']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...items.map((i) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12, style: BorderStyle.solid))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                        Text('x${i.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
                      ]),
                    )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: provider.closeKOTPreview,
                        style: TextButton.styleFrom(backgroundColor: const Color(0xFFE5E7EB), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: provider.printKOT,
                        style: TextButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Print'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
