import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_either/dart_either.dart';
import 'package:decimal/decimal.dart';
import 'package:pharma_scan/core/constants/chemical_constants.dart';

/// Parse error types for functional error handling
sealed class ParseError {
  const ParseError();
}

// Record typedefs for type-safe parsing
typedef SpecialiteRow = ({
  String cisCode,
  String nomSpecialite,
  String statutAdministratif,
  String procedureType,
  String formePharmaceutique,
  String voiesAdministration,
  String etatCommercialisation,
  String titulaire,
  String? conditionsPrescription,
  String? atcCode,
  bool isSurveillance,
});

typedef MedicamentRow = ({
  String codeCip,
  String cisCode,
  String? presentationLabel,
  String? commercialisationStatut,
  String? tauxRemboursement,
  double? prixPublic,
  String? agrementCollectivites,
});

typedef PrincipeRow = ({
  String codeCip,
  String principe,
  String? dosage,
  String? dosageUnit,
});

typedef GeneriqueGroupRow = ({
  String groupId,
  String libelle,
  String? princepsLabel,
  String? moleculeLabel,
});

typedef GroupMemberRow = ({
  String codeCip,
  String groupId,
  int type,
});

typedef AvailabilityRow = ({
  String codeCip,
  String statut,
  DateTime? dateDebut,
  DateTime? dateFin,
  String? lien,
});

class EmptyContentError extends ParseError {
  const EmptyContentError(this.fileName);
  final String fileName;
}

class InvalidFormatError extends ParseError {
  const InvalidFormatError(this.fileName, this.details);
  final String fileName;
  final String details;
}

class BdpmFileParser {
  BdpmFileParser._();

  static Stream<String>? openLineStream(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    return file
        .openRead()
        .transform(latin1.decoder)
        .transform(const LineSplitter());
  }

  static Future<Either<ParseError, SpecialitesParseResult>> parseSpecialites(
    Stream<String>? lines,
    Map<String, String> conditionsByCis,
    Map<String, String> mitmMap,
  ) async {
    final specialites = <SpecialiteRow>[];
    final namesByCis = <String, String>{};
    final seenCis = <String>{};

    if (lines == null) {
      return const Either.left(EmptyContentError('specialites'));
    }

    var hasData = false;
    await for (final line in lines) {
      hasData = true;
      if (line.trim().isEmpty) continue;
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

          if (titulaire.toUpperCase().contains('BOIRON')) {
            continue;
          }

          if (cis.isNotEmpty && nom.isNotEmpty && seenCis.add(cis)) {
            final record = (
              cisCode: cis,
              nomSpecialite: nom,
              statutAdministratif: statutAdministratif,
              procedureType: procedure,
              formePharmaceutique: forme,
              voiesAdministration: voies,
              etatCommercialisation: commercialisation,
              titulaire: titulaire,
              conditionsPrescription: conditionsByCis[cis],
              atcCode: mitmMap[cis],
              isSurveillance: isSurveillance,
            );
            specialites.add(record);
            namesByCis[cis] = nom;
          }
        default:
          continue;
      }
    }

    if (!hasData) {
      return const Either.left(EmptyContentError('specialites'));
    }

