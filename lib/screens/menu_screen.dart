// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/restaurant_provider.dart';
import '../models/menu_item.dart';
import '../data/repository.dart';
import '../widgets/app_ui_kit.dart';

// ── Palette ────────────────────────────────────────────────────────────────────
class _C {
  static const bg1      = Color(0xFF111114);
  static const bg2      = Color(0xFF18181B);
  static const bg3      = Color(0xFF27272A);
  static const border   = Color(0xFF2E2E32);
  static const amber    = Color(0xFFF59E0B);
  static const green    = Color(0xFF10B981);
  static const red      = Color(0xFFEF4444);
  static const blue     = Color(0xFF3B82F6);
  static const textPri  = Color(0xFFFAFAFA);
  static const textSec  = Color(0xFF71717A);
  static const textDim  = Color(0xFF52525B);
}

const String _kNewCategory = '__new_category__';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  static const String _defaultEmoji = '🍽️';
  final ImagePicker _picker = ImagePicker();
  bool _showPanel = false;
  late AnimationController _anim;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _openPanel()  { setState(() => _showPanel = true);  _anim.forward(from: 0); }
  void _closePanel() { _anim.reverse().then((_) { if (mounted) setState(() => _showPanel = false); }); }

  double _imgSz(double w) {
    if (w < 360) return 28; if (w < 480) return 36;
    if (w < 768) return 44; if (w < 1280) return 52;
    if (w < 1920) return 60; return 68;
  }

  String _normalizeEmoji(String s) {
    final t = s.trim();
    if (t.startsWith('data:image/')) return t;
    if (t.isEmpty) return '';
    final r = t.runes.toList();
    return r.length <= 2 ? t : String.fromCharCodes(r.take(2));
  }

  Widget _buildImg(String v, {double size = 28}) {
    final s = v.trim();
    if (s.startsWith('data:image/')) {
      try {
        final b = base64Decode(s.split(',').last);
        return ClipRRect(borderRadius: BorderRadius.circular(10),
            child: Image.memory(Uint8List.fromList(b), width: size, height: size, fit: BoxFit.cover));
      } catch (_) { return Text(_defaultEmoji, style: TextStyle(fontSize: size * .8)); }
    }
    if (s.isEmpty) return Text(_defaultEmoji, style: TextStyle(fontSize: size * .8));
    return Text(s, style: TextStyle(fontSize: size * .8));
  }

  Future<void> _pickImg(TextEditingController c, ImageSource src, void Function(void Function()) sl) async {
    try {
      final p = await _picker.pickImage(source: src, maxWidth: 512, maxHeight: 512, imageQuality: 75);
      if (p == null) return;
      c.text = 'data:image/png;base64,${base64Encode(await p.readAsBytes())}';
      sl(() {});
    } catch (_) {}
  }

  // ── shows gallery / camera choice then picks ──────────────────────────────
  Future<void> _addImagePrompt(TextEditingController c, void Function(void Function()) sl) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _C.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          _sheetTile(Icons.photo_library_outlined, 'Choose from Gallery',   () => Navigator.pop(context, ImageSource.gallery)),
          _sheetTile(Icons.camera_alt_outlined,    'Take a Photo',          () => Navigator.pop(context, ImageSource.camera)),
          _sheetTile(Icons.close,                  'Cancel',                () => Navigator.pop(context), color: _C.textSec),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (src != null) await _pickImg(c, src, sl);
  }

  Widget _sheetTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? _C.textPri, size: 20),
      title: Text(label, style: TextStyle(color: color ?? _C.textPri, fontSize: 14)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width    = constraints.maxWidth;
      final provider = context.watch<RestaurantProvider>();
      final cats     = provider.categories;
      final selCat   = provider.selectedCategory;
      final allItems = provider.menuItems;
      final items    = selCat == 'All' ? allItems : allItems.where((m) => m.category == selCat).toList();
      final cross    = width >= 1300 ? 4 : (width >= 900 ? 3 : (width >= 560 ? 2 : 1));

      return AppPageScaffold(
        title: 'Menu',
        scrollable: false,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(20)),
            child: Text('${items.length} items', style: const TextStyle(color: _C.textSec, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _showPanel ? _closePanel() : _openPanel(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _showPanel ? _C.bg3 : _C.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_showPanel ? Icons.close : Icons.add,
                    color: _showPanel ? _C.textSec : Colors.black, size: 16),
                const SizedBox(width: 4),
                Text(_showPanel ? 'Close' : 'Add',
                    style: TextStyle(color: _showPanel ? _C.textSec : Colors.black,
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
        ],
        child: Column(children: [
          // ── Category filter bar ──────────────────────────────────────
          _CategoryBar(
            categories: cats,
            selected: selCat,
            counts: { for (final c in cats) c: c == 'All' ? allItems.length : allItems.where((m) => m.category == c).length },
            onSelect: (c) => context.read<RestaurantProvider>().setSelectedCategory(c),
          ),
          // ── Add panel ────────────────────────────────────────────────
          if (_showPanel)
            SizeTransition(
              sizeFactor: _slide,
              child: _AddPanel(
                categories: cats,
                selectedCategory: selCat,
                defaultEmoji: _defaultEmoji,
                normalizeEmoji: _normalizeEmoji,
                addImagePrompt: _addImagePrompt,
                buildImg: _buildImg,
                onClose: _closePanel,
              ),
            ),
          // ── Grid ─────────────────────────────────────────────────────
          Expanded(
            child: items.isEmpty
                ? _EmptyState(onAdd: _openPanel)
                : LayoutBuilder(builder: (ctx, box) {
                    const sp = 10.0;
                    final cardW = cross == 1
                        ? box.maxWidth - 24
                        : (box.maxWidth - 24 - sp * (cross - 1)) / cross;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                      child: Wrap(
                        spacing: sp, runSpacing: sp,
                        children: items.map((item) {
                          int sold = 0;
                          for (final o in provider.orders) {
                            for (final it in o.items) { if (it.id == item.id) sold += it.quantity; }
                          }
                          return SizedBox(
                            width: cardW,
                            child: _ItemCard(
                              item: item, soldCount: sold,
                              lowStock: (item.stock ?? 0) > 0 && (item.stock ?? 0) <= 5,
                              imageSize: _imgSz(width),
                              categories: cats,
                              normalizeEmoji: _normalizeEmoji,
                              addImagePrompt: _addImagePrompt,
                              buildImg: _buildImg,
                              imgSzFn: _imgSz,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
          ),
        ]),
      );
    });
  }
}

// ── Category Filter Bar ────────────────────────────────────────────────────────
class _CategoryBar extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;
  const _CategoryBar({required this.categories, required this.selected, required this.counts, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48, color: _C.bg1,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = categories[i]; final active = c == selected; final n = counts[c] ?? 0;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: active ? _C.amber : _C.bg3,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(c, style: TextStyle(color: active ? Colors.black : _C.textSec,
                    fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                if (n > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: active ? Colors.black26 : _C.bg2, borderRadius: BorderRadius.circular(10)),
                    child: Text('$n', style: TextStyle(color: active ? Colors.black : _C.textDim, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Add Panel ─────────────────────────────────────────────────────────────────
class _AddPanel extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final String defaultEmoji;
  final String Function(String) normalizeEmoji;
  final Future<void> Function(TextEditingController, void Function(void Function())) addImagePrompt;
  final Widget Function(String, {double size}) buildImg;
  final VoidCallback onClose;
  const _AddPanel({
    required this.categories, required this.selectedCategory,
    required this.defaultEmoji, required this.normalizeEmoji,
    required this.addImagePrompt, required this.buildImg, required this.onClose,
  });
  @override
  State<_AddPanel> createState() => _AddPanelState();
}

class _AddPanelState extends State<_AddPanel> {
  final _nameC  = TextEditingController();
  final _priceC = TextEditingController();
  final _emojiC = TextEditingController();
  final _newCatC = TextEditingController();
  late String _selCat;
  bool _addingNewCat = false;

  @override
  void initState() {
    super.initState();
    _emojiC.text = widget.defaultEmoji;
    final cats = widget.categories.where((c) => c != 'All').toList();
    _selCat = widget.selectedCategory == 'All'
        ? (cats.isNotEmpty ? cats.first : '')
        : widget.selectedCategory;
  }

  @override
  void dispose() { _nameC.dispose(); _priceC.dispose(); _emojiC.dispose(); _newCatC.dispose(); super.dispose(); }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: _C.textDim, fontSize: 13),
    filled: true, fillColor: _C.bg3,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.amber, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final cats = widget.categories.where((c) => c != 'All').toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(color: _C.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 4),
          child: Row(children: [
            const Text('New Item', style: TextStyle(color: _C.textPri, fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.close, color: _C.textSec, size: 16),
              ),
            ),
          ]),
        ),
        // Form
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Image preview tap to pick
              GestureDetector(
                onTap: () => widget.addImagePrompt(_emojiC, (fn) => setState(fn)),
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.border)),
                  child: Stack(alignment: Alignment.center, children: [
                    widget.buildImg(_emojiC.text.isEmpty ? widget.defaultEmoji : _emojiC.text, size: 36),
                    Positioned(bottom: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: _C.amber, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.camera_alt, size: 10, color: Colors.black),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(children: [
                TextField(controller: _nameC, autofocus: true,
                    style: const TextStyle(color: _C.textPri, fontSize: 13), decoration: _dec('Item name')),
                const SizedBox(height: 8),
                TextField(controller: _priceC, keyboardType: TextInputType.number,
                    style: const TextStyle(color: _C.textPri, fontSize: 13), decoration: _dec('₹ Price')),
              ])),
            ]),
            const SizedBox(height: 10),
            // Category dropdown
            if (_addingNewCat)
              Row(children: [
                Expanded(child: TextField(
                  controller: _newCatC, autofocus: true,
                  style: const TextStyle(color: _C.textPri, fontSize: 13),
                  decoration: _dec('New category name'),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final v = _newCatC.text.trim();
                    if (v.isNotEmpty) { context.read<RestaurantProvider>().addCategory(v); setState(() { _selCat = v; _addingNewCat = false; }); }
                    else { setState(() => _addingNewCat = false); }
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: _C.amber, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13))),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _addingNewCat = false),
                  child: Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close, size: 16, color: _C.textSec)),
                ),
              ])
            else
              DropdownButtonFormField<String>(
                value: (cats.contains(_selCat)) ? _selCat : (cats.isNotEmpty ? cats.first : null),
                decoration: _dec('Category'),
                dropdownColor: _C.bg2,
                style: const TextStyle(color: _C.textPri, fontSize: 13),
                items: [
                  ...cats.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  DropdownMenuItem(
                    value: _kNewCategory,
                    child: Row(children: const [
                      Icon(Icons.add, size: 14, color: _C.amber),
                      SizedBox(width: 6),
                      Text('New category…', style: TextStyle(color: _C.amber)),
                    ]),
                  ),
                ],
                onChanged: (v) {
                  if (v == _kNewCategory) { setState(() { _addingNewCat = true; _newCatC.clear(); }); }
                  else if (v != null) { setState(() => _selCat = v); }
                },
              ),
            const SizedBox(height: 10),
            // Save button full-width
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name  = _nameC.text.trim();
                  final price = int.tryParse(_priceC.text.trim()) ?? 0;
                  if (name.isEmpty || price <= 0 || _selCat.isEmpty) return;
                  final norm = widget.normalizeEmoji(_emojiC.text);
                  final img  = norm.isEmpty ? widget.defaultEmoji : norm;
                  context.read<RestaurantProvider>().addMenuItem(name: name, category: _selCat, price: price, image: img);
                  widget.onClose();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.amber, foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Save Item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🍽️', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('No items here', style: TextStyle(color: _C.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('Tap Add to create your first item', style: TextStyle(color: _C.textDim, fontSize: 13)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add, size: 16, color: Colors.black),
        label: const Text('Add Item', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(backgroundColor: _C.amber,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
    ]),
  );
}

