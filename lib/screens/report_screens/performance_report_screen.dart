import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/report_widgets.dart';
import '../../widgets/report_fab.dart';
import '../../utils/report_utils.dart';
import '../reports_tabs/performance_tab.dart';

class PerformanceReportScreen extends StatelessWidget {
  const PerformanceReportScreen({super.key});

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
        title: 'Performance Report',
        actions: buildReportActions(context),
        child: PerformanceTab(orders: filteredOrders),
      ),
    );
  }
}
