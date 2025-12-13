import 'package:petitparser/petitparser.dart';

/// Result of parsing a GS1 DataMatrix barcode.
class Gs1DataMatrix {
  const Gs1DataMatrix({
    this.gtin, // AI (01) -> Code CIP
    this.serial, // AI (21)
    this.lot, // AI (10)
    this.expDate, // AI (17)
    this.manufacturingDate, // AI (11)
  });

  final String? gtin;
  final String? serial;
  final String? lot;
  final DateTime? expDate;
  final DateTime? manufacturingDate;
}

/// Declarative GS1 DataMatrix parser using petitparser grammar.
///
/// Supports the following Application Identifiers (AIs):
/// - 01: GTIN (14 digits, fixed length)
/// - 10: Batch/Lot number (variable length)
/// - 11: Manufacturing date (6 digits YYMMDD)
/// - 17: Expiration date (6 digits YYMMDD)
/// - 21: Serial number (variable length)
class Gs1Parser {
  Gs1Parser._();

  // FNC1 separator (Group Separator character)
  static final _fnc1 = char('\x1D');

  // End condition for variable-length fields: FNC1, known AI, or end of input
  static Parser<void> _fieldTerminator() {
    return _fnc1 | _knownAiLookahead() | endOfInput();
  }

  // Lookahead for known AI codes (doesn't consume input)
  static Parser<void> _knownAiLookahead() {
    return (string('01') |
            string('10') |
            string('11') |
            string('17') |
            string('21'))
        .and();
  }

  // AI 01: GTIN (14 fixed digits)
  static final _gtinParser = (string('01') & digit().repeat(14).flatten())
      .map((values) => {'ai': '01', 'value': values[1] as String});

  // AI 17: Expiration date (6 fixed digits YYMMDD)
  static final _expDateParser = (string('17') & digit().repeat(6).flatten())
      .map((values) => {'ai': '17', 'value': values[1] as String});

  // AI 11: Manufacturing date (6 fixed digits YYMMDD)
  static final _mfgDateParser = (string('11') & digit().repeat(6).flatten())
      .map((values) => {'ai': '11', 'value': values[1] as String});

  // AI 10: Lot/Batch number (variable length, up to 20 chars)
  static Parser<Map<String, String>> _lotParser() {
    return (string('10') & any().starLazy(_fieldTerminator()).flatten())
        .map((values) => {'ai': '10', 'value': values[1] as String});
  }

  // AI 21: Serial number (variable length, up to 20 chars)
  static Parser<Map<String, String>> _serialParser() {
    return (string('21') & any().starLazy(_fieldTerminator()).flatten())
        .map((values) => {'ai': '21', 'value': values[1] as String});
  }

  // Single GS1 field (any supported AI)
  static Parser<Map<String, String>> _gs1Field() {
    return _gtinParser |
        _expDateParser |
        _mfgDateParser |
        _lotParser() |
        _serialParser();
  }

  // Skip unknown AI fields (2-digit AI + variable content until next known AI or separator)
  static Parser<void> _unknownField() {
    return (digit().repeat(2) & any().starLazy(_fieldTerminator()))
        .map((_) => null);
  }

  // Complete GS1 grammar: sequence of fields separated by optional FNC1
  static Parser<List<Map<String, String>>> _gs1Grammar() {
    final field = _gs1Field() | _unknownField().map((_) => <String, String>{});
    return (_fnc1.optional() & field)
        .separatedBy<dynamic>(_fnc1.optional())
        .map((results) {
      final fields = <Map<String, String>>[];
      for (final item in results) {
        if (item is List &&
            item.length >= 2 &&
            item[1] is Map<String, String>) {
          final map = item[1] as Map<String, String>;
          if (map.isNotEmpty) fields.add(map);
        } else if (item is Map<String, String> && item.isNotEmpty) {
          fields.add(item);
        }
      }
      return fields;
    });
  }

  /// Parse a GS1 DataMatrix barcode string.
  ///
  /// Returns a [Gs1DataMatrix] with all successfully parsed fields.
  /// Unknown or malformed data is gracefully ignored.
  static Gs1DataMatrix parse(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return const Gs1DataMatrix();
    }

    // Normalize: replace whitespace with FNC1
    final normalized = rawValue.replaceAll(RegExp(r'\s'), '\x1D');

    final result = _gs1Grammar().parse(normalized);

    if (result is Failure) {
      return const Gs1DataMatrix();
    }

    String? gtin;
    String? serial;
    String? lot;
    DateTime? expDate;
    DateTime? manufacturingDate;

    for (final field in result.value) {
      final ai = field['ai'];
      final value = field['value'];
      if (value == null || value.isEmpty) continue;

      switch (ai) {
        case '01':
          // GTIN: strip leading zero if 14 digits (CIP-13 format)
          gtin = value.length == 14 ? value.substring(1) : value;
        case '10':
          lot = value;
        case '11':
          manufacturingDate = _parseDate(value);
        case '17':
          expDate = _parseDate(value);
        case '21':
          serial = value;
      }
    }

    return Gs1DataMatrix(
      gtin: gtin,
      serial: serial,
      lot: lot,
      expDate: expDate,
      manufacturingDate: manufacturingDate,
    );
  }

  /// Parse a 6-digit YYMMDD date string.
  static DateTime? _parseDate(String dateStr) {
    if (dateStr.length != 6) return null;

    final yy = int.tryParse(dateStr.substring(0, 2));
    final mm = int.tryParse(dateStr.substring(2, 4));
    final ddRaw = int.tryParse(dateStr.substring(4, 6));

    if (yy == null || mm == null || ddRaw == null) return null;
    if (mm < 1 || mm > 12 || ddRaw < 0 || ddRaw > 31) return null;

    // Y2K pivot: years 00-49 -> 2000-2049, 50-99 -> 1950-1999
    final year = yy < 50 ? 2000 + yy : 1900 + yy;

    // Day 00 means "last day of month"
    var day = ddRaw;
    if (day == 0) {
      day = DateTime.utc(year, mm + 1, 0).day;
    }

    return DateTime.utc(year, mm, day);
  }
}
