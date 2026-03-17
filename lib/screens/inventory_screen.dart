import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../data/repository.dart';
import '../models/cart_item.dart';
import '../widgets/app_ui_kit.dart';
import '../utils/web_adapter.dart' as web;

// ── Unit helpers ──────────────────────────────────────────────────────────────

const _kUnitFamilies = {
  'Weight': ['g', 'kg'],
  'Volume': ['ml', 'l'],
  'Count':  ['pc', 'dozen'],
  'Other':  ['tbsp', 'tsp', 'cup'],
};

/// Canonical base unit per family — stock is always stored in these.
const _kCanonicalBase = {'g': 'g', 'kg': 'g', 'ml': 'ml', 'l': 'ml',
    'liter': 'ml', 'ltr': 'ml'};

/// Convert qty from [from] to [to]. Returns null if families differ.
double? _convert(double qty, String from, String to) {
  final f = from.toLowerCase().trim();
  final t = to.toLowerCase().trim();
  if (f == t) return qty;
  if (f == 'kg'  && t == 'g')  return qty * 1000;
  if (f == 'g'   && t == 'kg') return qty / 1000;
  if ((f == 'l' || f == 'liter' || f == 'ltr') && t == 'ml') return qty * 1000;
  if (f == 'ml' && (t == 'l' || t == 'liter' || t == 'ltr')) return qty / 1000;
  return null;
}

/// Human-friendly display. e.g. 1500 g → "1.5 kg", 300 ml → "300 ml"
String _smartDisplay(double stockInBase, String baseUnit) {
  final b = baseUnit.toLowerCase();
  if (b == 'g'  && stockInBase >= 1000) return '${_f(stockInBase / 1000)} kg';
  if (b == 'ml' && stockInBase >= 1000) return '${_f(stockInBase / 1000)} L';
  return '${_f(stockInBase)} $baseUnit';
}

