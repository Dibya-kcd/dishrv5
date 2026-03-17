import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tax_settings.dart';
import '../providers/restaurant_provider.dart';
import '../widgets/app_ui_kit.dart';

/// Tax configuration screen.
/// Pass [embed] = true when hosting inside SettingsScreen to suppress
/// the redundant Scaffold/AppBar wrapper.
class TaxSettingsScreen extends StatefulWidget {
  final bool embed;
  const TaxSettingsScreen({super.key, this.embed = false});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  late TaxSettings _draft;
  final _rateCtrl  = TextEditingController();
  final _labelCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ts = context.read<RestaurantProvider>().taxSettings;
    _draft = ts;
    _rateCtrl.text = _fmtRate(ts.rate);
    _labelCtrl.text = ts.label;
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String _fmtRate(double r) {
    final pct = r * 100;
    return pct == pct.truncateToDouble()
        ? pct.toStringAsFixed(0)
        : pct.toStringAsFixed(2);
  }

  void _applyDraft() {
    final pct = double.tryParse(_rateCtrl.text.trim()) ?? (_draft.rate * 100);
    _draft = _draft.copyWith(
      rate: (pct / 100).clamp(0.0, 1.0),
      label: _labelCtrl.text.trim().isEmpty ? 'Tax' : _labelCtrl.text.trim(),
    );
  }

  Future<void> _save() async {
    _applyDraft();
    setState(() => _saving = true);
    try {
      await context.read<RestaurantProvider>().saveTaxSettings(_draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_draft.enabled
              ? 'Tax saved: ${_draft.label} ${_draft.rateLabel}'
                  '${_draft.inclusive ? ' (inclusive)' : ''}'
              : 'Tax disabled — bills will show no tax.'),
          backgroundColor: AppColors.green,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;

    Widget body = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 32 : 16,
        vertical: 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 680 : double.infinity),
          child: _buildForm(),
        ),
      ),
    );

    // When embedded, skip Scaffold so SettingsScreen's Scaffold is used
    if (widget.embed) {
      return SafeArea(child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        backgroundColor: AppColors.bg1,
        elevation: 0,
        title: const Text('Tax & Billing', style: AppTextStyles.h2),
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Enable toggle ────────────────────────────────────────────────
        _Card(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.amber,
            title: const Text('Enable Tax',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            subtitle: Text(
              _draft.enabled
                  ? 'Tax will appear on bills and receipts.'
                  : 'No tax will be charged or shown on bills.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            value: _draft.enabled,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(enabled: v)),
          ),
        ),

        if (_draft.enabled) ...[
          const SizedBox(height: 12),

          // ── Label + Rate side-by-side on wide, stacked on mobile ───────
          LayoutBuilder(builder: (_, c) {
            final row = c.maxWidth >= 300;
            final labelField = _LabeledField(
              label: 'Tax Label',
              hint: 'e.g. GST, VAT',
              controller: _labelCtrl,
              helper: 'Shown next to the tax line on printed bills.',
              caps: TextCapitalization.characters,
              maxLen: 20,
              onChanged: (_) => setState(() {}),
            );
            final rateField = _LabeledField(
              label: 'Rate (%)',
              hint: 'e.g. 5',
              controller: _rateCtrl,
              helper: 'Common: 5% GST · 18% GST · 10% Service',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              suffix: '%',
              onChanged: (_) => setState(() {}),
            );
            return row
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: labelField),
                      const SizedBox(width: 12),
                      Expanded(child: rateField),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      labelField,
                      const SizedBox(height: 12),
                      rateField,
                    ],
                  );
          }),

          const SizedBox(height: 12),

          // ── Inclusive toggle ─────────────────────────────────────────
          _Card(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.amber,
              title: const Text('Price-Inclusive Tax',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: Text(
                _draft.inclusive
                    ? 'Menu prices include tax — back-calculated for receipts.'
                    : 'Tax is added on top of menu prices at checkout.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              value: _draft.inclusive,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(inclusive: v)),
            ),
          ),

          const SizedBox(height: 12),

          // ── Live preview ─────────────────────────────────────────────
          _Card(
            tint: AppColors.amber.withValues(alpha: 0.06),
            child: _Preview(
              draft: _draft,
              rateText: _rateCtrl.text,
              labelText: _labelCtrl.text,
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ── Save ─────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.black))
                : const Text('Save Tax Settings',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers (file-private, used only here)
// ─────────────────────────────────────────────────────────────────────────────

/// Styled card container using AppColors — consistent with the rest of the app.
class _Card extends StatelessWidget {
  final Widget child;
  final Color? tint;
  const _Card({required this.child, this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint ?? AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// A labelled text field with helper text, wrapped in a _Card.
class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String helper;
  final TextCapitalization caps;
  final int? maxLen;
  final TextInputType? keyboard;
  final String? suffix;
  final ValueChanged<String>? onChanged;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.helper,
    this.caps = TextCapitalization.none,
    this.maxLen,
    this.keyboard,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            textCapitalization: caps,
            maxLength: maxLen,
            keyboardType: keyboard,
            onChanged: onChanged,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: AppColors.textSecondary),
              suffixText: suffix,
              counterText: '',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              filled: true,
              fillColor: AppColors.bg3,
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
                borderSide:
                    const BorderSide(color: AppColors.amber, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(helper,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Live bill preview so the admin sees the tax effect immediately.
class _Preview extends StatelessWidget {
  final TaxSettings draft;
  final String rateText;
  final String labelText;
  const _Preview(
      {required this.draft,
      required this.rateText,
      required this.labelText});

  @override
  Widget build(BuildContext context) {
    const sample = 500.0;
    final pct = double.tryParse(rateText.trim()) ?? (draft.rate * 100);
    final p = draft.copyWith(
      rate: (pct / 100).clamp(0.0, 1.0),
      label: labelText.trim().isEmpty ? 'Tax' : labelText.trim(),
    );
    final tax   = p.taxFor(sample);
    final total = p.totalFor(sample);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.receipt_long,
              size: 14, color: AppColors.amber),
          const SizedBox(width: 6),
          Text('Preview — sample ₹${sample.toStringAsFixed(0)} order',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 10),
        _BillRow('Subtotal', '₹${sample.toStringAsFixed(2)}'),
        if (p.enabled)
          _BillRow(
            '${p.label} (${p.rateLabel})${p.inclusive ? ' incl.' : ''}',
            '₹${tax.toStringAsFixed(2)}',
          ),
        const Divider(color: AppColors.border, height: 14),
        _BillRow('Total', '₹${total.toStringAsFixed(2)}', bold: true),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _BillRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 14 : 13,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: bold ? AppColors.textPrimary : AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
