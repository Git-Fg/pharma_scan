
/// Formats a price value as a Euro string with French locale formatting.
///
/// Centralized formatting utilities for the PharmaScan app.
///
/// Example:
/// - `12.50` → `"12,50 €"`
/// - `0.99` → `"0,99 €"`
/// - `100.0` → `"100,00 €"`
String formatEuro(double value) {
  final fixed = value.toStringAsFixed(2);
  final normalized = fixed.replaceAll('.', ',');
  return '$normalized €';
}
