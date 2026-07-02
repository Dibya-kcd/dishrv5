// ============================================================
// app_ui_kit.dart
// Shared design tokens, widgets, and helpers used across every
// screen. Eliminates the copy-paste duplication that existed
// in the original codebase (duplicate _buildMenuImage, duplicate
// status colour logic, duplicate cancel dialogs, etc.).
// ============================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/restaurant_provider.dart';
import '../models/menu_item.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Background layers
  static const bg0 = Color(0xFF0B0B0E); // deepest
  static const bg1 = Color(0xFF131316); // surface
  static const bg2 = Color(0xFF1C1C21); // card
  static const bg3 = Color(0xFF26262D); // elevated card / row

  // Borders
  static const border = Color(0xFF2E2E38);
  static const borderFaint = Color(0xFF222228);

  // Text
  static const textPrimary = Color(0xFFF4F4F5);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF52525B);

  // Accent
  static const amber = Color(0xFFF59E0B);
  static const orange = Color(0xFFFF9500);
  static const green = Color(0xFF10B981);
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFFA855F7);
  static const red = Color(0xFFEF4444);
  static const cyan = Color(0xFF06B6D4);

  // Table statuses
  static Color tableStatus(String status) {
    switch (status.toLowerCase()) {
      case 'available':   return green;
      case 'occupied':    return amber;
      case 'preparing':   return const Color(0xFFEAB308);
      case 'serving':     return blue;
      case 'billing':     return purple;
      case 'ready':       return cyan;
      default:            return const Color(0xFF71717A);
    }
  }

  // Order statuses
  static Color orderStatus(String status) {
    switch (status) {
      case 'Preparing':       return amber;
      case 'Ready':           return cyan;
      case 'Completed':       return green;
      case 'Settled':         return green;
      case 'Awaiting Payment':return purple;
      case 'Cancelled':       return red;
      default:                return const Color(0xFF71717A);
    }
  }
}

class AppTextStyles {
  AppTextStyles._();

  static const h1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3);
  static const h2 = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const h3 = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const body = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static const small = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static const mono = TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textPrimary);
  static const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textSecondary);
  static const price = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.amber);
}

// ── Breakpoints ───────────────────────────────────────────────────────────────

class Bp {
  Bp._();
  static bool mobile(BuildContext ctx)  => MediaQuery.sizeOf(ctx).width < 600;
  static bool tablet(BuildContext ctx)  { final w = MediaQuery.sizeOf(ctx).width; return w >= 600 && w < 1024; }
  static bool desktop(BuildContext ctx) => MediaQuery.sizeOf(ctx).width >= 1024;
  static bool wide(BuildContext ctx)    => MediaQuery.sizeOf(ctx).width >= 600;
  static T pick<T>(BuildContext ctx, {required T mob, T? tab, T? desk}) {
    if (desk != null && desktop(ctx)) return desk;
    if (tab  != null && wide(ctx))    return tab;
    return mob;
  }
}

// ── Surface / Card wrapper ─────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final double? elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderColor,
    this.radius = 12,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.bg2,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
        boxShadow: elevation != null
            ? [BoxShadow(color: Colors.black.withValues(alpha: elevation! * 0.04), blurRadius: elevation! * 4, offset: const Offset(0, 2))]
            : null,
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const StatusBadge(this.label, {super.key, required this.color, this.small = false});

  factory StatusBadge.tableStatus(String status, {bool small = false}) =>
      StatusBadge(status.toUpperCase(), color: AppColors.tableStatus(status), small: small);

  factory StatusBadge.orderStatus(String status, {bool small = false}) =>
      StatusBadge(status.toUpperCase(), color: AppColors.orderStatus(status), small: small);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Menu image helper (single canonical implementation) ───────────────────────

Widget buildMenuImage(String value, {double size = 32}) {
  const fallback = '🍽️';
  final v = value.trim();
  if (v.startsWith('data:image/')) {
    try {
      final bytes = base64Decode(v.split(',').last);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(Uint8List.fromList(bytes), width: size, height: size, fit: BoxFit.cover),
      );
    } catch (_) {
      return Text(fallback, style: TextStyle(fontSize: size * 0.75));
    }
  }
  if (v.isEmpty) return Text(fallback, style: TextStyle(fontSize: size * 0.75));
  return Text(v, style: TextStyle(fontSize: size * 0.75));
}

// ── Dark text field ───────────────────────────────────────────────────────────

