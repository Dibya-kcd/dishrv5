import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';

class PaymentTab extends StatefulWidget {
  final List<Order> orders;

  const PaymentTab({super.key, required this.orders});

  @override
  State<PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<PaymentTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Process Data
    final payments = <String, double>{};
    double totalRevenue = 0;
    
    for (var o in widget.orders) {
      final method = o.paymentMethod ?? 'Cash';
      payments[method] = (payments[method] ?? 0) + o.total;
      totalRevenue += o.total;
    }

    // Success Rate (Assuming 100% for now as we don't track failures/refunds yet)
    final successRate = 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Payment Method Cards
              _buildPaymentMethodCards(payments),
              const SizedBox(height: 24),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Animated Pie/Donut Chart
                    Expanded(child: RepaintBoundary(child: _buildPaymentDistributionChart(payments))),
                    const SizedBox(width: 24),
                    // 3. Radial Gauge
                    Expanded(child: RepaintBoundary(child: _buildSuccessRateGauge(successRate))),
                  ],
                )
              else
                Column(
                  children: [
                    RepaintBoundary(child: _buildPaymentDistributionChart(payments)),
                    const SizedBox(height: 24),
                    RepaintBoundary(child: _buildSuccessRateGauge(successRate)),
                  ],
                ),
              const SizedBox(height: 24),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 4. Comparison Bars (Cash vs Card vs Others)
                    Expanded(child: RepaintBoundary(child: _buildComparisonBars(payments))),
                    const SizedBox(width: 24),
                    // 5. Treemap Visualization (Simplified)
                    Expanded(child: _buildTreemap(payments, totalRevenue)),
                  ],
                )
              else
                Column(
                  children: [
                    RepaintBoundary(child: _buildComparisonBars(payments)),
                    const SizedBox(height: 24),
                    _buildTreemap(payments, totalRevenue),
                  ],
                ),
              const SizedBox(height: 24),

              // 6. Transaction List
              _buildTransactionList(widget.orders),
            ].animate(interval: 50.ms).fadeIn().slideY(begin: 0.1, end: 0),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodCards(Map<String, double> payments) {
    return SizedBox(
      height: 120, // Increased height to prevent overflow
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: payments.entries.map((e) {
          IconData icon;
          Color color;
          switch (e.key.toLowerCase()) {
            case 'card': icon = FontAwesomeIcons.creditCard; color = Colors.blue; break;
            case 'upi': icon = FontAwesomeIcons.mobile; color = Colors.purple; break;
            case 'wallet': icon = FontAwesomeIcons.wallet; color = Colors.orange; break;
            default: icon = FontAwesomeIcons.moneyBill; color = Colors.green;
          }
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('₹${e.value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentDistributionChart(Map<String, double> payments) {
    final sections = payments.entries.map((e) {
      Color color;
      switch (e.key.toLowerCase()) {
        case 'card': color = Colors.blue; break;
        case 'upi': color = Colors.purple; break;
        case 'wallet': color = Colors.orange; break;
        default: color = Colors.green;
      }
      return PieChartSectionData(
        value: e.value,
        title: '${((e.value / (payments.values.fold(0.0, (s,v)=>s+v))) * 100).toStringAsFixed(0)}%',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    }).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        children: [
          const Text('Payment Methods Distribution', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
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

  Widget _buildSuccessRateGauge(double rate) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        children: [
          const Text('Success Rate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100, height: 100,
                  child: CircularProgressIndicator(
                    value: rate / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[800],
                    color: Colors.greenAccent,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildComparisonBars(Map<String, double> payments) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Method Comparison', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                    final keys = payments.keys.toList();
                    if (v.toInt() < 0 || v.toInt() >= keys.length) return const SizedBox();
                    return Text(keys[v.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 10));
                  })),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: payments.entries.toList().asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.value, color: Colors.amber, width: 20, borderRadius: BorderRadius.circular(4))]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreemap(Map<String, double> payments, double total) {
    // Simplified Treemap: Vertical Column of proportional colored containers
    final sorted = payments.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Volume Treemap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: sorted.map((e) {
                final flex = ((e.value / total) * 100).round();
                if (flex == 0) return const SizedBox();
                Color color;
                switch (e.key.toLowerCase()) {
                  case 'card': color = Colors.blue; break;
                  case 'upi': color = Colors.purple; break;
                  case 'wallet': color = Colors.orange; break;
                  default: color = Colors.green;
                }
                return Expanded(
                  flex: flex,
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    color: color,
                    child: Center(child: Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<Order> orders) {
    // Group by Date
    final grouped = <String, List<Order>>{};
    for (var o in orders) {
      if (o.createdAt == null) continue;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(o.createdAt!));
      grouped.putIfAbsent(date, () => []).add(o);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        ...grouped.entries.take(3).map((e) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.key, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...e.value.take(5).map((o) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF27272A),
                  child: Icon(
                    o.paymentMethod == 'Card' ? FontAwesomeIcons.creditCard : FontAwesomeIcons.moneyBill,
                    color: Colors.white, size: 16,
                  ),
                ),
                title: Text('Order #${o.id.substring(0, 4)}', style: const TextStyle(color: Colors.white)),
                subtitle: Text(DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(o.createdAt!)), style: const TextStyle(color: Colors.grey)),
                trailing: Text('₹${o.total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              )),
              const Divider(color: Color(0xFF27272A)),
            ],
          );
        }),
      ],
    );
  }
}
