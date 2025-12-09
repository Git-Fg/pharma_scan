/// Formats a numeric value as `xx,xx €` using French separators.
String formatEuro(double value) {
  final fixed = value.toStringAsFixed(2);
  final normalized = fixed.replaceAll('.', ',');
  return '$normalized €';
}