String _f(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Compatible entry units for a given base unit.
List<String> _compatibleUnits(String baseUnit) {
  final b = baseUnit.toLowerCase();
  if (b == 'g' || b == 'kg') return ['g', 'kg'];
  if (b == 'ml' || b == 'l' || b == 'liter' || b == 'ltr') return ['ml', 'l'];
  return [baseUnit];
}

// ── Screen ────────────────────────────────────────────────────────────────────

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, Object>> _ingredients = [];
  Map<String, int?> _lastUpdated = {};
  bool _loading = true;
  String _search = '';
  String _catFilter = 'All';
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) { return; }
    setState(() => _loading = true);
    try {
      final all  = await Repository.instance.ingredients.listIngredients();
      final last = await Repository.instance.ingredients.listLastUpdatedByIngredient();
      if (mounted) { setState(() {
        _ingredients = all.map((e) => Map<String, Object>.from(e)).toList();
        _lastUpdated = last.map((k, v) => MapEntry(k, v));
        _loading = false;
      }); }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, Object>> get _filtered {
    var list = _catFilter == 'All'
        ? _ingredients
        : _ingredients.where((r) =>
            (r['category'] as String? ?? '') == _catFilter).toList();
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) { list = list.where((r) =>
        (r['name'] as String? ?? '').toLowerCase().contains(q) ||
        (r['supplier'] as String? ?? '').toLowerCase().contains(q)).toList(); }
    return list;
  }

  List<String> get _categories => [
    'All',
    ..._ingredients
        .map((r) => r['category'] as String? ?? '')
        .where((c) => c.isNotEmpty).toSet().toList()..sort(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'Inventory',
      scrollable: false,
      actions: [
        AppButton.primary('Add Ingredient', icon: Icons.add, small: true,
            onPressed: _showCreateDialog),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.refresh_outlined, color: AppColors.textSecondary),
          tooltip: 'Refresh', onPressed: _refresh,
        ),
      ],
      child: Column(children: [
        Container(color: AppColors.bg1, child: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.amber,
          labelColor: AppColors.amber,
          unselectedLabelColor: AppColors.textSecondary,
          dividerColor: AppColors.border,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 16), text: 'Stock'),
            Tab(icon: Icon(Icons.build_outlined, size: 16), text: 'Actions'),
          ],
        )),
        Expanded(child: TabBarView(controller: _tabs, children: [
          _StockTab(
            ingredients: _filtered,
            categories: _categories,
            catFilter: _catFilter,
            search: _search,
            searchCtrl: _searchCtrl,
            lastUpdated: _lastUpdated,
            loading: _loading,
            onCatChanged: (c) => setState(() => _catFilter = c),
            onSearchChanged: (v) => setState(() => _search = v),
            onEdit: _showEditDialog,
            onDelete: _confirmDelete,
            onRefill: (ing) => _showPurchaseDialog(presetIng: ing),
            onUsage: _showUsageDialog,
          ),
          _ActionsTab(ingredients: _ingredients, onRefresh: _refresh),
        ])),
      ]),
    );
  }

  // ── Create ingredient ─────────────────────────────────────────────────────

  Future<void> _showCreateDialog() async {
    final nameCtrl     = TextEditingController();
    final catCtrl      = TextEditingController();
    final supplierCtrl = TextEditingController();
    final threshCtrl   = TextEditingController(text: '0');
    final stockCtrl    = TextEditingController(text: '0');
    String selectedUnit = 'g';

    await showDialog(context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Add Ingredient', style: AppTextStyles.h2),
          content: SizedBox(width: 460, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DarkField(label: 'Name *', controller: nameCtrl),
              const SizedBox(height: 10),
              DarkField(label: 'Category', controller: catCtrl,
                  hint: 'e.g. Dairy, Spices, Oils'),
              const SizedBox(height: 10),
              _UnitPicker(selected: selectedUnit,
                  onChanged: (u) => set(() => selectedUnit = u)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DarkField(
                  label: 'Opening Stock ($selectedUnit)',
                  controller: stockCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 10),
                Expanded(child: DarkField(
                  label: 'Low-stock alert ($selectedUnit)',
                  controller: threshCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
              ]),
              const SizedBox(height: 10),
              DarkField(label: 'Supplier', controller: supplierCtrl),
            ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            AppButton.primary('Add', onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              if (_ingredients.any((i) =>
                  (i['name'] as String).toLowerCase() == name.toLowerCase())) {
                context.read<RestaurantProvider>()
                    .showToast('Ingredient already exists', icon: '⚠️');
                return;
              }
              final base  = _kCanonicalBase[selectedUnit] ?? selectedUnit;
              final stock = _convert(
                  double.tryParse(stockCtrl.text.trim()) ?? 0, selectedUnit, base) ??
                  (double.tryParse(stockCtrl.text.trim()) ?? 0);
              final thresh = _convert(
                  double.tryParse(threshCtrl.text.trim()) ?? 0, selectedUnit, base) ??
                  (double.tryParse(threshCtrl.text.trim()) ?? 0);
              await Repository.instance.ingredients.upsertIngredient({
                'id': '${DateTime.now().millisecondsSinceEpoch}_${name.hashCode}',
                'name': name,
                'category': catCtrl.text.trim().isEmpty
                    ? 'Uncategorized' : catCtrl.text.trim(),
                'base_unit': base,
                'stock': stock,
                'min_threshold': thresh,
                'supplier': supplierCtrl.text.trim(),
              });
              if (ctx.mounted) { Navigator.pop(ctx); }
              await _refresh();
              if (mounted) { context.read<RestaurantProvider>()
                  .showToast('$name added', icon: '✅'); }
            }),
          ],
        );
      }),
    );
  }

  // ── Edit ingredient ───────────────────────────────────────────────────────

  Future<void> _showEditDialog(Map<String, Object> ing) async {
    final id       = ing['id'] as String;
    final name     = (ing['name'] as String?) ?? '';
    final baseUnit = (ing['base_unit'] as String?) ?? 'g';
    final stockB   = (ing['stock'] as num?)?.toDouble() ?? 0.0;
    final threshB  = (ing['min_threshold'] as num?)?.toDouble() ?? 0.0;

    // Pick display unit (kg if ≥1000g, l if ≥1000ml)
    String dispUnit = (baseUnit == 'g' && stockB >= 1000) ? 'kg'
        : (baseUnit == 'ml' && stockB >= 1000) ? 'l'
        : baseUnit;
    final catCtrl      = TextEditingController(text: (ing['category'] as String?) ?? '');
    final supplierCtrl = TextEditingController(text: (ing['supplier'] as String?) ?? '');
    final stockCtrl    = TextEditingController(
        text: _f(_convert(stockB, baseUnit, dispUnit) ?? stockB));
    final threshCtrl   = TextEditingController(
        text: _f(_convert(threshB, baseUnit, dispUnit) ?? threshB));

    await showDialog(context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        final compat = _compatibleUnits(baseUnit);
        return AlertDialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Edit · $name', style: AppTextStyles.h2),
          content: SizedBox(width: 460, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Base unit badge + inline toggle
              Row(children: [
                const Text('Base unit:', style: AppTextStyles.small),
                const SizedBox(width: 8),
                _UnitBadge(baseUnit),
                const Spacer(),
                const Text('Enter in:', style: AppTextStyles.small),
                const SizedBox(width: 8),
                _InlineUnitToggle(
                  units: compat, selected: dispUnit,
                  onChanged: (u) {
                    final sv = double.tryParse(stockCtrl.text) ?? 0.0;
                    final tv = double.tryParse(threshCtrl.text) ?? 0.0;
                    set(() {
                      final sv2 = _convert(sv, dispUnit, u);
                      final tv2 = _convert(tv, dispUnit, u);
                      dispUnit = u;
                      if (sv2 != null) stockCtrl.text = _f(sv2);
                      if (tv2 != null) threshCtrl.text = _f(tv2);
                    });
                  },
                ),
              ]),
              const SizedBox(height: 12),
              DarkField(label: 'Category', controller: catCtrl),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DarkField(
                  label: 'Stock ($dispUnit)', controller: stockCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 10),
                Expanded(child: DarkField(
                  label: 'Alert ($dispUnit)', controller: threshCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
              ]),
              const SizedBox(height: 10),
              DarkField(label: 'Supplier', controller: supplierCtrl),
            ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            AppButton.primary('Save', onPressed: () async {
              final sv = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
              final tv = double.tryParse(threshCtrl.text.trim()) ?? 0.0;
              await Repository.instance.ingredients.upsertIngredient({
                'id': id, 'name': name,
                'category': catCtrl.text.trim().isEmpty
                    ? 'Uncategorized' : catCtrl.text.trim(),
                'base_unit': baseUnit,
                'stock':         _convert(sv, dispUnit, baseUnit) ?? sv,
                'min_threshold': _convert(tv, dispUnit, baseUnit) ?? tv,
                'supplier': supplierCtrl.text.trim(),
              });
              if (ctx.mounted) { Navigator.pop(ctx); }
              await _refresh();
              if (mounted) { context.read<RestaurantProvider>()
                  .showToast('$name updated', icon: '✅'); }
            }),
          ],
        );
      }),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(String id, String name) async {
    await showDialog(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Remove $name?', style: AppTextStyles.h2),
        content: const Text(
            'Removes recipe mappings. Transaction history is kept.',
            style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          AppButton.danger('Remove', onPressed: () async {
            await Repository.instance.ingredients.deleteIngredient(id);
            if (mounted) { Navigator.pop(context); }
            await _refresh();
            if (mounted) { context.read<RestaurantProvider>()
                .showToast('$name removed', icon: '🗑️'); }
          }),
        ],
      ),
    );
  }

  // ── Purchase / refill ─────────────────────────────────────────────────────

  Future<void> _showPurchaseDialog({Map<String, Object>? presetIng}) async {
    String? ingId      = presetIng?['id'] as String?;
    String baseUnit    = (presetIng?['base_unit'] as String?) ?? 'g';
    String entryUnit   = baseUnit;
    final qtyCtrl      = TextEditingController();
    final costCtrl     = TextEditingController();
    final supplierCtrl = TextEditingController(
        text: (presetIng?['supplier'] as String?) ?? '');
    final invoiceCtrl  = TextEditingController();

    await showDialog(context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Add Purchase / Refill', style: AppTextStyles.h2),
          content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min,
            children: [
              if (ingId == null)
                _IngredientDropdown(ingredients: _ingredients, value: ingId,
                    onChanged: (v) => set(() {
                      ingId = v;
                      final sel = _ingredients.firstWhere(
                          (x) => x['id'] == v, orElse: () => {});
                      baseUnit  = (sel['base_unit'] as String?) ?? 'g';
                      entryUnit = baseUnit;
                    }))
              else
                _IngredientBadge(_ingredients.firstWhere(
                    (x) => x['id'] == ingId, orElse: () => {})),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: DarkField(
                  label: 'Quantity ($entryUnit)', controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Unit', style: AppTextStyles.small),
                  const SizedBox(height: 5),
                  _InlineUnitToggle(
                    units: _compatibleUnits(baseUnit),
                    selected: entryUnit,
                    onChanged: (u) => set(() => entryUnit = u),
                  ),
                ]),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DarkField(label: 'Cost/unit (₹)',
                    controller: costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 10),
                Expanded(child: DarkField(label: 'Invoice #',
                    controller: invoiceCtrl)),
              ]),
              const SizedBox(height: 10),
              DarkField(label: 'Supplier', controller: supplierCtrl),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            AppButton.primary('Add Stock', onPressed: () async {
              if (ingId == null) return;
              final raw = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
              if (raw <= 0) return;
              final qtyInBase = _convert(raw, entryUnit, baseUnit) ?? raw;
              final cpu = double.tryParse(costCtrl.text.trim());
              await Repository.instance.ingredients.insertPurchase(
                ingId!, qtyInBase, baseUnit,
                costPerUnit: cpu,
                supplier: supplierCtrl.text.trim().isEmpty
                    ? null : supplierCtrl.text.trim(),
                invoice: invoiceCtrl.text.trim().isEmpty
                    ? null : invoiceCtrl.text.trim(),
              );
              if (ctx.mounted) { Navigator.pop(ctx); }
              await _refresh();
              if (mounted) { context.read<RestaurantProvider>()
                  .showToast('Added ${_smartDisplay(qtyInBase, baseUnit)}', icon: '📦'); }
            }),
          ],
        );
      }),
    );
  }

  // ── Recipe usage ──────────────────────────────────────────────────────────

  Future<void> _showUsageDialog(String id, String name) async {
    final items = await Repository.instance.ingredients
        .getMenuItemsUsingIngredient(id);
    if (!mounted) { return; }
    showDialog(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Used in · $name', style: AppTextStyles.h2),
        content: SizedBox(width: 360,
          child: items.isEmpty
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No recipes use this ingredient.',
                      style: AppTextStyles.body))
              : Column(mainAxisSize: MainAxisSize.min,
                  children: items.map((e) => ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restaurant_menu_outlined,
                        color: AppColors.amber, size: 18),
                    title: Text('${e['name']}', style: AppTextStyles.body),
                  )).toList())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          AppButton.ghost('Open Menu', small: true, icon: Icons.open_in_new,
              onPressed: () {
                // Deep-link to the specific category of the first matched menu item
                if (items.isNotEmpty) {
                  final cat = items.first['category']?.toString();
                  if (cat != null && cat.isNotEmpty) {
                    context.read<RestaurantProvider>().setSelectedCategory(cat);
                  }
                }
                context.read<RestaurantProvider>().setCurrentView('menu');
                Navigator.pop(context);
              }),
        ],
      ),
    );
  }
}

