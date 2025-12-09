import 'package:decimal/decimal.dart';

/// Low-level parsing helpers for ANSM TSV files (French locale quirks).
mixin BdpmRowParser {
  /// Parses a TSV row with a single mapper.
  ///
  /// - Skips empty lines
  /// - Validates [expectedColumns] length
  /// - Trims all columns
  /// - Returns `null` when invalid or mapping fails
  T? parseRow<T>(
    String line,
    int expectedColumns,
    T Function(List<String> cols) mapper,
  ) {
    final cols = splitLine(line, expectedColumns);
    if (cols.isEmpty) return null;
    try {
      return mapper(cols);
    } on Exception {
      return null;
    }
  }

  /// Splits a TSV line and ensures the expected column count.
  /// Returns an empty list for invalid lines.
  List<String> splitLine(String line, int expectedColumns) {
    if (line.trim().isEmpty) return const [];
    final parts = line.split('\t');
    if (parts.length < expectedColumns) return const [];
    return parts.map((e) => e.trim()).toList();
  }

  DateTime? parseDate(String raw) => parseBdpmDate(raw);

  double? parseDouble(String raw) {
    if (raw.isEmpty) return null;
    final normalized = raw.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Decimal? parseDecimal(String raw) {
    if (raw.isEmpty) return null;
    final normalized = raw.replaceAll(' ', '').replaceAll(',', '.');
    return Decimal.tryParse(normalized);
  }

  bool parseBool(String raw) => raw.toLowerCase() == 'oui';

  String parseString(String raw) => raw.trim();
}

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
