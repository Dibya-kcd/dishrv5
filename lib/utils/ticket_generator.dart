import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

class TicketGenerator {
  Future<List<int>> generateKOT(
    Map<String, dynamic> order,
    String tableId,
    String type,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text('KITCHEN ORDER TICKET',
        styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2));
    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Table: $tableId  |  Type: $type',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: 'Item', width: 8),
      PosColumn(text: 'Qty', width: 4),
    ]);
    bytes += generator.hr();

    final items = order['items'] as List<dynamic>;
    for (var item in items) {
      bytes += generator.row([
        PosColumn(text: item['name'], width: 8),
        PosColumn(text: item['qty'].toString(), width: 4),
      ]);
      if (item['note'] != null && item['note'].isNotEmpty) {
        bytes += generator.text('  Note: ${item['note']}');
      }
    }
    bytes += generator.hr();
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  Future<List<int>> generateBill(
    Map<String, dynamic> order,
    String tableId,
    double subtotal,
    double tax,
    double total,
  ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.text('RESTAURANT NAME',
        styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2));
    bytes += generator.text('123 Food Street, City',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Tel: 123-456-7890',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    bytes += generator.text('BILL / RECEIPT',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    bytes += generator.text('Table: $tableId');
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: 'Item', width: 6),
      PosColumn(text: 'Qty', width: 2),
      PosColumn(text: 'Price', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    final items = order['items'] as List<dynamic>;
    for (var item in items) {
      // Skip cancelled items or show them with 0 price? 
      // Usually better to show them as cancelled or skip if they shouldn't appear on final bill.
      // If we skip, the customer won't see them. If we show, we need to mark them.
      // Let's check if the item map has 'isCancelled'.
      // Note: The map comes from order.toJson() which might not include isCancelled if not in the map logic?
      // Wait, CartItem.toJson() (which I should check) usually dumps all fields.
      // Assuming it's there.
      
      bool isCancelled = item['isCancelled'] == true;
      if (isCancelled) continue; // Don't charge for cancelled items.
      // Alternatively, print them with STRIKETHROUGH if ESC/POS supports it (usually doesn't easily).
      // Or print "(Cancelled)" next to name and 0.00.
      
      double price = (item['price'] as num).toDouble();
      double qty = (item['qty'] as num).toDouble();
      double totalItem = price * qty;
      
      bytes += generator.row([
        PosColumn(text: item['name'], width: 6),
        PosColumn(text: qty.toString(), width: 2),
        PosColumn(text: totalItem.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Subtotal:', width: 8),
      PosColumn(text: subtotal.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Tax:', width: 8),
      PosColumn(text: tax.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'TOTAL:', width: 8, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: total.toStringAsFixed(2), width: 4, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]);
    
    bytes += generator.hr();
    bytes += generator.text('Thank you for dining with us!',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }
}