// ── Stock tab ─────────────────────────────────────────────────────────────────

class _StockTab extends StatelessWidget {
  final List<Map<String, Object>> ingredients;
  final List<String> categories;
  final String catFilter;
  final String search;
  final TextEditingController searchCtrl;
  final Map<String, int?> lastUpdated;
  final bool loading;
  final ValueChanged<String> onCatChanged;
  final ValueChanged<String> onSearchChanged;
  final void Function(Map<String, Object>) onEdit;
  final void Function(String, String) onDelete;
  final void Function(Map<String, Object>) onRefill;
  final void Function(String, String) onUsage;

  const _StockTab({
    required this.ingredients, required this.categories,
    required this.catFilter, required this.search,
    required this.searchCtrl, required this.lastUpdated,
    required this.loading, required this.onCatChanged,
    required this.onSearchChanged, required this.onEdit,
    required this.onDelete, required this.onRefill, required this.onUsage,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) { return const Center(
        child: CircularProgressIndicator(color: AppColors.amber)); }

    final lowCount = ingredients.where((r) {
      final s = (r['stock'] as num?)?.toDouble() ?? 0.0;
      final m = (r['min_threshold'] as num?)?.toDouble() ?? 0.0;
      return m > 0 && s <= m;
    }).length;

    return Column(children: [
      // ── Filter bar ────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        color: AppColors.bg1,
        child: Column(children: [
          TextField(
            controller: searchCtrl,
            style: AppTextStyles.body,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search ingredients or supplier…',
              hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textSecondary, size: 18),
              filled: true, fillColor: AppColors.bg2, isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.amber, width: 1.5)),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: categories.map((c) {
              final active = c == catFilter;
              return Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 8),
                child: GestureDetector(
                  onTap: () => onCatChanged(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? AppColors.amber : AppColors.bg2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active
                          ? AppColors.amber : AppColors.border),
                    ),
                    child: Text(c, style: TextStyle(
                      color: active ? Colors.black : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                    )),
                  ),
                ),
              );
            }).toList()),
          ),
        ]),
      ),
      const Divider(height: 1, color: AppColors.border),

      // ── Low stock banner ──────────────────────────────────────────────────
      if (lowCount > 0)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: AppColors.red.withValues(alpha: 0.12),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.red, size: 16),
            const SizedBox(width: 8),
            Text('$lowCount ingredient${lowCount > 1 ? 's' : ''} '
                'below low-stock threshold',
                style: const TextStyle(color: AppColors.red, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),

      // ── Grid of cards ─────────────────────────────────────────────────────
      Expanded(
        child: ingredients.isEmpty
            ? const EmptyState(message: 'No ingredients found',
                icon: Icons.inventory_2_outlined)
            : AdaptiveGrid(
                mobileCols: 1, tabletCols: 2, desktopCols: 3,
                childAspectRatio: 1.75,
                children: ingredients.map((r) => _IngredientCard(
                  ing: r,
                  lastUpdatedMs: lastUpdated[r['id'] as String],
                  onEdit:   () => onEdit(r),
                  onDelete: () => onDelete(r['id'] as String,
                      r['name'] as String? ?? ''),
                  onRefill: () => onRefill(r),
                  onUsage:  () => onUsage(r['id'] as String,
                      r['name'] as String? ?? ''),
                )).toList(),
              ),
      ),
    ]);
  }
}

