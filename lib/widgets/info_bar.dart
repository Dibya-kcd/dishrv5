import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/expense_provider.dart';

class InfoBar extends StatelessWidget {
  const InfoBar({super.key});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final items = [
      _InfoChip(label: 'Menu', value: provider.menuItems.length.toString()),
      _InfoChip(label: 'Tables', value: provider.tables.length.toString()),
      _InfoChip(label: 'Orders', value: provider.orders.length.toString()),
      _InfoChip(label: 'Expenses', value: expenseProvider.expenses.length.toString()),
    ];
    final isWide = MediaQuery.of(context).size.width >= 1024;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: isWide
          ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: items)
          : Wrap(spacing: 8, runSpacing: 8, children: items),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE5E5E5))),
          const SizedBox(width: 8),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

