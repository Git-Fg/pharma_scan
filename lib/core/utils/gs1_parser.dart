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

class Gs1Parser {
  static const String _internalSeparator = '|';
  static const List<String> _knownAIs = ['01', '10', '11', '17', '21'];

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
    DateTime? manufacturingDate;

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
        case '11':
          if (i + 6 <= normalized.length) {
            manufacturingDate = _parseExpiry(normalized.substring(i, i + 6));
            i += 6;
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
          final separatorIndex = normalized.indexOf(_internalSeparator, i);
          var nextPos =
              separatorIndex != -1 ? separatorIndex : normalized.length;
          for (var j = i; j < normalized.length - 1; j++) {
            final potentialAI = normalized.substring(j, j + 2);
            if (_knownAIs.contains(potentialAI)) {
              nextPos = j;
              break;
            }
          }
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
      manufacturingDate: manufacturingDate,
    );
  }

  static int _findFieldEnd(String data, int startIndex) {
    final separatorIndex = data.indexOf(_internalSeparator, startIndex);
    if (separatorIndex != -1) {
      return separatorIndex;
    }

    return data.length;
  }

  static DateTime? _parseExpiry(String exp) {
    if (exp.length != 6) return null;
    final yy = int.tryParse(exp.substring(0, 2));
    final mm = int.tryParse(exp.substring(2, 4));
    final ddRaw = int.tryParse(exp.substring(4, 6));
    if (yy == null || mm == null || ddRaw == null) return null;
    if (mm < 1 || mm > 12 || ddRaw < 0 || ddRaw > 31) return null;

    final year = yy < 50 ? 2000 + yy : 1900 + yy;

    var day = ddRaw;
    if (day == 0) {
      day = DateTime.utc(year, mm + 1, 0).day;
    }

    return DateTime.utc(year, mm, day);
  }
}
