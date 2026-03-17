import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/order.dart';
import '../models/table_info.dart';
import '../widgets/app_ui_kit.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final startMs = DateTime(_date.year, _date.month, _date.day).millisecondsSinceEpoch;
    final endMs   = startMs + 86400000;
    final role    = provider.clientRole?.toLowerCase() ?? 'staff';
    final isMgr   = role == 'admin' || role == 'manager';

    final allDay = provider.orders.where((o) {
      final ts = o.settledAt ?? o.createdAt ?? 0;
      return ts >= startMs && ts < endMs;
    }).toList();

    final settled   = allDay.where((o) => o.status == 'Settled').toList();
    final active    = allDay.where((o) => o.status != 'Settled' && o.status != 'Cancelled').toList();
    final cancelled = allDay.where((o) => o.status == 'Cancelled').toList();
    final revenue   = settled.fold<double>(0, (s, o) => s + o.total);
    final activeTbl = provider.tables.where((t) => t.status != 'available').length;
    final kitchen   = active.where((o) => o.status == 'Preparing' || o.status == 'Ready').length;

    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.bg0,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text('Dashboard', style: AppTextStyles.h2),
          actions: [
            _DateChip(date: _date, onPick: (d) => setState(() => _date = d)),
            const SizedBox(width: 12),
          ],
        ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), children: [
        // ── KPI strip (manager only) ──────────────────────────────────────
        if (isMgr) ...[
          _KpiRow(revenue: revenue, orders: settled.length,
              tables: activeTbl, kitchen: kitchen, cancelled: cancelled.length),
          const SizedBox(height: 14),
        ],

        // ── Live 3-panel grid ─────────────────────────────────────────────
        _LiveGrid(allDay: allDay, tables: provider.tables),

        // ── Cancellations alert (only when >0) ───────────────────────────
        if (isMgr && cancelled.isNotEmpty) ...[
          const SizedBox(height: 14),
          _CancellationAlert(orders: cancelled),
        ],

        // ── Recent closed orders ──────────────────────────────────────────
        if (isMgr) ...[
          const SizedBox(height: 14),
          _RecentList(orders: allDay),
        ],
      ]),
    );
  }
}

// ── KPI row ───────────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final double revenue;
  final int orders, tables, kitchen, cancelled;
  const _KpiRow({required this.revenue, required this.orders,
      required this.tables, required this.kitchen, required this.cancelled});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _K('Revenue', '₹${revenue.toStringAsFixed(0)}', AppColors.green, Icons.trending_up),
      const SizedBox(width: 8),
      _K('Orders', '$orders', AppColors.blue, Icons.receipt_long_outlined),
      const SizedBox(width: 8),
      _K('Tables', '$tables', AppColors.amber, Icons.table_bar_outlined),
      const SizedBox(width: 8),
      _K('Kitchen', '$kitchen', AppColors.purple, Icons.soup_kitchen_outlined),
      if (cancelled > 0) ...[
        const SizedBox(width: 8),
        _K('Voided', '$cancelled', AppColors.red, Icons.cancel_outlined),
      ],
    ]);
  }
}

class _K extends StatelessWidget {
  final String label, value;
  final Color accent;
  final IconData icon;
  const _K(this.label, this.value, this.accent, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: accent, size: 12),
          const SizedBox(width: 4),
          Flexible(child: Text(label,
              style: AppTextStyles.small.copyWith(color: AppColors.textSecondary, fontSize: 10),
              overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 15)),
      ]),
    ),
  );
}

// ── Live 3-panel grid ─────────────────────────────────────────────────────────
class _LiveGrid extends StatelessWidget {
  final List<Order> allDay;
  final List<TableInfo> tables;
  const _LiveGrid({required this.allDay, required this.tables});

  @override
  Widget build(BuildContext context) {
    const h = 320.0;
    final panels = [
      SizedBox(height: h, child: _TablePanel(tables: tables, orders: allDay)),
      SizedBox(height: h, child: _TakeoutPanel(orders: allDay)),
      SizedBox(height: h, child: _KitchenPanel(orders: allDay)),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth >= 1024) { return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: panels[0]), const SizedBox(width: 12),
        Expanded(child: panels[1]), const SizedBox(width: 12),
        Expanded(child: panels[2]),
      ]); }
      if (c.maxWidth >= 600) { return Column(children: [
        Row(children: [Expanded(child: panels[0]), const SizedBox(width: 12), Expanded(child: panels[1])]),
        const SizedBox(height: 12), panels[2],
      ]); }
      return Column(children: [panels[0], const SizedBox(height: 12), panels[1], const SizedBox(height: 12), panels[2]]);
    });
  }
}