    return Either.right((
      specialites: specialites,
      namesByCis: namesByCis,
      seenCis: seenCis,
    ));
  }

  static Future<Either<ParseError, MedicamentsParseResult>> parseMedicaments(
    Stream<String>? lines,
    SpecialitesParseResult specialitesResult,
  ) async {
    final cisToCip13 = <String, List<String>>{};
    final medicaments = <MedicamentRow>[];
    final medicamentCips = <String>{};
    final seenCis = specialitesResult.seenCis;
    final namesByCis = specialitesResult.namesByCis;

    if (lines == null) {
      return const Either.left(EmptyContentError('medicaments'));
    }

    var hasData = false;
    await for (final line in lines) {
      hasData = true;
      if (line.trim().isEmpty) continue;
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
              medicaments.add((
                codeCip: cip13,
                cisCode: cis,
                presentationLabel: presentationLabelRaw.trim().isEmpty
                    ? null
                    : presentationLabelRaw.trim(),
                commercialisationStatut: status,
                tauxRemboursement: refundRateRaw.trim().isEmpty
                    ? null
                    : refundRateRaw.trim(),
                prixPublic: parsedPrice,
                agrementCollectivites: agrement,
              ));
            }
          }
        default:
          continue;
      }
    }

    if (!hasData) {
      return const Either.left(EmptyContentError('medicaments'));
    }

    return Either.right((
      medicaments: medicaments,
      cisToCip13: cisToCip13,
      medicamentCips: medicamentCips,
    ));
  }

  static Future<Either<ParseError, List<PrincipeRow>>> parseCompositions(
    Stream<String>? lines,
    Map<String, List<String>> cisToCip13,
  ) async {
    final principes = <PrincipeRow>[];

    if (lines == null) {
      return Either.right(principes);
    }

    // Group by composite key: CIS + Substance Code
    final rowsByKey = <String, _CompositionGroup>{};

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length < 8) continue;

      final cis = parts[0].trim();
      final substanceCode = parts[2].trim(); // Index 2: Substance Code
      final denomination = parts[3].trim();
      final dosageRaw = parts[4].trim();
      final nature = parts[6].trim(); // Index 6: Nature (SA or FT)

      if (cis.isEmpty || denomination.isEmpty || substanceCode.isEmpty) {
        continue;
      }
      if (!cisToCip13.containsKey(cis)) continue;

      // Utiliser la grammaire Dart de production (parseMoleculeSegment) pour
      // extraire un nom canonique de principe actif UNIQUEMENT lorsque nous
      // n'avons pas besoin de préserver la structure exacte (tests unitaires
      // historiques reposent encore sur la forme normalisée par
      // `_normalizeSaltPrefix`).
      //
      // Pour l'instant, on conserve `_normalizeSaltPrefix` comme source de
      // vérité pour la colonne `principe`, et on laisse
      // `parseMoleculeSegment` aux couches supérieures (résumés, recherche)
      // via d'autres chemins de données.
      final normalizedDenomination = _normalizeSaltPrefix(denomination);

      final row = _CompositionRow(
        cis: cis,
        substanceCode: substanceCode,
        denomination: normalizedDenomination,
        dosage: dosageRaw,
        nature: nature,
      );
      // Composite key: CIS + Substance Code
      final key = '${cis}_$substanceCode';
      final group = rowsByKey.putIfAbsent(key, _CompositionGroup.new);
      group.rows.add(row);
    }

    // For each group, prioritize FT over SA
    for (final group in rowsByKey.values) {
      if (group.rows.isEmpty) continue;

      // Find the winner: FT if exists, otherwise SA
      _CompositionRow? winner;
      for (final row in group.rows) {
        if (row.nature.toUpperCase() == 'FT') {
          winner = row;
          break; // FT has highest priority, use first FT found
        }
        if (winner == null && row.nature.toUpperCase() == 'SA') {
          winner = row; // Use SA as fallback
        }
      }

      // If no SA or FT found, use first row as fallback
      final selectedRow = winner ?? group.rows.first;
      final cip13s = cisToCip13[selectedRow.cis];
      if (cip13s == null) continue;

      final (dosageValue, dosageUnit) = _parseDosage(selectedRow.dosage);

      // Emit only one PrincipeRow per (CIS, Substance Code) pair
      for (final cip13 in cip13s) {
        principes.add((
          codeCip: cip13,
          principe: selectedRow.denomination,
          dosage: dosageValue?.toString(),
          dosageUnit: dosageUnit,
        ));
      }
    }

    return Right(principes);
  }

  static Future<Either<ParseError, GeneriquesParseResult>> parseGeneriques(
    Stream<String>? lines,
    Map<String, List<String>> cisToCip13,
    Set<String> medicamentCips,
  ) async {
    final generiqueGroups = <GeneriqueGroupRow>[];
    final groupMembers = <GroupMemberRow>[];
    final seenGroups = <String>{};

    if (lines == null) {
      return Either.right((
        generiqueGroups: generiqueGroups,
        groupMembers: groupMembers,
      ));
    }

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
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
              // Split libelle by " - " to extract generic (first) and princeps (last)
              final segments = libelle.split(' - ');
              final firstSegment = segments.first.trim();
              // Get last segment and remove trailing period if present
              final lastSegmentRaw = segments.length > 1
                  ? segments.last.trim()
                  : null; // null if no split occurred
              final lastSegment = lastSegmentRaw
                  ?.replaceAll(RegExp(r'\.$'), '')
                  .trim();

              final moleculeLabel = _removeSaltSuffixes(firstSegment).trim();
              final normalizedMolecule = _normalizeSaltPrefix(moleculeLabel);
              final cleanedMoleculeLabel = normalizedMolecule
                  .replaceAll(RegExp(r'\s*\([^)]+\)\s*$'), '')
                  .trim();

              // Normalize first segment (generic label) with salt prefix handling for display
              final normalizedLibelle = _normalizeSaltPrefix(firstSegment);

              generiqueGroups.add((
                groupId: groupId,
                libelle: normalizedLibelle,
                princepsLabel: lastSegment?.isEmpty ?? false
                    ? null
                    : lastSegment,
                moleculeLabel: cleanedMoleculeLabel,
              ));
            }

            for (final cip13 in cip13s) {
              if (medicamentCips.contains(cip13)) {
                groupMembers.add((
                  codeCip: cip13,
                  groupId: groupId,
                  type: isPrinceps ? 0 : 1,
                ));
              }
            }
          }
        default:
          continue;
      }
    }

    return Either.right((
      generiqueGroups: generiqueGroups,
      groupMembers: groupMembers,
    ));
  }

  static Future<Map<String, String>> parseConditions(
    Stream<String>? lines,
  ) async {
    final conditions = <String, String>{};

    if (lines == null) return conditions;

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
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
    final isOtc = normalized.isEmpty || !hasAny;
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

  static Future<Map<String, String>> parseMitm(Stream<String>? lines) async {
    final mitmMap = <String, String>{};
    if (lines == null) return mitmMap;

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
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

  static Future<Either<ParseError, List<AvailabilityRow>>> parseAvailability(
    Stream<String>? lines,
    Map<String, List<String>> cisToCip13,
  ) async {
    final availability = <AvailabilityRow>[];
    if (lines == null) {
      return Either.right(availability);
    }

    await for (final line in lines) {
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
        availability.add((
          codeCip: codeCip,
          statut: statusLabel,
          dateDebut: dateDebut,
          dateFin: dateFin,
          lien: lienRaw.isNotEmpty ? lienRaw : null,
        ));
      }

      if (cip13.isNotEmpty) {
        addAvailabilityEntry(cip13);
        continue;
      }

      if (cisCode.isEmpty) continue;
      final expandedCips = cisToCip13[cisCode];
      if (expandedCips == null || expandedCips.isEmpty) continue;
      expandedCips.forEach(addAvailabilityEntry);
    }

    return Right(availability);
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

String _normalizeSaltPrefix(String label) {
  if (label.isEmpty) return label;

  // Match salt prefix at start of string: "SALT DE MOLECULE" or "SALT D'MOLECULE"
  // Case-insensitive matching for all common French salt types.
  const saltPattern =
      r'^((?:CHLORHYDRATE|SULFATE|MALEATE|MALÉATE|TARTRATE|BESILATE|BÉSILATE|MESILATE|MÉSILATE|SUCCINATE|FUMARATE|OXALATE|CITRATE|ACETATE|ACÉTATE|LACTATE|VALERATE|VALÉRATE|PROPIONATE|BUTYRATE|PHOSPHATE|NITRATE|BROMHYDRATE)\s+(?:DE\s+|D[\u0027\u2019]))(.+)$';
  final pattern = RegExp(saltPattern, caseSensitive: false);

  final match = pattern.firstMatch(label);
  if (match != null) {
    // On ne conserve que la molécule (groupe 2) et on jette le sel (groupe 1).
    final molecule = match.group(2)!.trim();
    // Nettoyage récursif pour gérer des chaînes de sels éventuelles.
    return _normalizeSaltPrefix(molecule);
  }

  return label;
}

/// Removes salt suffixes (like "Arginine", "Tosilate") from molecule names
/// to extract the base molecule name for grouping purposes.
String _removeSaltSuffixes(String label) {
  if (label.isEmpty) return label;

  // First normalize salt prefix (if present)
  var cleaned = _normalizeSaltPrefix(label);

  // Remove common salt suffixes that appear after the molecule name
  // These are typically separated by space: "MOLECULE ARGININE", "MOLECULE TOSILATE"
  for (final suffix in ChemicalConstants.saltSuffixes) {
    // Pattern: "MOLECULE SUFFIX" or "MOLECULE (SALT) SUFFIX"
    final suffixPattern = RegExp(
      r'\s+' + RegExp.escape(suffix) + r'(?:\s|$)',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(suffixPattern, ' ').trim();
  }

  // Clean up any double spaces
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Test helpers to validate salt normalization behavior in unit tests.
///
/// These wrappers expose the internal salt-handling logic without leaking
/// implementation details into the public API surface.
String debugNormalizeSaltPrefix(String label) => _normalizeSaltPrefix(label);

String debugRemoveSaltSuffixes(String label) => _removeSaltSuffixes(label);

typedef SpecialitesParseResult = ({
  List<SpecialiteRow> specialites,
  Map<String, String> namesByCis,
  Set<String> seenCis,
});

typedef MedicamentsParseResult = ({
  List<MedicamentRow> medicaments,
  Map<String, List<String>> cisToCip13,
  Set<String> medicamentCips,
});

typedef GeneriquesParseResult = ({
  List<GeneriqueGroupRow> generiqueGroups,
  List<GroupMemberRow> groupMembers,
});

class _CompositionGroup {
  _CompositionGroup();

  final List<_CompositionRow> rows = [];
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
    required this.substanceCode,
    required this.denomination,
    required this.dosage,
    required this.nature,
  });

  final String cis;
  final String substanceCode;
  final String denomination;
  final String dosage;
  final String nature;
}
