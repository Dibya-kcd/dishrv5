import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:intl/intl.dart';
import '../../data/repository.dart';

class InventoryTab extends StatefulWidget {
  final int startMs;
  final int endMs;

  const InventoryTab({
    super.key,
    required this.startMs,
    required this.endMs,
  });

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> with AutomaticKeepAliveClientMixin {
  final int _lowStockLimit = 20;
  late Future<List<dynamic>> _dataFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(InventoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startMs != widget.startMs || oldWidget.endMs != widget.endMs) {
      _loadData();
    }
  }

  void _loadData() {
    _dataFuture = Future.wait([
      Repository.instance.ingredients.listLowStock(),
      Repository.instance.ingredients.listIngredients(),
      Repository.instance.ingredients.listTransactions(type: 'deduction', fromMs: widget.startMs, toMs: widget.endMs, limit: 1000),
      Repository.instance.ingredients.listTransactions(type: 'wastage', fromMs: widget.startMs, toMs: widget.endMs, limit: 1000),
      Repository.instance.ingredients.listTransactions(type: 'purchase', fromMs: widget.startMs, toMs: widget.endMs, limit: 1000),
    ]);
  }

  Future<void> _refresh() async {
    setState(() {
      _loadData();
    });
    await _dataFuture;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Status Chips
                _buildStatusChips(),
                const SizedBox(height: 24),

                FutureBuilder<List<dynamic>>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                    
                    final lowStock = snapshot.data![0] as List<Map<String, dynamic>>;
                    final allIngredients = snapshot.data![1] as List<Map<String, dynamic>>;
                    final usageTxns = snapshot.data![2] as List<Map<String, dynamic>>;
                    final wastageTxns = snapshot.data![3] as List<Map<String, dynamic>>;
                    final purchaseTxns = snapshot.data![4] as List<Map<String, dynamic>>;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Low Stock Alerts
                        _buildLowStockAlerts(lowStock),
                        const SizedBox(height: 24),

                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 3. Stock Level Bars (Top 5)
                              Expanded(child: _buildStockLevelBars(allIngredients)),
                              const SizedBox(width: 24),
                              // 4. Ingredient Usage Pie Chart
                              Expanded(child: RepaintBoundary(child: _buildUsagePieChart(usageTxns, allIngredients))),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildStockLevelBars(allIngredients),
                              const SizedBox(height: 24),
                              RepaintBoundary(child: _buildUsagePieChart(usageTxns, allIngredients)),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // 5. Wastage Trend Line Chart
                        RepaintBoundary(child: _buildWastageTrendChart(wastageTxns)),
                        const SizedBox(height: 24),

                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 6. Purchase History Timeline
                              Expanded(child: _buildPurchaseHistory(purchaseTxns)),
                              const SizedBox(width: 24),
                              // 7. Cost Analysis Stacked Bar (Mocked as data might be scarce)
                              Expanded(child: RepaintBoundary(child: _buildCostAnalysisChart())),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildPurchaseHistory(purchaseTxns),
                              const SizedBox(height: 24),
                              RepaintBoundary(child: _buildCostAnalysisChart()),
                            ],
                          ),
                        const SizedBox(height: 24),

                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 8. Stock Movement Waterfall (Mocked)
                              Expanded(child: _buildStockMovementWaterfall()),
                              const SizedBox(width: 24),
                              // 9. Supplier Comparison (Mocked)
                              Expanded(child: _buildSupplierComparison()),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildStockMovementWaterfall(),
                              const SizedBox(height: 24),
                              _buildSupplierComparison(),
                            ],
                          ),
                      ],
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('All Stock', Colors.blue, true),
          const SizedBox(width: 8),
          _buildChip('Low Stock', Colors.orange, false),
          const SizedBox(width: 8),
          _buildChip('Out of Stock', Colors.red, false),
          const SizedBox(width: 8),
          _buildChip('Expiring Soon', Colors.purple, false),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.2) : const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : const Color(0xFF27272A)),
      ),
      child: Text(label, style: TextStyle(color: selected ? color : Colors.grey, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLowStockAlerts(List<Map<String, dynamic>> rows) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Low Stock Alerts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('View All')),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, cons) {
            final cross = cons.maxWidth < 700 ? 2 : 4;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cross, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.8),
              itemCount: _lowStockLimit.clamp(0, rows.length),
              itemBuilder: (_, i) {
                final r = rows[i];
                final stock = ((r['stock'] as num?)?.toDouble() ?? 0.0);
                final minT = ((r['min_threshold'] as num?)?.toDouble() ?? 1.0);
                final frac = (stock / (minT * 2)).clamp(0.0, 1.0);
                final color = frac < 0.25 ? const Color(0xFFEF4444) : (frac < 0.5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
                final imgUrl = (r['image']?.toString() ?? '');
                
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
                  child: Row(children: [
                    Stack(
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 40, height: 40, child: imgUrl.isNotEmpty ? Image.network(imgUrl, fit: BoxFit.cover) : Container(color: const Color(0xFF27272A)))),
                        if (frac < 0.25) Positioned(right: 0, top: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${r['name']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${stock.toStringAsFixed(1)} / $minT', style: TextStyle(color: color, fontSize: 10)),
                      const SizedBox(height: 2),
                      ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: frac, color: color, backgroundColor: const Color(0xFF27272A), minHeight: 2)),
                    ])),
                  ]),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStockLevelBars(List<Map<String, dynamic>> ingredients) {
    final sorted = List<Map<String, dynamic>>.from(ingredients)..sort((a,b) => ((b['stock'] as num?)??0).compareTo((a['stock'] as num?)??0));
    final top5 = sorted.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Stock Levels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...top5.map((ing) {
            final stock = (ing['stock'] as num?)?.toDouble() ?? 0.0;
            final max = 100.0; // Mock max for visualization
            final frac = (stock / max).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(ing['name'], style: const TextStyle(color: Colors.white)),
                    Text('${stock.toStringAsFixed(1)} ${ing['base_unit']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: frac, color: Colors.blueAccent, backgroundColor: const Color(0xFF27272A), minHeight: 8),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUsagePieChart(List<Map<String, dynamic>> txns, List<Map<String, dynamic>> ingredients) {
    final usage = <String, double>{};
    final ingMap = {for (final i in ingredients) i['id'] as String: i['name'] as String};
    
    for (final t in txns) {
      final id = t['ingredient_id'] as String;
      final qty = (t['qty'] as num).toDouble();
      usage[id] = (usage[id] ?? 0.0) + qty;
    }

    final sections = usage.entries.take(5).map((e) {
      return PieChartSectionData(
        value: e.value,
        title: '',
        color: Colors.primaries[usage.keys.toList().indexOf(e.key) % Colors.primaries.length],
        radius: 40,
        badgeWidget: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
          child: Text(ingMap[e.key] ?? '?', style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
        badgePositionPercentageOffset: 1.3,
      );
    }).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        children: [
          Row(children: [
            const Text('Ingredient Usage Distribution', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(onPressed: () => _showIngredientUsageDialog(context, widget.startMs, widget.endMs), child: const Text('View Details')),
          ]),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWastageTrendChart(List<Map<String, dynamic>> txns) {
    // Aggregate by day
    final daily = <int, double>{};
    for (final t in txns) {
      final ts = t['timestamp'] as int;
      final day = DateTime.fromMillisecondsSinceEpoch(ts).day;
      final qty = (t['qty'] as num).toDouble();
      daily[day] = (daily[day] ?? 0) + qty;
    }

    final spots = daily.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList()..sort((a,b) => a.x.compareTo(b.x));

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Wastage Trend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(onPressed: () => _showWastageLogsDialog(context, widget.startMs, widget.endMs), child: const Text('View Logs')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots.isEmpty ? [const FlSpot(0,0)] : spots,
                    isCurved: true,
                    color: Colors.redAccent,
                    barWidth: 3,
                    belowBarData: BarAreaData(show: true, color: Colors.redAccent.withValues(alpha: 0.2)),
                    dotData: const FlDotData(show: true),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((s) => LineTooltipItem('${s.y.toStringAsFixed(1)} units', const TextStyle(color: Colors.white))).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseHistory(List<Map<String, dynamic>> txns) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Purchase History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (txns.isEmpty) const Text('No purchases recorded.', style: TextStyle(color: Colors.grey)),
          ...txns.take(5).map((t) {
            final ts = DateTime.fromMillisecondsSinceEpoch(t['timestamp'] as int);
            return TimelineTile(
              alignment: TimelineAlign.start,
              lineXY: 0,
              isFirst: txns.indexOf(t) == 0,
              isLast: txns.indexOf(t) == (txns.length < 5 ? txns.length - 1 : 4),
              indicatorStyle: const IndicatorStyle(width: 12, color: Colors.blue),
              beforeLineStyle: const LineStyle(color: Colors.grey),
              endChild: Container(
                padding: const EdgeInsets.only(left: 16, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('MMM dd, HH:mm').format(ts), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Added ${t['qty']} units (Ref: ${t['ref_id'] ?? '-'})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    if (t['cost'] != null) Text('Cost: ₹${t['cost']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCostAnalysisChart() {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cost Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(toY: 100, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4)), // Procurement
                    BarChartRodData(toY: 30, color: Colors.red, width: 20, borderRadius: BorderRadius.circular(4)), // Wastage
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(toY: 120, color: Colors.blue, width: 20, borderRadius: BorderRadius.circular(4)),
                    BarChartRodData(toY: 25, color: Colors.red, width: 20, borderRadius: BorderRadius.circular(4)),
                  ]),
                ],
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: Colors.blue, size: 10), SizedBox(width: 4), Text('Procurement', style: TextStyle(color: Colors.grey, fontSize: 10)),
              SizedBox(width: 16),
              Icon(Icons.circle, color: Colors.red, size: 10), SizedBox(width: 4), Text('Wastage', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStockMovementWaterfall() {
    // Simplified representation of waterfall
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stock Movement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildWaterfallBar('Opening', 100, Colors.grey),
                _buildWaterfallBar('Purchases', 50, Colors.green),
                _buildWaterfallBar('Sales', -40, Colors.blue),
                _buildWaterfallBar('Wastage', -10, Colors.red),
                _buildWaterfallBar('Closing', 100, Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterfallBar(String label, double value, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: value.abs().toDouble(),
          color: color,
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildSupplierComparison() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Supplier Performance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 400),
              child: Table(
                border: TableBorder.all(color: const Color(0xFF27272A)),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                children: const [
                  TableRow(children: [
                    Padding(padding: EdgeInsets.all(8), child: Text('Supplier', style: TextStyle(color: Colors.grey))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Deliveries', style: TextStyle(color: Colors.grey))),
                    Padding(padding: EdgeInsets.all(8), child: Text('On Time', style: TextStyle(color: Colors.grey))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Quality', style: TextStyle(color: Colors.grey))),
                  ]),
                  TableRow(children: [
                    Padding(padding: EdgeInsets.all(8), child: Text('Fresh Farms', style: TextStyle(color: Colors.white))),
                    Padding(padding: EdgeInsets.all(8), child: Text('12', style: TextStyle(color: Colors.white))),
                    Padding(padding: EdgeInsets.all(8), child: Text('92%', style: TextStyle(color: Colors.green))),
                    Padding(padding: EdgeInsets.all(8), child: Text('4.8/5', style: TextStyle(color: Colors.amber))),
                  ]),
                  TableRow(children: [
                    Padding(padding: EdgeInsets.all(8), child: Text('Meat Masters', style: TextStyle(color: Colors.white))),
                    Padding(padding: EdgeInsets.all(8), child: Text('8', style: TextStyle(color: Colors.white))),
                    Padding(padding: EdgeInsets.all(8), child: Text('85%', style: TextStyle(color: Colors.orange))),
                    Padding(padding: EdgeInsets.all(8), child: Text('4.5/5', style: TextStyle(color: Colors.amber))),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showIngredientUsageDialog(BuildContext context, int startMs, int endMs) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Ingredient Usage Logs', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 500,
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: Repository.instance.ingredients.listTransactions(type: 'deduction', fromMs: startMs, toMs: endMs),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty) return const Center(child: Text('No usage records found', style: TextStyle(color: Colors.grey)));
              
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  final ts = DateTime.fromMillisecondsSinceEpoch(item['timestamp'] as int);
                  return ListTile(
                    title: Text('Ingredient: ${item['ingredient_id']}', style: const TextStyle(color: Colors.white)),
                    subtitle: Text(DateFormat('MMM dd, HH:mm').format(ts), style: const TextStyle(color: Colors.grey)),
                    trailing: Text('-${item['qty']}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showWastageLogsDialog(BuildContext context, int startMs, int endMs) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Wastage Logs', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 500,
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: Repository.instance.ingredients.listTransactions(type: 'wastage', fromMs: startMs, toMs: endMs),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty) return const Center(child: Text('No wastage records found', style: TextStyle(color: Colors.grey)));
              
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final item = snapshot.data![index];
                  final ts = DateTime.fromMillisecondsSinceEpoch(item['timestamp'] as int);
                  return ListTile(
                    title: Text('Ingredient: ${item['ingredient_id']}', style: const TextStyle(color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMM dd, HH:mm').format(ts), style: const TextStyle(color: Colors.grey)),
                        if (item['reason'] != null) Text('Reason: ${item['reason']}', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                      ],
                    ),
                    trailing: Text('-${item['qty']}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
