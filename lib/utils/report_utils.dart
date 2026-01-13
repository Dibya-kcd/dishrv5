import '../models/order.dart';
import '../models/menu_item.dart';

class ReportStats {
  final double total;
  final int count;
  final double avg;
  final Map<String, int> payGroups;
  final int dineInCount;
  final int takeoutCount;
  final double expensesTotal;
  final double taxCollected;
  final double netRevenue;
  final double avgPrep;
  final double delayedPct;
  final int cancelledCount;
  final double cancelledValue;
  final Map<String, int> kdsFlow;
  final List<MapEntry<String, int>> topCats;
  final List<MapEntry<int, int>> topItems;
  final List<MapEntry<int, int>> lowItems;

  ReportStats({
    required this.total,
    required this.count,
    required this.avg,
    required this.payGroups,
    required this.dineInCount,
    required this.takeoutCount,
    required this.expensesTotal,
    required this.taxCollected,
    required this.netRevenue,
    required this.avgPrep,
    required this.delayedPct,
    required this.cancelledCount,
    required this.cancelledValue,
    required this.kdsFlow,
    required this.topCats,
    required this.topItems,
    required this.lowItems,
  });
}

List<Order> getFilteredOrders(
  List<Order> orders,
  String range,
  String catFilter,
  String svcFilter,
  List<MenuItem> menuItems,
) {
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
  } else if (range == '365D') {
    startMs = nowMs - 365 * 24 * 60 * 60 * 1000;
    endMs = nowMs;
  } else {
    startMs = 0;
    endMs = nowMs + 24 * 60 * 60 * 1000;
  }

  return orders.where((o) {
    int? tsRaw = o.createdAt ?? o.settledAt ?? o.readyAt;
    if (tsRaw == null) {
      final digits = RegExp(r'\d+').allMatches(o.id).map((m) => m.group(0)!).toList();
      if (digits.isNotEmpty) {
        final s = digits.reduce((a, b) => a.length >= b.length ? a : b);
        final n = int.tryParse(s);
        if (n != null) tsRaw = n < 1000000000000 ? n * 1000 : n;
      }
      if (tsRaw == null && range != 'All Time') return false;
    } else {
      if (tsRaw < startMs || tsRaw >= endMs) return false;
    }
    if (svcFilter == 'Dine-In' && !o.table.startsWith('Table')) return false;
    if (svcFilter == 'Take-Out' && !o.table.startsWith('Takeout') && !o.table.startsWith('T#')) return false;
    if (catFilter != 'All') {
      final hasCat = o.items.any((i) {
        final mi = menuItems.firstWhere((m) => m.id == i.id, orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''));
        return mi.category == catFilter;
      });
      if (!hasCat) return false;
    }
    return true;
  }).toList();
}

Map<String, int> getDateRange(String range) {
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
  } else if (range == '365D') {
    startMs = nowMs - 365 * 24 * 60 * 60 * 1000;
    endMs = nowMs;
  } else {
    startMs = 0;
    endMs = nowMs + 24 * 60 * 60 * 1000;
  }
  return {'startMs': startMs, 'endMs': endMs};
}

ReportStats calculateReportStats(
  List<Order> filtered,
  List<Map<String, dynamic>> expenses,
  List<MenuItem> menuItems,
  int startMs,
  int endMs,
) {
  final completed = filtered.where((o) => o.status == 'Settled' || o.status == 'Completed').toList();
  final total = completed.fold<double>(0, (s, o) => s + o.total);
  final count = completed.length;
  final avg = count == 0 ? 0.0 : total / count;
  final payGroups = {'Cash': 0, 'Card': 0, 'UPI': 0, 'Wallet': 0, 'Split': 0};
  for (final o in completed) {
    final k = o.paymentMethod ?? 'Cash';
    if (payGroups.containsKey(k)) {
      payGroups[k] = (payGroups[k] ?? 0) + 1;
    } else {
      payGroups[k] = 1;
    }
  }
  final dineInCount = completed.where((o) => o.table.startsWith('Table')).length;
  final takeoutCount = completed.where((o) => o.table.startsWith('Takeout') || o.table.startsWith('T#')).length;

  final expensesTotal = expenses
      .where((e) => (e['timestamp'] as int) >= startMs && (e['timestamp'] as int) < endMs)
      .fold<double>(0.0, (s, e) => s + (e['amount'] as num).toDouble());
  final taxCollected = completed.fold<double>(0.0, (s, o) => s + (o.total - (o.total / 1.05)));
  final netRevenue = total - expensesTotal;

  final itemsCount = <int, int>{};
  final catCount = <String, int>{};
  final instrCount = <String, int>{};
  for (final o in completed) {
    for (final it in o.items) {
      itemsCount[it.id] = (itemsCount[it.id] ?? 0) + it.quantity;
      final mi = menuItems.firstWhere((m) => m.id == it.id, orElse: () => MenuItem(id: -1, name: '', category: '', price: 0, image: ''));
      final cat = mi.category;
      if (cat.isNotEmpty) catCount[cat] = (catCount[cat] ?? 0) + it.quantity;
      final note = (it.instructions ?? '').trim();
      if (note.isNotEmpty) instrCount[note] = (instrCount[note] ?? 0) + 1;
    }
  }
  final topCats = catCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final topItems = itemsCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final lowItems = itemsCount.entries.where((e) => e.value <= 2).toList();
  final prepTimes = filtered
      .where((o) => o.readyAt != null && o.createdAt != null)
      .map((o) => (o.readyAt! - o.createdAt!) / 60000.0)
      .toList();
  final avgPrep = prepTimes.isEmpty ? 0.0 : (prepTimes.reduce((a, b) => a + b) / prepTimes.length);
  final delayed = prepTimes.where((t) => t > 15.0).length;
  final delayedPct = prepTimes.isEmpty ? 0.0 : (delayed / prepTimes.length);
  final kdsFlow = {
    'Preparing': filtered.where((o) => o.status == 'Preparing').length,
    'Ready': filtered.where((o) => o.status == 'Ready').length,
    'Delivered/Closed': filtered.where((o) => o.status == 'Completed' || o.status == 'Settled').length,
  };

  final cancelledOrders = filtered.where((o) => o.status == 'Cancelled').toList();
  final cancelledCount = cancelledOrders.length;
  final cancelledValue = cancelledOrders.fold<double>(0.0, (s, o) => s + o.total);

  return ReportStats(
    total: total,
    count: count,
    avg: avg,
    payGroups: payGroups,
    dineInCount: dineInCount,
    takeoutCount: takeoutCount,
    expensesTotal: expensesTotal,
    taxCollected: taxCollected,
    netRevenue: netRevenue,
    avgPrep: avgPrep,
    delayedPct: delayedPct,
    cancelledCount: cancelledCount,
    cancelledValue: cancelledValue,
    kdsFlow: kdsFlow,
    topCats: topCats,
    topItems: topItems,
    lowItems: lowItems,
  );
}
