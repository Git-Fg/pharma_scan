part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

typedef _SpecialiteSeed = ({
  String cisCode,
  String nomSpecialite,
  String? statutAdministratif,
  String procedureType,
  String? formePharmaceutique,
  String? voiesAdministration,
  String? etatCommercialisation,
  String titulaire,
  String? conditionsPrescription,
  DateTime? dateAmm,
  String? atcCode,
  bool isSurveillance,
});

Future<Either<ParseError, SpecialitesParseResult>> parseSpecialitesImpl(
  Stream<List<dynamic>>? rows,
  Map<String, String> conditionsByCis,
  Map<String, String> mitmMap,
) async {
  if (rows == null) {
    return const Either.left(EmptyContentError('specialites'));
  }

  final seeds = <_SpecialiteSeed>[];
  final namesByCis = <String, String>{};
  final seenCis = <String>{};
  final holderNames = <String>{};

  var hadLines = false;
  var hasData = false;

  await for (final row in rows) {
    hadLines = true;
    final cols = row.map(_cellAsString).toList(growable: false);
    switch (cols) {
      case [
        final cis,
        final denomination,
        final formePharma,
        final voiesAdmin,
        final statutAdmin,
        final typeProcedure,
        final etatCommercialisation,
        final dateAmmRaw,
        _,
        _,
        final titulaire,
        final surveillanceRaw,
        ...,
      ]:
        final dateAmm = _cellAsDate(dateAmmRaw);
        final surveillanceRenforcee = _cellAsBool(surveillanceRaw);

        if (titulaire.isNotEmpty) {
          holderNames.add(titulaire);
        }

        if (titulaire.toUpperCase().contains('BOIRON')) {
          continue;
        }

        if (cis.isNotEmpty && denomination.isNotEmpty && seenCis.add(cis)) {
          hasData = true;
          seeds.add((
            cisCode: cis,
            nomSpecialite: denomination,
            statutAdministratif: statutAdmin.isEmpty ? null : statutAdmin,
            procedureType: typeProcedure,
            formePharmaceutique: formePharma.isEmpty ? null : formePharma,
            voiesAdministration: voiesAdmin.isEmpty ? null : voiesAdmin,
            etatCommercialisation: etatCommercialisation.isEmpty
                ? null
                : etatCommercialisation,
            titulaire: titulaire,
            conditionsPrescription: conditionsByCis[cis],
            dateAmm: dateAmm,
            atcCode: mitmMap[cis],
            isSurveillance: surveillanceRenforcee,
          ));
          namesByCis[cis] = denomination;
        }
      default:
        continue;
    }
  }

  if (!hasData) {
    return hadLines
        ? Either.right((
            specialites: <SpecialitesCompanion>[],
            namesByCis: namesByCis,
            seenCis: seenCis,
            labIdsByName: <String, int>{},
            laboratories: <LaboratoriesCompanion>[],
          ))
        : const Either.left(EmptyContentError('specialites'));
  }

  final labIdsByName = <String, int>{};
  final sortedHolders = holderNames.toList()..sort();
  for (var i = 0; i < sortedHolders.length; i++) {
    labIdsByName[sortedHolders[i]] = i + 1;
  }

  final specialitesCompanions = seeds
      .map(
        (seed) => SpecialitesCompanion(
          cisCode: Value(seed.cisCode),
          nomSpecialite: Value(seed.nomSpecialite),
          procedureType: Value(seed.procedureType),
          statutAdministratif: Value(seed.statutAdministratif),
          formePharmaceutique: Value(seed.formePharmaceutique),
          voiesAdministration: Value(seed.voiesAdministration),
          etatCommercialisation: Value(seed.etatCommercialisation),
          titulaireId: Value(
            seed.titulaire.isEmpty ? null : labIdsByName[seed.titulaire],
          ),
          conditionsPrescription: Value(seed.conditionsPrescription),
          dateAmm: Value(seed.dateAmm),
          atcCode: Value(seed.atcCode),
          isSurveillance: Value(seed.isSurveillance),
        ),
      )
      .toList();

  final laboratories = labIdsByName.entries
      .map(
        (entry) => LaboratoriesCompanion(
          id: Value(entry.value),
          name: Value(entry.key),
        ),
      )
      .toList();

  return Either.right((
    specialites: specialitesCompanions,
    namesByCis: namesByCis,
    seenCis: seenCis,
    labIdsByName: labIdsByName,
    laboratories: laboratories,
  ));
}

class SpecialitesParser
    implements FileParser<Either<ParseError, SpecialitesParseResult>> {
  SpecialitesParser({
    required this.conditionsByCis,
    required this.mitmMap,
  });

  final Map<String, String> conditionsByCis;
  final Map<String, String> mitmMap;

  @override
  Future<Either<ParseError, SpecialitesParseResult>> parse(
    Stream<List<dynamic>>? rows,
  ) => parseSpecialitesImpl(rows, conditionsByCis, mitmMap);
}
