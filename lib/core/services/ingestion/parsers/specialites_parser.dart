part of 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

Future<Either<ParseError, SpecialitesParseResult>> parseSpecialitesImpl(
  Stream<String>? lines,
  Map<String, String> conditionsByCis,
  Map<String, String> mitmMap,
) async {
  final specialites = <SpecialiteRow>[];
  final namesByCis = <String, String>{};
  final seenCis = <String>{};
  final holderNames = <String>{};

  if (lines == null) {
    return const Either.left(EmptyContentError('specialites'));
  }

  var hadLines = false;
  var hasData = false;
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    hadLines = true;
    final cols = _bdpmParser.splitLine(line, 12);
    if (cols.isEmpty) continue;
    final cis = cols[0];
    final denomination = cols[1];
    final formePharma = cols[2];
    final voiesAdmin = cols[3];
    final statutAdmin = cols[4];
    final typeProcedure = cols[5];
    final etatCommercialisation = cols[6];
    final dateAmm = _bdpmParser.parseDate(cols[7]);
    final titulaire = cols[10];
    final surveillanceRenforcee = _bdpmParser.parseBool(cols[11]);

    if (titulaire.isNotEmpty) {
      holderNames.add(titulaire);
    }

    if (titulaire.toUpperCase().contains('BOIRON')) {
      continue;
    }

    if (cis.isNotEmpty && denomination.isNotEmpty && seenCis.add(cis)) {
      hasData = true;
      final record = (
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
        titulaireId: null,
        conditionsPrescription: conditionsByCis[cis],
        dateAmm: dateAmm,
        atcCode: mitmMap[cis],
        isSurveillance: surveillanceRenforcee,
      );
      specialites.add(record);
      namesByCis[cis] = denomination;
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

  final enrichedSpecialites = specialites
      .map(
        (s) => (
          cisCode: s.cisCode,
          nomSpecialite: s.nomSpecialite,
          statutAdministratif: s.statutAdministratif,
          procedureType: s.procedureType,
          formePharmaceutique: s.formePharmaceutique,
          voiesAdministration: s.voiesAdministration,
          etatCommercialisation: s.etatCommercialisation,
          titulaire: s.titulaire,
          titulaireId: (s.titulaire?.isEmpty ?? true)
              ? null
              : labIdsByName[s.titulaire],
          conditionsPrescription: s.conditionsPrescription,
          dateAmm: s.dateAmm,
          atcCode: s.atcCode,
          isSurveillance: s.isSurveillance,
        ),
      )
      .toList();

  final specialitesCompanions = enrichedSpecialites
      .map(
        (s) => SpecialitesCompanion(
          cisCode: Value(s.cisCode),
          nomSpecialite: Value(s.nomSpecialite),
          procedureType: Value(s.procedureType),
          statutAdministratif: Value(s.statutAdministratif),
          formePharmaceutique: Value(s.formePharmaceutique),
          voiesAdministration: Value(s.voiesAdministration),
          etatCommercialisation: Value(s.etatCommercialisation),
          titulaireId: Value(s.titulaireId),
          conditionsPrescription: Value(s.conditionsPrescription),
          dateAmm: Value(s.dateAmm),
          atcCode: Value(s.atcCode),
          isSurveillance: Value(s.isSurveillance),
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
