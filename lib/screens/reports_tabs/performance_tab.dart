import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/restaurant_provider.dart';

class PerformanceTab extends StatefulWidget {
  final List<Order> orders;

  const PerformanceTab({super.key, required this.orders});

  @override
  State<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<PerformanceTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<RestaurantProvider>();
    final orders = widget.orders;
    
    // Calculate Real Metrics
    final totalOrders = orders.length;
    final completedOrders = orders.where((o) => o.status == 'Settled').length;
    final efficiency = totalOrders > 0 ? completedOrders / totalOrders : 0.0;
    
    // Avg Prep Time
    int totalPrepMs = 0;
    int prepCount = 0;
    for (final o in orders) {
      if (o.createdAt != null && o.readyAt != null) {
        totalPrepMs += (o.readyAt! - o.createdAt!);
        prepCount++;
      }
    }
    final avgPrepMins = prepCount > 0 ? (totalPrepMs / 1000 / 60).round() : 0;

    // Avg Table Time (Turnover proxy)
    int totalTableMs = 0;
    int tableCount = 0;
    for (final o in orders) {
      if (o.createdAt != null && o.settledAt != null) {
        totalTableMs += (o.settledAt! - o.createdAt!);
        tableCount++;
      }
    }
    final avgTableMins = tableCount > 0 ? (totalTableMs / 1000 / 60).round() : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KPI Grid
              _buildKPIGrid(efficiency, avgPrepMins, avgTableMins),
              const SizedBox(height: 24),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Efficiency Radial Gauge
                    Expanded(child: Center(child: RepaintBoundary(child: _buildEfficiencyGauge(efficiency)))),
                    const SizedBox(width: 24),
                  ],
                )
              else
                Column(
                  children: [
                    Center(child: RepaintBoundary(child: _buildEfficiencyGauge(efficiency))),
                    const SizedBox(height: 24),
                  ],
                ),
              const SizedBox(height: 24),

              // 4. Kitchen Performance Timeline
              const Text('Kitchen Performance Timeline (Avg)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildKitchenTimeline(avgPrepMins),
              const SizedBox(height: 24),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 6. Table Turnover Radial Chart
                    Expanded(child: RepaintBoundary(child: _buildTableTurnoverChart(provider))),
                    const SizedBox(width: 24),
                    // 7. Bottleneck Analysis Flow
                    Expanded(child: _buildBottleneckAnalysis(avgPrepMins, avgTableMins)),
                  ],
                )
              else
                Column(
                  children: [
                    RepaintBoundary(child: _buildTableTurnoverChart(provider)),
                    const SizedBox(height: 24),
                    _buildBottleneckAnalysis(avgPrepMins, avgTableMins),
                  ],
                ),
            ].animate(interval: 50.ms).fadeIn().slideY(begin: 0.1, end: 0),
          ),
        );
      },
    );
  }

  Widget _buildKPIGrid(double efficiency, int avgPrep, int avgTable) {
    final metrics = [
      {'title': 'Avg Prep Time', 'value': '${avgPrep}m', 'icon': Icons.timer, 'color': Colors.blue},
      {'title': 'Table Turnover', 'value': '${avgTable}m', 'icon': Icons.table_restaurant, 'color': Colors.orange},
      {'title': 'Efficiency', 'value': '${(efficiency * 100).toInt()}%', 'icon': Icons.speed, 'color': Colors.green},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250, // Responsive: Items will be at most 250px wide
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: 500.ms,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(m['icon'] as IconData, color: m['color'] as Color, size: 30),
                    const SizedBox(height: 8),
                    Text(m['value'] as String, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text(m['title'] as String, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEfficiencyGauge(double efficiency) {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF18181B)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 180, height: 180,
            child: CircularProgressIndicator(
              value: efficiency,
              strokeWidth: 15,
              backgroundColor: Colors.grey[800],
              color: Colors.greenAccent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${(efficiency * 100).toInt()}', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
              const Text('Efficiency Score', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildKitchenTimeline(int avgPrep) {
    // Construct timeline based on average prep time
    final steps = [
      {'title': 'Order Received', 'time': '00:00', 'status': 'done'},
      {'title': 'Prep Started', 'time': '00:05', 'status': 'done'},
      {'title': 'Cooking', 'time': '00:${(avgPrep * 0.5).toInt().toString().padLeft(2, '0')}', 'status': 'done'},
      {'title': 'Plating', 'time': '00:${(avgPrep * 0.8).toInt().toString().padLeft(2, '0')}', 'status': 'done'},
      {'title': 'Served', 'time': '00:${avgPrep.toString().padLeft(2, '0')}', 'status': 'done'},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: steps.length,
        itemBuilder: (context, index) {
          final step = steps[index];
          final isFirst = index == 0;
          final isLast = index == steps.length - 1;
          final status = step['status'];
          Color color;
          if (status == 'done') {
            color = Colors.green;
          } else if (status == 'active') {
            color = Colors.orange;
          } else {
            color = Colors.grey;
          }

          return SizedBox(
            width: 120,
            child: TimelineTile(
              axis: TimelineAxis.horizontal,
              alignment: TimelineAlign.center,
              isFirst: isFirst,
              isLast: isLast,
              indicatorStyle: IndicatorStyle(
                width: 20,
                color: color,
                iconStyle: status == 'done' ? IconStyle(iconData: Icons.check, color: Colors.white, fontSize: 12) : null,
              ),
              beforeLineStyle: LineStyle(color: color),
              afterLineStyle: LineStyle(color: status == 'done' ? Colors.green : Colors.grey),
              startChild: Container(
                padding: const EdgeInsets.only(bottom: 8),
                alignment: Alignment.bottomCenter,
                child: Text(step['time']!, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ),
              endChild: Container(
                padding: const EdgeInsets.only(top: 8),
                alignment: Alignment.topCenter,
                child: Text(step['title']!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
            ),
          );
        },
      ),
    );
  }



  Widget _buildTableTurnoverChart(RestaurantProvider provider) {
    final tables = provider.tables;
    final occupied = tables.where((t) => t.status != 'available').length;
    final available = tables.length - occupied;
    final total = tables.length;
    final occupiedPct = total > 0 ? (occupied / total) * 100 : 0.0;
    final availablePct = total > 0 ? (available / total) * 100 : 0.0;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(value: occupiedPct, color: Colors.green, title: 'Occupied', radius: 40, showTitle: false),
                  PieChartSectionData(value: availablePct, color: Colors.blue, title: 'Available', radius: 40, showTitle: false),
                ],
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Table Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Occupied: ${occupiedPct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.green)),
              Text('Available: ${availablePct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottleneckAnalysis(int avgPrep, int avgTable) {
    // Dynamic bottleneck detection
    final isPrepBottleneck = avgPrep > 20; // Threshold 20 mins
    final isServiceBottleneck = avgTable > 90; // Threshold 90 mins

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bottleneck Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildBottleneckNode('Ordering', false),
              _buildArrow(),
              _buildBottleneckNode('Prep', isPrepBottleneck), 
              _buildArrow(),
              _buildBottleneckNode('Service', isServiceBottleneck),
              _buildArrow(),
              _buildBottleneckNode('Payment', false),
            ],
          ),
          const SizedBox(height: 8),
          if (isPrepBottleneck)
            const Text('Warning: Prep station is causing delays (>20m)', style: TextStyle(color: Colors.redAccent, fontSize: 12))
          else if (isServiceBottleneck)
            const Text('Warning: Table turnover is slow (>90m)', style: TextStyle(color: Colors.orange, fontSize: 12))
          else
            const Text('Flow is optimized.', style: TextStyle(color: Colors.green, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBottleneckNode(String title, bool isBottleneck) {
    return Expanded(
      child: Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isBottleneck ? Colors.red.withValues(alpha: 0.2) : const Color(0xFF27272A),
          border: Border.all(color: isBottleneck ? Colors.red : Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(title, style: TextStyle(color: isBottleneck ? Colors.red : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
    );
  }
}
