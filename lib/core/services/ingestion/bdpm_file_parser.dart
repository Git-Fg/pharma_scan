// lib/core/services/ingestion/bdpm_file_parser.dart
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:fpdart/fpdart.dart';

/// Parse error types for functional error handling
sealed class ParseError {
  const ParseError();
}

class EmptyContentError extends ParseError {
  const EmptyContentError(this.fileName);
  final String fileName;
}

class InvalidFormatError extends ParseError {
  const InvalidFormatError(this.fileName, this.details);
  final String fileName;
  final String details;
}

/// WHY: BDPM file parser with static methods for parsing BDPM data files.
/// Separates parsing logic from service orchestration for better testability and reusability.
/// Uses fpdart Either for Railway Oriented Programming - explicit error handling without exceptions.
class BdpmFileParser {
  BdpmFileParser._(); // Private constructor to prevent instantiation

  // WHY: Parse BDPM specialites file and return structured data.
  // Allows every form and filters only on BOIRON noise.
  // Returns Either for Railway Oriented Programming - explicit error handling.
  static Either<ParseError, SpecialitesParseResult> parseSpecialites(
    String? content,
    Map<String, String> conditionsByCis,
    Map<String, String> mitmMap,
  ) {
    final specialites = <Map<String, dynamic>>[];
    final namesByCis = <String, String>{};
    final seenCis = <String>{};

    if (content == null || content.isEmpty) {
      return const Left(EmptyContentError('specialites'));
    }

    for (final line in content.split('\n')) {
      final parts = line.split('\t');
      switch (parts) {
        case [
          final cisRaw,
          final nomRaw,
          final formeRaw,
          final voiesRaw,
          final statutRaw,
          final procRaw,
          final commRaw,
          _,
          _,
          _,
          final titulaireRaw,
          final survRaw,
          ...,
        ]:
          final cis = cisRaw.trim();
          final nom = nomRaw.trim();
          final forme = formeRaw.trim();
          final voies = voiesRaw.trim();
          final statutAdministratif = statutRaw.trim();
          final procedure = procRaw.trim();
          final commercialisation = commRaw.trim();
          final titulaire = titulaireRaw.trim();
          final surveillanceRaw = survRaw.trim();
          final isSurveillance = surveillanceRaw.toLowerCase() == 'oui';

          // WHY: BOIRON floods BDPM with homeopathic granules/doses that are not useful
          // in PharmaScan. Skip them explicitly to keep the dataset lean while still
          // allowing every other form to flow through.
          if (titulaire.toUpperCase().contains('BOIRON')) {
            continue;
          }

          if (cis.isNotEmpty && nom.isNotEmpty && seenCis.add(cis)) {
            final record = {
              'cis_code': cis,
              'nom_specialite': nom,
              'statut_administratif': statutAdministratif,
              'procedure_type': procedure,
              'forme_pharmaceutique': forme,
              'voies_administration': voies,
              'etat_commercialisation': commercialisation,
              'titulaire': titulaire,
              'conditions_prescription': conditionsByCis[cis],
              'atc_code': mitmMap[cis],
              'is_surveillance': isSurveillance,
            };
            specialites.add(record);
            namesByCis[cis] = nom;
          }
        default:
          continue;
      }
    }

    return Right((
      specialites: specialites,
      namesByCis: namesByCis,
      seenCis: seenCis,
    ));
  }

