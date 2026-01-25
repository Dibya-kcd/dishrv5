import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../utils/report_utils.dart';
import '../models/menu_item.dart';
import '../utils/web_adapter.dart' as web;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportFAB extends StatelessWidget {
  final ReportStats stats;
  final String range;
  final List<MenuItem> menuItems;

  const ReportFAB({super.key, required this.stats, required this.range, required this.menuItems});

  void _printReport(BuildContext context) {
    final htmlDoc = '''
<html><head><style>body{font-family:sans-serif;padding:20px;} .card{border:1px solid #ccc;padding:10px;margin:10px 0;}</style></head><body>
<h1>The Dish Report ($range)</h1>
<div class="card">Total Revenue: ₹${stats.total.toStringAsFixed(2)}</div>
<div class="card">Orders: ${stats.count} (Avg: ₹${stats.avg.toStringAsFixed(2)})</div>
<div class="card">Expenses: ₹${stats.expensesTotal.toStringAsFixed(2)}</div>
<div class="card">Net Profit: ₹${stats.netRevenue.toStringAsFixed(2)}</div>
<div class="card">
  <h3>Payment Methods</h3>
  <ul>
    <li>Cash: ${stats.payGroups['Cash']}</li>
    <li>Card: ${stats.payGroups['Card']}</li>
    <li>UPI: ${stats.payGroups['UPI']}</li>
  </ul>
</div>
<div class="card">
  <h3>Performance</h3>
  <div>Avg Prep Time: ${stats.avgPrep.toStringAsFixed(1)} min</div>
  <div>Delayed Orders: ${(stats.delayedPct*100).toStringAsFixed(1)}%</div>
  <div>KDS Flow: Preparing ${stats.kdsFlow['Preparing']}, Ready ${stats.kdsFlow['Ready']}, Delivered/Closed ${stats.kdsFlow['Delivered/Closed']}</div>
</div>
<script>window.onload=function(){window.print();}</script>
</body></html>
''';
    web.openHtmlDocument(htmlDoc);
    context.read<RestaurantProvider>().showToast('Report opened in new tab.', icon: '✅');
  }

  Future<void> _exportPDF(double total, double avg, int dineIn, int takeOut, double tax, double net) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              children: [
                pw.Text('The Dish Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Total Revenue: ${total.toStringAsFixed(2)}'),
                pw.Text('Net Revenue: ${net.toStringAsFixed(2)}'),
                pw.Text('Tax Collected: ${tax.toStringAsFixed(2)}'),
                pw.SizedBox(height: 10),
                pw.Text('Average Order Value: ${avg.toStringAsFixed(2)}'),
                pw.Text('Dine-In Orders: $dineIn'),
                pw.Text('Take-Out Orders: $takeOut'),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF10B981),
      foregroundColor: Colors.white,
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF18181B),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          builder: (_) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Quick Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextButton(onPressed: () => _printReport(context), child: const Text('Print Report'))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextButton(onPressed: () => _exportPDF(stats.total, stats.avg, stats.dineInCount, stats.takeoutCount, stats.taxCollected, stats.netRevenue), child: const Text('Export PDF'))),
                ]),
              ]),
            );
          },
        );
      },
      child: const Icon(Icons.bolt),
    );
  }
}
