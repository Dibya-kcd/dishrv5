import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/cart_item.dart';

class BillPreviewModal extends StatelessWidget {
  const BillPreviewModal({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    if (!provider.showBillPreview || provider.currentBill == null) return const SizedBox.shrink();

    final bill    = provider.currentBill!;
    final items   = bill['items'] as List<CartItem>;

    // ── Dynamic tax fields (set by restaurant_provider.openPaymentModal) ──
    final taxEnabled  = bill['taxEnabled']  as bool?   ?? true;
    final taxLabel    = bill['taxLabel']    as String? ?? 'GST';
    final taxRate     = bill['taxRate']     as double? ?? 5.0;
    final taxAmount   = bill['gst']         as double? ?? 0.0;

    // Format rate: show "5%" not "5.0%"
    final rateStr = taxRate == taxRate.roundToDouble()
        ? taxRate.toInt().toString()
        : taxRate.toStringAsFixed(1);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black87)),
                ),
                child: Column(children: [
                  const Text(
                    'RESTOPOS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  const Text('123 Main Street, City', style: TextStyle(color: Colors.black)),
                  const Text('Phone: +91 9876543210', style: TextStyle(color: Colors.black)),
                  const Divider(color: Colors.black26),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(
                      'Bill #${bill['billNumber']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    Text('${bill['date']}', style: const TextStyle(color: Colors.black)),
                  ]),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Table: ${bill['table']}', style: const TextStyle(color: Colors.black)),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // ── Line items ───────────────────────────────────────────────
              ...items.map((i) {
                final isCancelled = i.isCancelled;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Column(children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isCancelled ? '${i.name} (Cancelled)' : i.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCancelled ? Colors.grey : Colors.black,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(
                        '₹${i.price} x ${i.quantity}',
                        style: TextStyle(
                          color: isCancelled ? Colors.grey : Colors.black,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        isCancelled ? '₹0.00' : '₹${(i.price * i.quantity).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isCancelled ? Colors.grey : Colors.black,
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ]),
                  ]),
                );
              }),

              const SizedBox(height: 8),

              // ── Totals ───────────────────────────────────────────────────
              Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Subtotal:', style: TextStyle(color: Colors.black)),
                  Text(
                    '₹${(bill['subtotal'] as double).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.black),
                  ),
                ]),

                // Tax row — shown only when tax is enabled
                if (taxEnabled)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(
                      '$taxLabel ($rateStr%):',
                      style: const TextStyle(color: Colors.black),
                    ),
                    Text(
                      '₹${taxAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.black),
                    ),
                  ]),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text(
                    'TOTAL:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  Text(
                    '₹${(bill['total'] as double).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ]),
              ]),

              const SizedBox(height: 8),

              // ── Payment method strip ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: const Color(0xFFF3F4F6),
                alignment: Alignment.center,
                child: Text(
                  'Payment: ${bill['paymentMethod']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),

              const SizedBox(height: 12),

              // ── Actions ──────────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => provider.setShowBillPreview(false),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E7EB),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => provider.printBill(),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Print'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
