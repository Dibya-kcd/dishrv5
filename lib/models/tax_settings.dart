/// Holds restaurant tax configuration.
/// Stored in the `settings` table under key `tax_config`.
class TaxSettings {
  /// Whether tax is enabled at all.
  final bool enabled;

  /// Tax rate as a fraction (e.g. 0.05 = 5 %).
  final double rate;

  /// Display label shown on bills (e.g. "GST", "VAT", "Tax").
  final String label;

  /// Whether the rate is inclusive in the item price or added on top.
  final bool inclusive;

  const TaxSettings({
    this.enabled = true,
    this.rate = 0.05,
    this.label = 'GST',
    this.inclusive = false,
  });

  /// Returns the tax amount for a given subtotal.
  double taxFor(double subtotal) {
    if (!enabled) return 0.0;
    if (inclusive) {
      // Back-calculate tax that is already embedded in the price.
      return subtotal - (subtotal / (1 + rate));
    }
    return subtotal * rate;
  }

  /// Returns the grand total for a given subtotal.
  double totalFor(double subtotal) {
    if (!enabled) return subtotal;
    if (inclusive) return subtotal; // tax is already inside
    return subtotal + taxFor(subtotal);
  }

  /// Percentage string for display (e.g. "5%").
  String get rateLabel => '${(rate * 100).toStringAsFixed(rate * 100 == (rate * 100).truncateToDouble() ? 0 : 2)}%';

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'rate': rate,
        'label': label,
        'inclusive': inclusive,
      };

  factory TaxSettings.fromJson(Map<String, dynamic> json) => TaxSettings(
        enabled: json['enabled'] as bool? ?? true,
        rate: (json['rate'] as num?)?.toDouble() ?? 0.05,
        label: json['label'] as String? ?? 'GST',
        inclusive: json['inclusive'] as bool? ?? false,
      );

  TaxSettings copyWith({
    bool? enabled,
    double? rate,
    String? label,
    bool? inclusive,
  }) =>
      TaxSettings(
        enabled: enabled ?? this.enabled,
        rate: rate ?? this.rate,
        label: label ?? this.label,
        inclusive: inclusive ?? this.inclusive,
      );

  @override
  String toString() =>
      'TaxSettings(enabled: $enabled, rate: $rate, label: $label, inclusive: $inclusive)';
}