// ── Ingredient card ───────────────────────────────────────────────────────────

class _IngredientCard extends StatelessWidget {
  final Map<String, Object> ing;
  final int? lastUpdatedMs;
  final VoidCallback onEdit, onDelete, onRefill, onUsage;

  const _IngredientCard({
    required this.ing, required this.lastUpdatedMs,
    required this.onEdit, required this.onDelete,
    required this.onRefill, required this.onUsage,
  });

  @override
  Widget build(BuildContext context) {
    final name      = (ing['name']     as String?) ?? '';
    final baseUnit  = (ing['base_unit'] as String?) ?? 'g';
    final stock     = (ing['stock']    as num?)?.toDouble() ?? 0.0;
    final thresh    = (ing['min_threshold'] as num?)?.toDouble() ?? 0.0;
    final supplier  = (ing['supplier'] as String?) ?? '';
    final category  = (ing['category'] as String?) ?? '';
    final isLow     = thresh > 0 && stock <= thresh;
    final accent    = isLow ? AppColors.red : AppColors.green;

    final barMax = thresh > 0 ? thresh * 2 : (stock > 0 ? stock * 2 : 1.0);
    final barPct = (stock / barMax).clamp(0.0, 1.0);

    String lastStr = '—';
    if (lastUpdatedMs != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(lastUpdatedMs!).toLocal();
      lastStr = '${d.day}/${d.month}  '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }

    final smartStr  = _smartDisplay(stock, baseUnit);
    final rawStr    = '${_f(stock)} $baseUnit';
    final showRaw   = smartStr != rawStr;

    return AppCard(
      borderColor: accent.withValues(alpha: 0.45),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppTextStyles.h3,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (category.isNotEmpty)
                Text(category, style: AppTextStyles.small,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          StatusBadge(isLow ? 'LOW' : 'OK', color: accent, small: true),
          const SizedBox(width: 4),
          _TinyBtn(Icons.edit_outlined, AppColors.textSecondary, onEdit),
          _TinyBtn(Icons.delete_outline, AppColors.red, onDelete),
        ]),
        const SizedBox(height: 10),

        // ── Stock display ─────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(smartStr, style: TextStyle(
                color: accent, fontSize: 15, fontWeight: FontWeight.w700)),
            if (showRaw) ...[
              const SizedBox(width: 6),
              Text('($rawStr)', style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 10)),
            ],
          ]),

        // ── Threshold + bar ───────────────────────────────────────────────
        if (thresh > 0) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.notifications_outlined,
                size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Text('Alert: ${_smartDisplay(thresh, baseUnit)}',
                style: AppTextStyles.small),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barPct, minHeight: 5,
              backgroundColor: AppColors.border, color: accent,
            )),
        ],
        const SizedBox(height: 6),

        // ── Meta ──────────────────────────────────────────────────────────
        if (supplier.isNotEmpty)
          Row(children: [
            const Icon(Icons.local_shipping_outlined,
                size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Expanded(child: Text(supplier, style: AppTextStyles.small,
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        Row(children: [
          const Icon(Icons.update_outlined,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(lastStr, style: AppTextStyles.small),
        ]),

        const Spacer(),

        // ── Action buttons ────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _CardBtn(Icons.add_circle_outline,
              'Refill', AppColors.green, onRefill)),
          const SizedBox(width: 6),
          Expanded(child: _CardBtn(Icons.receipt_long_outlined,
              'Recipes', AppColors.blue, onUsage)),
        ]),
      ]),
    );
  }
}

