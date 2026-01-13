import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FinancialTab extends StatefulWidget {
  final double totalSales;
  final double totalExpenses;
  final int startMs;
  final int endMs;

  const FinancialTab({
    super.key,
    required this.totalSales,
    required this.totalExpenses,
    required this.startMs,
    required this.endMs,
  });

  @override
  State<FinancialTab> createState() => _FinancialTabState();
}

class _FinancialTabState extends State<FinancialTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final netProfit = widget.totalSales - widget.totalExpenses;
    final profitMargin = widget.totalSales > 0 ? (netProfit / widget.totalSales) * 100 : 0.0;
    
    // Mock data for visualizations since we only have totals
    final cogs = widget.totalExpenses * 0.4; // 40% of expenses are Cost of Goods Sold
    final labor = widget.totalExpenses * 0.3; // 30% Labor
    final overhead = widget.totalExpenses * 0.2; // 20% Overhead
    final marketing = widget.totalExpenses * 0.1; // 10% Marketing

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              // 1. Header Section
              if (isWide || isTablet)
                Row(
                  children: [
                    Expanded(
                      child: _buildHeroCard(
                        'Net Profit', 
                        netProfit, 
                        netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                        netProfit >= 0 ? Colors.green : Colors.red,
                        '${profitMargin.toStringAsFixed(1)}% Margin'
                      )
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildHeroCard(
                        'Total Revenue', 
                        widget.totalSales, 
                        Icons.attach_money,
                        Colors.blue,
                        '+12.5% vs last period'
                      )
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildHeroCard(
                        'Total Expenses', 
                        widget.totalExpenses, 
                        Icons.money_off,
                        Colors.orange,
                        'Low Efficiency'
                      )
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildHeroCard(
                      'Net Profit', 
                      netProfit, 
                      netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                      netProfit >= 0 ? Colors.green : Colors.red,
                      '${profitMargin.toStringAsFixed(1)}% Margin'
                    ),
                    const SizedBox(height: 16),
                    _buildHeroCard(
                      'Total Revenue', 
                      widget.totalSales, 
                      Icons.attach_money,
                      Colors.blue,
                      '+12.5% vs last period'
                    ),
                    const SizedBox(height: 16),
                    _buildHeroCard(
                      'Total Expenses', 
                      widget.totalExpenses, 
                      Icons.money_off,
                      Colors.orange,
                      'Low Efficiency'
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // 2. Waterfall Chart
              RepaintBoundary(child: _buildFinancialWaterfall(widget.totalSales, cogs, labor, overhead, marketing, netProfit)),
              
              const SizedBox(height: 24),

              // 3. Expense Structure & Profit Trend
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: RepaintBoundary(child: _buildExpenseStructure(cogs, labor, overhead, marketing))),
                    const SizedBox(width: 24),
                    Expanded(child: RepaintBoundary(child: _buildProfitabilityTrend())),
                  ],
                )
              else
                Column(
                  children: [
                    RepaintBoundary(child: _buildExpenseStructure(cogs, labor, overhead, marketing)),
                    const SizedBox(height: 24),
                    RepaintBoundary(child: _buildProfitabilityTrend()),
                  ],
                ),

              const SizedBox(height: 24),

              // 4. Detailed Metrics
              _buildDetailedMetrics(widget.totalSales, cogs, labor, overhead, marketing, netProfit),
              
              const SizedBox(height: 24),

              // 5. Cash Flow Indicator
              _buildCashFlowIndicator(),
            ].animate(interval: 50.ms).fadeIn().slideY(begin: 0.1, end: 0),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(String title, double amount, IconData icon, Color color, String subtitle) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            currencyFormat.format(amount),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialWaterfall(double revenue, double cogs, double labor, double overhead, double marketing, double netProfit) {
    final double startCogs = revenue - cogs;
    final double startLabor = startCogs - labor;
    final double startOverhead = startLabor - overhead;
    final double startMarketing = startOverhead - marketing;
    
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profit & Loss Waterfall', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Icon(Icons.waterfall_chart, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: revenue * 1.1,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF27272A),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String label = '';
                      double value = 0;
                      switch(group.x) {
                        case 0: label = 'Revenue'; value = revenue; break;
                        case 1: label = 'COGS'; value = cogs; break;
                        case 2: label = 'Labor'; value = labor; break;
                        case 3: label = 'Overhead'; value = overhead; break;
                        case 4: label = 'Marketing'; value = marketing; break;
                        case 5: label = 'Net Profit'; value = netProfit; break;
                      }
                      return BarTooltipItem(
                        '$label\n',
                        const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                            text: '₹${value.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(color: Colors.grey, fontSize: 10);
                        switch (value.toInt()) {
                          case 0: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Revenue', style: style));
                          case 1: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('COGS', style: style));
                          case 2: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Labor', style: style));
                          case 3: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Overhead', style: style));
                          case 4: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Mktg', style: style));
                          case 5: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Profit', style: style));
                          default: return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFF27272A), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(toY: revenue, color: Colors.blue, width: 24, borderRadius: BorderRadius.circular(4)),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(toY: startCogs + cogs, fromY: startCogs, color: Colors.red.shade400, width: 24, borderRadius: BorderRadius.circular(4)),
                  ]),
                  BarChartGroupData(x: 2, barRods: [
                    BarChartRodData(toY: startLabor + labor, fromY: startLabor, color: Colors.red.shade400, width: 24, borderRadius: BorderRadius.circular(4)),
                  ]),
                  BarChartGroupData(x: 3, barRods: [
                    BarChartRodData(toY: startOverhead + overhead, fromY: startOverhead, color: Colors.red.shade400, width: 24, borderRadius: BorderRadius.circular(4)),
                  ]),
                  BarChartGroupData(x: 4, barRods: [
                    BarChartRodData(toY: startMarketing + marketing, fromY: startMarketing, color: Colors.red.shade400, width: 24, borderRadius: BorderRadius.circular(4)),
                  ]),
                  BarChartGroupData(x: 5, barRods: [
                    BarChartRodData(toY: netProfit, color: Colors.green, width: 24, borderRadius: BorderRadius.circular(4)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseStructure(double cogs, double labor, double overhead, double marketing) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cost Structure', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(value: cogs, title: '40%', color: Colors.red.shade300, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: labor, title: '30%', color: Colors.orange.shade300, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: overhead, title: '20%', color: Colors.purple.shade300, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: marketing, title: '10%', color: Colors.blue.shade300, radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem('COGS', Colors.red.shade300),
              _buildLegendItem('Labor', Colors.orange.shade300),
              _buildLegendItem('Overhead', Colors.purple.shade300),
              _buildLegendItem('Mktg', Colors.blue.shade300),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildProfitabilityTrend() {
    final spots = [
      const FlSpot(0, 15),
      const FlSpot(1, 18),
      const FlSpot(2, 14),
      const FlSpot(3, 22),
      const FlSpot(4, 25),
      const FlSpot(5, 28),
    ];

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profit Margin Trend (6M)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFF27272A), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (value, meta) {
                    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                    if (value.toInt() >= 0 && value.toInt() < months.length) {
                      return Padding(padding: const EdgeInsets.only(top: 8), child: Text(months[value.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 10)));
                    }
                    return const Text('');
                  })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 10, reservedSize: 30, getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(color: Colors.grey, fontSize: 10)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMetrics(double revenue, double cogs, double labor, double overhead, double marketing, double netProfit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial Statement', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStatementRow('Total Revenue', revenue, isHeader: true),
          const Divider(color: Color(0xFF27272A)),
          _buildStatementRow('Cost of Goods Sold (COGS)', -cogs, color: Colors.red.shade300),
          _buildStatementRow('Gross Profit', revenue - cogs, isBold: true),
          const Divider(color: Color(0xFF27272A)),
          _buildStatementRow('Operating Expenses', -(labor + overhead + marketing), color: Colors.red.shade300),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                _buildStatementRow('Labor Cost', -labor, isSubItem: true),
                _buildStatementRow('Overheads', -overhead, isSubItem: true),
                _buildStatementRow('Marketing', -marketing, isSubItem: true),
              ],
            ),
          ),
          const Divider(color: Color(0xFF27272A)),
          _buildStatementRow('Net Profit', netProfit, isHeader: true, color: netProfit >= 0 ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatementRow(String label, double amount, {bool isHeader = false, bool isBold = false, bool isSubItem = false, Color? color}) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: isHeader ? Colors.white : (isSubItem ? Colors.grey : Colors.grey.shade300),
            fontSize: isHeader ? 16 : 14,
            fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          )),
          Text(
            currencyFormat.format(amount),
            style: TextStyle(
              color: color ?? (isHeader ? Colors.white : Colors.white70),
              fontSize: isHeader ? 16 : 14,
              fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade900.withValues(alpha: 0.2), Colors.purple.shade900.withValues(alpha: 0.2)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            child: const Icon(FontAwesomeIcons.moneyBillTransfer, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cash Flow Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Positive cash flow maintained for 12 weeks', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
