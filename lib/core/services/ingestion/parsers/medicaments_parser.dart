part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

Future<Either<ParseError, MedicamentsParseResult>> parseMedicamentsImpl(
  Stream<String>? lines,
  SpecialitesParseResult specialitesResult,
) async {
  final cisToCip13 = <String, List<String>>{};
  final medicaments = <MedicamentsCompanion>[];
  final medicamentCips = <String>{};
  final seenCis = specialitesResult.seenCis;
  final namesByCis = specialitesResult.namesByCis;

  if (lines == null) {
    return const Either.left(EmptyContentError('medicaments'));
  }

  var hadLines = false;
  var hasData = false;
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    hadLines = true;
    final parsed = _bdpmParser
        .parseRow<
          (
            String cis,
            String libellePresentation,
            String statutAdmin,
            String etatCommercialisation,
            String cip13,
            String agrementCollectivites,
            String tauxRemboursement,
            double?,
          )
        >(
          line,
          10,
          (parts) => (
            parts[0],
            parts[2],
            parts[3],
            parts[4],
            parts.length > 6 ? parts[6] : '',
            parts.length > 7 ? parts[7] : '',
            parts.length > 8 ? parts[8] : '',
            _bdpmParser.parseDouble(parts.length > 9 ? parts[9] : ''),
          ),
        );
    if (parsed == null) continue;

    final (
      cis,
      libellePresentation,
      statutAdmin,
      etatCommercialisation,
      cip13,
      agrementCollectivites,
      tauxRemboursement,
      prixEuro,
    ) = parsed;

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
      final columns = line.split('\t');
      if (columns.isEmpty) continue;
      final fallbackCis = columns.first.trim();
      if (fallbackCis.isEmpty ||
          (!seenCis.contains(fallbackCis) && seenCis.isNotEmpty)) {
        continue;
      }
      final cipCandidate = columns
          .map((p) => p.trim())
          .firstWhere(
            (value) => RegExp(r'^\d{13}$').hasMatch(value),
            orElse: () => '',
          );
      if (cipCandidate.isEmpty) continue;
      hasData = true;
      final priceSource = columns.length > 9
          ? columns[9].trim()
          : columns.last.trim();
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
