import '../models/cart_item.dart';
import '../models/menu_item.dart';

class HtmlTicketGenerator {
  static String generateKOT({
    required Map<String, dynamic> kotData,
    required List<MenuItem> menuItems,
  }) {
    final items = kotData['items'] as List<CartItem>;
    final kotNumber = kotData['kotNumber'];
    final timestamp = kotData['timestamp'];
    final table = kotData['table'];

    final content = '''
<style>
@page { size: 80mm auto; margin: 0; }
@media print { body { margin: 0; padding: 0; } }
body { font-family: Courier New, monospace; width: 80mm; margin: 0 auto; padding: 10mm; font-size: 14px; color: #000000; background-color: #ffffff; }
.header { text-align: center; border-bottom: 3px double #000; padding-bottom: 8px; margin-bottom: 10px; }
.title { font-size: 28px; font-weight: bold; }
.table-info { font-size: 20px; font-weight: bold; background: #000; color: #fff; padding: 5px; text-align: center; margin: 8px 0; }
.item { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px dashed #000; }
.meta { font-size: 12px; color: #000; padding: 2px 0 6px 0; }
.footer { border-top: 3px double #000; padding-top: 10px; margin-top: 15px; text-align: center; }
</style>
<div class="header">
<div class="title">KITCHEN ORDER</div>
<div>KOT #$kotNumber</div>
<div style="font-size: 12px;">$timestamp</div>
</div>
<div class="table-info">$table</div>
${items.map((i) {
      final addons = (i.addons ?? [])
          .map((id) => menuItems
              .firstWhere((m) => m.id == id,
                  orElse: () => MenuItem(
                      id: -1, name: '', category: '', price: 0, image: ''))
              .name)
          .where((n) => n.isNotEmpty)
          .toList();
      final note = (i.instructions ?? '').trim();
      final mods = (i.modifiers ?? [])
          .map((m) => m['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      final metaParts = [
        if (note.isNotEmpty) 'Note: $note',
        if (addons.isNotEmpty) 'Add-ons: ${addons.join(', ')}',
        if (mods.isNotEmpty) 'Modifiers: ${mods.join(', ')}',
      ];
      final meta = metaParts.isEmpty
          ? ''
          : '<div class="meta">${metaParts.join(' | ')}</div>';
      return '<div class="item"><span>${i.name}</span><span style="font-weight: bold; font-size: 18px;">x${i.quantity}</span></div>$meta';
    }).join()}
<div class="footer"><div style="font-weight: bold;">Total Items: ${items.fold<int>(0, (s, i) => s + i.quantity)}</div></div>
<script>
window.onload = function() {
  setTimeout(function() {
    window.print();
  }, 500);
}
</script>
''';
    return '<!DOCTYPE html><html><head><meta charset="utf-8"><title>KOT</title></head><body>$content</body></html>';
  }

  static String generateBill({
    required Map<String, dynamic> billData,
  }) {
    final items = billData['items'] as List<CartItem>;
    final billNumber = billData['billNumber'];
    final timestamp = billData['timestamp'];
    final table = billData['table'];
    final subtotal = billData['subtotal'] as double;
    final gst = billData['gst'] as double;
    final total = billData['total'] as double;
    final paymentMethod = billData['paymentMethod'];

    final content = '''
<style>
@page { size: 80mm auto; margin: 0; }
@media print { body { margin: 0; padding: 0; } }
body { font-family: Courier New, monospace; width: 80mm; margin: 0 auto; padding: 10mm; font-size: 14px; color: #000000; background-color: #ffffff; }
.header { text-align: center; border-bottom: 3px double #000; padding-bottom: 8px; margin-bottom: 10px; }
.title { font-size: 28px; font-weight: bold; }
.bill-info { display: flex; justify-content: space-between; margin-bottom: 10px; border-bottom: 1px solid #000; padding-bottom: 5px; }
.item { display: flex; justify-content: space-between; padding: 4px 0; }
.totals { margin-top: 10px; border-top: 1px solid #000; padding-top: 5px; }
.row { display: flex; justify-content: space-between; padding: 2px 0; }
.total-row { font-weight: bold; font-size: 16px; border-top: 2px solid #000; margin-top: 5px; padding-top: 5px; }
.footer { margin-top: 20px; text-align: center; font-size: 12px; }
</style>
<div class="header">
<div class="title">RESTOPOS</div>
<div>123 Main Street, City</div>
<div>Phone: +91 9876543210</div>
</div>
<div class="bill-info">
<div>Bill #$billNumber</div>
<div>$timestamp</div>
</div>
<div style="margin-bottom: 10px;">Table: $table</div>
${items.map((i) {
      if (i.isCancelled) {
        return '<div class="item" style="color: #999; text-decoration: line-through;"><span>${i.name} (Cancelled)</span><span>0.00</span></div>';
      }
      return '<div class="item"><span>${i.name}</span><span>${(i.price * i.quantity).toStringAsFixed(2)}</span></div>';
    }).join()}
<div class="totals">
<div class="row"><span>Subtotal:</span><span>${subtotal.toStringAsFixed(2)}</span></div>
<div class="row"><span>GST (5%):</span><span>${gst.toStringAsFixed(2)}</span></div>
<div class="row total-row"><span>TOTAL:</span><span>${total.toStringAsFixed(2)}</span></div>
</div>
<div style="margin-top: 10px; font-weight: bold;">Payment: $paymentMethod</div>
<div class="footer">Thank you for dining with us!</div>
<script>
window.onload = function() {
  setTimeout(function() {
    window.print();
  }, 500);
}
</script>
''';
    return '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Bill</title></head><body>$content</body></html>';
  }
}
