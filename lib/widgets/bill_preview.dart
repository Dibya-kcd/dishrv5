import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/cart_item.dart';

class BillPreview extends StatelessWidget {
  const BillPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final showBillPreview = provider.showBillPreview;
    final currentBill = provider.currentBill;

    if (!showBillPreview || currentBill == null) return const SizedBox.shrink();
    
    final items = currentBill['items'] as List<CartItem>;
    
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
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black87))),
                  child: Column(children: const [
                    Text('RESTOPOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
                    SizedBox(height: 6),
                    Text('TAX INVOICE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  ]),
                ),
                const SizedBox(height: 12),
                ...items.map((i) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                      child: Column(children: [
                        Align(alignment: Alignment.centerLeft, child: Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('₹${i.price} x ${i.quantity}', style: const TextStyle(color: Colors.black54)),
                          Text('₹${(i.price * i.quantity).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black)),
                        ]),
                      ]),
                    )),
                const SizedBox(height: 8),
                Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Subtotal:', style: TextStyle(color: Colors.black)),
                    Text('₹${(currentBill['subtotal'] as double).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('GST (5%):', style: TextStyle(color: Colors.black)),
                    Text('₹${(currentBill['gst'] as double).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    Text('₹${(currentBill['total'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                  ]),
                ]),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xFFF3F4F6),
                  alignment: Alignment.center,
                  child: Text('Payment: ${currentBill['paymentMethod']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: provider.closeBillPreview,
                        style: TextButton.styleFrom(backgroundColor: const Color(0xFFE5E7EB), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: provider.printBill,
                        style: TextButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
