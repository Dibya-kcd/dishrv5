import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../providers/restaurant_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/app_ui_kit.dart';
import '../utils/report_utils.dart';

// ── Tab config ────────────────────────────────────────────────────────────────

const _kTabs = [
  (label: 'Sales',    icon: Icons.point_of_sale_outlined),
  (label: 'Trends',   icon: Icons.trending_up_outlined),
  (label: 'Payments', icon: Icons.payments_outlined),
  (label: 'Perf',     icon: Icons.speed_outlined),
  (label: 'Stock',    icon: Icons.inventory_2_outlined),
  (label: 'Finance',  icon: Icons.account_balance_outlined),
];

const _kRanges = ['Today', 'Week', 'Month', 'Year', 'All'];

// ── Router ────────────────────────────────────────────────────────────────────

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final idx = context.watch<RestaurantProvider>().reportsTabIndex;
    return _ReportShell(tabIndex: idx);
  }
}

// ── Shell: tab bar + date range chips ────────────────────────────────────────

class _ReportShell extends StatefulWidget {
  final int tabIndex;
  const _ReportShell({required this.tabIndex});

  @override
  State<_ReportShell> createState() => _ReportShellState();
}

class _ReportShellState extends State<_ReportShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _range = 'Today';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: _kTabs.length, vsync: this, initialIndex: widget.tabIndex);
  }

  @override
  void didUpdateWidget(_ReportShell old) {
    super.didUpdateWidget(old);
    if (widget.tabIndex != old.tabIndex &&
        widget.tabIndex != _tabs.index) {
      _tabs.animateTo(widget.tabIndex);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Header ───────────────────────────────────────────────────────────
      Container(
        color: AppColors.bg1,
        child: Column(children: [
          // Tab bar
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.amber,
            labelColor: AppColors.amber,
            unselectedLabelColor: AppColors.textSecondary,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: _kTabs.map((t) => Tab(
              height: 40,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.icon, size: 13),
                const SizedBox(width: 5),
                Text(t.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            )).toList(),
          ),
          // Date range chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: _kRanges.map((r) {
                final active = _range == r;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _range = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? AppColors.amber : AppColors.bg2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? AppColors.amber : AppColors.border),
                      ),
                      child: Text(r,
                        style: TextStyle(
                          color: active ? Colors.black : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
      const Divider(height: 1, color: AppColors.border),

      // ── Tab content ──────────────────────────────────────────────────────
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            _SalesPane(range: _range),
            _TrendsPane(range: _range),
            _PaymentsPane(range: _range),
            _PerformancePane(range: _range),
            _InventoryPane(range: _range),
            _FinancialPane(range: _range),
          ],
        ),
      ),
    ]);
  }
}

// ── Shared helper: compute stats once per pane ────────────────────────────────

({ReportStats stats, List<Order> filtered, List<Order> sorted}) _compute(
  BuildContext context,
  String range, {
  bool sort = false,
}) {
  final provider = context.watch<RestaurantProvider>();
  final expenses = context.watch<ExpenseProvider>().expenses;
  final ts = provider.taxSettings;
  final dr = getDateRange(range);
  final filtered = getFilteredOrders(
      provider.orders, range, 'All', 'All', provider.menuItems);
  final stats = calculateReportStats(
    filtered, expenses, provider.menuItems,
    dr['startMs']!, dr['endMs']!,
    taxRate: ts.rate, taxInclusive: ts.inclusive, taxEnabled: ts.enabled,
  );
  final sorted = sort
      ? (List.of(filtered)
        ..sort((a, b) {
          final ta = a.createdAt ?? a.settledAt ?? 0;
          final tb = b.createdAt ?? b.settledAt ?? 0;
          return tb.compareTo(ta);
        }))
      : filtered;
  return (stats: stats, filtered: filtered, sorted: sorted);
}

// ── 1. Sales ──────────────────────────────────────────────────────────────────

class _SalesPane extends StatelessWidget {
  final String range;
  const _SalesPane({required this.range});

