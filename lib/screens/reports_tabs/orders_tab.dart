import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../models/order.dart';

class OrdersTab extends StatefulWidget {
  final List<Order> orders;

  const OrdersTab({super.key, required this.orders});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFunnelChart(widget.orders),
              const SizedBox(height: 24),
              
              if (isWide)
                Row(
                  children: [
                    Expanded(child: _buildOrderTypeBarChart(widget.orders)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildCompletionRate(widget.orders)),
                  ],
                )
              else
                Column(
                  children: [
                    _buildOrderTypeBarChart(widget.orders),
                    const SizedBox(height: 24),
                    _buildCompletionRate(widget.orders),
                  ],
                ),

              const SizedBox(height: 24),
              _buildOrderVelocityCurve(widget.orders),
              const SizedBox(height: 24),
              _buildPeakHoursHeatmap(widget.orders),
              const SizedBox(height: 24),
              _buildLiquidGauge(widget.orders),
              const SizedBox(height: 24),
              const Text('Recent Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              _buildOrderTimeline(widget.orders),
              const SizedBox(height: 24),
              _buildSlidableOrderCards(widget.orders),
            ]
            .animate(interval: 50.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.1, end: 0, duration: 500.ms),
          ),
        );
      },
    );
  }

  Widget _buildFunnelChart(List<Order> orders) {
    int placed = orders.length;
    int preparing = orders.where((o) => o.status != 'Cancelled').length;
    int ready = orders.where((o) => ['Ready', 'Completed', 'Settled'].contains(o.status)).length;
    int completed = orders.where((o) => ['Completed', 'Settled'].contains(o.status)).length;

    return RepaintBoundary(
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Status Funnel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: CustomPaint(
                painter: FunnelPainter(
                  stages: [placed, preparing, ready, completed],
                  labels: ['Placed', 'Preparing', 'Ready', 'Completed'],
                  colors: [Colors.blue, Colors.orange, Colors.purple, Colors.green],
                ),
                child: Container(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeBarChart(List<Order> orders) {
    int dineIn = orders.where((o) => o.table.startsWith('Table')).length;
    int takeOut = orders.where((o) => o.table.startsWith('Takeout') || o.table.startsWith('T#')).length;

    return RepaintBoundary(
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Types', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: dineIn.toDouble(), color: Colors.blueAccent, width: 20)]),
                    BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: takeOut.toDouble(), color: Colors.orangeAccent, width: 20)]),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(value == 0 ? 'Dine-In' : 'Takeout', style: const TextStyle(color: Colors.white, fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionRate(List<Order> orders) {
    int total = orders.length;
    int completed = orders.where((o) => ['Completed', 'Settled'].contains(o.status)).length;
    double rate = total == 0 ? 0 : completed / total;

    return RepaintBoundary(
      child: Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          children: [
            const Text('Completion Rate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: rate,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  Text('${(rate * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderVelocityCurve(List<Order> orders) {
    Map<int, int> hourlyCounts = {};
    for (var order in orders) {
      if (order.createdAt != null) {
        int hour = DateTime.fromMillisecondsSinceEpoch(order.createdAt!).hour;
        hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
      }
    }
    
    List<FlSpot> spots = [];
    for (int i = 0; i < 24; i++) {
      spots.add(FlSpot(i.toDouble(), (hourlyCounts[i] ?? 0).toDouble()));
    }

    return RepaintBoundary(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Velocity (Orders/Hour)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.cyan,
                      barWidth: 3,
                      belowBarData: BarAreaData(show: true, color: Colors.cyan.withValues(alpha: 0.2)),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  titlesData: const FlTitlesData(show: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakHoursHeatmap(List<Order> orders) {
     Map<DateTime, int> heatMapData = {};
    for (var order in orders) {
       if (order.createdAt != null) {
        DateTime date = DateTime.fromMillisecondsSinceEpoch(order.createdAt!);
        DateTime normalizedDate = DateTime(date.year, date.month, date.day);
        heatMapData[normalizedDate] = (heatMapData[normalizedDate] ?? 0) + 1;
      }
    }

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Busy Days Heatmap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            HeatMap(
              datasets: heatMapData,
              colorMode: ColorMode.opacity,
              showText: false,
              scrollable: true,
              colorsets: const {
                1: Colors.red,
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiquidGauge(List<Order> orders) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const CircularProgressIndicator(
                  value: 0.75,
                  color: Colors.blue,
                  backgroundColor: Colors.white24,
                  strokeWidth: 8,
                ),
                const Text("Target", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          const Expanded(child: Text("Monthly Target Achievement", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildOrderTimeline(List<Order> orders) {
    final recentOrders = orders.take(5).toList();

    return Column(
      children: recentOrders.asMap().entries.map((entry) {
        final index = entry.key;
        final order = entry.value;
        final isFirst = index == 0;
        final isLast = index == recentOrders.length - 1;

        return SizedBox(
          height: 80,
          child: TimelineTile(
            isFirst: isFirst,
            isLast: isLast,
            beforeLineStyle: const LineStyle(color: Colors.grey),
            indicatorStyle: IndicatorStyle(
              width: 20,
              color: order.status == 'Completed' ? Colors.green : Colors.orange,
              padding: const EdgeInsets.all(6),
            ),
            endChild: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text('#${order.id}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text(order.table.startsWith('Takeout #') && order.status == 'Completed' ? 'Billing' : order.status, style: TextStyle(color: order.status == 'Completed' ? Colors.green : Colors.orange)),
                  const Spacer(),
                  Text(
                    order.createdAt != null 
                    ? DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(order.createdAt!)) 
                    : '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSlidableOrderCards(List<Order> orders) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.take(5).length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Slidable(
            key: ValueKey(order.id),
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) {},
                  backgroundColor: const Color(0xFFFE4A49),
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Delete',
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) {},
                  backgroundColor: const Color(0xFF7BC043),
                  foregroundColor: Colors.white,
                  icon: Icons.check,
                  label: 'Complete',
                ),
              ],
            ),
            child: Hero(
              tag: 'order_card_${order.id}',
              child: Card(
                color: const Color(0xFF27272A),
                child: ListTile(
                  title: Text('Order #${order.id}', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('₹${order.total}', style: const TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FunnelPainter extends CustomPainter {
  final List<int> stages;
  final List<String> labels;
  final List<Color> colors;

  FunnelPainter({required this.stages, required this.labels, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = stages.isNotEmpty ? stages.reduce((a, b) => a > b ? a : b).toDouble() : 1.0;
    final w = size.width;
    final h = size.height;
    final stageH = h / stages.length;

    for (int i = 0; i < stages.length; i++) {
      final val = stages[i];
      final width = maxVal > 0 ? (val / maxVal) * w : 0.0;
      final x = (w - width) / 2;
      final y = i * stageH;

      final paint = Paint()..color = colors[i % colors.length];
      
      final path = Path();
      if (i < stages.length - 1) {
        final nextVal = stages[i+1];
        final nextWidth = maxVal > 0 ? (nextVal / maxVal) * w : 0.0;
        final nextX = (w - nextWidth) / 2;
        
        path.moveTo(x, y);
        path.lineTo(x + width, y);
        path.lineTo(nextX + nextWidth, y + stageH);
        path.lineTo(nextX, y + stageH);
        path.close();
      } else {
        path.addRect(Rect.fromLTWH(x, y, width, stageH));
      }
      
      canvas.drawPath(path, paint);

      final textSpan = TextSpan(
        text: '${labels[i]}: $val',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((w - textPainter.width) / 2, y + stageH / 2 - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