  // WHY: Parse BDPM medicaments file and return structured data.
  // Returns Either for Railway Oriented Programming.
  static Either<ParseError, MedicamentsParseResult> parseMedicaments(
    String? content,
    SpecialitesParseResult specialitesResult,
  ) {
    final cisToCip13 = <String, List<String>>{};
    final medicaments = <Map<String, dynamic>>[];
    final medicamentCips = <String>{};
    final seenCis = specialitesResult.seenCis;
    final namesByCis = specialitesResult.namesByCis;

    if (content == null || content.isEmpty) {
      return const Left(EmptyContentError('medicaments'));
    }

    for (final line in content.split('\n')) {
      final parts = line.split('\t');
      switch (parts) {
        case [
          final cisRaw,
          _,
          final presentationLabelRaw,
          _,
          final statusRaw,
          _,
          final cip13Raw,
          final agrementRaw,
          final refundRateRaw,
          final priceRaw,
          ...,
        ]:
          final cis = cisRaw.trim();
          final cip13 = cip13Raw.trim();
          final correctName = namesByCis[cis];
          final status = statusRaw.trim().isEmpty ? null : statusRaw.trim();
          final agrement = agrementRaw.trim().isEmpty
              ? null
              : agrementRaw.trim().toLowerCase();
          final parsedPrice = _parseDecimal(
            priceRaw.trim().isEmpty ? null : priceRaw.trim(),
          );

          if (cis.isNotEmpty &&
              cip13.isNotEmpty &&
              correctName != null &&
              seenCis.contains(cis)) {
            cisToCip13.putIfAbsent(cis, () => []).add(cip13);

            if (medicamentCips.add(cip13)) {
              medicaments.add({
                'code_cip': cip13,
                'cis_code': cis,
                'presentation_label': presentationLabelRaw.trim().isEmpty
                    ? null
                    : presentationLabelRaw.trim(),
                'commercialisation_statut': status,
                'taux_remboursement': refundRateRaw.trim().isEmpty
                    ? null
                    : refundRateRaw.trim(),
                'prix_public': parsedPrice,
                'agrement_collectivites': agrement,
              });
            }
          }
        default:
          continue;
      }
    }

    return Right((
      medicaments: medicaments,
      cisToCip13: cisToCip13,
      medicamentCips: medicamentCips,
    ));
  }

  // WHY: Parse BDPM compositions file and extract active principles with dosages.
  // Returns Either for Railway Oriented Programming.
  static Either<ParseError, List<Map<String, dynamic>>> parseCompositions(
    String? content,
    Map<String, List<String>> cisToCip13,
  ) {
    final principes = <Map<String, dynamic>>[];

    if (content == null || content.isEmpty) {
      return Right(principes);
    }

    final rowsByKey = <String, _CompositionGroup>{};

    for (final line in content.split('\n')) {
      final parts = line.split('\t');
      if (parts.length < 8) continue;

      final cis = parts[0].trim();
      final denomination = parts[3].trim();
      final dosageRaw = parts[4].trim();
      final nature = parts[6].trim().toUpperCase();
      final linkId = parts.length > 7 ? parts[7].trim() : '';

      if (cis.isEmpty || denomination.isEmpty) continue;
      if (!cisToCip13.containsKey(cis)) continue;

      final row = _CompositionRow(
        cis: cis,
        denomination: denomination,
        dosage: dosageRaw,
      );
      final key = '${cis}_$linkId';
      final group = rowsByKey.putIfAbsent(key, _CompositionGroup.new);

      if (nature == 'FT') {
        group.ftRow = row;
      } else if (nature == 'SA') {
        group.saRows.add(row);
      }
    }

    for (final group in rowsByKey.values) {
      final rowsToUse = group.ftRow != null ? [group.ftRow!] : group.saRows;
      for (final row in rowsToUse) {
        final cip13s = cisToCip13[row.cis];
        if (cip13s == null) continue;

        final (dosageValue, dosageUnit) = _parseDosage(row.dosage);

        for (final cip13 in cip13s) {
          principes.add({
            'code_cip': cip13,
            'principe': row.denomination,
            'dosage': dosageValue?.toString(),
            'dosage_unit': dosageUnit,
          });
        }
      }
    }

    return Right(principes);
  }