class _TinyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TinyBtn(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(6),
    child: Padding(padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: color)),
  );
}

class _CardBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardBtn(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ── Actions tab ───────────────────────────────────────────────────────────────

class _ActionsTab extends StatelessWidget {
  final List<Map<String, Object>> ingredients;
  final Future<void> Function() onRefresh;
  const _ActionsTab({required this.ingredients, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Quick Actions'),
        AdaptiveGrid(mobileCols: 2, tabletCols: 2, desktopCols: 4,
          childAspectRatio: 2.2,
          children: [
            _ActionTile(Icons.block_outlined, 'Log Wastage', AppColors.red,
                () => _showWastageDialog(context, ingredients, onRefresh)),
            _ActionTile(Icons.playlist_add_outlined, 'Batch Prep',
                AppColors.amber,
                () => _showBatchPrepDialog(context, ingredients, onRefresh)),
            _ActionTile(Icons.restore_outlined, 'Restore KOT', AppColors.blue,
                () => _showRestoreKOTDialog(context, ingredients, onRefresh)),
            _ActionTile(Icons.cleaning_services_outlined, 'Fix Duplicates',
                AppColors.textSecondary, () async {
              await Repository.instance.ingredients.fixInventoryDuplicates();
              await onRefresh();
              if (context.mounted) { context.read<RestaurantProvider>()
                  .showToast('Duplicates cleaned', icon: '✨'); }
            }),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader('Reports & Export'),
        AdaptiveGrid(mobileCols: 2, tabletCols: 3, desktopCols: 3,
          childAspectRatio: 2.2,
          children: [
            _ActionTile(Icons.bar_chart_outlined, 'Daily Summary',
                AppColors.green, () => _showDailySummary(context)),
            _ActionTile(Icons.delete_sweep_outlined, 'Wastage Logs',
                AppColors.amber, () => _showWastageLogs(context)),
            _ActionTile(Icons.download_outlined, 'Export CSV',
                AppColors.blue, () => _exportCSV(context)),
          ],
        ),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(12),
    child: AppCard(
      borderColor: color.withValues(alpha: 0.3), padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTextStyles.h3,
            maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

// ── Wastage dialog ────────────────────────────────────────────────────────────

Future<void> _showWastageDialog(BuildContext context,
    List<Map<String, Object>> ingredients,
    Future<void> Function() onRefresh) async {
  String? ingId;
  String baseUnit = 'g';
  String entryUnit = 'g';
  final qtyCtrl    = TextEditingController();
  final reasonCtrl = TextEditingController(text: 'spoilage');

  await showDialog(context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Log Wastage', style: AppTextStyles.h2),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          _IngredientDropdown(ingredients: ingredients, value: ingId,
              onChanged: (v) => set(() {
                ingId = v;
                final sel = ingredients.firstWhere(
                    (x) => x['id'] == v, orElse: () => {});
                baseUnit  = (sel['base_unit'] as String?) ?? 'g';
                entryUnit = baseUnit;
              })),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: DarkField(
              label: 'Quantity ($entryUnit)', controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            )),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Unit', style: AppTextStyles.small),
              const SizedBox(height: 5),
              _InlineUnitToggle(
                units: _compatibleUnits(baseUnit), selected: entryUnit,
                onChanged: (u) => set(() => entryUnit = u),
              ),
            ]),
          ]),
          const SizedBox(height: 10),
          DarkField(label: 'Reason', controller: reasonCtrl),
        ],
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        AppButton.danger('Deduct', onPressed: () async {
          if (ingId == null) return;
          final raw = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
          if (raw <= 0) return;
          final inBase = _convert(raw, entryUnit, baseUnit) ?? raw;
          await Repository.instance.ingredients.recordWastage(
              ingId!, inBase, baseUnit,
              reasonCtrl.text.trim().isEmpty ? 'wastage' : reasonCtrl.text.trim());
          if (ctx.mounted) { Navigator.pop(ctx); }
          await onRefresh();
          if (context.mounted) { context.read<RestaurantProvider>()
              .showToast('Wastage: ${_smartDisplay(inBase, baseUnit)}', icon: '🗑️'); }
        }),
      ],
    )),
  );
}

