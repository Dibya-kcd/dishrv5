// app_theme.dart — Shared design tokens for "The Dish" POS
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  // Background layers
  static const bg0 = Color(0xFF0A0A0D);  // deepest
  static const bg1 = Color(0xFF111116);  // card bg
  static const bg2 = Color(0xFF1A1A22);  // elevated card
  static const bg3 = Color(0xFF24242E);  // input/chip fill

  // Borders
  static const border = Color(0xFF2C2C38);
  static const borderFocus = Color(0xFF4A4A5A);

  // Brand
  static const amber = Color(0xFFF59E0B);
  static const amberDim = Color(0xFF92600A);

  // Semantic
  static const green  = Color(0xFF10B981);
  static const blue   = Color(0xFF3B82F6);
  static const purple = Color(0xFFA855F7);
  static const red    = Color(0xFFEF4444);
  static const orange = Color(0xFFFF9500);
  static const teal   = Color(0xFF14B8A6);
  static const yellow = Color(0xFFEAB308);

  // Text
  static const textPrimary   = Color(0xFFE4E4F0);
  static const textSecondary = Color(0xFF8A8AA8);
  static const textMuted     = Color(0xFF55556A);
}

abstract class AppTextStyles {
  static TextStyle display(BuildContext ctx) =>
    GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5);
  static TextStyle title(BuildContext ctx) =>
    GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static TextStyle sectionHeader(BuildContext ctx) =>
    GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.8);
  static TextStyle body(BuildContext ctx) =>
    GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary);
  static TextStyle caption(BuildContext ctx) =>
    GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary);
  static TextStyle mono(BuildContext ctx) =>
    GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.green);
}

// Dark theme
ThemeData buildAppTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg0,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.amber,
      secondary: AppColors.blue,
      surface: AppColors.bg1,
      error: AppColors.red,
    ),
    cardColor: AppColors.bg1,
    dividerColor: AppColors.border,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg0,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg3,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      contentTextStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.amber : AppColors.bg3),
      checkColor: WidgetStateProperty.all(Colors.black),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.amber : AppColors.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.amberDim : AppColors.bg3),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bg3,
      selectedColor: AppColors.amber.withValues(alpha: 0.15),
      side: const BorderSide(color: AppColors.border),
      labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
      secondaryLabelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.amber),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ─── Reusable Widgets ────────────────────────────────────────────────────────

/// A standard card used throughout the app
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding, this.borderColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

/// Status badge / pill
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    );
  }
}

/// Section label (ALL-CAPS small header)
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    );
  }
}

/// Dark text field wrapper (shorthand)
class DarkField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final bool readOnly;
  final Widget? suffix;
  final void Function(String)? onChanged;
  const DarkField({
    super.key, required this.label, this.controller, this.hint,
    this.keyboardType, this.obscureText = false, this.maxLines = 1,
    this.readOnly = false, this.suffix, this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
        ),
      ],
    );
  }
}

/// Compact icon-button with tooltip (used in cards)
class CardIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  const CardIconBtn({super.key, required this.icon, required this.tooltip, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
        ),
      ),
    );
  }
}
