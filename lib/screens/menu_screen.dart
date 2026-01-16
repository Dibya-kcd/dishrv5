import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/menu_item.dart';
import '../data/repository.dart';
import '../widgets/page_scaffold.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final provider = context.watch<RestaurantProvider>();
      final categories = provider.categories;
      final selectedCategory = provider.selectedCategory;
      final menuItems = selectedCategory == 'All' ? provider.menuItems : provider.menuItems.where((m) => m.category == selectedCategory).toList();

      // final isMobile = width < 600;
      // final isTablet = width >= 600 && width <= 1024;
      // final isDesktop = width > 1024;
      final cross = width >= 1024 ? 4 : (width >= 640 ? 3 : 2);
      final cardAspect = 1.0;
      
      return PageScaffold(
        title: 'Menu',
        actions: [
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF18181B),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                builder: (_) {
                  final cats = context.read<RestaurantProvider>().categories;
                  final current = context.read<RestaurantProvider>().selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category Filter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: cats.map((c) {
                            final selected = c == current;
                            return FilterChip(
                              selected: selected,
                              label: Text(c),
                              onSelected: (_) {
                                context.read<RestaurantProvider>().setSelectedCategory(c);
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            icon: const Icon(Icons.tune, color: Colors.white),
            tooltip: 'Filters',
          ),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Removed category chips/dropdowns to keep filter icon only
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final nameController = TextEditingController();
                    await showDialog(context: context, builder: (_) {
                      return AlertDialog(
                        backgroundColor: const Color(0xFF18181B),
                        title: const Text('Add Category', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
                        content: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(hintText: 'Category name'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () {
                            final v = nameController.text.trim();
                            if (v.isNotEmpty) {
                              context.read<RestaurantProvider>().addCategory(v);
                            }
                            Navigator.of(context).pop();
                          }, child: const Text('Add')),
                        ],
                      );
                    });
                  },
                  style: TextButton.styleFrom(backgroundColor: const Color(0xFF27272A), foregroundColor: Colors.white),
                  child: const Text('Add Category'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final nameController = TextEditingController();
                    final priceController = TextEditingController();
                    String selected = selectedCategory == 'All' ? (categories.length > 1 ? categories[1] : 'General') : selectedCategory;
                    await showDialog(context: context, builder: (_) {
                      return StatefulBuilder(builder: (context, setLocal) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF18181B),
                          title: const Text('Add Menu Item', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(decoration: const InputDecoration(hintText: 'Name'), controller: nameController),
                              const SizedBox(height: 8),
                              TextField(decoration: const InputDecoration(hintText: 'Price'), controller: priceController, keyboardType: TextInputType.number),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: selected,
                                items: categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (v) { if (v != null) setLocal(() => selected = v); },
                                decoration: const InputDecoration(hintText: 'Category'),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () {
                              final name = nameController.text.trim();
                              final price = int.tryParse(priceController.text.trim()) ?? 0;
                              if (name.isNotEmpty && price > 0) {
                                context.read<RestaurantProvider>().addMenuItem(name: name, category: selected, price: price, image: '🍽️');
                              }
                              Navigator.of(context).pop();
                            }, child: const Text('Add')),
                          ],
                        );
                      });
                    });
                  },
                  style: TextButton.styleFrom(backgroundColor: const Color(0xFF27272A), foregroundColor: Colors.white),
                  child: const Text('Add Item'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: cardAspect
              ),
              itemCount: menuItems.length,
              itemBuilder: (context, i) {
                final item = menuItems[i];
                final orders = provider.orders;
                int soldCount = 0;
                for (final o in orders) {
                  for (final it in o.items) {
                    if (it.id == item.id) soldCount += it.quantity;
                  }
                }
                final lowStock = (item.stock ?? 0) > 0 && (item.stock ?? 0) <= 5;
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27272A))
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(item.image, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 6),
                    Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(item.category, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('₹${item.price}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Icon(Icons.sell, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text('Sold $soldCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        if (item.soldOut) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: const [
                            Icon(Icons.block, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('SOLD OUT', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ]),
                        ),
                        if (lowStock && !item.soldOut) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Icon(Icons.warning, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text('Stock ${item.stock}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        if (!item.soldOut && soldCount >= 10) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: const [
                            Icon(Icons.star_border, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ]),
                        ),
                        if (!item.soldOut && soldCount <= 2) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: const [
                            Icon(Icons.trending_down, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('LOW SELLING', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        ...item.specialFlags.map((f) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF27272A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF27272A))),
                          child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        );
                        })
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final nameController = TextEditingController(text: item.name);
                              final priceController = TextEditingController(text: item.price.toString());
                              String selected = item.category;
                              final emojiController = TextEditingController(text: item.image);
                              final soldOut = ValueNotifier<bool>(item.soldOut);
                              final stockController = TextEditingController(text: (item.stock ?? '').toString());
                              final mods = ValueNotifier<List<Map<String, dynamic>>>(List<Map<String, dynamic>>.from(item.modifiers));
                              final upsellIds = ValueNotifier<List<int>>(List<int>.from(item.upsellIds));
                              final instr = ValueNotifier<List<String>>(List<String>.from(item.instructionTemplates));
                              final flags = ValueNotifier<List<String>>(List<String>.from(item.specialFlags));
                              final days = ValueNotifier<List<String>>(List<String>.from(item.availableDays));
                              final startController = TextEditingController(text: item.availableStart ?? '');
                              final endController = TextEditingController(text: item.availableEnd ?? '');
                              final seasonal = ValueNotifier<bool>(item.seasonal);
                              final ing = ValueNotifier<List<Map<String, dynamic>>>(List<Map<String, dynamic>>.from(item.ingredients));
                              List<Map<String, Object>> allIngredients = [];
                              try {
                                final existing = await Repository.instance.ingredients.getRecipeForMenuItem(item.id);
                                if (existing.isNotEmpty) {
                                  final list = await Repository.instance.ingredients.listIngredients();
                                  allIngredients = list.map((e) => Map<String, Object>.from(e)).toList();
                                  final byId = <String, Map<String, Object>>{};
                                  for (final r in allIngredients) {
                                    byId[r['id'] as String] = r;
                                  }
                                  final mapped = existing.map((e) {
                                    final id = e['ingredient_id'] as String;
                                    final nm = byId[id]?['name']?.toString() ?? id;
                                    final qty = (e['qty'] as num?)?.toDouble() ?? 0.0;
                                    final unit = e['unit']?.toString() ?? 'g';
                                    return {'ingredient_id': id, 'name': nm, 'qty': qty, 'unit': unit};
                                  }).toList();
                                  ing.value = mapped;
                                }
                              } catch (_) {}
                              if (allIngredients.isEmpty) {
                                try { 
                                  final list = await Repository.instance.ingredients.listIngredients(); 
                                  allIngredients = list.map((e) => Map<String, Object>.from(e)).toList(); 
                                } catch (_) {}
                              }
                              if (!context.mounted) return;
                              await showDialog(context: context, builder: (_) {
                                return StatefulBuilder(builder: (context, setLocal) {
 
 
                                  return AlertDialog(
                                    backgroundColor: const Color(0xFF18181B),
                                    title: const Text('Edit Item', style: TextStyle(color: Colors.white, letterSpacing: 0.5)),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          TextField(decoration: const InputDecoration(hintText: 'Name'), controller: nameController),
                                          const SizedBox(height: 8),
                                          TextField(decoration: const InputDecoration(hintText: 'Price'), controller: priceController, keyboardType: TextInputType.number),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            value: selected,
                                            items: categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                            onChanged: (v) { if (v != null) setLocal(() => selected = v); },
                                            decoration: const InputDecoration(hintText: 'Category'),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(decoration: const InputDecoration(hintText: 'Emoji/Image'), controller: emojiController),
                                          const SizedBox(height: 8),
                                        ValueListenableBuilder<bool>(
                                          valueListenable: soldOut,
                                          builder: (_, v, __) => SwitchListTile(
                                            value: v,
                                            onChanged: (val) => soldOut.value = val,
                                            title: const Text('Sold Out', style: TextStyle(color: Colors.white)),
                                            activeColor: const Color(0xFFEF4444),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(decoration: const InputDecoration(hintText: 'Stock (optional)'), controller: stockController, keyboardType: TextInputType.number),
                                        const SizedBox(height: 12),
                                        const Text('Modifiers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                                          valueListenable: mods,
                                          builder: (_, list, __) => Column(
                                            children: [
                                              ...list.asMap().entries.map((e) {
                                                final i2 = e.key;
                                                final m2 = e.value;
                                                final nameC = TextEditingController(text: m2['name']?.toString() ?? '');
                                                final priceC = TextEditingController(text: (m2['priceDelta'] ?? '').toString());
                                                return Row(
                                                  children: [
                                                    Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Name'), controller: nameC)),
                                                    const SizedBox(width: 6),
                                                    SizedBox(width: 100, child: TextField(decoration: const InputDecoration(hintText: 'Δ Price'), controller: priceC, keyboardType: TextInputType.number)),
                                                    IconButton(onPressed: () { final next = List<Map<String, dynamic>>.from(list); next.removeAt(i2); mods.value = next; }, icon: const Icon(Icons.delete, color: Colors.white)),
                                                  ],
                                                );
                                              }),
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: TextButton(onPressed: () { final next = List<Map<String, dynamic>>.from(list); next.add({'name':'','priceDelta':0}); mods.value = next; }, child: const Text('Add Modifier')),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('Upsells', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        ValueListenableBuilder<List<int>>(
                                          valueListenable: upsellIds,
                                          builder: (_, ids, __) => Wrap(
                                            spacing: 6,
                                            children: [
                                              ...provider.menuItems.where((m) => m.id != item.id).map((m) {
                                                final sel = ids.contains(m.id);
                                                return ChoiceChip(
                                                  label: Text(m.name),
                                                  selected: sel,
                                                  onSelected: (s) {
                                                    final next = List<int>.from(ids);
                                                    if (s) { if (!next.contains(m.id)) next.add(m.id); } else { next.remove(m.id); }
                                                    upsellIds.value = next;
                                                  },
                                                );
                                              })
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('Instruction Templates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        ValueListenableBuilder<List<String>>(
                                          valueListenable: instr,
                                          builder: (_, list, __) => Column(
                                            children: [
                                              ...list.asMap().entries.map((e) {
                                                final i2 = e.key;
                                                final t = e.value;
                                                final c = TextEditingController(text: t);
                                                return Row(children: [
                                                  Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Template'), controller: c)),
                                                  IconButton(onPressed: () { final next = List<String>.from(list); next.removeAt(i2); instr.value = next; }, icon: const Icon(Icons.delete, color: Colors.white)),
                                                ]);
                                              }),
                                              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () { final next = List<String>.from(list); next.add(''); instr.value = next; }, child: const Text('Add Template'))),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('Special Flags', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        ValueListenableBuilder<List<String>>(
                                          valueListenable: flags,
                                          builder: (_, list, __) => Wrap(
                                            spacing: 6,
                                            children: [
                                              ...['Spicy','Jain','Gluten-Free','Vegan','Extra Crispy','No Onion','No Garlic'].map((f) {
                                                final sel = list.contains(f);
                                                return FilterChip(
                                                  label: Text(f),
                                                  selected: sel,
                                                  onSelected: (s) {
                                                    final next = List<String>.from(list);
                                                    if (s) { if (!next.contains(f)) next.add(f); } else { next.remove(f); }
                                                    flags.value = next;
                                                  },
                                                );
                                              })
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('Availability', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        ValueListenableBuilder<List<String>>(
                                          valueListenable: days,
                                          builder: (_, list, __) => Wrap(
                                            spacing: 6,
                                            children: [
                                              ...['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map((d) {
                                                final sel = list.contains(d);
                                                return FilterChip(
                                                  label: Text(d),
                                                  selected: sel,
                                                  onSelected: (s) {
                                                    final next = List<String>.from(list);
                                                    if (s) { if (!next.contains(d)) next.add(d); } else { next.remove(d); }
                                                    days.value = next;
                                                  },
                                                );
                                              })
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(children: [
                                          Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Start HH:mm'), controller: startController)),
                                          const SizedBox(width: 6),
                                          Expanded(child: TextField(decoration: const InputDecoration(hintText: 'End HH:mm'), controller: endController)),
                                        ]),
                                        const SizedBox(height: 6),
                                        ValueListenableBuilder<bool>(
                                          valueListenable: seasonal,
                                          builder: (_, v, __) => SwitchListTile(
                                            value: v,
                                            onChanged: (val) => seasonal.value = val,
                                            title: const Text('Seasonal', style: TextStyle(color: Colors.white)),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text('Inventory Mapping', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 6),
                                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                                          valueListenable: ing,
                                          builder: (_, list, __) => Column(
                                            children: [
                                              ...list.asMap().entries.map((e) {
                                                final i2 = e.key;
                                                final m2 = e.value;
                                                final qtyC = TextEditingController(text: (m2['qty'] ?? '').toString());
                                                final currentId = m2['ingredient_id']?.toString();
                                                String baseUnit = '';
                                                if (currentId != null) {
                                                  final sel = allIngredients.firstWhere((x) => x['id'] == currentId, orElse: () => <String, Object>{});
                                                  baseUnit = sel['base_unit']?.toString() ?? '';
                                                }
                                                final unitC = TextEditingController(text: (m2['unit']?.toString() ?? baseUnit));
                                                return Row(children: [
                                                  Expanded(child: DropdownButtonHideUnderline(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                                      decoration: BoxDecoration(color: const Color(0xFF0B0B0E), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF27272A))),
                                                      child: DropdownButton<String>(
                                                        value: (currentId != null && allIngredients.any((r) => (r['id']?.toString() ?? '') == currentId)) ? currentId : null,
                                                        hint: const Text('Select ingredient', style: TextStyle(color: Colors.white)),
                                                        isExpanded: true,
                                                        dropdownColor: const Color(0xFF18181B),
                                                        items: allIngredients.map((r) {
                                                          final name = (r['name'] as String?) ?? '';
                                                          final cat = (r['category'] as String?) ?? 'Uncategorized';
                                                          final bu = (r['base_unit'] as String?) ?? '';
                                                          return DropdownMenuItem(
                                                            value: r['id'] as String,
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(name, style: const TextStyle(color: Colors.white)),
                                                                Text('$cat • $bu', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList(),
                                                        onChanged: (v) {
                                                          final next = List<Map<String, dynamic>>.from(list);
                                                          final sel = allIngredients.firstWhere((x)=>x['id']==v, orElse: ()=><String, Object>{'name':'', 'id': v ?? '', 'base_unit':'', 'category':'Uncategorized'});
                                                          final bu = sel['base_unit']?.toString() ?? '';
                                                          next[i2] = {
                                                            'ingredient_id': v,
                                                            'name': (sel['name'] as String?),
                                                            'qty': double.tryParse(qtyC.text) ?? 0.0,
                                                            'unit': bu
                                                          };
                                                          unitC.text = bu;
                                                          ing.value = next;
                                                        },
                                                      ),
                                                    ),
                                                  )),
                                                  const SizedBox(width: 6),
                                                  SizedBox(width: 80, child: TextField(decoration: const InputDecoration(hintText: 'Qty'), controller: qtyC, keyboardType: TextInputType.number)),
                                                  const SizedBox(width: 6),
                                                  SizedBox(width: 100, child: TextField(decoration: const InputDecoration(hintText: 'Unit'), controller: unitC, readOnly: true)),
                                                  IconButton(onPressed: () { final next = List<Map<String, dynamic>>.from(list); next.removeAt(i2); ing.value = next; }, icon: const Icon(Icons.delete, color: Colors.white)),
                                                ]);
                                              }),
                                              Row(children: [
                                                TextButton(onPressed: () { final next = List<Map<String, dynamic>>.from(list); next.add({'ingredient_id': null, 'name':'', 'qty':0.0, 'unit':''}); ing.value = next; }, child: const Text('Add Ingredient')),
                                                const SizedBox(width: 8),
                                                TextButton(onPressed: () { 
                                                  context.read<RestaurantProvider>().setCurrentView('inventory'); 
                                                  Navigator.of(context).pop(); 
                                                }, child: const Text('Manage Ingredients')),
                                              ]),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                                    ElevatedButton(onPressed: () {
                                      final name = nameController.text.trim();
                                      final price = int.tryParse(priceController.text.trim()) ?? item.price;
                                      final img = emojiController.text.trim().isEmpty ? item.image : emojiController.text.trim();
                                      final st = stockController.text.trim().isEmpty ? item.stock : int.tryParse(stockController.text.trim());
                                      final updated = MenuItem(
                                        id: item.id,
                                        name: name.isEmpty ? item.name : name,
                                        category: selected,
                                        price: price,
                                        image: img,
                                        soldOut: soldOut.value,
                                        modifiers: mods.value,
                                        upsellIds: upsellIds.value,
                                        instructionTemplates: instr.value,
                                        specialFlags: flags.value,
                                        availableDays: days.value,
                                        availableStart: startController.text.trim().isEmpty ? null : startController.text.trim(),
                                        availableEnd: endController.text.trim().isEmpty ? null : endController.text.trim(),
                                        seasonal: seasonal.value,
                                        ingredients: ing.value,
                                        stock: st,
                                      );
                                      context.read<RestaurantProvider>().updateMenuItem(updated);
                                      Navigator.of(context).pop();
                                    }, child: const Text('Save')),
                                  ],
                                );
                              });
                            });
                            },
                            style: TextButton.styleFrom(backgroundColor: const Color(0xFF27272A), foregroundColor: Colors.white),
                            child: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                              onPressed: () async {
                                try {
                                  final recipe = await Repository.instance.ingredients.getRecipeForMenuItem(item.id);
                                  if (recipe.isEmpty) {
                                if (!context.mounted) return;
                                showDialog(context: context, builder: (_) => AlertDialog(
                                  backgroundColor: const Color(0xFF18181B),
                                  title: const Text('Recipe', style: TextStyle(color: Colors.white)),
                                  content: const Text('No recipe mapped for this item.', style: TextStyle(color: Colors.white)),
                                  actions: [TextButton(onPressed: ()=>Navigator.of(context).pop(), child: const Text('Close'))],
                                ));
                                    return;
                                  }
                                  final list = await Repository.instance.ingredients.listIngredients();
                                  final byId = <String, Map<String, dynamic>>{};
                                  for (final r in list) {
                                    byId[r['id'] as String] = r;
                                  }
                                  final lines = recipe.map((e) {
                                    final id = e['ingredient_id'] as String;
                                    final nm = byId[id]?['name']?.toString() ?? id;
                                    final qty = (e['qty'] as num?)?.toDouble() ?? 0.0;
                                    final unit = e['unit']?.toString() ?? 'g';
                                    return '$nm — $qty $unit';
                                  }).toList();
                                  if (!context.mounted) return;
                                  showDialog(context: context, builder: (_) => AlertDialog(
                                    backgroundColor: const Color(0xFF18181B),
                                    title: const Text('Recipe', style: TextStyle(color: Colors.white)),
                                    content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      ...lines.map((t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(color: Colors.white)))),
                                    ])),
                                    actions: [TextButton(onPressed: ()=>Navigator.of(context).pop(), child: const Text('Close'))],
                                  ));
                                } catch (_) {}
                              },
                          style: TextButton.styleFrom(backgroundColor: const Color(0xFF27272A), foregroundColor: Colors.white),
                          child: const Text('Recipe'),
                        ),
                        IconButton(
                          onPressed: () => context.read<RestaurantProvider>().deleteMenuItem(item.id),
                          icon: const Icon(Icons.delete, color: Colors.white),
                        ),
                        Switch(
                          value: item.soldOut,
                          onChanged: (v) => context.read<RestaurantProvider>().toggleSoldOut(item.id, v),
                          activeColor: const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ]),
                );
              },
            ),
          ]),
        );
    });
  }
}