// ── Table panel ───────────────────────────────────────────────────────────────
class _TablePanel extends StatelessWidget {
  final List<TableInfo> tables;
  final List<Order> orders;
  const _TablePanel({required this.tables, required this.orders});

  @override
  Widget build(BuildContext context) {
    final busy = tables.where((t) => t.status != 'available').toList();
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PanelHeader('Dine-In', '${busy.length}/${tables.length}', AppColors.amber),
      Expanded(child: busy.isEmpty
          ? const EmptyState(message: 'All tables free', icon: Icons.table_bar_outlined)
          : ListView.separated(
              itemCount: busy.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final t = busy[i];
                final o = orders.where((o) => o.table == 'Table ${t.number}'
                    && o.status != 'Settled' && o.status != 'Cancelled')
                    .toList()..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
                final ord = o.isNotEmpty ? o.first : null;
                return _OrderRow('Table ${t.number}',
                    StatusBadge.tableStatus(t.status, small: true), ord,
                    ord != null ? () => ctx.read<RestaurantProvider>().openOrderFromDashboard(ord) : null);
              })),
    ]));
  }
}

// ── Takeout panel ─────────────────────────────────────────────────────────────
class _TakeoutPanel extends StatelessWidget {
  final List<Order> orders;
  const _TakeoutPanel({required this.orders});

  @override
  Widget build(BuildContext context) {
    final toks = orders.where((o) =>
        o.table.startsWith('Takeout #') && o.status != 'Settled' && o.status != 'Cancelled').toList();
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PanelHeader('Take-Out', '${toks.length} open', AppColors.blue),
      Expanded(child: toks.isEmpty
          ? const EmptyState(message: 'No take-out orders', icon: Icons.delivery_dining_outlined)
          : ListView.separated(
              itemCount: toks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final o = toks[i];
                final tok = o.table.replaceFirst('Takeout #', '');
                return _OrderRow('Token $tok', StatusBadge.orderStatus(o.status, small: true), o,
                    () => ctx.read<RestaurantProvider>().openOrderFromDashboard(o));
              })),
    ]));
  }
}

// ── Kitchen panel ─────────────────────────────────────────────────────────────
class _KitchenPanel extends StatelessWidget {
  final List<Order> orders;
  const _KitchenPanel({required this.orders});

  @override
  Widget build(BuildContext context) {
    final q = orders.where((o) => o.status == 'Preparing' || o.status == 'Ready').toList();
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _PanelHeader('Kitchen', '${q.length} active', AppColors.purple)),
        AppButton.ghost('View', small: true, icon: Icons.open_in_new,
            onPressed: () => context.read<RestaurantProvider>().setCurrentView('kitchen')),
      ]),
      Expanded(child: q.isEmpty
          ? const EmptyState(message: 'Kitchen clear', icon: Icons.soup_kitchen_outlined)
          : ListView.separated(
              itemCount: q.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) {
                final o = q[i];
                final label = o.table.startsWith('Table ') ? o.table : 'Token ${o.table.replaceFirst('Takeout #', '')}';
                final elapsed = ((DateTime.now().millisecondsSinceEpoch - (o.createdAt ?? DateTime.now().millisecondsSinceEpoch)) / 60000).floor();
                final pct = o.status == 'Ready' ? 1.0 : (elapsed / 15.0).clamp(0.0, 1.0);
                final late = pct >= 0.8 && o.status != 'Ready';
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ctx.read<RestaurantProvider>().setCurrentView('kitchen'),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      borderRadius: BorderRadius.circular(8),
                      border: late ? Border.all(color: AppColors.red.withValues(alpha: 0.4)) : null,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(label, style: AppTextStyles.h3),
                        Row(children: [
                          if (elapsed > 0) Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text('${elapsed}m', style: AppTextStyles.small.copyWith(
                                color: late ? AppColors.red : AppColors.textSecondary))),
                          StatusBadge.orderStatus(o.status, small: true),
                        ]),
                      ]),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: pct, minHeight: 3,
                        backgroundColor: AppColors.border,
                        color: o.status == 'Ready' ? AppColors.green : (late ? AppColors.red : AppColors.amber),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ]),
                  ),
                );
              })),
    ]));
  }
}

