import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/app_ui_kit.dart';

// ── Expense categories ────────────────────────────────────────────────────────

const _kCategories = [
  ('Raw Materials/Ingredients',     '🍖', Color(0xFF10B981)),
  ('Utilities (Electricity, Water, Gas)', '⚡', Color(0xFFF59E0B)),
  ('Staff Salaries & Wages',        '👥', Color(0xFF3B82F6)),
  ('Housekeeping & Cleaning Supplies','🧹', Color(0xFF14B8A6)),
  ('Maintenance & Repairs',         '🔧', Color(0xFFF97316)),
  ('Marketing & Advertising',       '📢', Color(0xFFA855F7)),
  ('Transportation & Delivery',     '🚗', Color(0xFF6366F1)),
  ('Rent & Property',               '📄', Color(0xFFEF4444)),
  ('Technology & Software',         '📱', Color(0xFF06B6D4)),
  ('Bank Charges & Fees',           '🏦', Color(0xFF71717A)),
  ('Professional Services',         '📊', Color(0xFF8B5CF6)),
  ('Miscellaneous',                 '🎯', Color(0xFFEC4899)),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restaurantProv = context.watch<RestaurantProvider>();
    final expenseProv = context.watch<ExpenseProvider>();
    final range = restaurantProv.analyticsRange;

    // Date range calculation
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final (startMs, endMs) = _dateRange(range, nowMs);

    final filtered = expenseProv.expenses.where((e) {
      final ts = (e['timestamp'] as int?) ?? 0;
      return ts >= startMs && ts < endMs;
    }).toList();

    return AppPageScaffold(
      title: 'Expenses',
      scrollable: false,
      actions: [
        DateRangeChips(
          current: range,
          onChanged: (r) => restaurantProv.setAnalyticsRange(r),
        ),
        const SizedBox(width: 8),
        AppButton.primary('Add', icon: Icons.add, small: true,
            onPressed: () => _showAddDialog(context)),
      ],
      child: CustomScrollView(slivers: [
        // ── Category summary cards ─────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(builder: (context, c) {
              final cols = Bp.pick(context, mob: 1, tab: 2, desk: 3);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.6,
                children: _kCategories.map((cat) {
                  final total = filtered
                      .where((e) => (e['category']?.toString() ?? '') == cat.$1)
                      .fold<double>(0, (s, e) => s + ((e['amount'] as num?)?.toDouble() ?? 0));
                  return _CategoryTile(
                    name: cat.$1,
                    emoji: cat.$2,
                    color: cat.$3,
                    total: total,
                    onTap: () => _showAddDialog(context, preset: cat.$1),
                  );
                }).toList(),
              );
            }),
          ),
        ),

        // ── Transaction list ───────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
          sliver: filtered.isEmpty
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(message: 'No expenses in this period', icon: Icons.receipt_long_outlined),
                )
              : SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final e = filtered[idx];
                    final ts = DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int? ?? 0);
                    final cat = _kCategories.firstWhere(
                        (c) => c.$1 == (e['category']?.toString() ?? ''),
                        orElse: () => ('Misc', '🎯', const Color(0xFF71717A)));
                    return AppCard(
                      color: AppColors.bg2,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(children: [
                        Text(cat.$2, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e['category']?.toString() ?? '', style: AppTextStyles.h3),
                          const SizedBox(height: 2),
                          Text(
                            '${_fmtDate(ts)}${(e['note']?.toString() ?? '').isNotEmpty ? ' · ${e['note']}' : ''}',
                            style: AppTextStyles.small,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ])),
                        Text('₹${((e['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                            style: AppTextStyles.price),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  (int, int) _dateRange(String range, int nowMs) {
    switch (range) {
      case 'Today':
        final s = DateTime.now();
        final start = DateTime(s.year, s.month, s.day).millisecondsSinceEpoch;
        return (start, start + 86400000);
      case 'Week':  return (nowMs - 7  * 86400000, nowMs);
      case 'Month': return (nowMs - 30 * 86400000, nowMs);
      case 'Year':return (nowMs - 365 * 86400000, nowMs);
      case 'All': return (0, nowMs + 86400000);
      default:    return (nowMs - 30 * 86400000, nowMs);
    }
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _showAddDialog(BuildContext context, {String? preset}) {
    String? selectedCategory = preset;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Add Expense', style: TextStyle(color: AppColors.textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Category dropdown
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bg1,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    hint: const Text('Select Category', style: TextStyle(color: AppColors.textMuted)),
                    dropdownColor: AppColors.bg3,
                    isExpanded: true,
                    items: _kCategories.map((c) => DropdownMenuItem(
                      value: c.$1,
                      child: Row(children: [
                        Text(c.$2, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.$1, style: AppTextStyles.body, overflow: TextOverflow.ellipsis)),
                      ]),
                    )).toList(),
                    onChanged: (v) => setLocal(() => selectedCategory = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DarkField(label: 'Amount (₹)', controller: amountCtrl, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DarkField(label: 'Note (optional)', controller: noteCtrl),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            AppButton.primary('Add', onPressed: () {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              final cat = selectedCategory ?? '';
              if (amt <= 0 || cat.isEmpty) return;
              ctx.read<ExpenseProvider>().addExpense(amount: amt, category: cat, note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null);
              Navigator.pop(ctx);
            }),
          ],
        );
      }),
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────

class _CategoryTile extends StatefulWidget {
  final String name;
  final String emoji;
  final Color color;
  final double total;
  final VoidCallback onTap;

  const _CategoryTile({required this.name, required this.emoji, required this.color, required this.total, required this.onTap});

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _hover ? widget.color : AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _hover ? 0.5 : 0.3), blurRadius: _hover ? 8 : 4)],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.name, style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('₹${widget.total.toStringAsFixed(2)}', style: TextStyle(color: widget.color, fontSize: 14, fontWeight: FontWeight.w700)),
              ])),
              Icon(Icons.add_circle_outline, size: 20, color: widget.color.withValues(alpha: 0.7)),
            ]),
          ),
        ),
      ),
    );
  }
}
