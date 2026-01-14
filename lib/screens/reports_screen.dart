import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import 'report_screens/sales_report_screen.dart';
import 'report_screens/orders_report_screen.dart';
import 'report_screens/payment_report_screen.dart';
import 'report_screens/performance_report_screen.dart';
import 'report_screens/inventory_report_screen.dart';
import 'report_screens/financial_report_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final index = provider.reportsTabIndex;
    switch (index) {
      case 0:
        return const SalesReportScreen();
      case 1:
        return const OrdersReportScreen();
      case 2:
        return const PaymentReportScreen();
      case 3:
        return const PerformanceReportScreen();
      case 4:
        return const InventoryReportScreen();
      case 5:
        return const FinancialReportScreen();
      default:
        return const SalesReportScreen();
    }
  }
}
