// lib/core/utils/gs1_parser.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'gs1_parser.freezed.dart';

@freezed
abstract class Gs1DataMatrix with _$Gs1DataMatrix {
  const factory Gs1DataMatrix({
    String? gtin, // AI (01) -> Code CIP
    String? serial, // AI (21)
    String? lot, // AI (10)
    DateTime? expDate, // AI (17)
  }) = _Gs1DataMatrix;
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
    String normalized = rawValue.replaceAll(
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
    int i = 0;
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
            // WHY: The database uses 13-digit CIPs. The GTIN-14 is often a
            // 13-digit EAN with a leading packaging indicator (usually '0').
            // We strip this leader to match the database key.
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
          break;
        case '17': // Date de péremption - 6 chiffres fixes
          if (i + 6 <= normalized.length) {
            expDate = _parseExpiry(normalized.substring(i, i + 6));
            i += 6;
            // Sauter le séparateur s'il est présent
            if (i < normalized.length && normalized[i] == _internalSeparator) {
              i++;
            }
          }
          break;
        case '10': // Lot - longueur variable, se termine au prochain AI ou séparateur
          final lotEnd = _findFieldEnd(normalized, i);
          lot = normalized.substring(i, lotEnd);
          i = lotEnd;
          // Sauter le séparateur s'il est présent
          if (i < normalized.length && normalized[i] == _internalSeparator) {
            i++;
          }
          break;
        case '21': // Numéro de série - longueur variable, se termine au prochain AI ou séparateur
          final serialEnd = _findFieldEnd(normalized, i);
          serial = normalized.substring(i, serialEnd);
          i = serialEnd;
          // Sauter le séparateur s'il est présent
          if (i < normalized.length && normalized[i] == _internalSeparator) {
            i++;
          }
          break;
        default:
          // Ignorer les AI inconnus en cherchant le prochain AI ou séparateur
          final nextPos = _findFieldEnd(normalized, i);
          i = nextPos;
          if (i < normalized.length && normalized[i] == _internalSeparator) {
            i++;
          }
          break;
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
    for (int i = startIndex; i < data.length - 1; i++) {
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
    } catch (_) {
      return null;
    }
  }
}
