// tables_screen.dart  — refactored, uses shared AppColors / StatusBadge
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/app_ui_kit.dart';
import '../models/table_info.dart';

// ── Tables screen (select a table to place an order) ──────────────────────────

class TablesScreen extends StatelessWidget {
  final bool embedded;
  const TablesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final tables = [...provider.tables]..sort((a, b) => a.number.compareTo(b.number));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tap a table to take or continue an order.', style: AppTextStyles.small),
        const SizedBox(height: 14),
        Expanded(
          child: tables.isEmpty
              ? const EmptyState(message: 'No tables configured', icon: Icons.table_bar_outlined)
              : AdaptiveGrid(
                  mobileCols: 2,
                  tabletCols: 3,
                  desktopCols: 4,
                  childAspectRatio: 0.95,
                  shrinkWrap: false,
                  children: tables.map((t) => _TableCard(
                    table: t,
                    onTap: () => provider.selectTableForOrder(t),
                  )).toList(),
                ),
        ),
      ]),
    );
  }
}

// ── Table management screen (add / edit / delete tables) ──────────────────────

class TableManagementScreen extends StatelessWidget {
  const TableManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantProvider>();
    final tables = [...provider.tables]..sort((a, b) => a.number.compareTo(b.number));

    return AppPageScaffold(
      title: 'Table Management',
      scrollable: false,
      actions: [
        AppButton.primary('Add Table',
            icon: Icons.add,
            small: true,
            onPressed: () => _showTableDialog(context, provider)),
      ],
      child: tables.isEmpty
          ? const EmptyState(message: 'No tables yet — add one above', icon: Icons.table_bar_outlined)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AdaptiveGrid(
                mobileCols: 2,
                tabletCols: 3,
                desktopCols: 4,
                childAspectRatio: 0.85,
                physics: const NeverScrollableScrollPhysics(),
                children: tables.map((t) => _TableCard(
                  table: t,
                  editable: true,
                  onEdit: () => _showTableDialog(context, provider, table: t),
                  onDelete: () => _confirmDelete(context, provider, t),
                )).toList(),
              ),
            ),
    );
  }

  void _showTableDialog(BuildContext context, RestaurantProvider provider, {TableInfo? table}) {
    final isEdit = table != null;
    final numberCtrl = TextEditingController(text: table?.number.toString() ?? '');
    final capacityCtrl = TextEditingController(text: table?.capacity.toString() ?? '4');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isEdit ? 'Edit Table' : 'Add New Table', style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DarkField(label: 'Table Number', controller: numberCtrl, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          DarkField(label: 'Capacity (seats)', controller: capacityCtrl, keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          AppButton.primary(isEdit ? 'Save' : 'Add Table', onPressed: () {
            final number = int.tryParse(numberCtrl.text.trim());
            final capacity = int.tryParse(capacityCtrl.text.trim());
            if (number == null || capacity == null) return;
            if (isEdit) {
              provider.editTable(table.id, number, capacity);
            } else {
              provider.addTable(number, capacity);
            }
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, RestaurantProvider provider, TableInfo table) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Table ${table.number}?', style: const TextStyle(color: AppColors.textPrimary)),
        content: const Text('This cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          AppButton.danger('Delete', onPressed: () {
            provider.deleteTable(table.id);
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }
}

// ── Shared table card ─────────────────────────────────────────────────────────

class _TableCard extends StatelessWidget {
  final TableInfo table;
  final bool editable;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TableCard({
    required this.table,
    this.editable = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.tableStatus(table.status);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AppCard(
        borderColor: color.withValues(alpha: 0.7),
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.table_bar_rounded, color: color, size: 34),
          const SizedBox(height: 8),
          Text('Table ${table.number}', style: AppTextStyles.h3),
          const SizedBox(height: 2),
          Text('${table.capacity} seats', style: AppTextStyles.small),
          const SizedBox(height: 8),
          StatusBadge.tableStatus(table.status, small: true),
          if (editable) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _IconBtn(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: onEdit!),
              const SizedBox(width: 8),
              _IconBtn(icon: Icons.delete_outline, tooltip: 'Delete', onTap: onDelete!, color: AppColors.red),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _IconBtn({required this.icon, required this.tooltip, required this.onTap, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
