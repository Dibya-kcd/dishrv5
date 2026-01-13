import 'package:flutter/material.dart';
import '../utils/web_adapter.dart' as web;
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../data/repository.dart';
import '../models/cart_item.dart';
import '../widgets/page_scaffold.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, Object>> _ingredients = [];
  String _categoryFilter = 'All';
  String _searchText = '';
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  bool _qaExpanded = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final all = await Repository.instance.ingredients.listIngredients();
    setState(() {
      _ingredients = all.map((e) => Map<String, Object>.from(e)).toList();
      _loading = false;
    });
  }

  Future<void> _showReportsDialog() async {
    String filterType = 'All';
    List<Map<String, dynamic>> txns = [];
    bool loading = true;

    Future<void> load(StateSetter setLocal) async {
      setLocal(() => loading = true);
      final t = await Repository.instance.ingredients.listTransactions(
        type: filterType == 'All' ? null : filterType.toLowerCase(),
        limit: 50,
      );
      setLocal(() {
        txns = t;
        loading = false;
      });
    }

    await showDialog(context: context, builder: (_) {
      return StatefulBuilder(builder: (context, setLocal) {
        if (loading) load(setLocal);
        
        return AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          title: const Text('Inventory Reports', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
          content: SizedBox(
            width: 700,
            height: 500,
            child: Column(children: [
              Row(children: [
                const Text('Filter by Type: ', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                    child: DropdownButton<String>(
                      value: filterType,
                      dropdownColor: const Color(0xFF18181B),
                      items: ['All', 'Purchase', 'Wastage', 'Deduction', 'Restore'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setLocal(() {
                            filterType = v;
                            loading = true; // Trigger reload
                          });
                        }
                      },
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(onPressed: () => load(setLocal), icon: const Icon(Icons.refresh, color: Colors.white)),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : txns.isEmpty
                        ? const Center(child: Text('No transactions found', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: txns.length,
                            itemBuilder: (context, index) {
                              final t = txns[index];
                              final ingId = t['ingredient_id'] as String;
                              final ingName = _ingredients.firstWhere((i) => i['id'] == ingId, orElse: () => <String, Object>{'name': 'Unknown'})['name'];
                              final type = t['type'] as String;
                              final qty = (t['qty'] as num).toDouble();
                              final unit = t['unit'] as String;
                              final date = DateTime.fromMillisecondsSinceEpoch(t['timestamp'] as int);
                              final color = type == 'purchase' || type == 'restore' ? Colors.green : Colors.red;
                              final reason = t['reason'] != null ? '(${t['reason']})' : '';
                              final kot = t['kot_number'] != null ? '[KOT: ${t['kot_number']}]' : '';
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(8)),
                                child: Row(children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('$ingName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      Text(date.toString().split('.')[0], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ]),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${type.toUpperCase()} $reason $kot', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (t['supplier'] != null) Text('Supplier: ${t['supplier']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ]),
                                  ),
                                  Text('${qty.toStringAsFixed(2)} $unit', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ]),
                              );
                            },
                          ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ],
        );
      });
    });
  }

  List<Map<String, Object>> get _filtered {
    final byCat = _categoryFilter == 'All' ? _ingredients : _ingredients.where((r) => (r['category'] as String? ?? '') == _categoryFilter).toList();
    if (_searchText.trim().isEmpty) return byCat;
    final q = _searchText.trim().toLowerCase();
    return byCat.where((r) => ((r['name'] as String? ?? '').toLowerCase().contains(q)) || ((r['supplier'] as String? ?? '').toLowerCase().contains(q))).toList();
  }

  Future<void> _showPurchaseDialog({String? presetIngId}) async {
    String? ingId = presetIngId;
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'g');
    final costCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final invoiceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    if (ingId != null && !_ingredients.any((x) => (x['id']?.toString() ?? '') == ingId)) {
      ingId = null;
    }
    if (ingId != null) {
      final sel = _ingredients.firstWhere((x) => (x['id']?.toString() ?? '') == ingId, orElse: () => <String, Object>{});
      unitCtrl.text = (sel['base_unit']?.toString() ?? unitCtrl.text);
      final s = (sel['supplier'] as String?)?.trim();
      if (s != null && s.isNotEmpty) supplierCtrl.text = s;
    }
    try {
      await showDialog(context: context, builder: (_) {
        return StatefulBuilder(builder: (context, setLocal) {
          return AlertDialog(
            backgroundColor: const Color(0xFF18181B),
            title: const Text('Add Purchase/Refill', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (ingId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                  child: Builder(builder: (_) {
                    final sel = _ingredients.firstWhere((x) => (x['id']?.toString() ?? '') == ingId, orElse: () => <String, Object>{});
                    final name = (sel['name'] as String?) ?? '';
                    final cat = (sel['category'] as String?) ?? 'Uncategorized';
                    final bu = (sel['base_unit'] as String?) ?? '';
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: const TextStyle(color: Colors.white)),
                      Text('$cat • $bu', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
                    ]);
                  }),
                )
              else
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                    child: DropdownButton<String>(
                      value: null,
                      hint: const Text('Ingredient', style: TextStyle(color: Colors.white)),
                      dropdownColor: const Color(0xFF18181B),
                      items: _ingredients.map((r) {
                        final name = (r['name'] as String?) ?? '';
                        final cat = (r['category'] as String?) ?? 'Uncategorized';
                        final bu = (r['base_unit'] as String?) ?? '';
                        return DropdownMenuItem(
                          value: r['id'] as String,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: const TextStyle(color: Colors.white)),
                            Text('$cat • $bu', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
                          ]),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setLocal(() {
                          ingId = v;
                          final sel = _ingredients.firstWhere((x) => (x['id']?.toString() ?? '') == v, orElse: () => <String, Object>{});
                          unitCtrl.text = (sel['base_unit']?.toString() ?? unitCtrl.text);
                          final s = (sel['supplier'] as String?)?.trim();
                          if (s != null && s.isNotEmpty) supplierCtrl.text = s;
                        });
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: qtyCtrl, decoration: const InputDecoration(hintText: 'Quantity'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(hintText: 'Unit'), readOnly: true)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: costCtrl, decoration: const InputDecoration(hintText: 'Cost/Unit'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: supplierCtrl, decoration: const InputDecoration(hintText: 'Supplier'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: invoiceCtrl, decoration: const InputDecoration(hintText: 'Invoice'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: noteCtrl, decoration: const InputDecoration(hintText: 'Note'))),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () async {
              if (ingId == null) return;
              final nav = Navigator.of(context);
              final rp = context.read<RestaurantProvider>();
              final q = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
              final u = unitCtrl.text.trim().isEmpty ? 'g' : unitCtrl.text.trim();
              final c = double.tryParse(costCtrl.text.trim());
              await Repository.instance.ingredients.insertPurchase(ingId!, q, u, costPerUnit: c, supplier: supplierCtrl.text.trim().isEmpty ? null : supplierCtrl.text.trim(), invoice: invoiceCtrl.text.trim().isEmpty ? null : invoiceCtrl.text.trim(), note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
              nav.pop();
              rp.showToast('Refilled $q $u', icon: '✅');
              await _refresh();
            }, child: const Text('Add')),
          ],
        );
          });
      });
    } catch (_) {}
  }

  Future<void> _showWastageDialog() async {
    String? ingId;
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'g');
    final reasonCtrl = TextEditingController(text: 'spoilage');
    await showDialog(context: context, builder: (_) {
      return StatefulBuilder(builder: (context, setLocal) {
        return AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          title: const Text('Deduct for Wastage', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                  child: DropdownButton<String>(
                    value: ingId,
                    hint: const Text('Ingredient', style: TextStyle(color: Colors.white)),
                    dropdownColor: const Color(0xFF18181B),
                    items: _ingredients.map((r) {
                      final name = (r['name'] as String?) ?? '';
                      final cat = (r['category'] as String?) ?? 'Uncategorized';
                      final bu = (r['base_unit'] as String?) ?? '';
                      return DropdownMenuItem(
                        value: r['id'] as String,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: const TextStyle(color: Colors.white)),
                          Text('$cat • $bu', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
                        ]),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setLocal(() {
                        ingId = v;
                        final sel = _ingredients.firstWhere((x) => x['id'] == v, orElse: () => <String, Object>{});
                        unitCtrl.text = (sel['base_unit']?.toString() ?? unitCtrl.text);
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: qtyCtrl, decoration: const InputDecoration(hintText: 'Quantity'), keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(hintText: 'Unit'), readOnly: true)),
              ]),
              const SizedBox(height: 8),
              TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'Reason')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () async {
              if (ingId == null) return;
              final nav = Navigator.of(context);
              final rp = context.read<RestaurantProvider>();
              final q = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
              final u = unitCtrl.text.trim().isEmpty ? 'g' : unitCtrl.text.trim();
              final r = reasonCtrl.text.trim().isEmpty ? 'wastage' : reasonCtrl.text.trim();
              await Repository.instance.ingredients.recordWastage(ingId!, q, u, r);
              nav.pop();
              rp.showToast('Wastage: $q $u • $r', icon: '🗑️');
              await _refresh();
            }, child: const Text('Deduct')),
          ],
        );
      });
    });
  }

  Future<void> _showBatchPrepDialog() async {
    final items = <Map<String, dynamic>>[];
    void addRow() => items.add({'ingredient_id': null, 'qty': 0.0, 'unit': 'g'});
    addRow();
    await showDialog(context: context, builder: (_) {
      return StatefulBuilder(builder: (context, setLocal) {
        return AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          title: const Text('Batch Prep', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ...items.asMap().entries.map((entry) {
                final idx = entry.key;
                final it = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(child: DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                        child: DropdownButton<String>(
                          value: it['ingredient_id'] as String?,
                          hint: const Text('Ingredient', style: TextStyle(color: Colors.white)),
                          dropdownColor: const Color(0xFF18181B),
                          items: _ingredients.map((r) {
                            final name = (r['name'] as String?) ?? '';
                            final cat = (r['category'] as String?) ?? 'Uncategorized';
                            final bu = (r['base_unit'] as String?) ?? '';
                            return DropdownMenuItem(
                              value: r['id'] as String,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: const TextStyle(color: Colors.white)),
                                Text('$cat • $bu', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
                              ]),
                            );
                          }).toList(),
                          onChanged: (v) => setLocal(() { 
                            it['ingredient_id'] = v; 
                            final sel = _ingredients.firstWhere((x) => x['id'] == v, orElse: () => <String, Object>{});
                            it['unit'] = sel['base_unit']?.toString() ?? (it['unit']?.toString() ?? 'g');
                          }),
                        ),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Qty'), keyboardType: TextInputType.number, onChanged: (v) => it['qty'] = double.tryParse(v) ?? 0.0)),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: TextEditingController(text: (it['unit']?.toString() ?? 'g')), decoration: const InputDecoration(hintText: 'Unit'), readOnly: true)),
                    IconButton(onPressed: () => setLocal(() { items.removeAt(idx); }), icon: const Icon(Icons.delete, color: Colors.white), tooltip: 'Remove'),
                  ]),
                );
              }),
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setLocal(() { addRow(); }), child: const Text('Add Row'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () async {
              final filtered = items.where((it) => (it['ingredient_id'] as String?) != null && ((it['qty'] as num?)?.toDouble() ?? 0.0) > 0).toList();
              if (filtered.isEmpty) return;
              final nav = Navigator.of(context);
              await Repository.instance.ingredients.applyBatchPrep(filtered);
              nav.pop();
              await _refresh();
            }, child: const Text('Deduct')),
          ],
        );
      });
    });
  }

  Future<void> _showRestoreKOTDialog() async {
    final provider = context.read<RestaurantProvider>();
    String? tableLabel;
    List<Map<String, dynamic>> batches = [];
    int? selectedIdx;
    await showDialog(context: context, builder: (_) {
      return StatefulBuilder(builder: (context, setLocal) {
        return AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          title: const Text('Restore Cancelled KOT', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                  child: DropdownButton<String>(
                    value: tableLabel,
                    hint: const Text('Select Table/Order Label', style: TextStyle(color: Colors.white)),
                    dropdownColor: const Color(0xFF18181B),
                    items: provider.orders.map((o) => o.table).toSet().map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setLocal(() {
                      tableLabel = v;
                      batches = v == null ? [] : provider.getKotBatchesForTable(v);
                      selectedIdx = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (batches.isNotEmpty)
                Container(
                  decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                  child: Column(children: batches.asMap().entries.map((e) {
                    final idx = e.key;
                    final b = e.value;
                    final ts = DateTime.fromMillisecondsSinceEpoch((b['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch).toLocal().toString();
                    return RadioListTile<int>(
                      value: idx,
                      groupValue: selectedIdx,
                      onChanged: (v) => setLocal(() => selectedIdx = v),
                      title: Text('Batch ${idx + 1} • $ts', style: const TextStyle(color: Colors.white)),
                    );
                  }).toList()),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ElevatedButton(onPressed: () async {
              if (tableLabel == null || selectedIdx == null) return;
              final nav = Navigator.of(context);
              final order = provider.orders.firstWhere((o) => o.table == tableLabel);
              final batch = batches[selectedIdx!];
              final items = List<CartItem>.from(batch['items'] as List<CartItem>);
              final kotNum = provider.currentKOT?['kotNumber']?.toString();
              await Repository.instance.ingredients.restoreKOTBatch(items, orderId: order.id, kotNumber: kotNum);
              nav.pop();
              provider.showToast('Restored KOT items to inventory', icon: '♻️');
              await _refresh();
            }, child: const Text('Restore')),
              ElevatedButton(onPressed: () async {
                if (tableLabel == null || selectedIdx == null) return;
                final nav = Navigator.of(context);
                final batch = batches[selectedIdx!];
                final items = List<CartItem>.from(batch['items'] as List<CartItem>);
                for (final ci in items) {
                  final recipe = await Repository.instance.ingredients.getRecipeForMenuItem(ci.id);
                  for (final r in recipe) {
                  final ingId = r['ingredient_id'] as String;
                  final qtyPerUnit = (r['qty'] as num?)?.toDouble() ?? 0.0;
                  final unit = r['unit'] as String? ?? '';
                  final total = qtyPerUnit * ci.quantity.toDouble();
                  await Repository.instance.ingredients.recordWastage(ingId, total, unit, 'cancelled');
                }
              }
              nav.pop();
              provider.showToast('Marked batch items as wasted', icon: '🗑️');
              await _refresh();
            }, child: const Text('Mark Wasted')),
          ],
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cats = ['All', ..._ingredients.map((r) => r['category'] as String? ?? '').where((c) => c.isNotEmpty).toSet()];
    return PageScaffold(
      title: 'Inventory',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 0),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Expanded(child: Text('Quick Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      IconButton(
                        onPressed: () => setState(() => _qaExpanded = !_qaExpanded),
                        icon: Icon(_qaExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    LayoutBuilder(builder: (context, constraints) {
                      if (!_qaExpanded) return const SizedBox.shrink();
                      final w = constraints.maxWidth;
                      final cross = w < 600 ? 2 : (w < 900 ? 3 : 4);
                      final actions = [
      {'icon': Icons.block, 'label': 'Deduct for Wastage', 'onTap': _showWastageDialog, 'color': const Color(0xFFEF4444)},
      {'icon': Icons.playlist_add_outlined, 'label': 'Batch Prep', 'onTap': _showBatchPrepDialog, 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.assessment_outlined, 'label': 'View Reports', 'onTap': _showReportsDialog, 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.restore_outlined, 'label': 'Restore Cancelled KOT', 'onTap': _showRestoreKOTDialog, 'color': const Color(0xFF14B8A6)},
      {'icon': Icons.add_circle_outline, 'label': 'Add New Ingredient', 'onTap': _showCreateIngredientDialog, 'color': const Color(0xFF10B981)},
      {'icon': Icons.cleaning_services_outlined, 'label': 'Clean Duplicates', 'onTap': _fixDuplicates, 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.image_outlined, 'label': 'Design Mockups', 'onTap': _openMockupPreview, 'color': const Color(0xFFA78BFA)},
    ];
                      return GridView.count(
                        crossAxisCount: cross,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: actions.map((a) {
                          return Tooltip(
                            message: a['label'] as String,
                            child: _QuickActionPill(
                              icon: a['icon'] as IconData,
                              color: a['color'] as Color,
                              onTap: a['onTap'] as void Function()?,
                            ),
                          );
                        }).toList(),
                      );
                    }),
                    const SizedBox(height: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search ingredients or supplier',
                          prefixIcon: Icon(Icons.search, color: Colors.white),
                          filled: true,
                          fillColor: Color(0xFF0B0B0E),
                          border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF27272A)), borderRadius: BorderRadius.all(Radius.circular(8))),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF27272A)), borderRadius: BorderRadius.all(Radius.circular(8))),
                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF3F3F46)), borderRadius: BorderRadius.all(Radius.circular(8))),
                        ),
                        onChanged: (v) => setState(() => _searchText = v),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: cats.map((c) {
                          final sel = _categoryFilter == c;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: sel,
                              onSelected: (_) => setState(() => _categoryFilter = c),
                            ),
                          );
                        }).toList()),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Builder(builder: (_) {
                      final w = MediaQuery.of(context).size.width;
                      final cross = w >= 1200 ? 4 : (w >= 900 ? 3 : (w >= 600 ? 2 : 1));
                      final aspect = w >= 1200 ? 1.5 : (w >= 900 ? 1.4 : (w >= 600 ? 1.3 : 1.2));
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: aspect,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final r = _filtered[i];
                          final name = r['name'] as String? ?? '';
                          final unit = r['base_unit'] as String? ?? '';
                          final stock = (r['stock'] as num?)?.toDouble() ?? 0.0;
                          final min = (r['min_threshold'] as num?)?.toDouble() ?? 0.0;
                          final supplier = r['supplier'] as String? ?? '';
                          final below = min > 0 && stock <= min;
                          final borderColor = below ? const Color(0xFFEF4444) : const Color(0xFF10B981);
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.5)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(12)),
                                  child: Text(below ? 'LOW' : 'OK', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Remove Ingredient',
                                  child: IconButton(
                                    onPressed: () => _confirmAndDeleteIngredient(r['id'] as String, name),
                                    icon: const Icon(Icons.delete_forever, color: Colors.white),
                                  ),
                                )
                              ]),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(child: Text('Stock: ${stock.toStringAsFixed(0)} $unit', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12))),
                                Expanded(child: Text('Threshold: ${min.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12))),
                              ]),
                              const SizedBox(height: 4),
                              Text('Supplier: $supplier', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12), overflow: TextOverflow.ellipsis),
                              const Spacer(),
                              FutureBuilder<int?>(
                                future: Repository.instance.ingredients.getLastUpdatedTs(r['id'] as String),
                                builder: (_, snap) {
                                  final ts = snap.data;
                                  final text = ts == null ? '-' : DateTime.fromMillisecondsSinceEpoch(ts).toLocal().toString();
                                  return Text(text, style: const TextStyle(color: Colors.white, fontSize: 12));
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(children: [
                                Tooltip(
                                  message: 'Add/Refill',
                                  child: _QuickActionPill(
                                    icon: Icons.add_circle_outlined,
                                    color: const Color(0xFF10B981),
                                    onTap: () => _showPurchaseDialog(presetIngId: r['id'] as String),
                                  ),
                                ),
                              ]),
                            ]),
                          );
                        },
                      );
                    }),
                  ]),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Reports', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      TextButton(onPressed: () async {
                        final now = DateTime.now();
                        final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
                        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).millisecondsSinceEpoch;
                        final tx = await Repository.instance.ingredients.listTransactions(fromMs: start, toMs: end, limit: 1000);
                        final cogs = tx.where((t) => t['type'] == 'purchase').fold<double>(0.0, (s, t) => s + (((t['qty'] as num?)?.toDouble() ?? 0.0) * ((t['cost_per_unit'] as num?)?.toDouble() ?? 0.0)));
                        final wastage = tx.where((t) => t['type'] == 'wastage').fold<double>(0.0, (s, t) => s + ((t['qty'] as num?)?.toDouble() ?? 0.0));
                        final usage = tx.where((t) => t['type'] == 'deduction').fold<double>(0.0, (s, t) => s + ((t['qty'] as num?)?.toDouble() ?? 0.0));
                        if (!context.mounted) return;
                        showDialog(context: context, builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF18181B),
                          title: const Text('Daily Summary', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
                          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Usage Qty: ${usage.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white)),
                            Text('Wastage Qty: ${wastage.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white)),
                            Text('COGS: ₹${cogs.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white)),
                          ]),
                          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                        ));
                      }, child: const Text('Daily Usage Summary')),
                      TextButton(onPressed: () async {
                        final now = DateTime.now();
                        final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
                        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).millisecondsSinceEpoch;
                        final tx = await Repository.instance.ingredients.listTransactions(type: 'wastage', fromMs: start, toMs: end, limit: 500);
                        if (!context.mounted) return;
                        showDialog(context: context, builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF18181B),
                          title: const Text('Wastage Logs', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
                          content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ...tx.map((t) => Text('${t['ingredient_id']}: ${(t['qty'] as num?)?.toDouble() ?? 0.0} ${(t['unit'] as String?) ?? ''} • ${t['reason'] ?? ''}', style: const TextStyle(color: Colors.white))),
                          ]))),
                          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                        ));
                      }, child: const Text('Wastage Logs')),
                      TextButton(onPressed: () async {
                        final now = DateTime.now();
                        final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
                        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).millisecondsSinceEpoch;
                        final tx = await Repository.instance.ingredients.listTransactions(fromMs: start, toMs: end, limit: 2000);
                        final header = 'id,ingredient_id,type,qty,unit,cost_per_unit,supplier,invoice,note,timestamp,related_order_id,kot_number,reason';
                        final rows = tx.map((t) => [
                          t['id'], t['ingredient_id'], t['type'], t['qty'], t['unit'], t['cost_per_unit'] ?? '', t['supplier'] ?? '', t['invoice'] ?? '', t['note'] ?? '', t['timestamp'], t['related_order_id'] ?? '', t['kot_number'] ?? '', t['reason'] ?? ''
                        ].join(',')).join('\n');
                        final csv = '$header\n$rows';
                        final bytes = Uri.encodeComponent(csv);
                        final url = 'data:text/csv;charset=utf-8,$bytes';
                        web.openNewTab(url);
                      }, child: const Text('Export to CSV')),
                      TextButton(onPressed: () async {
                        final now = DateTime.now();
                        final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
                        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).millisecondsSinceEpoch;
                        final tx = await Repository.instance.ingredients.listTransactions(fromMs: start, toMs: end, limit: 1000);
                        final rows = tx.map((t) => '<tr><td>${t['id']}</td><td>${t['ingredient_id']}</td><td>${t['type']}</td><td>${t['qty']}</td><td>${t['unit']}</td><td>${t['cost_per_unit'] ?? ''}</td><td>${t['supplier'] ?? ''}</td><td>${t['invoice'] ?? ''}</td><td>${t['note'] ?? ''}</td><td>${DateTime.fromMillisecondsSinceEpoch((t['timestamp'] as int?) ?? 0).toLocal()}</td><td>${t['related_order_id'] ?? ''}</td><td>${t['kot_number'] ?? ''}</td><td>${t['reason'] ?? ''}</td></tr>').join();
                        final htmlDoc = '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Inventory Report</title>
<style>
body { font-family: Arial; padding: 16px; }
table { border-collapse: collapse; width: 100%; }
th, td { border: 1px solid #333; padding: 6px; font-size: 12px; }
</style>
</head><body>
<h2>Inventory Transactions (Today)</h2>
<table><thead><tr><th>ID</th><th>Ingredient</th><th>Type</th><th>Qty</th><th>Unit</th><th>Cost/Unit</th><th>Supplier</th><th>Invoice</th><th>Note</th><th>Timestamp</th><th>Order</th><th>KOT</th><th>Reason</th></tr></thead>
<tbody>$rows</tbody></table>
<script>
window.onload = function(){ setTimeout(function(){ window.print(); }, 500); }
</script>
</body></html>
''';
                        final url = 'data:text/html;charset=utf-8,${Uri.encodeComponent(htmlDoc)}';
                        web.openNewTab(url);
                      }, child: const Text('Export to PDF')),
                    ]),
                  ]),
                ),
              ]),
    );
  }

  Future<void> _fixDuplicates() async {
    final rp = context.read<RestaurantProvider>();
    await Repository.instance.ingredients.fixInventoryDuplicates();
    await _refresh();
    rp.showToast('Inventory duplicates cleaned.', icon: '✨');
  }

  Future<void> _showCreateIngredientDialog() async {
    String name = '';
    String category = 'Uncategorized';
    String unit = 'g';
    String supplier = '';
    double minThreshold = 0.0;
    double stock = 0.0;
    await showDialog(context: context, builder: (_) {
      return AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Add New Ingredient', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(decoration: const InputDecoration(hintText: 'Name'), onChanged: (v) => name = v),
          const SizedBox(height: 8),
          TextField(decoration: const InputDecoration(hintText: 'Category'), onChanged: (v) => category = v),
          const SizedBox(height: 8),
          TextField(decoration: const InputDecoration(hintText: 'Base Unit (e.g., g, kg, ml, l, pc)'), onChanged: (v) => unit = v),
          const SizedBox(height: 8),
          TextField(decoration: const InputDecoration(hintText: 'Supplier'), onChanged: (v) => supplier = v),
          const SizedBox(height: 8),
          TextField(decoration: const InputDecoration(hintText: 'Min Threshold'), keyboardType: TextInputType.number, onChanged: (v) => minThreshold = double.tryParse(v) ?? 0.0),
          const SizedBox(height: 8),
          TextField(decoration: const InputDecoration(hintText: 'Opening Stock'), keyboardType: TextInputType.number, onChanged: (v) => stock = double.tryParse(v) ?? 0.0),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            if (name.trim().isEmpty) return;
            final nav = Navigator.of(context);
            final rp = context.read<RestaurantProvider>();
            
            // Check for duplicates
            final exists = _ingredients.any((i) => (i['name'] as String).trim().toLowerCase() == name.trim().toLowerCase());
            if (exists) {
              rp.showToast('Ingredient with this name already exists.', icon: '⚠️');
              return;
            }

            final id = '${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}';
            await Repository.instance.ingredients.upsertIngredient({
              'id': id,
              'name': name.trim(),
              'category': category.trim().isEmpty ? 'Uncategorized' : category.trim(),
              'base_unit': unit.trim().isEmpty ? 'g' : unit.trim(),
              'stock': stock,
              'min_threshold': minThreshold,
              'supplier': supplier.trim(),
            });
            nav.pop();
            await _refresh();
            rp.showToast('Ingredient added.', icon: '✅');
          }, child: const Text('Save')),
        ],
      );
    });
  }

  Future<void> _confirmAndDeleteIngredient(String id, String name) async {
    await showDialog(context: context, builder: (_) {
      return AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Remove Ingredient', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
        content: Text(
          "Remove '$name' from inventory? This deletes recipe mappings. Transactions history remains.",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () async {
            final nav = Navigator.of(context);
            final rp = context.read<RestaurantProvider>();
            await Repository.instance.ingredients.deleteIngredient(id);
            nav.pop();
            await _refresh();
            rp.showToast('Ingredient removed.', icon: '🗑️');
          }, child: const Text('Delete')),
        ],
      );
    });
  }

  Future<void> _openMockupPreview() async {
    final htmlDoc = '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Inventory Quick Actions — Visual Mock</title>
<style>
  :root {
    --bg: #0B0B0E; --card: #18181B; --text: #FFFFFF; --muted: #A1A1AA; --border: #27272A;
    --red:#EF4444; --amber:#F59E0B; --blue:#3B82F6; --teal:#14B8A6; --green:#10B981; --violet:#A78BFA;
  }
  body { background: var(--bg); color: var(--text); font-family: Arial, sans-serif; margin: 0; padding: 24px; }
  h1 { font-size: 20px; margin: 0 0 8px 0; }
  .section { margin-bottom: 24px; }
  .grid { display: grid; gap: 12px; }
  .grid.mobile { grid-template-columns: repeat(2, 1fr); width: 375px; }
  .grid.tablet { grid-template-columns: repeat(3, 1fr); width: 768px; }
  .grid.desktop { grid-template-columns: repeat(4, 1fr); width: 1280px; }
  .pill { background: var(--card); border-radius: 24px; border: 1px solid var(--border); min-height: 56px; display: flex; align-items: center; justify-content: center; padding: 12px; transition: box-shadow .15s, border-color .15s; }
  .pill .dot { width: 36px; height: 36px; border-radius: 50%; border: 2px solid currentColor; display: inline-block; margin-right: 8px; }
  .pill .label { font-size: 13px; color: var(--muted); }
  .pill:hover { box-shadow: 0 4px 12px rgba(255,255,255,0.05); }
  .pill.red { color: var(--red); border-color: rgba(239,68,68,0.35); }
  .pill.amber { color: var(--amber); border-color: rgba(245,158,11,0.35); }
  .pill.blue { color: var(--blue); border-color: rgba(59,130,246,0.35); }
  .pill.teal { color: var(--teal); border-color: rgba(20,184,166,0.35); }
  .pill.green { color: var(--green); border-color: rgba(16,185,129,0.35); }
  .pill.violet { color: var(--violet); border-color: rgba(167,139,250,0.35); }
  .wrap { display: flex; gap: 24px; align-items: flex-start; }
  .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 16px; }
  .sub { color: var(--muted); font-size: 12px; margin-bottom: 12px; }
</style>
</head><body>
  <div class="wrap">
    <div class="card">
      <h1>Mobile • 2 columns</h1>
      <div class="sub">Min touch 56×56, collapsible Quick Actions</div>
      <div class="grid mobile">
        <div class="pill red"><span class="dot"></span><span class="label">Wastage</span></div>
        <div class="pill amber"><span class="dot"></span><span class="label">Batch Prep</span></div>
        <div class="pill blue"><span class="dot"></span><span class="label">Reports</span></div>
        <div class="pill teal"><span class="dot"></span><span class="label">Restore KOT</span></div>
        <div class="pill green"><span class="dot"></span><span class="label">Add Ingredient</span></div>
        <div class="pill violet"><span class="dot"></span><span class="label">Design Mockups</span></div>
      </div>
    </div>
    <div class="card">
      <h1>Tablet • 3 columns</h1>
      <div class="sub">Balanced spacing</div>
      <div class="grid tablet">
        <div class="pill red"><span class="dot"></span><span class="label">Wastage</span></div>
        <div class="pill amber"><span class="dot"></span><span class="label">Batch Prep</span></div>
        <div class="pill blue"><span class="dot"></span><span class="label">Reports</span></div>
        <div class="pill teal"><span class="dot"></span><span class="label">Restore KOT</span></div>
        <div class="pill green"><span class="dot"></span><span class="label">Add Ingredient</span></div>
        <div class="pill violet"><span class="dot"></span><span class="label">Design Mockups</span></div>
      </div>
    </div>
    <div class="card">
      <h1>Desktop • 4 columns</h1>
      <div class="sub">Compact, consistent stroke and padding</div>
      <div class="grid desktop">
        <div class="pill red"><span class="dot"></span><span class="label">Wastage</span></div>
        <div class="pill amber"><span class="dot"></span><span class="label">Batch Prep</span></div>
        <div class="pill blue"><span class="dot"></span><span class="label">Reports</span></div>
        <div class="pill teal"><span class="dot"></span><span class="label">Restore KOT</span></div>
        <div class="pill green"><span class="dot"></span><span class="label">Add Ingredient</span></div>
        <div class="pill violet"><span class="dot"></span><span class="label">Design Mockups</span></div>
      </div>
    </div>
  </div>
</body></html>
''';
    await web.openHtmlDocument(htmlDoc);
  }
}

class _QuickActionPill extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _QuickActionPill({required this.icon, required this.color, this.onTap});
  @override
  State<_QuickActionPill> createState() => _QuickActionPillState();
}

class _QuickActionPillState extends State<_QuickActionPill> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.color.withValues(alpha: 0.35)),
            boxShadow: _hover ? [BoxShadow(color: widget.color.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 1, offset: const Offset(0, 4))] : [],
          ),
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          child: Center(child: Icon(widget.icon, color: widget.color, size: 24)),
        ),
      ),
    );
  }
}

 