  @override
  Widget build(BuildContext context) {
    final (:stats, :filtered, :sorted) = _compute(context, range);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdaptiveGrid(
          mobileCols: 2, tabletCols: 2, desktopCols: 4, childAspectRatio: 1.4,
          children: [
            StatTile(label: 'Total Revenue',
                value: '₹${stats.total.toStringAsFixed(2)}',
                icon: Icons.currency_rupee, accent: AppColors.green),
            StatTile(label: 'Orders', value: '${stats.count}',
                icon: Icons.receipt_outlined),
            StatTile(label: 'Avg Order',
                value: '₹${stats.avg.toStringAsFixed(2)}',
                icon: Icons.trending_up_outlined),
            StatTile(label: 'Tax Collected',
                value: '₹${stats.taxCollected.toStringAsFixed(2)}',
                icon: Icons.percent_outlined, accent: AppColors.amber),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader('Order Types'),
        const SizedBox(height: 10),
        AdaptiveGrid(
          mobileCols: 2, tabletCols: 3, desktopCols: 3, childAspectRatio: 1.6,
          children: [
            StatTile(label: 'Dine-In', value: '${stats.dineInCount}',
                icon: Icons.table_bar_outlined),
            StatTile(label: 'Takeout', value: '${stats.takeoutCount}',
                icon: Icons.shopping_bag_outlined),
            StatTile(label: 'Cancelled', value: '${stats.cancelledCount}',
                icon: Icons.cancel_outlined, accent: AppColors.red),
          ],
        ),
        if (stats.topCats.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader('Top Categories'),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: stats.topCats.take(5).map((e) {
                final pct = stats.count == 0
                    ? 0.0 : (e.value / stats.count).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: AppTextStyles.body),
                          Text('${e.value} orders',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                        ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          backgroundColor: AppColors.border,
                          color: AppColors.amber, minHeight: 6),
                      ),
                    ]),
                );
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── 2. Orders ─────────────────────────────────────────────────────────────────

// ── 2. Trends — day-over-day revenue + order volume ──────────────────────────

class _TrendsPane extends StatelessWidget {
  final String range;
  const _TrendsPane({required this.range});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final allOrders = provider.orders;

    // Build per-day buckets (last 7 days or within range)
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - (6 - i)));
    final dayData = days.map((d) {
      final start = d.millisecondsSinceEpoch;
      final end = start + 86400000;
      final dayOrders = allOrders.where((o) {
        final t = o.settledAt ?? o.createdAt ?? 0;
        return t >= start && t < end && o.status == 'Settled';
      }).toList();
      final rev = dayOrders.fold<double>(0, (s, o) => s + o.total);
      return (day: d, revenue: rev, count: dayOrders.length);
    }).toList();

    final maxRev = dayData.fold<double>(0, (m, d) => d.revenue > m ? d.revenue : m);
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Period stats
    final (:stats, filtered: _, sorted: _) = _compute(context, range);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Period comparison
        AdaptiveGrid(mobileCols: 2, tabletCols: 2, desktopCols: 4, childAspectRatio: 1.4,
          children: [
            StatTile(label: 'Revenue', value: '₹${stats.total.toStringAsFixed(0)}',
                icon: Icons.currency_rupee, accent: AppColors.green),
            StatTile(label: 'Orders', value: '${stats.count}', icon: Icons.receipt_outlined),
            StatTile(label: 'Avg Order', value: '₹${stats.avg.toStringAsFixed(0)}',
                icon: Icons.trending_up_outlined, accent: AppColors.amber),
            StatTile(label: 'Cancelled', value: '${stats.cancelledCount}',
                icon: Icons.cancel_outlined, accent: AppColors.red),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader('Last 7 Days'),
        const SizedBox(height: 10),
        AppCard(
          child: Column(children: [
            ...dayData.map((d) {
              final bar = maxRev > 0 ? (d.revenue / maxRev).clamp(0.0, 1.0) : 0.0;
              final label = weekdays[d.day.weekday - 1];
              final isToday = d.day.day == now.day && d.day.month == now.month;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(width: 30,
                    child: Text(label, style: AppTextStyles.small.copyWith(
                        color: isToday ? AppColors.amber : AppColors.textSecondary,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bar.toDouble(), minHeight: 14,
                        backgroundColor: AppColors.bg3,
                        color: isToday ? AppColors.amber : AppColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(width: 60,
                    child: Text('₹${d.revenue.toStringAsFixed(0)}',
                        style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right)),
                  const SizedBox(width: 6),
                  SizedBox(width: 24,
                    child: Text('${d.count}',
                        style: AppTextStyles.small.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.right)),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Top Categories'),
        const SizedBox(height: 10),
        if (stats.topCats.isEmpty)
          const EmptyState(message: 'No data', icon: Icons.bar_chart_outlined)
        else
          AppCard(
            child: Column(children: stats.topCats.take(6).map((e) {
              final pct = stats.count == 0 ? 0.0 : (e.value / stats.count).clamp(0.0, 1.0);
              return Padding(padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: Text(e.key, style: AppTextStyles.body)),
                    Text('${e.value}×', style: AppTextStyles.small),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct.toDouble(),
                        backgroundColor: AppColors.border, color: AppColors.amber, minHeight: 5)),
                ]));
            }).toList()),
          ),
      ]),
    );
  }
}

// ── 3. Payments ───────────────────────────────────────────────────────────────

class _PaymentsPane extends StatelessWidget {
  final String range;
  const _PaymentsPane({required this.range});

