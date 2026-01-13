import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';

class PaymentModal extends StatelessWidget {
  const PaymentModal({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    if (!provider.showPaymentModal || provider.currentBill == null) return const SizedBox.shrink();

    final total = provider.currentBill!['total'] as double;
    final totalPaid = provider.splitPayment 
        ? (provider.cashAmount + provider.cardAmount + provider.upiAmount) 
        : total;
    final isValid = provider.splitPayment ? totalPaid >= total : true;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          decoration: BoxDecoration(color: const Color(0xFF0B0F0E), borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF0D9488)]), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Payment Method', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () => provider.updatePaymentDetails(split: !provider.splitPayment),
                      style: TextButton.styleFrom(
                        backgroundColor: provider.splitPayment ? const Color(0xFFF59E0B) : const Color(0xFF27272A),
                        foregroundColor: provider.splitPayment ? Colors.white : const Color(0xFFA1A1AA),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(provider.splitPayment ? '✓ Split Payment' : 'Split Payment'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (!provider.splitPayment)
                    Row(children: ['Cash', 'Card', 'UPI'].map((mode) {
                      final active = provider.paymentMode == mode;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextButton(
                            onPressed: () => provider.updatePaymentDetails(mode: mode),
                            style: TextButton.styleFrom(
                              backgroundColor: active ? const Color(0xFF10B981) : const Color(0xFF27272A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: active ? const Color(0xFF10B981) : const Color(0xFF3F3F46), width: 2)),
                            ),
                            child: Text(mode),
                          ),
                        ),
                      );
                    }).toList()),
                  if (provider.splitPayment)
                    Column(children: [
                      _AmountRow(label: 'Cash', value: provider.cashAmount, onChanged: (v) => provider.updatePaymentDetails(cash: v)),
                      const SizedBox(height: 8),
                      _AmountRow(label: 'Card', value: provider.cardAmount, onChanged: (v) => provider.updatePaymentDetails(card: v)),
                      const SizedBox(height: 8),
                      _AmountRow(label: 'UPI', value: provider.upiAmount, onChanged: (v) => provider.updatePaymentDetails(upi: v)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444), width: 2), color: (isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1)),
                        child: Text('Paid: ₹${totalPaid.toStringAsFixed(2)} • Required: ₹${total.toStringAsFixed(2)}${!isValid ? ' • Short: ₹${(total - totalPaid).toStringAsFixed(2)}' : ''}', style: const TextStyle(color: Color(0xFFA1A1AA))),
                      ),
                    ]),
                  const Spacer(),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => provider.setShowPaymentModal(false),
                        style: TextButton.styleFrom(backgroundColor: const Color(0xFF27272A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: isValid ? () => provider.processPayment() : null,
                        style: TextButton.styleFrom(backgroundColor: isValid ? const Color(0xFF10B981) : const Color(0xFF3F3F46), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text('Complete'),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AmountRow extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _AmountRow({required this.label, required this.value, required this.onChanged});

  @override
  State<_AmountRow> createState() => _AmountRowState();
}

class _AmountRowState extends State<_AmountRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value == 0 ? '' : widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _AmountRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != double.tryParse(_controller.text)) {
       // Only update if value changed externally to avoid cursor jumps if we were typing
       // But here we are relying on parent state, so it might be tricky.
       // For simplicity in this port, let's just update if it doesn't match
       if (widget.value == 0 && _controller.text == '') return;
       if (double.tryParse(_controller.text) != widget.value) {
          _controller.text = widget.value == 0 ? '' : widget.value.toString();
       }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(widget.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
      SizedBox(
        width: 120,
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          onChanged: (v) => widget.onChanged(double.tryParse(v) ?? 0),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFF18181B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3F3F46))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF10B981))),
            hintText: '0',
            hintStyle: const TextStyle(color: Color(0xFFA1A1AA)),
          ),
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ]);
  }
}