class DarkField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? hint;
  final int? maxLines;
  final Widget? suffix;

  const DarkField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.hint,
    this.maxLines = 1,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.small.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hint ?? label,
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.bg1,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.amber, width: 1.5)),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.h2),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── AppButton ─────────────────────────────────────────────────────────────────

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final IconData? icon;
  final bool outlined;
  final bool small;
  final bool fullWidth;

  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.background,
    this.foreground,
    this.icon,
    this.outlined = false,
    this.small = false,
    this.fullWidth = false,
  });

  const AppButton.primary(this.label, {super.key, this.onPressed, this.icon, this.small = false, this.fullWidth = false})
      : background = AppColors.orange, foreground = Colors.white, outlined = false;

  const AppButton.danger(this.label, {super.key, this.onPressed, this.icon, this.small = false, this.fullWidth = false})
      : background = AppColors.red, foreground = Colors.white, outlined = false;

  const AppButton.ghost(this.label, {super.key, this.onPressed, this.icon, this.small = false, this.fullWidth = false})
      : background = AppColors.bg3, foreground = AppColors.textPrimary, outlined = false;

  @override
  Widget build(BuildContext context) {
    final bg = outlined ? Colors.transparent : (background ?? AppColors.bg3);
    final fg = foreground ?? AppColors.textPrimary;
    final h = small ? 36.0 : 44.0;
    final px = small ? 12.0 : 16.0;
    final fz = small ? 12.0 : 13.0;

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: fz + 2, color: fg), const SizedBox(width: 6)],
        Text(label, style: TextStyle(fontSize: fz, fontWeight: FontWeight.w600, color: fg)),
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: h,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: background ?? AppColors.border),
                foregroundColor: fg,
                padding: EdgeInsets.symmetric(horizontal: px),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: content,
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: fg,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: px),
                minimumSize: Size(0, h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: content,
            ),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  final IconData? icon;

  const StatTile({super.key, required this.label, required this.value, this.accent, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.amber;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, color: c, size: 16), const SizedBox(width: 6)],
            Text(label, style: AppTextStyles.label),
          ]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
        ],
      ),
    );
  }
}

// ── Cancel order dialog (single shared implementation) ────────────────────────

void showCancelOrderDialog(BuildContext context, String orderId, {bool isWastageDefault = true}) {
  final reasons = ['Customer left', 'Emergency', 'Service too slow', 'Wrong entry', 'Other'];
  String selectedReason = reasons.first;
  bool isWastage = isWastageDefault;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cancel Entire Order?', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('All items will be cancelled. This cannot be undone.', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedReason,
              dropdownColor: AppColors.bg3,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: 'Reason',
                labelStyle: AppTextStyles.small,
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
              ),
              items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => selectedReason = v!),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Mark as Wastage', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              subtitle: const Text('Deducts inventory', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              value: isWastage,
              onChanged: (v) => setState(() => isWastage = v!),
              activeColor: AppColors.red,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          AppButton.danger('Confirm Cancel', onPressed: () {
            ctx.read<RestaurantProvider>().cancelOrder(orderId, selectedReason, isWastage);
            Navigator.pop(ctx);
          }),
        ],
      ),
    ),
  );
}

// ── Cancel item dialog (from kitchen / order screens) ─────────────────────────

void showCancelItemDialog(BuildContext context, String orderId, dynamic item) {
  final reasons = ['Customer changed mind', 'Item unavailable', 'Wrong entry', 'Kitchen error', 'Other'];
  String selectedReason = reasons.first;
  bool isWastage = true;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Cancel ${item.name}?', style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedReason,
              dropdownColor: AppColors.bg3,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                labelText: 'Reason',
                labelStyle: AppTextStyles.small,
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
              ),
              items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => selectedReason = v!),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Mark as Wastage', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              subtitle: const Text('Deducts inventory', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              value: isWastage,
              onChanged: (v) => setState(() => isWastage = v!),
              activeColor: AppColors.red,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          AppButton.danger('Cancel Item', onPressed: () {
            ctx.read<RestaurantProvider>().cancelOrderedItem(orderId, item, selectedReason, isWastage);
            Navigator.pop(ctx);
          }),
        ],
      ),
    ),
  );
}

// ── Date range filter chips (reused in expense + reports) ────────────────────

class DateRangeChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  final List<String> options;

  const DateRangeChips({
    super.key,
    required this.current,
    required this.onChanged,
    this.options = const ['Today', 'Week', 'Month', 'Year', 'All'],
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((r) {
          final sel = r == current;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(r),
              selected: sel,
              onSelected: (_) => onChanged(r),
              selectedColor: AppColors.amber.withValues(alpha: 0.2),
              backgroundColor: AppColors.bg3,
              labelStyle: TextStyle(
                color: sel ? AppColors.amber : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
              ),
              side: BorderSide(color: sel ? AppColors.amber : AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Empty state widget ────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

// ── Page scaffold (title + scrollable content) ───────────────────────────────

class AppPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  /// Set to false when child manages its own scrolling (e.g. CustomScrollView,
  /// ListView, SingleChildScrollView). Defaults to true which wraps child in
  /// a SingleChildScrollView with standard padding.
  final bool scrollable;

  const AppPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.floatingActionButton,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          // ── Pinned app bar ─────────────────────────────────
          Material(
            color: AppColors.bg1,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                SizedBox(
                  height: kToolbarHeight,
                  child: Row(children: [
                    const SizedBox(width: 16),
                    Expanded(child: Text(title, style: AppTextStyles.h2)),
                    if (actions != null) ...actions!,
                    const SizedBox(width: 8),
                  ]),
                ),
                const Divider(height: 1, color: AppColors.border),
              ]),
            ),
          ),
          // ── Body ───────────────────────────────────────────
          Expanded(
            child: scrollable
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  )
                : child,
          ),
        ],
      ),
    );
  }
}

