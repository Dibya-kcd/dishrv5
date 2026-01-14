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
                        
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      );
      return PageScaffold(title: 'Tables', child: SingleChildScrollView(child: content));
    });
  }
}
