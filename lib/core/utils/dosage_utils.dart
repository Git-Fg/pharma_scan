import 'package:decimal/decimal.dart';

Decimal? parseDecimalValue(String? raw) {
  if (raw == null) return null;
  final normalized = raw.trim();
  if (normalized.isEmpty) return null;
  return Decimal.tryParse(normalized);
}

String formatDecimal(Decimal value) {
  final raw = value.toString();
  if (!raw.contains('.')) return raw;

  var trimmed = raw;
  trimmed = trimmed.replaceFirst(RegExp(r'0+$'), '');
  if (trimmed.endsWith('.')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}
