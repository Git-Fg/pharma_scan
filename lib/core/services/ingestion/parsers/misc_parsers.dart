part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

Future<Map<String, String>> parseConditionsImpl(
  Stream<List<dynamic>>? rows,
) async {
  final conditions = <String, String>{};

  if (rows == null) return conditions;

  await for (final row in rows) {
    switch (row.map(_cellAsString).toList(growable: false)) {
      case [final cis, final condition, ...]:
        if (cis.isNotEmpty && condition.isNotEmpty) {
          final existing = conditions[cis];
          if (existing != null && existing.isNotEmpty) {
            conditions[cis] = '$existing, $condition';
          } else {
            conditions[cis] = condition;
          }
        }
      default:
        continue;
    }
  }

  return conditions;
}

Future<Map<String, String>> parseMitmImpl(Stream<List<dynamic>>? rows) async {
  final mitmMap = <String, String>{};
  if (rows == null) return mitmMap;

  await for (final row in rows) {
    switch (row.map(_cellAsString).toList(growable: false)) {
      case [final cis, final atc, ...]:
        if (cis.isNotEmpty && atc.isNotEmpty) {
          mitmMap[cis] = atc;
        }
      default:
        continue;
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
    final parts = row.map(_cellAsString).toList(growable: false);
    switch (parts) {
      case [
        final cisCode,
        final cip13,
        final statusCode,
        final statusLabel,
        ...final tail,
      ]:
        final dateDebutRaw = tail.isNotEmpty ? tail[0] : null;
        final dateFinRaw = tail.length > 1 ? tail[1] : null;
        final lienRaw = tail.length > 2 ? tail[2] : '';

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
      default:
        continue;
    }
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
