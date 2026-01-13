import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';

List<Widget> buildReportActions(BuildContext context) {
  final provider = context.watch<RestaurantProvider>();
  final range = provider.analyticsRange;
  final catFilter = provider.analyticsCategoryFilter;
  final svcFilter = provider.analyticsServiceFilter;

  return [
    Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: range,
          dropdownColor: const Color(0xFF27272A),
          icon: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          ),
          isDense: true,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          items: const [
            DropdownMenuItem(value: 'Today', child: Text('Today')),
            DropdownMenuItem(value: '7D', child: Text('Week')),
            DropdownMenuItem(value: '30D', child: Text('Month')),
            DropdownMenuItem(value: '365D', child: Text('Year')),
            DropdownMenuItem(value: 'All Time', child: Text('All Time')),
          ],
          onChanged: (v) { if (v != null) context.read<RestaurantProvider>().setAnalyticsRange(v); },
        ),
      ),
    ),
    IconButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF18181B),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
          builder: (_) {
            final cats = context.read<RestaurantProvider>().categories;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Filters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Category', style: TextStyle(color: Color(0xFFA1A1AA))),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: cats.map((c) {
                  final selected = c == catFilter;
                  return FilterChip(
                    selected: selected,
                    label: Text(c),
                    onSelected: (_) { context.read<RestaurantProvider>().setAnalyticsCategoryFilter(c); },
                  );
                }).toList()),
                const SizedBox(height: 12),
                const Text('Service', style: TextStyle(color: Color(0xFFA1A1AA))),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: ['All','Dine-In','Take-Out'].map((s) {
                  final selected = s == svcFilter;
                  return FilterChip(
                    selected: selected,
                    label: Text(s),
                    onSelected: (_) { context.read<RestaurantProvider>().setAnalyticsServiceFilter(s); },
                  );
                }).toList()),
              ]),
            );
          },
        );
      },
      icon: const Icon(Icons.tune, color: Colors.white),
      tooltip: 'Filters',
    ),
  ];
}
