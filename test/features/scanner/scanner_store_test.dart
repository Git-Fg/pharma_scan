import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/features/scanner/logic/scanner_store.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/core/database/database.dart' as db;
import 'package:pharma_scan/core/domain/types/ids.dart';

// Helper to create a minimal MedicamentSummaryData
db.MedicamentSummaryData _makeSummary() {
  return db.MedicamentSummaryData(
    cisCode: '00000001',
    nomCanonique: 'Test',
    princepsDeReference: '',
    isPrinceps: false,
    clusterId: null,
    groupId: null,
    principesActifsCommuns: null,
    formattedDosage: null,
    formePharmaceutique: null,
    voiesAdministration: null,
    memberType: 0,
    princepsBrandName: '',
    procedureType: null,
    titulaireId: null,
    conditionsPrescription: null,
    dateAmm: null,
    isSurveillance: false,
    atcCode: null,
    status: null,
    priceMin: null,
    priceMax: null,
    aggregatedConditions: null,
    ansmAlertUrl: null,
    isHospital: false,
    isDental: false,
    isList1: false,
    isList2: false,
    isNarcotic: false,
    isException: false,
    isRestricted: false,
    isOtc: false,
    smrNiveau: null,
    smrDate: null,
    asmrNiveau: null,
    asmrDate: null,
    urlNotice: null,
    hasSafetyAlert: null,
    representativeCip: null,
  );
}

void main() {
  test('ScannerStore addScan increments bubbleCount and hasBubbles', () {
    final store = ScannerStore();

    expect(store.bubbleCount.value, 0);
    expect(store.hasBubbles.value, false);

    final summaryEntity = MedicamentEntity.fromData(_makeSummary());
    final scan = (
      summary: summaryEntity,
      cip: Cip13.validated('1234567890123'),
      price: null,
      refundRate: null,
      boxStatus: null,
      availabilityStatus: null,
      isHospitalOnly: false,
      libellePresentation: null,
      expDate: null,
    );

    store.addScan(scan);

    expect(store.bubbleCount.value, 1);
    expect(store.hasBubbles.value, true);
  });
}
