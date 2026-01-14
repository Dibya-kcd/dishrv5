import 'dart:convert';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

class TicketGenerator {
  Future<Generator?> _safeCreateGenerator() async {
    try {
      final profile = await CapabilityProfile.load();
      return Generator(PaperSize.mm80, profile);
    } catch (_) {
      return null;
    }
  }

  List<int> _initCmd() {
    return [27, 64];
  }

  List<int> _textLine(String text) {
    return utf8.encode('$text\n');
  }

  List<int> _hr() {
    return utf8.encode('--------------------------------\n');
  }

  List<int> _cut() {
    return [29, 86, 66, 0];
  }

  List<int> _fallbackKOT(
    Map<String, dynamic> order,
    String tableId,
    String type,
  ) {
    List<int> bytes = [];
    bytes += _initCmd();
    bytes += _textLine('KITCHEN ORDER TICKET');
    bytes += _textLine('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    bytes += _textLine('Table: $tableId  |  Type: $type');
    bytes += _hr();
    bytes += _textLine('Item                 Qty');
    bytes += _hr();

    final items = order['items'] as List<dynamic>;
    for (var item in items) {
      final name = item['name']?.toString() ?? '';
      final qty = item['qty']?.toString() ?? '';
      bytes += _textLine('$name x$qty');
      if (item['note'] != null && item['note'].toString().isNotEmpty) {
        bytes += _textLine('Note: ${item['note']}');
      }
    }

    bytes += _hr();
    bytes += _textLine('');
    bytes += _textLine('');
    bytes += _cut();

    return bytes;
  }

  List<int> _fallbackBill(
    Map<String, dynamic> order,
    String tableId,
    double subtotal,
    double tax,
    double total,
  ) {
    List<int> bytes = [];
    bytes += _initCmd();
    bytes += _textLine('RESTAURANT NAME');
    bytes += _textLine('123 Food Street, City');
    bytes += _textLine('Tel: 123-456-7890');
    bytes += _hr();
    bytes += _textLine('BILL / RECEIPT');
    bytes += _textLine('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    bytes += _textLine('Table: $tableId');
    bytes += _hr();
    bytes += _textLine('Item           Qty    Price');
    bytes += _hr();

    final items = order['items'] as List<dynamic>;
    for (var item in items) {
      bool isCancelled = item['isCancelled'] == true;
      if (isCancelled) continue;

      double price = (item['price'] as num).toDouble();
      double qty = (item['qty'] as num).toDouble();
      double totalItem = price * qty;
      final name = item['name']?.toString() ?? '';
      bytes += _textLine('$name x$qty = ${totalItem.toStringAsFixed(2)}');
    }

    bytes += _hr();
    bytes += _textLine('Subtotal: ${subtotal.toStringAsFixed(2)}');
    bytes += _textLine('Tax: ${tax.toStringAsFixed(2)}');
    bytes += _textLine('TOTAL: ${total.toStringAsFixed(2)}');
    bytes += _hr();
    bytes += _textLine('Thank you for dining with us!');
    bytes += _textLine('');
    bytes += _textLine('');
    bytes += _cut();

    return bytes;
  }

  Future<List<int>> generateKOT(
    Map<String, dynamic> order,
    String tableId,
    String type,
  ) async {
    final generator = await _safeCreateGenerator();
    if (generator != null) {
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
    } else {
      return _fallbackKOT(order, tableId, type);
    }
  }

  Future<List<int>> generateBill(
    Map<String, dynamic> order,
    String tableId,
    double subtotal,
    double tax,
    double total,
  ) async {
    final generator = await _safeCreateGenerator();
    if (generator != null) {
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
        bool isCancelled = item['isCancelled'] == true;
        if (isCancelled) continue;

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
    } else {
      return _fallbackBill(order, tableId, subtotal, tax, total);
    }
  }
}