  @override
  Widget build(BuildContext context) {
    final (:stats, filtered: _, sorted: _) = _compute(context, range);

    final payEntries = stats.payGroups.entries
        .where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = payEntries.fold<int>(0, (s, e) => s + e.value);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdaptiveGrid(
          mobileCols: 2, tabletCols: 2, desktopCols: 4, childAspectRatio: 1.4,
          children: [
            StatTile(label: 'Gross Revenue',
                value: '₹${stats.total.toStringAsFixed(2)}',
                icon: Icons.currency_rupee, accent: AppColors.green),
            StatTile(label: 'Tax Collected',
                value: '₹${stats.taxCollected.toStringAsFixed(2)}',
                icon: Icons.percent_outlined, accent: AppColors.amber),
            StatTile(label: 'Expenses',
                value: '₹${stats.expensesTotal.toStringAsFixed(2)}',
                icon: Icons.receipt_long_outlined, accent: AppColors.red),
            StatTile(label: 'Net Revenue',
                value: '₹${stats.netRevenue.toStringAsFixed(2)}',
                icon: Icons.savings_outlined, accent: AppColors.green),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader('Payment Methods'),
        const SizedBox(height: 10),
        payEntries.isEmpty
            ? const EmptyState(
                message: 'No payment data', icon: Icons.payment_outlined)
            : AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: payEntries.map((e) {
                    final pct = total == 0 ? 0.0 : e.value / total;
                    final color = _methodColor(e.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                Icon(_methodIcon(e.key),
                                    size: 16, color: color),
                                const SizedBox(width: 6),
                                Text(e.key, style: AppTextStyles.body),
                              ]),
                              Text(
                                '${e.value} orders  '
                                '(${(pct * 100).toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                            ]),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: AppColors.border,
                              color: color, minHeight: 7),
                          ),
                        ]),
                    );
                  }).toList(),
                ),
              ),
      ]),
    );
  }
}

// ── 4. Performance ────────────────────────────────────────────────────────────

class _PerformancePane extends StatelessWidget {
  final String range;
  const _PerformancePane({required this.range});