  // WHY: Parse BDPM generiques file and return group data.
  // Returns Either for Railway Oriented Programming.
  static Either<ParseError, GeneriquesParseResult> parseGeneriques(
    String? content,
    Map<String, List<String>> cisToCip13,
    Set<String> medicamentCips,
  ) {
    final generiqueGroups = <Map<String, dynamic>>[];
    final groupMembers = <Map<String, dynamic>>[];
    final seenGroups = <String>{};

    if (content == null || content.isEmpty) {
      return Right((
        generiqueGroups: generiqueGroups,
        groupMembers: groupMembers,
      ));
    }

    for (final line in content.split('\n')) {
      final parts = line.split('\t');
      switch (parts) {
        case [
          final groupIdRaw,
          final libelleRaw,
          final cisRaw,
          final typeRaw,
          ...,
        ]:
          final groupId = groupIdRaw.trim();
          final libelle = libelleRaw.trim();
          final cis = cisRaw.trim();
          final type = int.tryParse(typeRaw.trim());
          final cip13s = cisToCip13[cis];
          final isPrinceps = type == 0;
          final isGeneric = type == 1 || type == 2 || type == 4;

          if (cip13s != null && (isPrinceps || isGeneric)) {
            if (seenGroups.add(groupId)) {
              generiqueGroups.add({'group_id': groupId, 'libelle': libelle});
            }

            for (final cip13 in cip13s) {
              if (medicamentCips.contains(cip13)) {
                groupMembers.add({
                  'code_cip': cip13,
                  'group_id': groupId,
                  'type': isPrinceps ? 0 : 1,
                });
              }
            }
          }
        default:
          continue;
      }
    }

    return Right((
      generiqueGroups: generiqueGroups,
      groupMembers: groupMembers,
    ));
  }

  // WHY: Parse BDPM conditions file and return CIS-to-condition mapping.
  static Map<String, String> parseConditions(String? content) {
    final conditions = <String, String>{};

    if (content == null) return conditions;

    for (final line in content.split('\n')) {
      final parts = line.split('\t');
      if (parts.length >= 2) {
        final cis = parts[0].trim();
        final condition = parts[1].trim();
        if (cis.isNotEmpty && condition.isNotEmpty) {
          conditions[cis] = condition;
        }
      }
    }

    return conditions;
  }

  static ({
    bool isHospitalOnly,
    bool isDental,
    bool isList1,
    bool isList2,
    bool isNarcotic,
    bool isException,
    bool isRestricted,
    bool isSurveillance,
    bool isOtc,
  })
  parseRegulatoryFlags(String? conditionText) {
    final normalized = _normalizeConditionText(conditionText);
    final hasHospital =
        normalized.contains('HOSPITALIER') ||
        normalized.contains('PHARMACIES A USAGE INTERIEUR') ||
        normalized.contains('DELIVRANCE RESERVEE AUX ETS');
    final hasDental = normalized.contains('DENTAIRE');
    final hasList2 = normalized.contains('LISTE II');
    final hasList1 = normalized.contains('LISTE I') && !hasList2;
    final hasNarcotic = normalized.contains('STUPEFIANT');
    final hasException =
        normalized.contains('EXCEPTION') ||
        normalized.contains('ORDONNANCE SECURISEE');
    final hasRestricted =
        normalized.contains('PRESCRIPTION HOSPITALIERE') ||
        normalized.contains('PRESCRIPTION INITIALE HOSPITALIERE') ||
        normalized.contains('RESERVEE AUX SPECIALISTES');
    final hasSurveillance =
        normalized.contains('SURVEILLANCE PARTICULIERE') ||
        normalized.contains('CARNET DE SUIVI') ||
        normalized.contains('GROSSESSE');
    final hasAny =
        hasHospital ||
        hasDental ||
        hasList1 ||
        hasList2 ||
        hasNarcotic ||
        hasException ||
        hasRestricted;
    final isOtc = normalized.isEmpty ? true : !hasAny;
    return (
      isHospitalOnly: hasHospital,
      isDental: hasDental,
      isList1: hasList1,
      isList2: hasList2,
      isNarcotic: hasNarcotic,
      isException: hasException,
      isRestricted: hasRestricted,
      isSurveillance: hasSurveillance,
      isOtc: isOtc,
    );
  }

  // WHY: Parse BDPM MITM file and return CIS-to-ATC mapping.
  static Map<String, String> parseMitm(String? content) {
    final mitmMap = <String, String>{};
    if (content == null) return mitmMap;

    for (final line in content.split('\n')) {
      final parts = line.split('\t');
      if (parts.length >= 2) {
        final cis = parts[0].trim();
        final atc = parts[1].trim();
        if (cis.isNotEmpty && atc.isNotEmpty) {
          mitmMap[cis] = atc;
        }
      }
    }
    return mitmMap;
  }

