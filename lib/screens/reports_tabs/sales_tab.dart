import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/menu_item.dart';

class SalesTab extends StatefulWidget {
  final List<Order> orders;
  final List<MenuItem> menuItems;

  const SalesTab({super.key, required this.orders, required this.menuItems});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final completedOrders = widget.orders.where((o) => o.status == 'Settled' || o.status == 'Completed').toList();
    
    

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroRevenueCard(completedOrders),
              const SizedBox(height: 24),
              
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildRevenueTrendsChart(completedOrders)),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: _buildRevenueDistributionChart(completedOrders)),
                  ],
                )
              else
                Column(
                  children: [
                    _buildRevenueTrendsChart(completedOrders),
                    const SizedBox(height: 24),
                    _buildRevenueDistributionChart(completedOrders),
                  ],
                ),
              
              const SizedBox(height: 24),
              
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildCategorySalesChart(completedOrders, widget.menuItems)),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: _buildTopSellingItems(completedOrders, widget.menuItems)),
                  ],
                )
              else
                Column(
                  children: [
                    _buildCategorySalesChart(completedOrders, widget.menuItems),
                    const SizedBox(height: 24),
                    _buildTopSellingItems(completedOrders, widget.menuItems),
                  ],
                ),
                
              const SizedBox(height: 24),
              
              if (isWide)
                 Row(
                   children: [
                     Expanded(child: _buildSparklines(completedOrders)),
                     const SizedBox(width: 24),
                     Expanded(child: _buildProfitMarginChart(completedOrders)),
                   ],
                 )
              else
                Column(
                  children: [
                    _buildSparklines(completedOrders),
                    const SizedBox(height: 24),
                    _buildProfitMarginChart(completedOrders),
                  ],
                ),

              const SizedBox(height: 24),
              _buildHeatmap(completedOrders),
            ]
            .animate(interval: 50.ms)
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.1, end: 0, duration: 500.ms),
          ),
        );
      },
    );
  }

  

  Widget _buildHeroRevenueCard(List<Order> orders) {
    double totalRevenue = orders.fold(0, (sum, order) => sum + order.total);
    
    return Hero(
      tag: 'revenue_card',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Revenue',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: totalRevenue),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Text(
                  '₹${NumberFormat('#,##0.00').format(value)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueTrendsChart(List<Order> orders) {
    Map<int, double> dailyRevenue = {};
    for (var order in orders) {
      if (order.createdAt != null) {
        DateTime date = DateTime.fromMillisecondsSinceEpoch(order.createdAt!);
        int day = date.day;
        dailyRevenue[day] = (dailyRevenue[day] ?? 0) + order.total;
      }
    }

    List<FlSpot> spots = dailyRevenue.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    
    if (spots.isEmpty) spots = [const FlSpot(0, 0)];
    spots.sort((a, b) => a.x.compareTo(b.x));

    return RepaintBoundary(
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenue Trends', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF10B981),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF27272A),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            'Day ${spot.x.toInt()}\n₹${spot.y.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySalesChart(List<Order> orders, List<MenuItem> menuItems) {
    Map<String, double> categorySales = {};
    for (var order in orders) {
      for (var item in order.items) {
        final menuItem = menuItems.firstWhere((m) => m.id == item.id, orElse: () => MenuItem(id: -1, name: '', category: 'Unknown', price: 0, image: ''));
        categorySales[menuItem.category] = (categorySales[menuItem.category] ?? 0) + (item.price * item.quantity);
      }
    }

    List<BarChartGroupData> barGroups = [];
    int index = 0;
    categorySales.forEach((category, amount) {
      barGroups.add(BarChartGroupData(
        x: index++,
        barRods: [
          BarChartRodData(toY: amount, color: Colors.blueAccent, width: 16, borderRadius: BorderRadius.circular(4)),
        ],
      ));
    });

    return RepaintBoundary(
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales by Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: const FlTitlesData(show: false),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF27272A),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueDistributionChart(List<Order> orders) {
    double dineIn = orders.where((o) => o.table.startsWith('Table')).fold(0, (sum, o) => sum + o.total);
    double takeOut = orders.where((o) => o.table.startsWith('Takeout') || o.table.startsWith('T#')).fold(0, (sum, o) => sum + o.total);

    return RepaintBoundary(
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenue Distribution', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: dineIn,
                      title: 'Dine-In',
                      color: Colors.purpleAccent,
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: takeOut,
                      title: 'Takeout',
                      color: Colors.orangeAccent,
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingItems(List<Order> orders, List<MenuItem> menuItems) {
     Map<int, int> itemCounts = {};
    for (var order in orders) {
      for (var item in order.items) {
        itemCounts[item.id] = (itemCounts[item.id] ?? 0) + item.quantity;
      }
    }
    
    var sortedItems = itemCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Selling Items', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedItems.take(5).length,
            itemBuilder: (context, index) {
              final entry = sortedItems[index];
              final menuItem = menuItems.firstWhere((m) => m.id == entry.key, orElse: () => MenuItem(id: -1, name: 'Unknown', category: '', price: 0, image: ''));
              
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: menuItem.image.isNotEmpty 
                      ? CachedNetworkImage(
                          imageUrl: menuItem.image,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[800]!,
                            highlightColor: Colors.grey[700]!,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => const Icon(Icons.fastfood, color: Colors.grey),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[800],
                          child: const Icon(Icons.fastfood, color: Colors.white54),
                        ),
                ),
                title: Text(menuItem.name, style: const TextStyle(color: Colors.white)),
                trailing: Text('${entry.value} Sold', style: const TextStyle(color: Colors.white70)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSparklines(List<Order> orders) {
     return RepaintBoundary(
       child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Activity', style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              const FlSpot(0, 1),
                              const FlSpot(1, 3),
                              const FlSpot(2, 2),
                              const FlSpot(3, 5),
                              const FlSpot(4, 3),
                              const FlSpot(5, 4),
                            ], 
                            isCurved: true,
                            color: Colors.greenAccent,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
           ),
     );
  }

  Widget _buildHeatmap(List<Order> orders) {
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
            const Text('Sales Heatmap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            HeatMap(
              datasets: heatMapData,
              colorMode: ColorMode.opacity,
              showText: false,
              scrollable: true,
              colorsets: const {
                1: Colors.green,
              },
              onClick: (value) {
                // Handle click
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitMarginChart(List<Order> orders) {
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
            const Text('Profit Margin (Est.)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 10),
                        const FlSpot(1, 15),
                        const FlSpot(2, 12),
                        const FlSpot(3, 20),
                        const FlSpot(4, 18),
                        const FlSpot(5, 25),
                      ],
                      isCurved: true,
                      color: Colors.amber,
                      barWidth: 2,
                      belowBarData: BarAreaData(show: true, color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