  @override
  Widget build(BuildContext context) {
    final (:stats, filtered: _, sorted: _) = _compute(context, range);
    final provider = context.watch<RestaurantProvider>();

    final avgPrepMin = stats.avgPrep.toStringAsFixed(1);
    final delayedPct = (stats.delayedPct * 100).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Kitchen Flow'),
        const SizedBox(height: 10),
        AdaptiveGrid(
          mobileCols: 2, tabletCols: 3, desktopCols: 3, childAspectRatio: 1.5,
          children: [
            StatTile(label: 'Preparing',
                value: '${stats.kdsFlow['Preparing'] ?? 0}',
                icon: Icons.local_fire_department_outlined,
                accent: AppColors.amber),
            StatTile(label: 'Ready',
                value: '${stats.kdsFlow['Ready'] ?? 0}',
                icon: Icons.check_circle_outline, accent: AppColors.green),
            StatTile(label: 'Completed',
                value: '${stats.kdsFlow['Delivered/Closed'] ?? 0}',
                icon: Icons.done_all_outlined),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader('Order Timing'),
        const SizedBox(height: 10),
        AdaptiveGrid(
          mobileCols: 2, tabletCols: 3, desktopCols: 3, childAspectRatio: 1.5,
          children: [
            StatTile(label: 'Avg Prep Time', value: '$avgPrepMin min',
                icon: Icons.timer_outlined,
                accent: stats.avgPrep > 15
                    ? AppColors.red : AppColors.green),
            StatTile(label: 'Delayed Orders', value: '$delayedPct%',
                icon: Icons.warning_amber_outlined,
                accent: stats.delayedPct > 0.2
                    ? AppColors.red : AppColors.amber),
            StatTile(
              label: 'Cancellation Rate',
              value: stats.count == 0
                  ? '0%'
                  : '${(stats.cancelledCount /
                      (stats.count + stats.cancelledCount) * 100)
                      .toStringAsFixed(1)}%',
              icon: Icons.cancel_outlined, accent: AppColors.red,
            ),
          ],
        ),
        if (stats.topItems.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader('Best Sellers'),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: stats.topItems.take(5).map((e) {
                final name = provider.menuItems
                    .firstWhere((m) => m.id == e.key,
                        orElse: () => MenuItem(id: -1, name: '#${e.key}',
                            category: '', price: 0, image: ''))
                    .name;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text(name, style: AppTextStyles.body,
                          overflow: TextOverflow.ellipsis)),
                      Text('${e.value}×',
                          style: const TextStyle(
                              color: AppColors.amber,
                              fontWeight: FontWeight.w600)),
                    ]),
                );
              }).toList(),
            ),
          ),
        ],
        if (stats.lowItems.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader('Slow Movers (≤2 orders)'),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8, runSpacing: 6,
              children: stats.lowItems.map((e) {
                final name = provider.menuItems
                    .firstWhere((m) => m.id == e.key,
                        orElse: () => MenuItem(id: -1, name: '#${e.key}',
                            category: '', price: 0, image: ''))
                    .name;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(name,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                );
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── 5. Inventory ──────────────────────────────────────────────────────────────

class _InventoryPane extends StatelessWidget {
  final String range;
  const _InventoryPane({required this.range});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final items = provider.menuItems;
    final available = items.where((m) => m.soldOut != true).toList();
    final soldOut   = items.where((m) => m.soldOut == true).toList();
    final catMap = <String, List<MenuItem>>{};
    for (final m in items) {
      catMap.putIfAbsent(m.category, () => []).add(m);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdaptiveGrid(
          mobileCols: 2, tabletCols: 2, desktopCols: 4, childAspectRatio: 1.5,
          children: [
            StatTile(label: 'Total Items', value: '${items.length}',
                icon: Icons.inventory_2_outlined),
            StatTile(label: 'Available', value: '${available.length}',
                icon: Icons.check_circle_outline, accent: AppColors.green),
            StatTile(label: 'Sold Out', value: '${soldOut.length}',
                icon: Icons.remove_shopping_cart_outlined,
                accent: soldOut.isNotEmpty
                    ? AppColors.red : AppColors.textSecondary),
            StatTile(label: 'Categories', value: '${catMap.length}',
                icon: Icons.category_outlined),
          ],
        ),
        if (soldOut.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader('Sold Out'),
          const SizedBox(height: 10),
          AppCard(
            borderColor: AppColors.red.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: soldOut.map((m) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: buildMenuImage(m.image, size: 22),
                title: Text(m.name, style: AppTextStyles.body),
                subtitle: Text(m.category,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                trailing:
                    const StatusBadge('SOLD OUT', color: AppColors.red),
              )).toList(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const SectionHeader('By Category'),
        const SizedBox(height: 10),
        ...catMap.entries.map((entry) {
          final catItems = entry.value;
          final catSoldOut =
              catItems.where((m) => m.soldOut == true).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.label_outline,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(entry.key, style: AppTextStyles.h3),
                  ]),
                  Row(children: [
                    Text('${catItems.length} items',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    if (catSoldOut > 0) ...[
                      const SizedBox(width: 8),
                      StatusBadge('$catSoldOut sold out',
                          color: AppColors.red),
                    ],
                  ]),
                ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ── 6. Financial ──────────────────────────────────────────────────────────────

class _FinancialPane extends StatelessWidget {
  final String range;
  const _FinancialPane({required this.range});

  @override
  Widget build(BuildContext context) {
    final (:stats, filtered: _, sorted: _) = _compute(context, range);
    final provider = context.watch<RestaurantProvider>();
    final ts = provider.taxSettings;
    final expenses = context.watch<ExpenseProvider>().expenses;
    final dr = getDateRange(range);

    final rangeExpenses = expenses.where((e) =>
        (e['timestamp'] as int) >= dr['startMs']! &&
        (e['timestamp'] as int) < dr['endMs']!).toList();
    final expCats = <String, double>{};
    for (final e in rangeExpenses) {
      final cat = (e['category'] as String?) ?? 'Other';
      expCats[cat] =
          (expCats[cat] ?? 0) + (e['amount'] as num).toDouble();
    }
    final sortedExpCats = expCats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Profit & Loss'),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _PnlRow('Gross Revenue', stats.total, positive: true),
            _PnlRow('Tax Collected', stats.taxCollected, positive: true,
                subtitle: ts.enabled
                    ? '${(ts.rate * 100).toStringAsFixed(1)}%'
                      ' ${ts.inclusive ? "(inclusive)" : "(exclusive)"}'
                    : 'disabled'),
            const Divider(color: AppColors.border),
            _PnlRow('Total Expenses', stats.expensesTotal, positive: false),
            const Divider(color: AppColors.border, height: 8),
            _PnlRow('Net Revenue', stats.netRevenue,
                positive: stats.netRevenue >= 0, bold: true),
          ]),
        ),
        const SizedBox(height: 20),
        AdaptiveGrid(
          mobileCols: 2, tabletCols: 2, desktopCols: 2, childAspectRatio: 1.8,
          children: [
            StatTile(label: 'Cancelled Value',
                value: '₹${stats.cancelledValue.toStringAsFixed(2)}',
                icon: Icons.money_off_outlined, accent: AppColors.red),
            StatTile(label: 'Avg Order Value',
                value: '₹${stats.avg.toStringAsFixed(2)}',
                icon: Icons.trending_up_outlined),
          ],
        ),
        const SizedBox(height: 20),
        if (sortedExpCats.isNotEmpty) ...[
          const SectionHeader('Expense Breakdown'),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: sortedExpCats.map((e) {
                final pct = stats.expensesTotal == 0
                    ? 0.0
                    : (e.value / stats.expensesTotal).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key, style: AppTextStyles.body),
                          Text('₹${e.value.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppColors.red, fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          backgroundColor: AppColors.border,
                          color: AppColors.red, minHeight: 6),
                      ),
                    ]),
                );
              }).toList(),
            ),
          ),
        ] else
          const EmptyState(
              message: 'No expenses in this period',
              icon: Icons.receipt_long_outlined),
      ]),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

IconData _methodIcon(String m) {
  switch (m.toLowerCase()) {
    case 'cash':   return Icons.money_outlined;
    case 'card':   return Icons.credit_card_outlined;
    case 'upi':    return Icons.qr_code_outlined;
    case 'wallet': return Icons.account_balance_wallet_outlined;
    default:       return Icons.payment_outlined;
  }
}

Color _methodColor(String m) {
  switch (m.toLowerCase()) {
    case 'cash':   return AppColors.green;
    case 'card':   return Colors.blue;
    case 'upi':    return Colors.purple;
    case 'wallet': return AppColors.amber;
    default:       return AppColors.textSecondary;
  }
}

// ── P&L row ───────────────────────────────────────────────────────────────────

class _PnlRow extends StatelessWidget {
  final String label;
  final double value;
  final bool positive;
  final bool bold;
  final String? subtitle;

  const _PnlRow(this.label, this.value,
      {required this.positive, this.bold = false, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.green : AppColors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: bold
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                  fontSize: bold ? 14 : 13)),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10)),
        ]),
        Text(
          '${positive ? '' : '−'}₹${value.abs().toStringAsFixed(2)}',
          style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              fontSize: bold ? 15 : 13),
        ),
      ]),
    );
  }
}
