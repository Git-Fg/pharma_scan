import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/models/medicament_summary_data.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_traffic_control.dart';
import 'package:pharma_scan/features/scanner/domain/scanner_mode.dart';

import '../../../test_utils.dart' show generateGs1String;

class _MockCatalogDao extends Mock implements CatalogDao {}

class _MockRestockDao extends Mock implements RestockDao {}

MedicamentEntity _buildEntity(String cis) {
  return MedicamentEntity.fromData(
    MedicamentSummaryData(
      cisCode: cis,
      nomCanonique: 'Produit $cis',
      isPrinceps: true,
      memberType: 0,
      princepsDeReference: 'Produit $cis',
      formePharmaceutique: 'Comprimé',
      voiesAdministration: 'Orale',
      princepsBrandName: 'Produit $cis',
      isSurveillance: false,
      isHospitalOnly: false,
      isDental: false,
      isList1: false,
      isList2: false,
      isNarcotic: false,
      isException: false,
      isRestricted: false,
      isOtc: true,
    ),
  );
}

void main() {
  late ScanOrchestrator orchestrator;
  late _MockCatalogDao catalogDao;
  late _MockRestockDao restockDao;
  late ScanTrafficControl trafficControl;
  late ScanResult scanResult;

  setUpAll(() {
    registerFallbackValue(Cip13.validated('3400934056781'));
  });

  setUp(() {
    catalogDao = _MockCatalogDao();
    restockDao = _MockRestockDao();
    trafficControl = ScanTrafficControl();
    scanResult = ScanResult(
      summary: _buildEntity('CIS1'),
      cip: Cip13.validated('3400934056781'),
    );

    orchestrator = ScanOrchestrator(
      catalogDao: catalogDao,
      restockDao: restockDao,
      trafficControl: trafficControl,
    );

    when(
      () => catalogDao.getProductByCip(
        any(),
        expDate: any(named: 'expDate'),
      ),
    ).thenAnswer((_) async => scanResult);
  });

  group('ScanOrchestrator - restock duplicates', () {
    test('emits duplicate warning when serial already scanned', () async {
      when(
        () => restockDao.isDuplicate(
          cip: any(named: 'cip'),
          serial: any(named: 'serial'),
        ),
      ).thenAnswer((_) async => true);
      when(() => restockDao.getRestockQuantity(any())).thenAnswer(
        (_) async => 3,
      );

      final decision = await orchestrator.decide(
        generateGs1String('3400934056781', serial: 'SER123'),
        ScannerMode.restock,
      );

      expect(decision, isA<RestockDuplicate>());
      final duplicateAction = decision as RestockDuplicate;
      expect(duplicateAction.event.serial, 'SER123');
      expect(duplicateAction.toastMessage, isNull);
    });

    test(
      'returns duplicate outcome when DB unique constraint triggers',
      () async {
        when(
          () => restockDao.isDuplicate(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
          ),
        ).thenAnswer((_) async => false);
        when(
          () => restockDao.addUniqueBox(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
            batchNumber: any(named: 'batchNumber'),
            expiryDate: any(named: 'expiryDate'),
          ),
        ).thenAnswer((_) async => ScanOutcome.duplicate);
        when(() => restockDao.getRestockQuantity(any())).thenAnswer(
          (_) async => 1,
        );

        final decision = await orchestrator.decide(
          generateGs1String('3400934056781', serial: 'SER999'),
          ScannerMode.restock,
        );

        expect(decision, isA<RestockDuplicate>());
        final duplicate = decision as RestockDuplicate;
        expect(duplicate.toastMessage, Strings.duplicateSerial('SER999'));
      },
    );
  });
}
