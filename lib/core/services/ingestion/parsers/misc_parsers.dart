part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

Future<Map<String, String>> parseConditionsImpl(
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
        final existing = conditions[cis];
        if (existing != null && existing.isNotEmpty) {
          conditions[cis] = '$existing, $condition';
        } else {
          conditions[cis] = condition;
        }
      }
    }
  }

  return conditions;
}

Future<Map<String, String>> parseMitmImpl(Stream<String>? lines) async {
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

Future<Either<ParseError, List<MedicamentAvailabilityCompanion>>>
parseAvailabilityImpl(
  Stream<String>? lines,
  Map<String, List<String>> cisToCip13,
) async {
  final availability = <MedicamentAvailabilityCompanion>[];
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
      availability.add(
        MedicamentAvailabilityCompanion(
          codeCip: Value(codeCip),
          statut: Value(statusLabel),
          dateDebut: Value(dateDebut),
          dateFin: Value(dateFin),
          lien: Value(lienRaw.isNotEmpty ? lienRaw : null),
        ),
      );
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
