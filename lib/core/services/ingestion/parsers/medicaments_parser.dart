part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

Future<Either<ParseError, MedicamentsParseResult>> parseMedicamentsImpl(
  Stream<List<dynamic>>? rows,
  SpecialitesParseResult specialitesResult,
) async {
  if (rows == null) {
    return const Either.left(EmptyContentError('medicaments'));
  }

  final cisToCip13 = <String, List<String>>{};
  final medicaments = <MedicamentsCompanion>[];
  final medicamentCips = <String>{};
  final seenCis = specialitesResult.seenCis;
  final namesByCis = specialitesResult.namesByCis;

  var hadLines = false;
  var hasData = false;

  await for (final row in rows) {
    if (row.length < 10) continue;
    final columns = row.map(_cellAsString).toList(growable: false);
    hadLines = true;
    final cis = columns[0];
    final libellePresentation = columns[2];
    final statutAdmin = columns[3];
    final etatCommercialisation = columns[4];
    final cip13 = columns[6];
    final agrementCollectivites = columns[7];
    final tauxRemboursement = columns[8];
    final prixEuro = _cellAsDouble(columns[9]);

    var added = false;
    final correctName = namesByCis[cis];
    final hasValidCis = cis.isNotEmpty && seenCis.contains(cis);
    final hasValidCip = RegExp(r'^\d{13}$').hasMatch(cip13);

    if (hasValidCis && correctName != null && hasValidCip) {
      hasData = true;
      cisToCip13.putIfAbsent(cis, () => []).add(cip13);

      if (medicamentCips.add(cip13)) {
        final agrement = agrementCollectivites.isEmpty
            ? null
            : agrementCollectivites.toLowerCase();
        medicaments.add(
          MedicamentsCompanion(
            codeCip: Value(cip13),
            cisCode: Value(cis),
            presentationLabel: Value(
              libellePresentation.isEmpty ? null : libellePresentation,
            ),
            commercialisationStatut: Value(
              etatCommercialisation.isEmpty ? null : etatCommercialisation,
            ),
            tauxRemboursement: Value(
              tauxRemboursement.isEmpty ? null : tauxRemboursement,
            ),
            prixPublic: Value(prixEuro),
            agrementCollectivites: Value(agrement),
          ),
        );
        added = true;
      }
    }

    if (!added) {
      final fallbackCis = columns.isNotEmpty ? columns.first : cis;
      if (fallbackCis.isEmpty ||
          (!seenCis.contains(fallbackCis) && seenCis.isNotEmpty)) {
        continue;
      }
      final cipCandidate = columns.firstWhere(
        (value) => RegExp(r'^\d{13}$').hasMatch(value),
        orElse: () => '',
      );
      if (cipCandidate.isEmpty) continue;
      hasData = true;
      final priceSource = columns.length > 9 ? columns[9] : columns.last;
      final parsedPrice = _parseDecimal(
        priceSource.isNotEmpty ? priceSource : null,
      );
      cisToCip13.putIfAbsent(fallbackCis, () => []).add(cipCandidate);
      if (medicamentCips.add(cipCandidate)) {
        medicaments.add(
          MedicamentsCompanion(
            codeCip: Value(cipCandidate),
            cisCode: Value(fallbackCis),
            presentationLabel: const Value(null),
            commercialisationStatut: Value(
              statutAdmin.isEmpty ? null : statutAdmin,
            ),
            tauxRemboursement: const Value(null),
            prixPublic: Value(parsedPrice),
            agrementCollectivites: const Value(null),
          ),
        );
      }
    }
  }

  if (!hasData) {
    return hadLines
        ? Either.right((
            medicaments: medicaments,
            cisToCip13: cisToCip13,
            medicamentCips: medicamentCips,
          ))
        : const Either.left(EmptyContentError('medicaments'));
  }

  return Either.right((
    medicaments: medicaments,
    cisToCip13: cisToCip13,
    medicamentCips: medicamentCips,
  ));
}

class MedicamentsParser
    implements FileParser<Either<ParseError, MedicamentsParseResult>> {
  MedicamentsParser(this.specialitesResult);

  final SpecialitesParseResult specialitesResult;

  @override
  Future<Either<ParseError, MedicamentsParseResult>> parse(
    Stream<List<dynamic>>? rows,
  ) => parseMedicamentsImpl(rows, specialitesResult);
}
