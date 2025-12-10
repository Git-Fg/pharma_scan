import 'package:decimal/decimal.dart';

DateTime? parseBdpmDate(String raw) {
  if (raw.isEmpty) return null;
  final parts = raw.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime.utc(year, month, day);
}

double? parseBdpmDouble(String raw) {
  if (raw.isEmpty) return null;
  final normalized = raw.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  try {
    return double.tryParse(normalized);
  } on Exception {
    return null;
  }
}

Decimal? parseBdpmDecimal(String raw) {
  if (raw.isEmpty) return null;
  final normalized = raw.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  try {
    return Decimal.tryParse(normalized);
  } on Exception {
    return null;
  }
}

bool parseBdpmBool(String raw) {
  final lower = raw.trim().toLowerCase();
  return lower == 'oui' || lower == '1' || lower == 'true';
}
