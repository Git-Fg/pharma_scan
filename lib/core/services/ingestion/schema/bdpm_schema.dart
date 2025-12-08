import 'package:pharma_scan/core/services/ingestion/schema/bdpm_parsers.dart';

/// CIS_bdpm.txt (Spécialités)
class BdpmSpecialiteRow with BdpmRowParser {
  const BdpmSpecialiteRow({
    required this.cis,
    required this.denomination,
    required this.formePharma,
    required this.voiesAdmin,
    required this.statutAdmin,
    required this.typeProcedure,
    required this.etatCommercialisation,
    required this.dateAmm,
    required this.statutBdm,
    required this.numAutorisationEurope,
    required this.titulaire,
    required this.surveillanceRenforcee,
  });
  final String cis;
  final String denomination;
  final String formePharma;
  final String voiesAdmin;
  final String statutAdmin;
  final String typeProcedure;
  final String etatCommercialisation;
  final DateTime? dateAmm;
  final String statutBdm;
  final String numAutorisationEurope;
  final String titulaire;
  final bool surveillanceRenforcee;

  static BdpmSpecialiteRow? fromLine(String line) {
    const parser = _BdpmParserInstance();
    final cols = parser.splitLine(line, 12);
    if (cols.isEmpty) return null;

    return BdpmSpecialiteRow(
      cis: cols[0],
      denomination: cols[1],
      formePharma: cols[2],
      voiesAdmin: cols[3],
      statutAdmin: cols[4],
      typeProcedure: cols[5],
      etatCommercialisation: cols[6],
      dateAmm: parser.parseDate(cols[7]),
      statutBdm: cols[8],
      numAutorisationEurope: cols[9],
      titulaire: cols[10],
      surveillanceRenforcee: parser.parseBool(cols[11]),
    );
  }
}

/// CIS_CIP_bdpm.txt (Présentations)
class BdpmPresentationRow with BdpmRowParser {
  const BdpmPresentationRow({
    required this.cis,
    required this.cip7,
    required this.libellePresentation,
    required this.statutAdmin,
    required this.etatCommercialisation,
    required this.dateDeclaration,
    required this.cip13,
    required this.agrementCollectivites,
    required this.tauxRemboursement,
    required this.prixEuro,
    required this.indicationsRemb,
  });
  final String cis;
  final String cip7;
  final String libellePresentation;
  final String statutAdmin;
  final String etatCommercialisation;
  final DateTime? dateDeclaration;
  final String cip13;
  final String agrementCollectivites;
  final String tauxRemboursement;
  final double? prixEuro;
  final String indicationsRemb;

  static BdpmPresentationRow? fromLine(String line) {
    const parser = _BdpmParserInstance();
    final cols = parser.splitLine(line, 10);
    if (cols.isEmpty) return null;

    return BdpmPresentationRow(
      cis: cols[0],
      cip7: cols[1],
      libellePresentation: cols[2],
      statutAdmin: cols[3],
      etatCommercialisation: cols[4],
      dateDeclaration: parser.parseDate(cols[5]),
      cip13: cols[6],
      agrementCollectivites: cols[7],
      tauxRemboursement: cols[8],
      prixEuro: parser.parseDouble(cols[9]),
      indicationsRemb: cols.length > 10 ? cols[10] : '',
    );
  }
}

/// CIS_COMPO_bdpm.txt (Compositions)
class BdpmCompositionRow with BdpmRowParser {
  const BdpmCompositionRow({
    required this.cis,
    required this.designationElem,
    required this.codeSubstance,
    required this.denominationSubst,
    required this.dosage,
    required this.referenceDosage,
    required this.natureComposant,
    required this.numLiaison,
  });
  final String cis;
  final String designationElem;
  final String codeSubstance;
  final String denominationSubst;
  final String dosage;
  final String referenceDosage;
  final String natureComposant;
  final int numLiaison;

  static BdpmCompositionRow? fromLine(String line) {
    const parser = _BdpmParserInstance();
    final cols = parser.splitLine(line, 8);
    if (cols.isEmpty) return null;

    final substanceCode = cols[2].trim();

    return BdpmCompositionRow(
      cis: cols[0],
      designationElem: cols[1],
      codeSubstance: substanceCode,
      denominationSubst: cols[3],
      dosage: cols[4],
      referenceDosage: cols[5],
      natureComposant: cols[6],
      numLiaison: int.tryParse(cols[7]) ?? 0,
    );
  }
}

class _BdpmParserInstance with BdpmRowParser {
  const _BdpmParserInstance();
}
