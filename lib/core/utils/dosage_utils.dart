import 'package:decimal/decimal.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

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

extension MedicamentDosageX on Medicament {
  String? get formattedDosage {
    final value = dosage;
    final unit = dosageUnit.trim();
    final hasUnit = unit.isNotEmpty;

    if (value == null && !hasUnit) return null;
    if (value == null) return unit;

    final formattedValue = formatDecimal(value);
    return hasUnit ? '$formattedValue $unit' : formattedValue;
  }
}