// ── Batch prep dialog ─────────────────────────────────────────────────────────

Future<void> _showBatchPrepDialog(BuildContext context,
    List<Map<String, Object>> ingredients,
    Future<void> Function() onRefresh) async {
  final rows = <Map<String, dynamic>>[
    {'ingredient_id': null, 'qty': 0.0, 'unit': 'g', 'base_unit': 'g'},
  ];

  await showDialog(context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Batch Prep Deduction', style: AppTextStyles.h2),
      content: SizedBox(width: 500, child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ...rows.asMap().entries.map((e) {
            final idx = e.key;
            final it  = e.value;
            final baseU  = (it['base_unit'] as String?) ?? 'g';
            final entryU = (it['unit'] as String?) ?? baseU;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Expanded(flex: 3, child: _IngredientDropdown(
                  ingredients: ingredients,
                  value: it['ingredient_id'] as String?,
                  onChanged: (v) => set(() {
                    it['ingredient_id'] = v;
                    final sel = ingredients.firstWhere(
                        (x) => x['id'] == v, orElse: () => {});
                    final bu = (sel['base_unit'] as String?) ?? 'g';
                    it['base_unit'] = bu;
                    it['unit'] = bu;
                  }),
                )),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: TextField(
                  style: AppTextStyles.body,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => it['qty'] = double.tryParse(v) ?? 0.0,
                  decoration: InputDecoration(
                    hintText: 'Qty', isDense: true,
                    hintStyle: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary),
                    filled: true, fillColor: AppColors.bg1,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border)),
                  ),
                )),
                const SizedBox(width: 6),
                _InlineUnitToggle(
                  units: _compatibleUnits(baseU),
                  selected: entryU,
                  onChanged: (u) => set(() => it['unit'] = u),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => set(() => rows.removeAt(idx)),
                  child: const Icon(Icons.close, size: 18,
                      color: AppColors.textSecondary),
                ),
              ]),
            );
          }),
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => set(() => rows.add(
                  {'ingredient_id': null, 'qty': 0.0,
                   'unit': 'g', 'base_unit': 'g'})),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Row'),
            )),
        ]),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        AppButton.danger('Deduct All', onPressed: () async {
          final valid = rows
              .where((it) =>
                  it['ingredient_id'] != null &&
                  ((it['qty'] as num?)?.toDouble() ?? 0) > 0)
              .map((it) {
                final eu = it['unit'] as String;
                final bu = it['base_unit'] as String;
                final q  = (it['qty'] as num).toDouble();
                return {
                  'ingredient_id': it['ingredient_id'],
                  'qty': _convert(q, eu, bu) ?? q,
                  'unit': bu,
                };
              }).toList();
          if (valid.isEmpty) return;
          await Repository.instance.ingredients.applyBatchPrep(valid);
          if (ctx.mounted) { Navigator.pop(ctx); }
          await onRefresh();
        }),
      ],
    )),
  );
}

