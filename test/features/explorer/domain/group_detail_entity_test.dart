import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/reference_schema.drift.dart';
import 'package:pharma_scan/core/domain/entities/group_detail_entity.dart';

void main() {
  group('GroupDetailEntity', () {
    // Helper to create valid UiGroupDetail data
    UiGroupDetail createData({
      int isPrinceps = 0,
      String? prixPublic,
      String? availabilityStatus,
      String? summaryTitulaire,
      String? officialTitulaire,
    }) {
      return UiGroupDetail(
        groupId: 'g1',
        cipCode: '123',
        rawLabel: 'Label',
        parsingMethod: 'method',
        cisCode: 'cis1',
        nomCanonique: 'Nom',
        princepsDeReference: '',
        princepsBrandName: '',
        isPrinceps: isPrinceps,
        status: '',
        formePharmaceutique: '',
        voiesAdministration: '',
        principesActifsCommuns: '[]',
        formattedDosage: '',
        summaryTitulaire: summaryTitulaire,
        officialTitulaire: officialTitulaire, // view expects distinct columns
        nomSpecialite: '',
        procedureType: '',
        conditionsPrescription: '',
        isSurveillance: 0,
        atcCode: '',
        memberType: 1,
        prixPublic: prixPublic != null ? double.tryParse(prixPublic) : null,
        tauxRemboursement: '',
        ansmAlertUrl: '',
        isHospitalOnly: 0,
        isDental: 0,
        isList1: 0,
        isList2: 0,
        isNarcotic: 0,
        isException: 0,
        isRestricted: 0,
        isOtc: 0,
        availabilityStatus: availabilityStatus,
      );
    }

    test('isPrinceps returns true for integer 1', () {
      final data = createData(isPrinceps: 1);
      final entity = GroupDetailEntity.fromData(data);
      expect(entity.isPrinceps, isTrue);
    });

    test('isPrinceps returns false for integer 0', () {
      final data = createData(isPrinceps: 0);
      final entity = GroupDetailEntity.fromData(data);
      expect(entity.isPrinceps, isFalse);
    });

    test('parsedTitulaire prefers summaryTitulaire', () {
      final data = createData(
        summaryTitulaire: 'Sanofi Winthrop',
        officialTitulaire: 'Other Lab',
      );
      final entity = GroupDetailEntity.fromData(data);
      expect(entity.parsedTitulaire, equals('Sanofi Winthrop'));
    });

    test('parsedTitulaire falls back to officialTitulaire', () {
      final data = createData(
        summaryTitulaire: null,
        officialTitulaire: 'Biogaran',
      );
      final entity = GroupDetailEntity.fromData(data);
      expect(entity.parsedTitulaire, equals('Biogaran'));
    });
  });
}
