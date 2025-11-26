import 'package:pharma_scan/core/database/daos/library_dao.dart';
import 'package:pharma_scan/core/database/database.dart' as drift_db;

/// Builds mock [ProductGroupData] objects for widget and golden tests.
ProductGroupData createGroupExplorerTestData({
  required String groupId,
  required String syntheticTitle,
  required List<String> commonPrincipes,
  required List<
    ({
      String codeCip,
      String cisCode,
      String nomCanonique,
      String nomSpecialite,
      String titulaire,
      String? formePharmaceutique,
      int type, // 0 = princeps, 1 = generic
      String? principe,
      String? dosage,
      String? dosageUnit,
    })
  >
  members,
  List<GroupMemberData> relatedPrincepsRows = const [],
}) {
  final memberRows = <GroupMemberData>[];
  final principesByCip = <String, List<drift_db.PrincipesActif>>{};

  for (final member in members) {
    final medicamentRow = drift_db.Medicament(
      codeCip: member.codeCip,
      cisCode: member.cisCode,
    );

    final specialiteRow = drift_db.Specialite(
      cisCode: member.cisCode,
      nomSpecialite: member.nomSpecialite,
      procedureType: 'Autorisation',
      formePharmaceutique: member.formePharmaceutique,
      titulaire: member.titulaire,
      conditionsPrescription: null,
      etatCommercialisation: null,
      isSurveillance: false,
    );

    final groupMemberRow = drift_db.GroupMember(
      codeCip: member.codeCip,
      groupId: groupId,
      type: member.type,
    );

    final summaryRow = drift_db.MedicamentSummaryData(
      cisCode: member.cisCode,
      nomCanonique: member.nomCanonique,
      isPrinceps: member.type == 0,
      groupId: groupId,
      principesActifsCommuns: commonPrincipes,
      princepsDeReference: syntheticTitle,
      formePharmaceutique: member.formePharmaceutique,
      princepsBrandName: member.nomCanonique,
      procedureType: 'Autorisation',
      titulaire: member.titulaire,
      conditionsPrescription: null,
      isSurveillance: false,
      formattedDosage: null,
    );

    memberRows.add(
      GroupMemberData(
        medicamentRow: medicamentRow,
        specialiteRow: specialiteRow,
        groupMemberRow: groupMemberRow,
        summaryRow: summaryRow,
      ),
    );

    if (member.principe != null) {
      final principeRow = drift_db.PrincipesActif(
        id: 0,
        codeCip: member.codeCip,
        principe: member.principe!,
        dosage: member.dosage,
        dosageUnit: member.dosageUnit,
      );
      principesByCip[member.codeCip] = [principeRow];
    }
  }

  return ProductGroupData(
    groupId: groupId,
    memberRows: memberRows,
    principesByCip: principesByCip,
    commonPrincipes: commonPrincipes,
    relatedPrincepsRows: relatedPrincepsRows,
  );
}