// ── Restore KOT dialog ────────────────────────────────────────────────────────

Future<void> _showRestoreKOTDialog(BuildContext context,
    List<Map<String, Object>> ingredients,
    Future<void> Function() onRefresh) async {
  final provider = context.read<RestaurantProvider>();
  final orders = provider.orders
      .where((o) => o.status != 'Settled' && o.status != 'Cancelled')
      .toList();
  String? tableLabel;
  int? selectedIdx;
  List<Map<String, dynamic>> batches = [];

  await showDialog(context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Restore Cancelled KOT', style: AppTextStyles.h2),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonHideUnderline(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bg1,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButton<String>(
                value: tableLabel,
                hint: const Text('Select table / token',
                    style: AppTextStyles.body),
                dropdownColor: AppColors.bg2, isExpanded: true,
                items: orders.map((o) => DropdownMenuItem(
                  value: o.table,
                  child: Text(o.table, style: AppTextStyles.body),
                )).toList(),
                onChanged: (v) async {
                  final txns = await Repository.instance.ingredients
                      .listTransactions(type: 'deduction', limit: 100);
                  final grouped = <String, List<CartItem>>{};
                  for (final t in txns) {
                    final kot = t['kot_number']?.toString() ?? 'KOT1';
                    grouped.putIfAbsent(kot, () => []);
                  }
                  set(() {
                    tableLabel  = v;
                    batches     = grouped.entries
                        .map((e) => {'kotNumber': e.key, 'items': e.value})
                        .toList();
                    selectedIdx = null;
                  });
                },
              ),
            ),
          ),
          if (batches.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...batches.asMap().entries.map((e) => InkWell(
              onTap: () => set(() => selectedIdx = e.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(selectedIdx == e.key
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                      color: selectedIdx == e.key ? AppColors.amber : AppColors.textSecondary,
                      size: 20),
                  const SizedBox(width: 10),
                  Text('KOT ${e.value['kotNumber']}', style: AppTextStyles.body),
                ]),
              ),
            )),
          ],
        ],
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')),
        AppButton.primary('Restore', onPressed: () async {
          if (tableLabel == null || selectedIdx == null) return;
          final order = orders.firstWhere((o) => o.table == tableLabel);
          final batch = batches[selectedIdx!];
          final items = List<CartItem>.from(batch['items'] as List);
          await Repository.instance.ingredients
              .restoreKOTBatch(items, orderId: order.id);
          if (ctx.mounted) { Navigator.pop(ctx); }
          await onRefresh();
          if (context.mounted) { context.read<RestaurantProvider>()
              .showToast('KOT items restored to stock', icon: '♻️'); }
        }),
      ],
    )),
  );
}

// ── Report helpers ────────────────────────────────────────────────────────────

Future<void> _showDailySummary(BuildContext context) async {
  final now   = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  final tx    = await Repository.instance.ingredients
      .listTransactions(fromMs: start, toMs: start + 86400000, limit: 1000);
  final cogs = tx.where((t) => t['type'] == 'purchase').fold<double>(0,
      (s, t) => s + ((t['qty'] as num?)?.toDouble() ?? 0) *
          ((t['cost_per_unit'] as num?)?.toDouble() ?? 0));
  final wastage = tx.where((t) => t['type'] == 'wastage').fold<double>(
      0, (s, t) => s + ((t['qty'] as num?)?.toDouble() ?? 0));
  final usage = tx.where((t) => t['type'] == 'deduction').fold<double>(
      0, (s, t) => s + ((t['qty'] as num?)?.toDouble() ?? 0));
  if (!context.mounted) return;
  showDialog(context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text("Today's Summary", style: AppTextStyles.h2),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _SRow('Deducted (sales)', '${usage.toStringAsFixed(1)} units',
            AppColors.amber),
        _SRow('Wastage', '${wastage.toStringAsFixed(1)} units', AppColors.red),
        _SRow('COGS (purchases)', '₹${cogs.toStringAsFixed(0)}',
            AppColors.green),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Close'))],
    ),
  );
}

class _SRow extends StatelessWidget {
  final String l, v;
  final Color c;
  const _SRow(this.l, this.v, this.c);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: AppTextStyles.body),
      Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
    ]),
  );
}

