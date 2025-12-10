part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

Future<Map<String, String>> parseConditionsImpl(
  Stream<List<dynamic>>? rows,
) async {
  final conditions = <String, String>{};

  if (rows == null) return conditions;

  await for (final row in rows) {
    if (row.length < 2) continue;
    final cis = _cellAsString(row[0]);
    final condition = _cellAsString(row[1]);
    if (cis.isNotEmpty && condition.isNotEmpty) {
      final existing = conditions[cis];
      if (existing != null && existing.isNotEmpty) {
        conditions[cis] = '$existing, $condition';
      } else {
        conditions[cis] = condition;
      }
    }
  }

  return conditions;
}

Future<Map<String, String>> parseMitmImpl(Stream<List<dynamic>>? rows) async {
  final mitmMap = <String, String>{};
  if (rows == null) return mitmMap;

  await for (final row in rows) {
    if (row.length < 2) continue;
    final cis = _cellAsString(row[0]);
    final atc = _cellAsString(row[1]);
    if (cis.isNotEmpty && atc.isNotEmpty) {
      mitmMap[cis] = atc;
    }
  }
  return mitmMap;
}

Future<Either<ParseError, List<MedicamentAvailabilityCompanion>>>
parseAvailabilityImpl(
  Stream<List<dynamic>>? rows,
  Map<String, List<String>> cisToCip13,
) async {
  final availability = <MedicamentAvailabilityCompanion>[];
  if (rows == null) {
    return Either.right(availability);
  }

  await for (final row in rows) {
    if (row.length < 4) continue;
    final parts = row.map(_cellAsString).toList(growable: false);

    final cisCode = parts.isNotEmpty ? parts[0] : '';
    final cip13 = parts.length > 1 ? parts[1] : '';
    final statusCode = parts.length > 2 ? parts[2] : '';
    final statusLabel = parts[3];
    final dateDebutRaw = parts.length > 4 ? parts[4] : null;
    final dateFinRaw = parts.length > 5 ? parts[5] : null;
    final lienRaw = parts.length > 6 ? parts[6] : '';

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

class ConditionsParser implements FileParser<Map<String, String>> {
  const ConditionsParser();

  @override
  Future<Map<String, String>> parse(Stream<List<dynamic>>? rows) =>
      parseConditionsImpl(rows);
}

class MitmParser implements FileParser<Map<String, String>> {
  const MitmParser();

  @override
  Future<Map<String, String>> parse(Stream<List<dynamic>>? rows) =>
      parseMitmImpl(rows);
}

class AvailabilityParser
    implements
        FileParser<Either<ParseError, List<MedicamentAvailabilityCompanion>>> {
  const AvailabilityParser(this.cisToCip13);

  final Map<String, List<String>> cisToCip13;

  @override
  Future<Either<ParseError, List<MedicamentAvailabilityCompanion>>> parse(
    Stream<List<dynamic>>? rows,
  ) => parseAvailabilityImpl(rows, cisToCip13);
}
