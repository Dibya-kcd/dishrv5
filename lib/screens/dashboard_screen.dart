import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/order.dart';
import '../models/table_info.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final orders = provider.orders;
    final tables = provider.tables;
    final catFilter = provider.analyticsCategoryFilter;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startOfSelected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).millisecondsSinceEpoch;
    final startMs = startOfSelected;
    final endMs = startMs + 24 * 60 * 60 * 1000;
    final filteredOrders = orders.where((o) {
      final ts = o.settledAt ?? o.createdAt ?? nowMs;
      if (ts < startMs || ts >= endMs) return false;
      if (catFilter != 'All') {
        final hasCat = o.items.any((i) {
          final mi = provider.menuItems.firstWhere((m) => m.id == i.id, orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''));
          return mi.category == catFilter;
        });
        if (!hasCat) return false;
      }
      return true;
    }).toList();

    filteredOrders.where((o) => o.status == 'Preparing').toList();
    filteredOrders.where((o) => o.status == 'Ready').toList();
    filteredOrders.where((o) => o.status == 'Settled' || o.status == 'Completed').toList();
    tables.where((t) => t.status == 'occupied' || t.status == 'billing' || t.status == 'serving' || t.status == 'preparing').toList();

    final role = provider.clientRole?.toLowerCase() ?? 'staff';
    
    // Simplified Dashboard Visibility
    final showClosedOrders = role == 'admin' || role == 'manager';

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      
      return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                title: const Text('Live Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildDateChip(width),
                  ),
                ],
              ),
          ],
          body: ListView(
            children: [
              if (role == 'admin' || role == 'manager') _buildCancellationReport(context, width, startMs, endMs),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(builder: (context, box) {
                  final w = box.maxWidth;
                  final isWide = w >= 1024;
                  final targetCols = isWide ? 3 : (w >= 600 ? 2 : 1);
                  const spacing = 16.0;
                  final totalSpacing = spacing * (targetCols - 1);
                  final itemWidth = targetCols == 1 ? w : (w - totalSpacing) / targetCols;
                  final desiredHeight = isWide ? 420.0 : 380.0;
                  final height = desiredHeight;

                  final cards = [
                    _gridCard(child: _buildTableOrders(context, tables, filteredOrders), height: height),
                    _gridCard(child: _buildTakeoutOrders(context, filteredOrders), height: height),
                    _gridCard(child: _buildKitchenStatus(context, filteredOrders, width), height: height),
                  ];

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.center,
                    children: cards
                        .map((c) => SizedBox(
                              width: isWide ? itemWidth : w,
                              child: c,
                            ))
                        .toList(),
                  );
                }),
              ),
              if (showClosedOrders)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildClosedOrders(context, filteredOrders),
                ),
            ],
          ),
        );
    });
  }
  Widget _gridCard({required Widget child, double? height}) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: height == null ? child : SizedBox(height: height, child: child),
      ),
    );
  }
  Widget _buildDateChip(double width) {
    final font = width < 600 ? 14.0 : (width <= 1024 ? 15.0 : 16.0);
    final paddingH = width < 600 ? 12.0 : 14.0;
    final paddingV = width < 600 ? 8.0 : 10.0;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (ctx, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFFF59E0B),
                  surface: Color(0xFF18181B),
                  onSurface: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(_dateLabel(_selectedDate), style: TextStyle(color: Colors.white, fontSize: font, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    final w = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d.weekday - 1];
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '$w, ${d.day} ${months[d.month - 1]}';
  }
  Widget _buildClosedOrders(BuildContext context, List<Order> orders) {
    final closed = orders.where((o) => o.status == 'Settled' || o.status == 'Cancelled').toList();
    closed.sort((a, b) => ((b.settledAt ?? b.createdAt) ?? 0).compareTo((a.settledAt ?? a.createdAt) ?? 0));
    final items = closed.take(6).toList();
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Recent Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (items.isEmpty) const Text('No recent closures', style: TextStyle(color: Color(0xFFA1A1AA))) else
          Column(children: items.map((o) {
            final label = o.table.startsWith('Takeout #') ? o.table.replaceFirst('Takeout #', 'Token#') : o.table;
            final statusLabel = o.status == 'Cancelled' ? 'Cancelled' : 'Closed';
            final method = o.paymentMethod ?? '';
            final ts = o.settledAt ?? o.createdAt ?? DateTime.now().millisecondsSinceEpoch;
            final t = DateTime.fromMillisecondsSinceEpoch(ts);
            final timeStr = '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$statusLabel • $method • $timeStr', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                ])),
                Text('₹${o.total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            );
          }).toList()),
      ]),
    );
  }


  Widget _buildTableOrders(BuildContext context, List<TableInfo> tables, List<Order> orders) {
    final activeTables = tables.where((t) => t.status != 'available').toList();
    final scrollController = ScrollController();
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Table Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(
          child: activeTables.isEmpty
              ? Center(child: const Text('No active tables', style: TextStyle(color: Color(0xFFA1A1AA))))
              : Scrollbar(
                  thumbVisibility: true,
                  controller: scrollController,
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: activeTables.length,
                    itemBuilder: (context, i) {
                      final t = activeTables[i];
                      Order o;
                      final oid = t.orderId;
                      if (oid != null && oid.isNotEmpty) {
                        o = orders.firstWhere(
                          (x) => x.id == oid,
                          orElse: () => Order(id: '', table: '', status: '', items: [], total: 0, time: ''),
                        );
                      if (o.id.isEmpty) {
                        final candidates = orders.where((x) => x.table == 'Table ${t.number}' && x.status != 'Settled' && x.status != 'Cancelled').toList();
                        candidates.sort((a, b) => ((b.createdAt ?? 0)).compareTo(a.createdAt ?? 0));
                        o = candidates.isNotEmpty ? candidates.first : Order(id: '', table: '', status: '', items: [], total: 0, time: '');
                      }
                    } else {
                      final candidates = orders.where((x) => x.table == 'Table ${t.number}' && x.status != 'Settled' && x.status != 'Cancelled').toList();
                      candidates.sort((a, b) => ((b.createdAt ?? 0)).compareTo(a.createdAt ?? 0));
                      o = candidates.isNotEmpty ? candidates.first : Order(id: '', table: '', status: '', items: [], total: 0, time: '');
                    }
                    final status = t.status;
                    return InkWell(
                        onTap: () {
                          if (o.id.isNotEmpty) context.read<RestaurantProvider>().openOrderFromDashboard(o);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('Table ${t.number}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF3B82F6))),
                                child: (status.toLowerCase() == 'preparing')
                                    ? const Icon(Icons.restaurant_menu, color: Colors.white, size: 16)
                                    : Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            if (o.id.isNotEmpty)
                              ExpansionTile(
                                title: Text('${o.items.fold<int>(0, (s, i) => s + i.quantity)} items • ₹${o.total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white)),
                                children: o.items.map((it) => ListTile(
                                  title: Text('${it.name} x${it.quantity}', style: const TextStyle(color: Colors.white)),
                                  subtitle: (it.instructions != null && it.instructions!.isNotEmpty) ? Text(it.instructions!, style: const TextStyle(color: Color(0xFFA1A1AA))) : null,
                                )).toList(),
                              ) else const Text('No order yet', style: TextStyle(color: Color(0xFFA1A1AA))),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }
  Widget _buildTakeoutOrders(BuildContext context, List<Order> orders) {
    final toks = orders.where((o) => o.table.startsWith('Takeout #') && o.status != 'Settled' && o.status != 'Cancelled').toList();
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Take-Out Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(
          child: toks.isEmpty
              ? Center(child: const Text('No take-out orders', style: TextStyle(color: Color(0xFFA1A1AA))))
              : Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    itemCount: toks.length,
                    itemBuilder: (context, i) {
                      final o = toks[i];
                      final token = o.table.replaceFirst('Takeout #', '');
                      final status = o.status;
                      String label;
                      Color badgeBorder;
                      switch (status) {
                        case 'Preparing':
                          label = 'Preparing';
                          badgeBorder = const Color(0xFFF59E0B);
                          break;
                        case 'Ready':
                          label = 'Ready';
                          badgeBorder = const Color(0xFF3B82F6);
                          break;
                        case 'Awaiting Payment':
                          label = 'Awaiting Payment';
                          badgeBorder = const Color(0xFFA855F7);
                          break;
                        case 'Completed':
                          label = 'Completed';
                          badgeBorder = const Color(0xFF22C55E);
                          break;
                        default:
                          label = status;
                          badgeBorder = const Color(0xFF71717A);
                      }
                      return InkWell(
                        onTap: () => context.read<RestaurantProvider>().openOrderFromDashboard(o),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(token, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: badgeBorder)),
                                child: (label.toLowerCase() == 'preparing')
                                    ? const Icon(Icons.restaurant_menu, color: Colors.white, size: 16)
                                    : Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            if (status == 'Awaiting Payment') ...[
                              ...context.read<RestaurantProvider>().getKotBatchesForTable(o.table).map((b) {
                                final ts = b['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
                                final when = DateTime.fromMillisecondsSinceEpoch(ts);
                                final hh = when.hour.toString().padLeft(2,'0');
                                final mm = when.minute.toString().padLeft(2,'0');
                                final items = (b['items'] as List<CartItem>);
                                return InkWell(
                                  onTap: () {
                                    final consolidated = context.read<RestaurantProvider>().consolidatedItemsForTable(o.table);
                                    context.read<RestaurantProvider>().openPaymentModal(consolidated, o.table, false);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('KOT Batch • $hh:$mm • ${items.fold<int>(0, (s, i) => s + i.quantity)} items', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      ...items.map((it) => Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text('${it.name} x${it.quantity}', style: const TextStyle(color: Colors.white))),
                                          if (it.instructions != null && it.instructions!.isNotEmpty)
                                            Flexible(child: Text(it.instructions!, style: const TextStyle(color: Color(0xFFA1A1AA)), overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        ],
                                      )),
                                    ]),
                                  ),
                                );
                              }),
                            ] else
                              ExpansionTile(
                                title: Text('${o.items.fold<int>(0, (s, i) => s + i.quantity)} items • ₹${o.total.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white)),
                                children: o.items.map((it) => ListTile(
                                  title: Text('${it.name} x${it.quantity}', style: const TextStyle(color: Colors.white)),
                                  subtitle: (it.instructions != null && it.instructions!.isNotEmpty) ? Text(it.instructions!, style: const TextStyle(color: Color(0xFFA1A1AA))) : null,
                                )).toList(),
                              ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }
  Widget _buildKitchenStatus(BuildContext context, List<Order> orders, double width) {
    final queue = orders.where((o) => o.status == 'Preparing' || o.status == 'Ready').toList();
    final scrollController = ScrollController();
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Kitchen Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(
          child: queue.isEmpty
              ? Center(child: const Text('No pending orders', style: TextStyle(color: Color(0xFFA1A1AA))))
              : Scrollbar(
                  thumbVisibility: true,
                  controller: scrollController,
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: queue.length,
                    itemBuilder: (context, i) {
                      final o = queue[i];
                      final label = o.table.startsWith('Table ') ? o.table : o.table.replaceFirst('Takeout #', '');
                      final start = o.createdAt ?? DateTime.now().millisecondsSinceEpoch;
                      final now = DateTime.now().millisecondsSinceEpoch;
                      final elapsedMin = ((now - start) / 60000).floor();
                      final pct = (o.status == 'Ready') ? 1.0 : (elapsedMin / 15.0).clamp(0.0, 1.0);
                      return InkWell(
                        onTap: () => context.read<RestaurantProvider>().setCurrentView('kitchen'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(o.status, style: const TextStyle(color: Color(0xFFA1A1AA))),
                            ]),
                            const SizedBox(height: 6),
                            ...o.items.map((it) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text('${it.name} x${it.quantity}', style: const TextStyle(color: Colors.white))),
                                if (it.instructions != null && it.instructions!.isNotEmpty)
                                  Flexible(child: Text(it.instructions!, style: const TextStyle(color: Color(0xFFA1A1AA)), overflow: TextOverflow.ellipsis, maxLines: 1)),
                              ],
                            )),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: const Color(0xFF18181B), color: const Color(0xFF10B981)),
                            const SizedBox(height: 4),
                            Text('Elapsed: $elapsedMin min', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }
  Widget _buildCancellationReport(BuildContext context, double width, int startMs, int endMs) {
    final provider = context.watch<RestaurantProvider>();
    final cancelledItems = provider.orders.expand((o) {
      if ((o.createdAt ?? 0) < startMs || (o.createdAt ?? 0) >= endMs) return <CartItem>[];
      return o.items.where((i) => i.isCancelled);
    }).toList();

    if (cancelledItems.isEmpty) return const SizedBox.shrink();

    final totalCancelled = cancelledItems.length;
    final reasonCounts = <String, int>{};
    for (var item in cancelledItems) {
      final r = item.cancellationReason ?? 'Unknown';
      reasonCounts[r] = (reasonCounts[r] ?? 0) + 1;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_presentation, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Cancellation Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              Text('$totalCancelled Items', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Reasons Breakdown', style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...reasonCounts.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(color: Colors.white)),
                Text('${e.value} (${(e.value / totalCancelled * 100).toStringAsFixed(1)}%)', style: const TextStyle(color: Color(0xFFA1A1AA))),
              ],
            ),
          )),
        ],
      ),
    );
  }


 
}
