import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/page_scaffold.dart';

class TablesScreen extends StatelessWidget {
  final bool embedded;
  const TablesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final tables = provider.tables.where((t) => t.status != 'deleted').toList();

    void showAddTableDialog() {
      final numberController = TextEditingController();
      final capacityController = TextEditingController(text: '4');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add New Table'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                decoration: const InputDecoration(labelText: 'Table Number', hintText: 'e.g. 10'),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: capacityController,
                decoration: const InputDecoration(labelText: 'Capacity', hintText: 'Number of seats'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final number = int.tryParse(numberController.text.trim());
                final capacity = int.tryParse(capacityController.text.trim());
                if (number != null && capacity != null) {
                  provider.addTable(number, capacity);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Table'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select a table to take an order', style: TextStyle(color: Color(0xFFA1A1AA))),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final cross = width >= 1024 ? 4 : (width >= 640 ? 3 : 2);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: tables.length,
              itemBuilder: (context, i) {
                final t = tables[i];
                Color getColor(String status) {
                  switch (status) {
                    case 'available': return const Color(0xFF10B981);
                    case 'occupied': return const Color(0xFFF59E0B);
                    case 'preparing': return const Color(0xFFEAB308);
                    case 'serving': return const Color(0xFF3B82F6);
                    case 'billing': return const Color(0xFFA855F7);
                    default: return const Color(0xFF71717A);
                  }
                }
                final color = getColor(t.status);
                return InkWell(
                  onTap: () => provider.selectTableForOrder(t),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color, width: 2),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_bar, color: color, size: 36),
                        const SizedBox(height: 8),
                        Text('Table ${t.number}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('${t.capacity} seats', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(t.status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              tooltip: 'Edit',
                              onPressed: () {
                                final numberController = TextEditingController(text: '${t.number}');
                                final capacityController = TextEditingController(text: '${t.capacity}');
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Edit Table'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: numberController,
                                          decoration: const InputDecoration(labelText: 'Table Number'),
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 16),
                                        TextField(
                                          controller: capacityController,
                                          decoration: const InputDecoration(labelText: 'Capacity'),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () {
                                          final number = int.tryParse(numberController.text.trim());
                                          final capacity = int.tryParse(capacityController.text.trim());
                                          if (number != null && capacity != null) {
                                            provider.editTable(t.id, number, capacity);
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: const Text('Save'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'Delete',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Table'),
                                    content: const Text('Are you sure you want to delete this table?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                      ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Yes, Delete')),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  provider.deleteTable(t.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      );
      if (!embedded) {
        return PageScaffold(
          title: 'Table Management', 
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Table',
              onPressed: showAddTableDialog,
            ),
          ],
          child: content
        );
      }
      return Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: content));
    });
  }
}