Future<void> _showWastageLogs(BuildContext context) async {
  final now   = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  final tx    = await Repository.instance.ingredients
      .listTransactions(type: 'wastage',
          fromMs: start, toMs: start + 86400000, limit: 500);
  if (!context.mounted) return;
  showDialog(context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text("Today's Wastage", style: AppTextStyles.h2),
      content: SizedBox(width: 460, height: 300,
        child: tx.isEmpty
            ? const Center(child: Text('No wastage today 🎉',
                style: AppTextStyles.body))
            : ListView.separated(
                itemCount: tx.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.border, height: 1),
                itemBuilder: (_, i) {
                  final t = tx[i];
                  return ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text('${t['ingredient_id']}',
                        style: AppTextStyles.body),
                    subtitle: Text('${t['reason'] ?? '—'}',
                        style: AppTextStyles.small),
                    trailing: Text(
                      '${(t['qty'] as num?)?.toStringAsFixed(1)} ${t['unit']}',
                      style: const TextStyle(color: AppColors.red,
                          fontWeight: FontWeight.w600)),
                  );
                }),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Close'))],
    ),
  );
}

Future<void> _exportCSV(BuildContext context) async {
  final now   = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  final tx    = await Repository.instance.ingredients
      .listTransactions(fromMs: start, toMs: start + 86400000, limit: 5000);
  const hdr =
      'id,ingredient_id,type,qty,unit,cost_per_unit,supplier,invoice,'
      'note,timestamp,order_id,kot_number,reason';
  final body = tx.map((t) => [
    t['id'], t['ingredient_id'], t['type'], t['qty'], t['unit'],
    t['cost_per_unit'] ?? '', t['supplier'] ?? '', t['invoice'] ?? '',
    t['note'] ?? '', t['timestamp'], t['related_order_id'] ?? '',
    t['kot_number'] ?? '', t['reason'] ?? '',
  ].join(',')).join('\n');
  web.openNewTab(
      'data:text/csv;charset=utf-8,${Uri.encodeComponent('$hdr\n$body')}');
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _IngredientDropdown extends StatelessWidget {
  final List<Map<String, Object>> ingredients;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _IngredientDropdown({required this.ingredients,
      required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: const Text('Select ingredient', style: AppTextStyles.body),
        dropdownColor: AppColors.bg2, isExpanded: true,
        items: ingredients.map((r) {
          final name = (r['name'] as String?) ?? '';
          final cat  = (r['category'] as String?) ?? '';
          final bu   = (r['base_unit'] as String?) ?? '';
          return DropdownMenuItem(value: r['id'] as String,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
              Text(name, style: AppTextStyles.body),
              Text('$cat • $bu', style: AppTextStyles.small),
            ]),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

class _IngredientBadge extends StatelessWidget {
  final Map<String, Object> ing;
  const _IngredientBadge(this.ing);

  @override
  Widget build(BuildContext context) {
    final name = (ing['name'] as String?) ?? '';
    final cat  = (ing['category'] as String?) ?? '';
    final bu   = (ing['base_unit'] as String?) ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, children: [
        Text(name, style: AppTextStyles.h3),
        Text('$cat • $bu', style: AppTextStyles.small),
      ]),
    );
  }
}

/// Segmented g/kg or ml/l toggle — auto-converts values on switch.
class _InlineUnitToggle extends StatelessWidget {
  final List<String> units;
  final String selected;
  final ValueChanged<String> onChanged;
  const _InlineUnitToggle({required this.units,
      required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (units.length == 1) return _UnitBadge(units.first);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: units.map((u) {
        final active = u == selected;
        return GestureDetector(
          onTap: () => onChanged(u),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.amber : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(u, style: TextStyle(
              color: active ? Colors.black : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            )),
          ),
        );
      }).toList()),
    );
  }
}

/// Full unit family picker used in the create dialog.
class _UnitPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _UnitPicker({required this.selected, required this.onChanged});

  static String _hint(String u) {
    switch (u) {
      case 'g':  case 'kg':
        return 'Stored as grams. Enter stock in g or kg interchangeably.';
      case 'ml': case 'l':
        return 'Stored as ml. Enter stock in ml or L interchangeably.';
      case 'pc': return 'Stored as piece count.';
      default:   return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Base Unit', style: AppTextStyles.small),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6,
        children: _kUnitFamilies.entries.expand((fam) =>
          fam.value.map((u) {
            final active = u == selected;
            return GestureDetector(
              onTap: () => onChanged(u),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.amber : AppColors.bg1,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? AppColors.amber : AppColors.border),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(u, style: TextStyle(
                    color: active ? Colors.black : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  )),
                  Text(fam.key, style: TextStyle(
                    color: active ? Colors.black54 : AppColors.textSecondary,
                    fontSize: 9,
                  )),
                ]),
              ),
            );
          })
        ).toList(),
      ),
      if (_hint(selected).isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(_hint(selected), style: AppTextStyles.small),
      ],
    ]);
  }
}

class _UnitBadge extends StatelessWidget {
  final String unit;
  const _UnitBadge(this.unit);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.bg3,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(unit, style: const TextStyle(
        color: AppColors.textPrimary, fontSize: 12,
        fontWeight: FontWeight.w600)),
  );
}
