import 'dart:convert';

import 'package:drift/drift.dart';

/// TypeConverter for List<String> to JSON String
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}

/// Helpers pour convertir les types String? retournés par les vues Drift
/// vers les types Dart attendus (bool, int, double).
///
/// Les vues Drift retournent souvent des String? pour les booléens et nombres
/// car SQLite stocke tout comme texte dans certaines vues.
class ViewTypeConverters {
  /// Convertit un String? en bool
  /// Accepte '1', 'true' (case-insensitive) comme true, sinon false
  static bool toBool(String? value) {
    if (value == null) return false;
    final normalized = value.trim().toLowerCase();
    return normalized == '1' || normalized == 'true';
  }

  /// Convertit un String? en int, retourne null si invalide
  static int? toInt(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value.trim());
  }

  /// Convertit un String? en double, retourne null si invalide
  static double? toDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value.trim());
  }

  /// Convertit un String? en int avec une valeur par défaut
  static int toIntOrDefault(String? value, int defaultValue) {
    return toInt(value) ?? defaultValue;
  }

  /// Convertit un String? en double avec une valeur par défaut
  static double toDoubleOrDefault(String? value, double defaultValue) {
    return toDouble(value) ?? defaultValue;
  }
}
