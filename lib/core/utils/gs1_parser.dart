import 'package:petitparser/petitparser.dart';
import 'package:pharma_scan/core/utils/cip_utils.dart';

/// Result of parsing a GS1 DataMatrix barcode.
class Gs1DataMatrix {
  const Gs1DataMatrix({
    this.gtin, // AI (01) -> Code CIP
    this.cip7,
    this.serial, // AI (21)
    this.lot, // AI (10)
    this.expDate, // AI (17)
    this.manufacturingDate, // AI (11)
  });

  final String? gtin;
  final String? cip7;
  final String? serial;
  final String? lot;
  final DateTime? expDate;
  final DateTime? manufacturingDate;
}

/// GS1 field parsed from a barcode.
class _Gs1Field {
  const _Gs1Field(this.ai, this.value);
  final String ai;
  final String value;
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

  // AI 01: GTIN (14 fixed digits)
  static final _gtinParser = (string('01') & digit().repeat(14).flatten())
      .map((values) => _Gs1Field('01', values[1] as String));

  // AI 17: Expiration date (6 fixed digits YYMMDD)
  static final _expDateParser = (string('17') & digit().repeat(6).flatten())
      .map((values) => _Gs1Field('17', values[1] as String));

  // AI 11: Manufacturing date (6 fixed digits YYMMDD)
  static final _mfgDateParser = (string('11') & digit().repeat(6).flatten())
      .map((values) => _Gs1Field('11', values[1] as String));

  // Variable-length field content: stop only at FNC1 or end of input
  // Known AIs within content (like "01" in "SERIAL001") should NOT stop parsing
  // AI boundaries only matter when preceded by FNC1 or at start
  static Parser<String> _variableContent() {
    // Variable fields end at FNC1 or end of input only
    // The grammar structure ensures we don't consume next AI because
    // fixed-length AIs self-terminate by length, and variable AIs are
    // always at the end or followed by FNC1 per GS1 spec
    return any().starLazy(_fnc1 | endOfInput()).flatten();
  }

  // AI 10: Lot/Batch number (variable length)
  static Parser<_Gs1Field> _lotParser() {
    return (string('10') & _variableContent())
        .map((values) => _Gs1Field('10', values[1] as String));
  }

  // AI 21: Serial number (variable length)
  static Parser<_Gs1Field> _serialParser() {
    return (string('21') & _variableContent())
        .map((values) => _Gs1Field('21', values[1] as String));
  }

  // Single GS1 field (any supported AI)
  // Order matters: fixed-length AIs first, then variable-length
  static Parser<_Gs1Field?> _gs1Field() {
    // Try fixed-length AIs first (they are self-delimiting by length)
    // Then try variable-length AIs (which consume until FNC1/end)
    return (_gtinParser |
            _mfgDateParser |
            _expDateParser |
            _lotParser() |
            _serialParser())
        .cast<_Gs1Field>();
  }

  // Skip FNC1 separators
  static Parser<void> _skipFnc1() {
    return _fnc1.star().map((_) {});
  }

  // Full GS1 grammar: sequence of fields with optional FNC1 separators
  static Parser<List<_Gs1Field>> _gs1Grammar() {
    final fieldWithSeparator = (_skipFnc1() & _gs1Field() & _skipFnc1())
        .map((values) => values[1] as _Gs1Field);

    return fieldWithSeparator.star();
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
      final value = field.value;
      if (value.isEmpty) continue;

      switch (field.ai) {
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
      cip7: CipUtils.extractCip7(gtin),
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