// ── Responsive adaptive grid ──────────────────────────────────────────────────

class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final int mobileCols;
  final int tabletCols;
  final int desktopCols;
  final double childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.mobileCols = 2,
    this.tabletCols = 3,
    this.desktopCols = 4,
    this.childAspectRatio = 1,
    this.shrinkWrap = true,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = Bp.pick(context, mob: mobileCols, tab: tabletCols, desk: desktopCols);
      return GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: children.length,
        itemBuilder: (_, i) => children[i],
      );
    });
  }
}

// ── Loading / busy overlay ─────────────────────────────────────────────────────

class BusyOverlay extends StatelessWidget {
  final bool busy;
  final Widget child;
  final String? message;

  const BusyOverlay({super.key, required this.busy, required this.child, this.message});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (busy)
          Container(
            color: Colors.black45,
            child: Center(
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: AppColors.amber, strokeWidth: 2.5),
                  if (message != null) ...[const SizedBox(height: 12), Text(message!, style: AppTextStyles.body)],
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu availability helper — single source of truth, used by both order screens
// ─────────────────────────────────────────────────────────────────────────────

/// Returns true if the menu item is currently available (not sold-out, right
/// day, within the time window).
bool menuIsAvailable(MenuItem item) {
  if (item.soldOut == true) return false;
  final now = DateTime.now();
  const dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
  final today = dayMap[now.weekday]!;
  if (!item.availableDays.contains(today)) return false;
  final s = item.availableStart;
  final e = item.availableEnd;
  if (s != null && e != null && s.isNotEmpty && e.isNotEmpty) {
    int parsePart(String t, int idx, int def) {
      final parts = t.split(':');
      return int.tryParse(parts.length > idx ? parts[idx] : '') ?? def;
    }
    final nowMin = now.hour * 60 + now.minute;
    final sMin   = parsePart(s, 0, 0)  * 60 + parsePart(s, 1, 0);
    final eMin   = parsePart(e, 0, 23) * 60 + parsePart(e, 1, 59);
    if (nowMin < sMin || nowMin > eMin) return false;
  }
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// MenuFilterBar — consistent category filter + search used across order screens
// ─────────────────────────────────────────────────────────────────────────────

/// A unified filter/search bar for order screens.
///
/// Shows:
///  • A horizontally-scrollable row of category chip-buttons (always "All" first)
///  • A 🔍 icon-button that expands an inline search field
///  • A filter badge on the active category chip so it's obvious when a filter
///    is active
///
/// Usage:
/// ```dart
/// MenuFilterBar(
///   categories: provider.categories,
///   selectedCategory: provider.selectedCategory,
///   onCategoryChanged: provider.setSelectedCategory,
///   searchQuery: _searchQuery,
///   onSearchChanged: (q) => setState(() => _searchQuery = q),
/// )
/// ```
class MenuFilterBar extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const MenuFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  State<MenuFilterBar> createState() => _MenuFilterBarState();
}

class _MenuFilterBarState extends State<MenuFilterBar> {
  bool _searching = false;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.searchQuery;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _closeSearch() {
    setState(() => _searching = false);
    _ctrl.clear();
    widget.onSearchChanged('');
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isFiltered = widget.selectedCategory != 'All';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Row: chips + search icon ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.categories.map((c) {
                    final active = widget.selectedCategory == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _CategoryChip(
                        label: c,
                        active: active,
                        onTap: () => widget.onCategoryChanged(c),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Search toggle
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: _searching
                    ? AppColors.amber.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  _searching ? Icons.search_off : Icons.search,
                  color: _searching ? AppColors.amber : AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: _searching ? 'Close search' : 'Search menu',
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  if (_searching) {
                    _closeSearch();
                  } else {
                    setState(() => _searching = true);
                    Future.delayed(
                      const Duration(milliseconds: 80),
                      () => _focus.requestFocus(),
                    );
                  }
                },
              ),
            ),
            // Filter badge dot — visible when a category is active
            if (isFiltered && !_searching)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: IconButton(
                  icon: const Icon(Icons.filter_alt, color: AppColors.amber, size: 18),
                  tooltip: 'Clear filter',
                  constraints: const BoxConstraints.tightFor(width: 32, height: 36),
                  padding: EdgeInsets.zero,
                  onPressed: () => widget.onCategoryChanged('All'),
                ),
              ),
          ],
        ),

        // ── Inline search field (expands below chips) ──────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _searching
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              onChanged: widget.onSearchChanged,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search items…',
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                        onPressed: () {
                          _ctrl.clear();
                          widget.onSearchChanged('');
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: AppColors.bg2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.amber : AppColors.bg2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.amber : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