  // WHY: Parse BDPM availability file and keep only actionable shortage/tension rows.
  // Expands CIS-level shortages (empty CIP) to every known CIP for that CIS.
  // Returns Either for Railway Oriented Programming.
  static Either<ParseError, List<Map<String, dynamic>>> parseAvailability(
    String? content,
    Map<String, List<String>> cisToCip13,
  ) {
    final availability = <Map<String, dynamic>>[];
    if (content == null || content.isEmpty) {
      return Right(availability);
    }

    for (final line in content.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length < 4) continue;

      final cisCode = parts.isNotEmpty ? parts[0].trim() : '';
      final cip13 = parts.length > 1 ? parts[1].trim() : '';
      final statusCode = parts.length > 2 ? parts[2].trim() : '';
      final statusLabel = parts[3].trim();
      final dateDebutRaw = parts.length > 4 ? parts[4].trim() : null;
      final dateFinRaw = parts.length > 5 ? parts[5].trim() : null;
      final lienRaw = parts.length > 6 ? parts[6].trim() : '';

      if (statusCode != '1' && statusCode != '2') continue;
      if (statusLabel.isEmpty) continue;

      final dateDebut = _parseBdpmDate(dateDebutRaw);
      final dateFin = _parseBdpmDate(dateFinRaw);

      void addAvailabilityEntry(String codeCip) {
        if (codeCip.isEmpty) return;
        availability.add({
          'code_cip': codeCip,
          'statut': statusLabel,
          'date_debut': dateDebut,
          'date_fin': dateFin,
          'lien': lienRaw.isNotEmpty ? lienRaw : null,
        });
      }

      if (cip13.isNotEmpty) {
        addAvailabilityEntry(cip13);
        continue;
      }

      if (cisCode.isEmpty) continue;
      final expandedCips = cisToCip13[cisCode];
      if (expandedCips == null || expandedCips.isEmpty) continue;
      for (final expandedCip in expandedCips) {
        addAvailabilityEntry(expandedCip);
      }
    }

    return Right(availability);
  }

  // WHY: Decode file content, handling both latin1 and utf8 encodings.
  static String? decodeContent(List<int>? bytes) {
    if (bytes == null) return null;
    try {
      return latin1.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}

double? _parseDecimal(String? raw) {
  if (raw == null) return null;
  final sanitized = raw.replaceAll(' ', '').replaceAll(',', '.');
  if (sanitized.isEmpty) return null;
  return double.tryParse(sanitized);
}

DateTime? _parseBdpmDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime.utc(year, month, day);
}

String _normalizeConditionText(String? raw) {
  if (raw == null) {
    return '';
  }
  var text = raw.trim().toUpperCase();
  const replacements = {
    'É': 'E',
    'È': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'À': 'A',
    'Â': 'A',
    'Î': 'I',
    'Ï': 'I',
    'Ô': 'O',
    'Û': 'U',
    'Ù': 'U',
  };
  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text;
}

typedef SpecialitesParseResult = ({
  List<Map<String, dynamic>> specialites,
  Map<String, String> namesByCis,
  Set<String> seenCis,
});

typedef MedicamentsParseResult = ({
  List<Map<String, dynamic>> medicaments,
  Map<String, List<String>> cisToCip13,
  Set<String> medicamentCips,
});

typedef GeneriquesParseResult = ({
  List<Map<String, dynamic>> generiqueGroups,
  List<Map<String, dynamic>> groupMembers,
});

class _CompositionGroup {
  _CompositionGroup();

  _CompositionRow? ftRow;
  final List<_CompositionRow> saRows = [];
}

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

class _CompositionRow {
  const _CompositionRow({
    required this.cis,
    required this.denomination,
    required this.dosage,
  });

  final String cis;
  final String denomination;
  final String dosage;
}
