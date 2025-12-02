import 'package:dart_mappable/dart_mappable.dart';

part 'gs1_parser.mapper.dart';

@MappableClass()
class Gs1DataMatrix with Gs1DataMatrixMappable {
  const Gs1DataMatrix({
    this.gtin, // AI (01) -> Code CIP
    this.serial, // AI (21)
    this.lot, // AI (10)
    this.expDate, // AI (17)
  });

  final String? gtin;
  final String? serial;
  final String? lot;
  final DateTime? expDate;
}

class Gs1Parser {
  static const String _internalSeparator = '|';

  static Gs1DataMatrix parse(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return const Gs1DataMatrix();
    }

    var normalized = rawValue.replaceAll(
      RegExp(r'[\s\x1D]'),
      _internalSeparator,
    );

    normalized = normalized.replaceAll(RegExp(r'\|+'), _internalSeparator);
    normalized = normalized.replaceAll(RegExp(r'^\|+|\|+$'), '');

    String? gtin;
    String? serial;
    String? lot;
    DateTime? expDate;

    var i = 0;
    while (i < normalized.length) {
      if (normalized[i] == _internalSeparator) {
        i++;
        continue;
      }

      if (i + 2 > normalized.length) break;

      final ai = normalized.substring(i, i + 2);
      i += 2;

      switch (ai) {
        case '01':
          if (i + 14 <= normalized.length) {
            final rawGtin = normalized.substring(i, i + 14);
            if (rawGtin.length == 14) {
              gtin = rawGtin.substring(1);
            } else {
              gtin = rawGtin;
            }
            i += 14;
            if (i < normalized.length && normalized[i] == _internalSeparator) {
              i++;
            }
          }
        case '17':
          if (i + 6 <= normalized.length) {
            expDate = _parseExpiry(normalized.substring(i, i + 6));
            i += 6;
            if (i < normalized.length && normalized[i] == _internalSeparator) {
              i++;
            }
          }
        case '10':
          final lotEnd = _findFieldEnd(normalized, i);
          lot = normalized.substring(i, lotEnd);
          i = lotEnd;
          if (i < normalized.length && normalized[i] == _internalSeparator) {
            i++;
          }
        case '21':
          final serialEnd = _findFieldEnd(normalized, i);
          serial = normalized.substring(i, serialEnd);
          i = serialEnd;
          if (i < normalized.length && normalized[i] == _internalSeparator) {
            i++;
          }
        default:
          final nextPos = _findFieldEnd(normalized, i);
          i = nextPos;
          if (i < normalized.length && normalized[i] == _internalSeparator) {
            i++;
          }
      }
    }

    return Gs1DataMatrix(
      gtin: gtin,
      serial: serial,
      lot: lot,
      expDate: expDate,
    );
  }

  static int _findFieldEnd(String data, int startIndex) {
    final separatorIndex = data.indexOf(_internalSeparator, startIndex);
    if (separatorIndex != -1) {
      return separatorIndex;
    }

    final knownAIs = ['01', '10', '17', '21'];
    for (var i = startIndex; i < data.length - 1; i++) {
      final potentialAI = data.substring(i, i + 2);
      if (knownAIs.contains(potentialAI)) {
        return i;
      }
    }
    return data.length;
  }

  static DateTime? _parseExpiry(String exp) {
    if (exp.length != 6) return null;
    try {
      final yy = int.parse(exp.substring(0, 2));
      final mm = int.parse(exp.substring(2, 4));
      final dd = int.parse(exp.substring(4, 6));
      final year = yy < 50 ? 2000 + yy : 1900 + yy;
      return DateTime.utc(year, mm, dd);
    } on Exception catch (_) {
      return null;
    }
  }
}
