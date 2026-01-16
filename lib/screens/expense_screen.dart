import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../providers/expense_provider.dart';

class ExpenseScreen extends StatelessWidget {
  const ExpenseScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final isMobile = width < 768;
      final isTablet = width >= 768 && width < 1024;
      final isLaptop = width >= 1024 && width < 1440;
      final cols = isMobile ? 1 : isTablet ? 2 : isLaptop ? 3 : 4;
      final scale = width < 360
          ? 0.85
          : width > 1728
              ? 1.2
              : (width / 1024).clamp(0.85, 1.2);
      final restaurantProvider = context.watch<RestaurantProvider>();
      final expenseProvider = context.watch<ExpenseProvider>();
      final categories = [
        {'name': 'Raw Materials/Ingredients', 'emoji': '🍖', 'color': Colors.green},
        {'name': 'Utilities (Electricity, Water, Gas)', 'emoji': '⚡', 'color': Colors.amber},
        {'name': 'Staff Salaries & Wages', 'emoji': '👥', 'color': Colors.blue},
        {'name': 'Housekeeping & Cleaning Supplies', 'emoji': '🧹', 'color': Colors.teal},
        {'name': 'Maintenance & Repairs', 'emoji': '🔧', 'color': Colors.orange},
        {'name': 'Marketing & Advertising', 'emoji': '📢', 'color': Colors.purple},
        {'name': 'Transportation & Delivery', 'emoji': '🚗', 'color': Colors.indigo},
        {'name': 'Rent & Property', 'emoji': '📄', 'color': Colors.red},
        {'name': 'Technology & Software', 'emoji': '📱', 'color': Colors.cyan},
        {'name': 'Bank Charges & Fees', 'emoji': '🏦', 'color': Colors.grey},
        {'name': 'Professional Services', 'emoji': '📊', 'color': Colors.deepPurple},
        {'name': 'Miscellaneous', 'emoji': '🎯', 'color': Colors.pink},
      ];
      final maxContentWidth = isLaptop || !isDesktop(width) ? width : 1280.0;
      final horizontalPadding = 16.0 * scale;
      final gutter = 12.0 * scale;
      final usableWidth = (maxContentWidth - (horizontalPadding * 2));
      final cardWidth = cols == 1
          ? usableWidth
          : ((usableWidth - gutter * (cols - 1)) / cols).floorToDouble();
      final range = restaurantProvider.analyticsRange;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      int startMs;
      int endMs;
      if (range == 'Today') {
        final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).millisecondsSinceEpoch;
        startMs = startOfDay;
        endMs = startOfDay + 24 * 60 * 60 * 1000;
      } else if (range == '7D') {
        startMs = nowMs - 7 * 24 * 60 * 60 * 1000;
        endMs = nowMs;
      } else if (range == '30D') {
        startMs = nowMs - 30 * 24 * 60 * 60 * 1000;
        endMs = nowMs;
      } else if (range == 'All Time') {
        startMs = 0;
        endMs = nowMs + 24 * 60 * 60 * 1000;
      } else {
        startMs = nowMs - 365 * 24 * 60 * 60 * 1000;
        endMs = nowMs;
      }
      final filteredExpenses = expenseProvider.expenses.where((e) {
        final ts = (e['timestamp'] as int?) ?? 0;
        return ts >= startMs && ts < endMs;
      }).toList();
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: const Color(0xFF1A1A1A),
                    title: Text('Expenses', style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold)),
                    actions: [
                      Padding(
                        padding: EdgeInsets.only(right: 8 * scale),
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddExpenseDialog(context, categories, scale),
                          icon: Icon(Icons.add, size: 16 * scale),
                          label: Text('Add Expense', style: TextStyle(fontSize: 12 * scale)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9500),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 10 * scale),
                            minimumSize: Size(isMobile ? 44 * scale : 0, 44 * scale),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: const Color(0xFF18181B),
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                            builder: (_) {
                              final opts = ['Today','7D','30D','365D','All Time'];
                              final current = context.read<RestaurantProvider>().analyticsRange;
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Date Range', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: opts.map((r) {
                                        final sel = r == current || (r == '365D' && !['Today','7D','30D','All Time'].contains(current));
                                        return FilterChip(
                                          selected: sel,
                                          label: Text(r),
                                          onSelected: (_) {
                                            context.read<RestaurantProvider>().setAnalyticsRange(r == '365D' ? '365D' : r);
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
                  SliverPadding(
                    padding: EdgeInsets.only(top: 12 * scale, bottom: 8 * scale),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: gutter,
                        runSpacing: gutter,
                        children: categories.map((cat) {
                          final name = cat['name'] as String;
                          final emoji = cat['emoji'] as String;
                          final color = cat['color'] as Color;
                          final total = filteredExpenses
                              .where((e) => (e['category']?.toString() ?? '') == name)
                              .fold<double>(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
                          return SizedBox(
                            width: cardWidth,
                            child: _CategoryCard(
                              name: name,
                              emoji: emoji,
                              accent: color,
                              total: total,
                              scale: scale,
                              onTap: () => _showAddExpenseDialog(context, categories, scale, presetCategory: name),
                              onAdd: () => _showAddExpenseDialog(context, categories, scale, presetCategory: name),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.only(top: 8 * scale),
                    sliver: filteredExpenses.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No expenses recorded',
                                style: TextStyle(color: const Color(0xFFA1A1AA), fontSize: 14 * scale),
                              ),
                            ),
                          )
                        : SliverList.builder(
                            itemCount: filteredExpenses.length,
                            itemBuilder: (context, index) {
                              final e = filteredExpenses[index];
                              final ts = DateTime.fromMillisecondsSinceEpoch((e['timestamp'] as int? ?? 0));
                              final date = ts.toString().split('.')[0];
                              return Container(
                                margin: EdgeInsets.only(left: 12 * scale, right: 12 * scale, top: index == 0 ? 12 * scale : 0, bottom: 12 * scale),
                                padding: EdgeInsets.all(12 * scale),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text((e['category']?.toString() ?? ''), style: TextStyle(color: Colors.white, fontSize: 13 * scale, fontWeight: FontWeight.w600)),
                                          SizedBox(height: 2 * scale),
                                          Text(date, style: TextStyle(color: const Color(0xFFA1A1AA), fontSize: 11 * scale)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text((e['note']?.toString() ?? ''), style: TextStyle(color: Colors.white, fontSize: 12 * scale), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ),
                                    Text('₹${((e['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}', style: TextStyle(color: const Color(0xFFFF9500), fontSize: 14 * scale, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
  bool isDesktop(double width) => width >= 1440;
  Future<void> _showAddExpenseDialog(BuildContext context, List<Map<String, Object>> categories, double scale, {String? presetCategory}) async {
    String? selected = presetCategory;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final provider = context.read<ExpenseProvider>();
    await showDialog(context: context, builder: (_) {
      return StatefulBuilder(builder: (context, setLocal) {
        return AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          title: Text('Add Expense', style: TextStyle(color: Colors.white, fontSize: 16 * scale, letterSpacing: 0.5)),
          content: SizedBox(
            width: 420 * scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                    decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                    child: DropdownButton<String>(
                      value: selected,
                      hint: const Text('Category', style: TextStyle(color: Colors.white)),
                      dropdownColor: const Color(0xFF18181B),
                      items: categories.map((c) {
                        final name = c['name'] as String;
                        final emoji = c['emoji'] as String;
                        return DropdownMenuItem(
                          value: name,
                          child: Row(children: [
                            Text(emoji, style: TextStyle(fontSize: 16 * scale)),
                            SizedBox(width: 8 * scale),
                            Text(name, style: const TextStyle(color: Colors.white)),
                          ]),
                        );
                      }).toList(),
                      onChanged: (v) => setLocal(() => selected = v),
                    ),
                  ),
                ),
                SizedBox(height: 8 * scale),
                _DarkField(
                  label: 'Amount',
                  controller: amountCtrl,
                  scale: scale,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 8 * scale),
                _DarkField(
                  label: 'Note',
                  controller: noteCtrl,
                  scale: scale,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                final cat = selected ?? '';
                final note = noteCtrl.text.trim();
                if (amt <= 0 || cat.isEmpty) return;
                provider.addExpense(amount: amt, category: cat, note: note.isEmpty ? null : note);
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      });
    });
  }
}

class _CategoryCard extends StatefulWidget {
  final String name;
  final String emoji;
  final Color accent;
  final double total;
  final double scale;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  const _CategoryCard({required this.name, required this.emoji, required this.accent, required this.total, required this.scale, required this.onTap, required this.onAdd});
  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}
class _CategoryCardState extends State<_CategoryCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hover = true),
        onTapCancel: () => setState(() => _hover = false),
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.all(12 * s),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hover ? widget.accent : const Color(0xFF27272A)),
            boxShadow: [BoxShadow(color: const Color(0xFF000000).withValues(alpha: _hover ? 0.6 : 0.4), blurRadius: _hover ? 10 : 6)],
          ),
          child: Row(
            children: [
              Text(widget.emoji, style: TextStyle(fontSize: 20 * s)),
              SizedBox(width: 10 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name, style: TextStyle(color: Colors.white, fontSize: 14 * s, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4 * s),
                    Text('₹${widget.total.toStringAsFixed(2)}', style: TextStyle(color: widget.accent, fontSize: 16 * s, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: widget.onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27272A),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
                  minimumSize: Size(44 * s, 44 * s),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Add', style: TextStyle(fontSize: 12 * s)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final double scale;
  final TextInputType? keyboardType;
  const _DarkField({required this.label, required this.controller, required this.scale, this.keyboardType});
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3F3F46)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.centerLeft, child: Text(label, style: TextStyle(color: Colors.white, fontSize: 12 * scale))),
        SizedBox(height: 4 * scale),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: Colors.white, fontSize: 12 * scale),
          decoration: InputDecoration(
            hintText: label,
            filled: true,
            fillColor: const Color(0xFF0B0B0E),
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: const BorderSide(color: Color(0xFFF59E0B))),
          ),
        ),
      ],
    );
  }
}
