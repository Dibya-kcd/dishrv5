import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/report_widgets.dart';
import '../../widgets/report_fab.dart';
import '../../utils/report_utils.dart';
import '../reports_tabs/inventory_tab.dart';
import '../../data/repository.dart';

class InventoryReportScreen extends StatelessWidget {
  const InventoryReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final range = provider.analyticsRange;
    final filteredOrders = getFilteredOrders(
      provider.orders,
      range,
      provider.analyticsCategoryFilter,
      provider.analyticsServiceFilter,
      provider.menuItems,
    );
    final dateRange = getDateRange(range);
    final stats = calculateReportStats(filteredOrders, expenseProvider.expenses, provider.menuItems, dateRange['startMs']!, dateRange['endMs']!);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: ReportFAB(stats: stats, range: range, menuItems: provider.menuItems),
      body: PageScaffold(
        title: 'Inventory Report',
        actions: [
          ...buildReportActions(context),
          IconButton(
            onPressed: () {
              String filterType = 'All';
              List<Map<String, dynamic>> txns = [];
              bool loading = true;
              Map<String, String> ingNames = {};
              showDialog(context: context, builder: (_) {
                return StatefulBuilder(builder: (context, setLocal) {
                  Future<void> load() async {
                    setLocal(() => loading = true);
                    final list = await Repository.instance.ingredients.listIngredients();
                    ingNames = {
                      for (final e in list) (e['id'] as String): (e['name'] as String? ?? '')
                    };
                    final t = await Repository.instance.ingredients.listTransactions(
                      type: filterType == 'All' ? null : filterType.toLowerCase(),
                      limit: 100,
                    );
                    setLocal(() {
                      txns = t;
                      loading = false;
                    });
                  }
                  if (loading) load();
                  return AlertDialog(
                    backgroundColor: const Color(0xFF18181B),
                    title: const Text('Inventory Transactions', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
                    content: SizedBox(
                      width: 700,
                      height: 500,
                      child: Column(children: [
                        Row(children: [
                          const Text('Filter by Type: ', style: TextStyle(color: Colors.white)),
                          const SizedBox(width: 8),
                          DropdownButtonHideUnderline(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                              child: DropdownButton<String>(
                                value: filterType,
                                dropdownColor: const Color(0xFF18181B),
                                items: ['All', 'Purchase', 'Wastage', 'Deduction', 'Restore'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setLocal(() {
                                      filterType = v;
                                    });
                                    load();
                                  }
                                },
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(onPressed: load, icon: const Icon(Icons.refresh, color: Colors.white)),
                        ]),
                        const SizedBox(height: 12),
                        Expanded(
                          child: loading
                              ? const Center(child: CircularProgressIndicator())
                              : txns.isEmpty
                                  ? const Center(child: Text('No transactions found', style: TextStyle(color: Colors.grey)))
                                  : ListView.builder(
                                      itemCount: txns.length,
                                      itemBuilder: (context, index) {
                                        final t = txns[index];
                                        final ingId = t['ingredient_id'] as String;
                                        final ingName = ingNames[ingId] ?? ingId;
                                        final type = t['type'] as String;
                                        final qty = (t['qty'] as num).toDouble();
                                        final unit = t['unit'] as String;
                                        final date = DateTime.fromMillisecondsSinceEpoch(t['timestamp'] as int);
                                        final color = type == 'purchase' || type == 'restore' ? Colors.green : Colors.red;
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                                          child: Row(children: [
                                            Expanded(
                                              flex: 2,
                                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Text(ingName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                Text(date.toString().split('.')[0], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                              ]),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(type.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                                            ),
                                            Text('${qty.toStringAsFixed(2)} $unit', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ]),
                                        );
                                      },
                                    ),
                        ),
                      ]),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                  );
                });
              });
            },
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            tooltip: 'Inventory Transactions',
          ),
        ],
        child: InventoryTab(startMs: dateRange['startMs']!, endMs: dateRange['endMs']!),
      ),
    );
  }
}