// ── Menu Item Card ─────────────────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  final MenuItem item;
  final int soldCount;
  final bool lowStock;
  final double imageSize;
  final List<String> categories;
  final String Function(String) normalizeEmoji;
  final Future<void> Function(TextEditingController, void Function(void Function())) addImagePrompt;
  final Widget Function(String, {double size}) buildImg;
  final double Function(double) imgSzFn;

  const _ItemCard({
    required this.item, required this.soldCount, required this.lowStock,
    required this.imageSize, required this.categories, required this.normalizeEmoji,
    required this.addImagePrompt, required this.buildImg, required this.imgSzFn,
  });

  @override
  Widget build(BuildContext context) {
    final isPopular = !item.soldOut && soldCount >= 10;
    final isLowSell = !item.soldOut && soldCount <= 2;

    return GestureDetector(
      onTap: () => _openEdit(context),
      child: Container(
      decoration: BoxDecoration(
        color: _C.bg2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.soldOut ? _C.red.withOpacity(0.3) : _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image zone
        Stack(children: [
          Container(
            height: imageSize + 28, width: double.infinity,
            decoration: const BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
            child: Center(child: buildImg(item.image, size: imageSize + 8)),
          ),
          if (item.soldOut)
            Positioned.fill(child: Container(
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.65),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
              child: const Center(child: Text('SOLD OUT',
                  style: TextStyle(color: _C.red, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5))),
            )),
          if (isPopular)
            Positioned(top: 7, right: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(20)),
                child: const Text('⭐ TOP', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
          if (lowStock && !item.soldOut)
            Positioned(top: 7, left: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: _C.amber, borderRadius: BorderRadius.circular(20)),
                child: Text('${item.stock} left', style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
        // Info
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: const TextStyle(color: _C.textPri, fontWeight: FontWeight.w700, fontSize: 13, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(item.category, style: const TextStyle(color: _C.textDim, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 6),
            Text('₹${item.price}', style: const TextStyle(color: _C.green, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
        // Tags
        if (item.specialFlags.isNotEmpty || isLowSell)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: Wrap(spacing: 4, runSpacing: 4, children: [
              if (isLowSell) _tag('Low sales', _C.blue.withOpacity(0.15), _C.blue),
              ...item.specialFlags.map((f) => _tag(f, _C.bg3, _C.textSec)),
            ]),
          ),
        // Actions bar
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 6),
          child: Row(children: [
            const Icon(Icons.sell_outlined, size: 11, color: _C.textDim),
            const SizedBox(width: 3),
            Text('$soldCount sold', style: const TextStyle(color: _C.textDim, fontSize: 11)),
            const Spacer(),
            GestureDetector(
              onTap: () { _openRecipe(context); },
              behavior: HitTestBehavior.opaque,
              child: Container(padding: const EdgeInsets.all(6), child: const Icon(Icons.receipt_long_outlined, size: 16, color: _C.textSec)),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // absorb to prevent card edit tap
              child: Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: item.soldOut,
                  onChanged: (v) => context.read<RestaurantProvider>().toggleSoldOut(item.id, v),
                  activeColor: _C.red,
                  inactiveThumbColor: _C.textDim,
                  inactiveTrackColor: _C.bg3,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ]),
        ),
      ]),
    ), // Container
    ); // GestureDetector
  }

  Widget _tag(String t, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w600)),
  );

  // ── Recipe ─────────────────────────────────────────────────────────────────
  void _openRecipe(BuildContext ctx) async {
    try {
      final recipe = await Repository.instance.ingredients.getRecipeForMenuItem(item.id);
      if (!ctx.mounted) return;
      if (recipe.isEmpty) { _dark(ctx, 'Recipe', const Text('No recipe mapped.', style: TextStyle(color: _C.textSec))); return; }
      final list = await Repository.instance.ingredients.listIngredients();
      final byId = <String, Map<String, dynamic>>{for (final r in list) r['id'] as String: r};
      final lines = recipe.map((e) {
        final id = e['ingredient_id'] as String;
        return '${byId[id]?['name'] ?? id} — ${(e['qty'] as num?)?.toDouble() ?? 0} ${e['unit'] ?? 'g'}';
      }).toList();
      if (!ctx.mounted) return;
      _dark(ctx, 'Recipe', Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((t) => Padding(padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [const Icon(Icons.fiber_manual_record, size: 6, color: _C.amber), const SizedBox(width: 8),
            Expanded(child: Text(t, style: const TextStyle(color: _C.textPri, fontSize: 13)))]))).toList()));
    } catch (_) {}
  }

  void _dark(BuildContext ctx, String title, Widget body) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: _C.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(color: _C.textPri, fontWeight: FontWeight.w700, fontSize: 16)),
      content: body,
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close', style: TextStyle(color: _C.amber)))],
    ));
  }

  // ── Edit dialog ────────────────────────────────────────────────────────────
  void _openEdit(BuildContext ctx) async {
    final nameC  = TextEditingController(text: item.name);
    final priceC = TextEditingController(text: item.price.toString());
    final emojiC = TextEditingController(text: item.image);
    final stockC = TextEditingController(text: (item.stock ?? '').toString());
    final startC = TextEditingController(text: item.availableStart ?? '');
    final endC   = TextEditingController(text: item.availableEnd ?? '');
    final newCatC = TextEditingController();
    String selCat       = item.category;
    bool   addingNewCat = false;
    final soldOut   = ValueNotifier<bool>(item.soldOut);
    final mods      = ValueNotifier<List<Map<String, dynamic>>>(List.from(item.modifiers));
    final upsellIds = ValueNotifier<List<int>>(List.from(item.upsellIds));
    final instr     = ValueNotifier<List<String>>(List.from(item.instructionTemplates));
    final flags     = ValueNotifier<List<String>>(List.from(item.specialFlags));
    final days      = ValueNotifier<List<String>>(List.from(item.availableDays));
    final seasonal  = ValueNotifier<bool>(item.seasonal);
    final ing       = ValueNotifier<List<Map<String, dynamic>>>(List.from(item.ingredients));
    List<Map<String, Object>> allIng = [];

    try {
      final existing = await Repository.instance.ingredients.getRecipeForMenuItem(item.id);
      if (existing.isNotEmpty) {
        final list = await Repository.instance.ingredients.listIngredients();
        allIng = list.map((e) => Map<String, Object>.from(e)).toList();
        final byId = <String, Map<String, Object>>{for (final r in allIng) r['id'] as String: r};
        ing.value = existing.map((e) {
          final id = e['ingredient_id'] as String;
          return <String, dynamic>{'ingredient_id': id, 'name': byId[id]?['name']?.toString() ?? id,
            'qty': (e['qty'] as num?)?.toDouble() ?? 0.0, 'unit': e['unit']?.toString() ?? 'g'};
        }).toList();
      }
    } catch (_) {}
    if (allIng.isEmpty) {
      try { final l = await Repository.instance.ingredients.listIngredients(); allIng = l.map((e) => Map<String, Object>.from(e)).toList(); } catch (_) {}
    }
    if (!ctx.mounted) return;

    await showDialog(context: ctx, builder: (dlg) {
      return StatefulBuilder(builder: (c, sl) {
        final dw  = MediaQuery.of(c).size.width;
        final psz = imgSzFn(dw) * 0.8;
        final cats = categories.where((x) => x != 'All').toList();

        InputDecoration dec(String h, {Widget? suf}) => InputDecoration(
          hintText: h, hintStyle: const TextStyle(color: _C.textDim, fontSize: 13), suffixIcon: suf,
          filled: true, fillColor: _C.bg3, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.amber, width: 1.5)),
        );
        Widget tf(TextEditingController ct, String h, {TextInputType? kb, bool ro = false, ValueChanged<String>? onCh}) =>
          TextField(controller: ct, keyboardType: kb, readOnly: ro, onChanged: onCh,
              style: const TextStyle(color: _C.textPri, fontSize: 13), decoration: dec(h));
        Widget sec(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Text(t, style: const TextStyle(color: _C.textSec, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)));
        Widget mini(IconData ic, String lb, VoidCallback fn) => GestureDetector(onTap: fn,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: _C.bg2, borderRadius: BorderRadius.circular(6), border: Border.all(color: _C.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, size: 12, color: _C.textSec), const SizedBox(width: 4), Text(lb, style: const TextStyle(color: _C.textSec, fontSize: 11))])));

        return Dialog(
          backgroundColor: _C.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                decoration: const BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(children: [
                  const Text('Edit Item', style: TextStyle(color: _C.textPri, fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  GestureDetector(onTap: () => Navigator.of(dlg).pop(),
                      child: const Icon(Icons.close, color: _C.textSec, size: 20)),
                ]),
              ),
              // Body
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: tf(nameC, 'Name')),
                    const SizedBox(width: 8),
                    SizedBox(width: 96, child: tf(priceC, '₹ Price', kb: TextInputType.number)),
                  ]),
                  const SizedBox(height: 10),
                  // Category dropdown with New Category option
                  if (addingNewCat)
                    Row(children: [
                      Expanded(child: TextField(controller: newCatC, autofocus: true,
                          style: const TextStyle(color: _C.textPri, fontSize: 13), decoration: dec('New category'))),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final v = newCatC.text.trim();
                          if (v.isNotEmpty) { c.read<RestaurantProvider>().addCategory(v); sl(() { selCat = v; addingNewCat = false; }); }
                          else { sl(() => addingNewCat = false); }
                        },
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: _C.amber, borderRadius: BorderRadius.circular(8)),
                            child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700))),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(onTap: () => sl(() => addingNewCat = false),
                          child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.close, size: 16, color: _C.textSec))),
                    ])
                  else
                    DropdownButtonFormField<String>(
                      value: cats.contains(selCat) ? selCat : (cats.isNotEmpty ? cats.first : null),
                      decoration: dec('Category'), dropdownColor: _C.bg2,
                      style: const TextStyle(color: _C.textPri, fontSize: 13),
                      items: [
                        ...cats.map((ct) => DropdownMenuItem(value: ct, child: Text(ct))),
                        DropdownMenuItem(value: _kNewCategory, child: Row(children: const [
                          Icon(Icons.add, size: 14, color: _C.amber), SizedBox(width: 6),
                          Text('New category…', style: TextStyle(color: _C.amber)),
                        ])),
                      ],
                      onChanged: (v) {
                        if (v == _kNewCategory) { sl(() { addingNewCat = true; newCatC.clear(); }); }
                        else if (v != null) { sl(() => selCat = v); }
                      },
                    ),
                  const SizedBox(height: 10),
                  // Image
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(
                      onTap: () => addImagePrompt(emojiC, sl),
                      child: Container(
                        width: psz + 8, height: psz + 8,
                        decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(10)),
                        child: Stack(alignment: Alignment.center, children: [
                          buildImg(emojiC.text.trim().isEmpty ? item.image : emojiC.text.trim(), size: psz),
                          Positioned(bottom: 4, right: 4,
                            child: Container(padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: _C.amber, borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.camera_alt, size: 10, color: Colors.black))),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TextField(controller: emojiC, style: const TextStyle(color: _C.textPri, fontSize: 13),
                        decoration: dec('Emoji / image', suf: emojiC.text.isEmpty ? null : IconButton(
                            icon: const Icon(Icons.clear, size: 14, color: _C.textSec), onPressed: () { emojiC.clear(); sl(() {}); })),
                        onChanged: (v) { final n = normalizeEmoji(v); if (n != v) { emojiC.text = n; emojiC.selection = TextSelection.collapsed(offset: n.length); } sl(() {}); },
                      ),
                      const SizedBox(height: 6),
                      mini(Icons.add_photo_alternate_outlined, 'Add Image', () => addImagePrompt(emojiC, sl)),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    ValueListenableBuilder<bool>(valueListenable: soldOut, builder: (_, v, __) => Row(children: [
                      Switch(value: v, onChanged: (val) => soldOut.value = val, activeColor: _C.red, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      const SizedBox(width: 4),
                      const Text('Sold Out', style: TextStyle(color: _C.textSec, fontSize: 13)),
                    ])),
                    const Spacer(),
                    SizedBox(width: 100, child: tf(stockC, 'Stock', kb: TextInputType.number)),
                  ]),
                  const SizedBox(height: 14),
                  sec('SPECIAL FLAGS'),
                  ValueListenableBuilder<List<String>>(valueListenable: flags, builder: (_, list, __) => Wrap(spacing: 6, runSpacing: 6, children: [
                    ...['Spicy','Jain','Gluten-Free','Vegan','Extra Crispy','No Onion','No Garlic'].map((f) {
                      final sel = list.contains(f);
                      return FilterChip(label: Text(f, style: TextStyle(fontSize: 11, color: sel ? Colors.black : _C.textSec)),
                        selected: sel, selectedColor: _C.amber, backgroundColor: _C.bg3, checkmarkColor: Colors.black, side: BorderSide.none,
                        onSelected: (s) { final nx = List<String>.from(list); if (s) { if (!nx.contains(f)) nx.add(f); } else {
                          nx.remove(f);
                        } flags.value = nx; });
                    }),
                  ])),
                  const SizedBox(height: 14),
                  sec('MODIFIERS'),
                  ValueListenableBuilder<List<Map<String, dynamic>>>(valueListenable: mods, builder: (_, list, __) => Column(children: [
                    ...list.asMap().entries.map((e) {
                      final i2 = e.key; final m2 = e.value;
                      final nc = TextEditingController(text: m2['name']?.toString() ?? '');
                      final pc = TextEditingController(text: (m2['priceDelta'] ?? '').toString());
                      return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                        Expanded(child: tf(nc, 'Name')), const SizedBox(width: 6),
                        SizedBox(width: 88, child: tf(pc, 'Δ Price', kb: TextInputType.number)),
                        IconButton(onPressed: () { final nx = List<Map<String, dynamic>>.from(list); nx.removeAt(i2); mods.value = nx; },
                            icon: const Icon(Icons.remove_circle_outline, color: _C.red, size: 18)),
                      ]));
                    }),
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                      onPressed: () { final nx = List<Map<String, dynamic>>.from(list); nx.add({'name':'','priceDelta':0}); mods.value = nx; },
                      icon: const Icon(Icons.add, size: 14, color: _C.amber), label: const Text('Add Modifier', style: TextStyle(color: _C.amber, fontSize: 12)))),
                  ])),
                  const SizedBox(height: 14),
                  sec('UPSELLS'),
                  ValueListenableBuilder<List<int>>(valueListenable: upsellIds, builder: (_, ids, __) {
                    final pv = c.read<RestaurantProvider>();
                    return Wrap(spacing: 6, runSpacing: 6, children: [
                      ...pv.menuItems.where((m) => m.id != item.id).map((m) {
                        final sel = ids.contains(m.id);
                        return ChoiceChip(label: Text(m.name, style: TextStyle(fontSize: 11, color: sel ? Colors.black : _C.textSec)),
                          selected: sel, selectedColor: _C.amber, backgroundColor: _C.bg3, side: BorderSide.none,
                          onSelected: (s) { final nx = List<int>.from(ids); if (s) { if (!nx.contains(m.id)) nx.add(m.id); } else {
                            nx.remove(m.id);
                          } upsellIds.value = nx; });
                      }),
                    ]);
                  }),
                  const SizedBox(height: 14),
                  sec('AVAILABILITY'),
                  ValueListenableBuilder<List<String>>(valueListenable: days, builder: (_, list, __) => Wrap(spacing: 6, runSpacing: 6, children: [
                    ...['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((d) {
                      final sel = list.contains(d);
                      return FilterChip(label: Text(d, style: TextStyle(fontSize: 11, color: sel ? Colors.black : _C.textSec)),
                        selected: sel, selectedColor: _C.amber, backgroundColor: _C.bg3, checkmarkColor: Colors.black, side: BorderSide.none,
                        onSelected: (s) { final nx = List<String>.from(list); if (s) { if (!nx.contains(d)) nx.add(d); } else {
                          nx.remove(d);
                        } days.value = nx; });
                    }),
                  ])),
                  const SizedBox(height: 8),
                  Row(children: [Expanded(child: tf(startC, 'Start HH:mm')), const SizedBox(width: 8), Expanded(child: tf(endC, 'End HH:mm'))]),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<bool>(valueListenable: seasonal, builder: (_, v, __) => Row(children: [
                    Switch(value: v, onChanged: (val) => seasonal.value = val, activeColor: _C.amber, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    const SizedBox(width: 4), const Text('Seasonal', style: TextStyle(color: _C.textSec, fontSize: 13)),
                  ])),
                  const SizedBox(height: 14),
                  sec('INSTRUCTION TEMPLATES'),
                  ValueListenableBuilder<List<String>>(valueListenable: instr, builder: (_, list, __) => Column(children: [
                    ...list.asMap().entries.map((e) {
                      final i2 = e.key; final c2 = TextEditingController(text: e.value);
                      return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                        Expanded(child: tf(c2, 'Template')),
                        IconButton(onPressed: () { final nx = List<String>.from(list); nx.removeAt(i2); instr.value = nx; },
                            icon: const Icon(Icons.remove_circle_outline, color: _C.red, size: 18)),
                      ]));
                    }),
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                      onPressed: () { final nx = List<String>.from(list); nx.add(''); instr.value = nx; },
                      icon: const Icon(Icons.add, size: 14, color: _C.amber), label: const Text('Add Template', style: TextStyle(color: _C.amber, fontSize: 12)))),
                  ])),
                  const SizedBox(height: 14),
                  sec('INVENTORY MAPPING'),
                  ValueListenableBuilder<List<Map<String, dynamic>>>(valueListenable: ing, builder: (_, list, __) => Column(children: [
                    ...list.asMap().entries.map((e) {
                      final i2 = e.key; final m2 = e.value;
                      final qC  = TextEditingController(text: (m2['qty'] ?? '').toString());
                      final cId = m2['ingredient_id']?.toString();
                      String bu = cId != null ? (allIng.firstWhere((x) => x['id'] == cId, orElse: () => <String, Object>{})['base_unit']?.toString() ?? '') : '';
                      final uC  = TextEditingController(text: m2['unit']?.toString() ?? bu);
                      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                        Expanded(child: DropdownButtonHideUnderline(child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.circular(8), border: Border.all(color: _C.border)),
                          child: DropdownButton<String>(
                            value: (cId != null && allIng.any((r) => r['id']?.toString() == cId)) ? cId : null,
                            hint: const Text('Ingredient', style: TextStyle(color: _C.textDim, fontSize: 12)),
                            isExpanded: true, dropdownColor: _C.bg2,
                            items: allIng.map((r) => DropdownMenuItem(value: r['id'] as String,
                                child: Text('${r['name'] ?? ''}  (${r['base_unit'] ?? ''})', style: const TextStyle(color: _C.textPri, fontSize: 12)))).toList(),
                            onChanged: (v) {
                              final nx = List<Map<String, dynamic>>.from(list);
                              final sel = allIng.firstWhere((x) => x['id'] == v, orElse: () => <String, Object>{'name':'','id': v ?? '','base_unit':''});
                              final bu2 = sel['base_unit']?.toString() ?? '';
                              nx[i2] = {'ingredient_id': v, 'name': sel['name'] as String?, 'qty': double.tryParse(qC.text) ?? 0.0, 'unit': bu2};
                              uC.text = bu2; ing.value = nx;
                            },
                          ),
                        ))),
                        const SizedBox(width: 6),
                        SizedBox(width: 60, child: TextField(controller: qC, keyboardType: TextInputType.number,
                            style: const TextStyle(color: _C.textPri, fontSize: 13), decoration: dec('Qty'),
                            onChanged: (v) { final nx = List<Map<String, dynamic>>.from(list); final cur = Map<String, dynamic>.from(nx[i2]); cur['qty'] = double.tryParse(v) ?? 0.0; nx[i2] = cur; ing.value = nx; })),
                        const SizedBox(width: 6),
                        SizedBox(width: 60, child: TextField(controller: uC, readOnly: true, style: const TextStyle(color: _C.textPri, fontSize: 13), decoration: dec('Unit'))),
                        IconButton(onPressed: () { final nx = List<Map<String, dynamic>>.from(list); nx.removeAt(i2); ing.value = nx; },
                            icon: const Icon(Icons.remove_circle_outline, color: _C.red, size: 18)),
                      ]));
                    }),
                    Row(children: [
                      TextButton.icon(onPressed: () { final nx = List<Map<String, dynamic>>.from(list); nx.add({'ingredient_id': null,'name':'','qty':0.0,'unit':''}); ing.value = nx; },
                          icon: const Icon(Icons.add, size: 14, color: _C.amber), label: const Text('Add Ingredient', style: TextStyle(color: _C.amber, fontSize: 12))),
                      TextButton(onPressed: () { c.read<RestaurantProvider>().setCurrentView('inventory'); Navigator.of(dlg).pop(); },
                          child: const Text('Manage →', style: TextStyle(color: _C.textSec, fontSize: 12))),
                    ]),
                  ])),
                ]),
              )),
              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(color: _C.bg3, borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
                child: Row(children: [
                  TextButton(onPressed: () { c.read<RestaurantProvider>().deleteMenuItem(item.id); Navigator.of(dlg).pop(); },
                      child: const Text('Delete', style: TextStyle(color: _C.red, fontSize: 13))),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      final name = nameC.text.trim(); final price = int.tryParse(priceC.text.trim()) ?? item.price;
                      final norm = normalizeEmoji(emojiC.text); final img = norm.isEmpty ? item.image : norm;
                      final st = stockC.text.trim().isEmpty ? item.stock : int.tryParse(stockC.text.trim());
                      c.read<RestaurantProvider>().updateMenuItem(MenuItem(
                        id: item.id, name: name.isEmpty ? item.name : name, category: selCat,
                        price: price, image: img, soldOut: soldOut.value,
                        modifiers: mods.value, upsellIds: upsellIds.value,
                        instructionTemplates: instr.value, specialFlags: flags.value,
                        availableDays: days.value,
                        availableStart: startC.text.trim().isEmpty ? null : startC.text.trim(),
                        availableEnd:   endC.text.trim().isEmpty   ? null : endC.text.trim(),
                        seasonal: seasonal.value, ingredients: ing.value, stock: st,
                      ));
                      Navigator.of(dlg).pop();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _C.amber, foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ]),
              ),
            ]),
          ),
        );
      });
    });
  }
}
