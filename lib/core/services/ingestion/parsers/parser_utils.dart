part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

String _cellAsString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  return value.toString().trim();
}

bool _cellAsBool(dynamic value) {
  final raw = _cellAsString(value).toLowerCase();
  return raw == 'oui' || raw == '1' || raw == 'true';
}

DateTime? _cellAsDate(dynamic value) => parseBdpmDate(_cellAsString(value));

double? _cellAsDouble(dynamic value) {
  final raw = _cellAsString(value);
  return parseBdpmDouble(raw);
}

double? _parseDecimal(String? raw) {
  if (raw == null) return null;
  var sanitized = raw.replaceAll(' ', '');
  if (sanitized.isEmpty) return null;

  final commaCount = ','.allMatches(sanitized).length;
  if (commaCount > 0) {
    final lastComma = sanitized.lastIndexOf(',');
    final before = sanitized.substring(0, lastComma).replaceAll(',', '');
    final after = sanitized.substring(lastComma + 1);
    sanitized = '$before.$after';
  }

  if (sanitized.isEmpty) return null;
  return double.tryParse(sanitized);
}

DateTime? _parseBdpmDate(String? raw) {
  if (raw == null) return null;
  return parseBdpmDate(raw);
}

String _normalizeSaltPrefix(String label) {
  if (label.isEmpty) return label;

  const saltPattern =
      r'^((?:CHLORHYDRATE|SULFATE|MALEATE|MALÉATE|TARTRATE|BESILATE|BÉSILATE|MESILATE|MÉSILATE|SUCCINATE|FUMARATE|OXALATE|CITRATE|ACETATE|ACÉTATE|LACTATE|VALERATE|VALÉRATE|PROPIONATE|BUTYRATE|PHOSPHATE|NITRATE|BROMHYDRATE)\s+(?:DE\s+|D[\u0027\u2019]))(.+)$';
  final pattern = RegExp(saltPattern, caseSensitive: false);

  final match = pattern.firstMatch(label);
  if (match != null) {
    final molecule = match.group(2)!.trim();
    return _normalizeSaltPrefix(molecule);
  }

  return label;
}

/// Removes salt suffixes (like "Arginine", "Tosilate") from molecule names
/// to extract the base molecule name for grouping purposes.
String _removeSaltSuffixes(String label) {
  if (label.isEmpty) return label;

  var cleaned = _normalizeSaltPrefix(label);

  for (final suffix in ChemicalConstants.saltSuffixes) {
    final suffixPattern = RegExp(
      r'\s+' + RegExp.escape(suffix) + r'(?:\s|$)',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(suffixPattern, ' ').trim();
  }

  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String debugNormalizeSaltPrefix(String label) => _normalizeSaltPrefix(label);

String debugRemoveSaltSuffixes(String label) => _removeSaltSuffixes(label);

(Decimal?, String?) _parseDosage(String dosageStr) {
  if (dosageStr.isEmpty) return (null, null);

  final dosageParts = dosageStr.split(' ');
  if (dosageParts.isEmpty) return (null, null);

  final normalizedValue = dosageParts[0].replaceAll(',', '.');
  final value = Decimal.tryParse(normalizedValue);
  if (dosageParts.length == 1) {
    return (value, null);
  }

  final unit = dosageParts.sublist(1).join(' ');
  return (value, unit.isEmpty ? null : unit);
}

({String title, String subtitle, String method}) _smartSplitLabel(
  String rawLabel,
) {
  var clean = rawLabel.replaceAll('\u00a0', ' ');
  for (final dash in ['–', '—', '−', '‑', '‒', '―', '']) {
    clean = clean.replaceAll(dash, '-');
  }

  clean = clean.replaceAllMapped(
    RegExp(r'(?<=[a-zA-Z0-9%)])\s*-\s*(?=[A-Z])'),
    (_) => ' - ',
  );
  clean = clean.replaceAllMapped(
    RegExp(r'\s+-(?=[A-Z])'),
    (_) => ' - ',
  );
  clean = clean.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  if (clean.contains(' - ')) {
    final parts = clean.split(' - ');
    final subtitle = parts.last.trim();
    final title = parts.sublist(0, parts.length - 1).join(' - ').trim();
    return (
      title: title,
      subtitle: subtitle.isEmpty ? Strings.unknownReference : subtitle,
      method: 'text_smart_split',
    );
  }

  return (
    title: clean,
    subtitle: Strings.unknownReference,
    method: 'fallback',
  );
}