// ── Cancellation alert ────────────────────────────────────────────────────────
class _CancellationAlert extends StatelessWidget {
  final List<Order> orders;
  const _CancellationAlert({required this.orders});

  @override
  Widget build(BuildContext context) {
    final items = orders.expand((o) => o.items.where((i) => i.isCancelled)).toList();
    final counts = <String, int>{};
    for (final it in items) {
      final r = it.cancellationReason ?? 'Unknown';
      counts[r] = (counts[r] ?? 0) + 1;
    }
    return AppCard(
      borderColor: AppColors.red.withValues(alpha: 0.4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cancel_presentation_outlined, color: AppColors.red, size: 15),
          const SizedBox(width: 7),
          Text('${orders.length} cancellations', style: AppTextStyles.h3),
          const Spacer(),
          StatusBadge('${items.length} items', color: AppColors.red, small: true),
        ]),
        if (counts.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...counts.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(e.key, style: AppTextStyles.small),
              Text('${e.value}×', style: AppTextStyles.small.copyWith(color: AppColors.red)),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ── Recent list ───────────────────────────────────────────────────────────────
class _RecentList extends StatelessWidget {
  final List<Order> orders;
  const _RecentList({required this.orders});

  @override
  Widget build(BuildContext context) {
    final closed = [...orders.where((o) => o.status == 'Settled' || o.status == 'Cancelled')]
      ..sort((a, b) => ((b.settledAt ?? b.createdAt) ?? 0).compareTo((a.settledAt ?? a.createdAt) ?? 0));
    final items = closed.take(8).toList();

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Recent'),
      if (items.isEmpty)
        const EmptyState(message: 'No closed orders yet', icon: Icons.receipt_outlined)
      else
        ...items.map((o) {
          final label = o.table.startsWith('Takeout #')
              ? 'Token ${o.table.replaceFirst('Takeout #', '')}' : o.table;
          final ts = DateTime.fromMillisecondsSinceEpoch(o.settledAt ?? o.createdAt ?? 0);
          final time = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
          final ok = o.status == 'Settled';
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: (ok ? AppColors.green : AppColors.red).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: ok ? AppColors.green : AppColors.red, size: 15),
              ),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                Text('${o.paymentMethod ?? o.status} · $time', style: AppTextStyles.small),
              ])),
              Text('₹${o.total.toStringAsFixed(0)}',
                  style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ok ? AppColors.textPrimary : AppColors.red)),
            ]),
          );
        }),
    ]));
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _PanelHeader extends StatelessWidget {
  final String title, badge;
  final Color color;
  const _PanelHeader(this.title, this.badge, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Text(title, style: AppTextStyles.h3),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(badge, style: AppTextStyles.small.copyWith(color: color, fontSize: 10)),
      ),
    ]),
  );
}

class _OrderRow extends StatelessWidget {
  final String title;
  final Widget status;
  final Order? order;
  final VoidCallback? onTap;
  const _OrderRow(this.title, this.status, this.order, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.h3),
          if (order != null)
            Text('${order!.items.fold<int>(0, (s, i) => s + i.quantity)} items · ₹${order!.total.toStringAsFixed(0)}',
                style: AppTextStyles.small),
        ])),
        status,
        if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 15),
      ]),
    ),
  );
}

// ── Date chip ─────────────────────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DateChip({required this.date, required this.onPick});

  String _label(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    const w = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${w[d.weekday-1]} ${d.day} ${m[d.month-1]}';
  }

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () async {
      final p = await showDatePicker(context: context, initialDate: date,
          firstDate: DateTime(2020), lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: AppColors.amber, surface: AppColors.bg2)),
            child: child!));
      if (p != null) onPick(p);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 13),
        const SizedBox(width: 5),
        Text(_label(date), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
