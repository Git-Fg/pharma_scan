// lib/core/utils/gs1_parser.dart
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
  // On définit notre propre séparateur interne pour la simplicité.
  static const String _internalSeparator = '|';

  static Gs1DataMatrix parse(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return const Gs1DataMatrix();
    }

    // --- ÉTAPE DE NORMALISATION ---
    // Remplace les caractères de contrôle (comme FNC1/GS) et les espaces
    // qui pourraient être utilisés comme séparateurs par notre séparateur interne.
    // Le \x1D est la représentation hexadécimale de l'ASCII 29 (FNC1/GS).
    var normalized = rawValue.replaceAll(
      RegExp(r'[\s\x1D]'),
      _internalSeparator,
    );

    // Supprime les séparateurs multiples pour éviter les champs vides.
    normalized = normalized.replaceAll(RegExp(r'\|+'), _internalSeparator);

    // Ignorer les séparateurs au début et à la fin
    normalized = normalized.replaceAll(RegExp(r'^\|+|\|+$'), '');

    String? gtin;
    String? serial;
    String? lot;
    DateTime? expDate;

    // Parser directement en cherchant les AI dans la chaîne normalisée
    // Cette approche fonctionne avec ou sans séparateurs
    var i = 0;
    while (i < normalized.length) {
      // Ignorer les séparateurs
      if (normalized[i] == _internalSeparator) {
        i++;
        continue;
      }

      if (i + 2 > normalized.length) break;

      final ai = normalized.substring(i, i + 2);
      i += 2;

      switch (ai) {
        case '01': // GTIN (Code CIP) - 14 chiffres fixes
          if (i + 14 <= normalized.length) {
            final rawGtin = normalized.substring(i, i + 14);
            if (rawGtin.length == 14) {
              gtin = rawGtin.substring(1);
            } else {
              gtin = rawGtin;
            }
            i += 14;
            // Sauter le séparateur s'il est présent
            if (i < normalized.length && normalized[i] == _internalSeparator) {
              i++;
            }
          }
        case '17': // Date de péremption - 6 chiffres fixes
          if (i + 6 <= normalized.length) {
            expDate = _parseExpiry(normalized.substring(i, i + 6));
            i += 6;
            // Sauter le séparateur s'il est présent
            if (i < normalized.length && normalized[i] == _internalSeparator) {
              i++;
            }
          }
        case '10': // Lot - longueur variable, se termine au prochain AI ou séparateur
          final lotEnd = _findFieldEnd(normalized, i);
          lot = normalized.substring(i, lotEnd);
          i = lotEnd;
          // Sauter le séparateur s'il est présent
          if (i < normalized.length && normalized[i] == _internalSeparator) {
            i++;
          }
        case '21': // Numéro de série - longueur variable, se termine au prochain AI ou séparateur
          final serialEnd = _findFieldEnd(normalized, i);
          serial = normalized.substring(i, serialEnd);
          i = serialEnd;
          // Sauter le séparateur s'il est présent
          if (i < normalized.length && normalized[i] == _internalSeparator) {
            i++;
          }
        default:
          // Ignorer les AI inconnus en cherchant le prochain AI ou séparateur
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
    // Chercher d'abord un séparateur
    final separatorIndex = data.indexOf(_internalSeparator, startIndex);
    if (separatorIndex != -1) {
      return separatorIndex;
    }

    // Si pas de séparateur, chercher le prochain AI (01, 10, 17, 21) dans la chaîne
    final knownAIs = ['01', '10', '17', '21'];
    for (var i = startIndex; i < data.length - 1; i++) {
      final potentialAI = data.substring(i, i + 2);
      if (knownAIs.contains(potentialAI)) {
        return i;
      }
    }
    return data.length; // Fin de la chaîne
  }

  static DateTime? _parseExpiry(String exp) {
    if (exp.length != 6) return null;
    try {
      final yy = int.parse(exp.substring(0, 2));
      final mm = int.parse(exp.substring(2, 4));
      final dd = int.parse(exp.substring(4, 6));
      // Logique simple pour gérer le siècle.
      final year = yy < 50 ? 2000 + yy : 1900 + yy;
      return DateTime.utc(year, mm, dd);
    } on Object catch (_) {
      return null;
    }
  }
}
