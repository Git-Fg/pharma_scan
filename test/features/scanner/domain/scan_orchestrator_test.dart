import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/reference_schema.drift.dart';
import 'package:pharma_scan/core/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/models/scan_models.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_traffic_control.dart';
import 'package:pharma_scan/features/scanner/domain/scanner_mode.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Mocks
class MockCatalogDao extends Mock implements CatalogDao {}

class MockRestockDao extends Mock implements RestockDao {}

class MockScanTrafficControl extends Mock implements ScanTrafficControl {}

void main() {
  late ScanOrchestrator orchestrator;
  late MockCatalogDao mockCatalogDao;
  late MockRestockDao mockRestockDao;
  late MockScanTrafficControl mockTrafficControl;

  setUp(() {
    mockCatalogDao = MockCatalogDao();
    mockRestockDao = MockRestockDao();
    mockTrafficControl = MockScanTrafficControl();

    orchestrator = ScanOrchestrator(
      catalogDao: mockCatalogDao,
      restockDao: mockRestockDao,
      trafficControl: mockTrafficControl,
    );

    // Register fallback values for Mocktail
    registerFallbackValue(Cip13.validated('3400934056781'));
    registerFallbackValue(ScannerMode.analysis);
  });

  group('ScanOrchestrator.decide - Invalid Barcode', () {
    test('should return ProductNotFound when barcode is null', () async {
      // Arrange: Invalid GTIN (will be parsed as null by Gs1Parser)
      const invalidBarcode = 'INVALID_BARCODE';

      // Act
      final result = await orchestrator.decide(
        invalidBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
      );

      // Assert
      expect(result, isA<ProductNotFound>());
    });

    test('should return ProductNotFound when GTIN is garbage', () async {
      // Arrange: Non-parseable datamatrix
      const garbageBarcode = '01XXXXXXXXXX';

      // Act
      final result = await orchestrator.decide(
        garbageBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
      );

      // Assert
      expect(result, isA<ProductNotFound>());
    });
  });

  group('ScanOrchestrator.decide - Cooldown Logic', () {
    test('should return Ignore when cooldown is active', () async {
      // Arrange: Valid GTIN but cooldown blocks processing
      const validBarcode = '0103400934056781';
      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(false);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
      );

      // Assert
      expect(result, isA<Ignore>());
      verify(() => mockTrafficControl.shouldProcess(any(), force: false))
          .called(1);
      verifyNever(() => mockCatalogDao.getProductByCip(any()));
    });

    test('should bypass cooldown when force is true', () async {
      // Arrange: Force scan ignores cooldown
      const validBarcode = '0103400934056781';
      when(() => mockTrafficControl.shouldProcess(any(), force: true))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
              expDate: any(named: 'expDate')))
          .thenAnswer((_) async => _createMockScanResult());
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
        force: true,
      );

      // Assert
      expect(result, isA<AnalysisSuccess>());
      verify(() => mockTrafficControl.shouldProcess(any(), force: true))
          .called(1);
    });
  });

  group('ScanOrchestrator.decide - Analysis Mode', () {
    test('should return AnalysisSuccess when product is found', () async {
      // Arrange: Valid CIP with known product
      const validBarcode = '0103400934056781';
      final mockScanResult = _createMockScanResult();

      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
              expDate: any(named: 'expDate')))
          .thenAnswer((_) async => mockScanResult);
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
      );

      // Assert
      expect(result, isA<AnalysisSuccess>());
      final success = result as AnalysisSuccess;
      expect(success.result, equals(mockScanResult));
      expect(success.replacedExisting, isFalse);
    });

    test('should return ProductNotFound when product is not in catalog',
        () async {
      // Arrange: Valid GTIN but not in database
      const unknownBarcode = '013400999999999';

      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
          expDate: any(named: 'expDate'))).thenAnswer((_) async => null);
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        unknownBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
      );

      // Assert
      expect(result, isA<ProductNotFound>());
    });

    test('should ignore duplicate scans in analysis mode', () async {
      // Arrange: Same CIP scanned twice
      const validBarcode = '0103400934056781';
      final scannedCodes = {'3400934056781'};

      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(true);
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
        scannedCodes: scannedCodes,
      );

      // Assert
      expect(result, isA<Ignore>());
    });

    test('should replace existing bubble when force is true', () async {
      // Arrange: Force scan replaces existing bubble
      const validBarcode = '0103400934056781';
      final mockScanResult = _createMockScanResult();
      final existingBubbles = [mockScanResult];

      when(() => mockTrafficControl.shouldProcess(any(), force: true))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
              expDate: any(named: 'expDate')))
          .thenAnswer((_) async => mockScanResult);
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
        force: true,
        existingBubbles: existingBubbles,
      );

      // Assert
      expect(result, isA<AnalysisSuccess>());
      final success = result as AnalysisSuccess;
      expect(success.replacedExisting, isTrue);
    });
  });

  group('ScanOrchestrator.decide - Restock Mode', () {
    test('should return RestockAdded when adding new unique box', () async {
      // Arrange: New box with serial number
      const validBarcode = '013400934056781211234567890';
      final mockScanResult = _createMockScanResult();

      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
              expDate: any(named: 'expDate')))
          .thenAnswer((_) async => mockScanResult);
      when(() => mockRestockDao.isDuplicate(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
          )).thenAnswer((_) async => false);
      when(() => mockRestockDao.addUniqueBox(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
            batchNumber: any(named: 'batchNumber'),
            expiryDate: any(named: 'expiryDate'),
          )).thenAnswer((_) async => ScanOutcome.added);
      when(() => mockRestockDao.getRestockQuantity(any()))
          .thenAnswer((_) async => 1);
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.restock,
      );

      // Assert
      expect(result, isA<RestockAdded>());
      final added = result as RestockAdded;
      expect(added.item.quantity, equals(1));
      verify(() => mockRestockDao.addUniqueBox(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
            batchNumber: any(named: 'batchNumber'),
            expiryDate: any(named: 'expiryDate'),
          )).called(1);
    });

    test('should return RestockDuplicate when scanning duplicate serial',
        () async {
      // Arrange: Duplicate serial number
      const validBarcode = '0103400934056781211234567890';
      final mockScanResult = _createMockScanResult();

      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
              expDate: any(named: 'expDate')))
          .thenAnswer((_) async => mockScanResult);
      when(() => mockRestockDao.isDuplicate(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
          )).thenAnswer((_) async => true);
      when(() => mockRestockDao.getRestockQuantity(any()))
          .thenAnswer((_) async => 5);
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.restock,
      );

      // Assert
      expect(result, isA<RestockDuplicate>());
      final duplicate = result as RestockDuplicate;
      expect(duplicate.event.currentQuantity, equals(5));
      expect(duplicate.event.serial, equals('1234567890'));
    });

    test('should handle restock without serial number', () async {
      // Arrange: No serial in datamatrix
      const validBarcode = '0103400934056781';
      final mockScanResult = _createMockScanResult();

      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
              expDate: any(named: 'expDate')))
          .thenAnswer((_) async => mockScanResult);
      when(() => mockRestockDao.addUniqueBox(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
            batchNumber: any(named: 'batchNumber'),
            expiryDate: any(named: 'expiryDate'),
          )).thenAnswer((_) async => ScanOutcome.added);
      when(() => mockRestockDao.getRestockQuantity(any()))
          .thenAnswer((_) async => 1);
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.restock,
      );

      // Assert
      expect(result, isA<RestockAdded>());
      verifyNever(() => mockRestockDao.isDuplicate(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
          ));
    });

    test(
        'should detect duplicate from addUniqueBox when isDuplicate check passes',
        () async {
      // Arrange: Edge case where isDuplicate returns false but DB constraint catches duplicate
      const validBarcode = '0103400934056781211234567890';
      final mockScanResult = _createMockScanResult();

      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
              expDate: any(named: 'expDate')))
          .thenAnswer((_) async => mockScanResult);
      when(() => mockRestockDao.isDuplicate(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
          )).thenAnswer((_) async => false);
      when(() => mockRestockDao.addUniqueBox(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
            batchNumber: any(named: 'batchNumber'),
            expiryDate: any(named: 'expiryDate'),
          )).thenAnswer((_) async => ScanOutcome.duplicate);
      when(() => mockRestockDao.getRestockQuantity(any()))
          .thenAnswer((_) async => 5);
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.restock,
      );

      // Assert
      expect(result, isA<RestockDuplicate>());
      final duplicate = result as RestockDuplicate;
      expect(duplicate.toastMessage, isNotNull);
    });
  });

  group('ScanOrchestrator.decide - Error Handling', () {
    test('should return ScanError when DAO throws exception', () async {
      // Arrange: Database error
      const validBarcode = '0103400934056781';

      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
              expDate: any(named: 'expDate')))
          .thenThrow(Exception('Database error'));
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      final result = await orchestrator.decide(
        validBarcode,
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
      );

      // Assert
      expect(result, isA<ScanError>());
      final error = result as ScanError;
      expect(error.error, isA<Exception>());
      expect(error.stackTrace, isNotNull);
    });

    test('should still mark processed even when error occurs', () async {
      // Arrange: Error should not prevent markProcessed from being called
      const validBarcode = '0103400934056781';

      when(() => mockTrafficControl.shouldProcess(any(), force: false))
          .thenReturn(true);
      when(() => mockCatalogDao.getProductByCip(any(),
          expDate: any(named: 'expDate'))).thenThrow(Exception('Error'));
      when(() => mockTrafficControl.markProcessed(any())).thenReturn(null);

      // Act
      await orchestrator.decide(
          validBarcode, BarcodeFormat.dataMatrix, ScannerMode.analysis);

      // Assert
      verify(() => mockTrafficControl.markProcessed(any())).called(1);
    });
  });

  group('ScanOrchestrator.decide - Warning Logic', () {
    test('should return ScanWarning for EAN13 barcode', () async {
      // Arrange
      const ean13 = '3400934056781';
      final mockScanResult = _createMockScanResult();

      when(() => mockCatalogDao.getProductByCip(any()))
          .thenAnswer((_) async => mockScanResult);

      // Act
      final result = await orchestrator.decide(
        ean13,
        BarcodeFormat.ean13,
        ScannerMode.analysis,
      );

      // Assert
      expect(result, isA<ScanWarning>());
      final warning = result as ScanWarning;
      expect(warning.productCip, equals(ean13));
      expect(warning.scanResult, equals(mockScanResult));
    });
  });

  group('ScanOrchestrator.updateQuantity', () {
    test('should delegate to restockDao.forceUpdateQuantity', () async {
      // Arrange
      const cip = '3400934056781';
      const newQuantity = 10;

      when(() => mockRestockDao.forceUpdateQuantity(
            cip: any(named: 'cip'),
            newQuantity: any(named: 'newQuantity'),
          )).thenAnswer((_) async => {});

      // Act
      await orchestrator.updateQuantity(cip, newQuantity);

      // Assert
      verify(() => mockRestockDao.forceUpdateQuantity(
            cip: Cip13.validated(cip),
            newQuantity: newQuantity,
          )).called(1);
    });
  });
}

// Helper to create a mock ScanResult
ScanResult _createMockScanResult() {
  return (
    summary: _createMockMedicamentEntity(),
    cip: Cip13.validated('3400934056781'),
    price: 2.5,
    refundRate: '65%',
    boxStatus: 'Commercialisé',
    availabilityStatus: 'Available',
    isHospitalOnly: false,
    libellePresentation: null,
    expDate: null,
  );
}

// Helper to create a mock MedicamentEntity
MedicamentEntity _createMockMedicamentEntity() {
  return MedicamentEntity.fromData(
    MedicamentSummaryData(
      cisCode: '12345678',
      nomCanonique: 'TEST MEDICAMENT',
      princepsDeReference: 'TEST',
      princepsBrandName: 'TEST BRAND',
      isPrinceps: 1,
      memberType: 0,
      status: null,
      formePharmaceutique: 'Comprimé',
      voiesAdministration: null,
      principesActifsCommuns: null,
      formattedDosage: null,
      titulaireId: null,
      procedureType: null,
      conditionsPrescription: null,
      isSurveillance: 0,
      atcCode: null,
      dateAmm: null,
      aggregatedConditions: null,
      ansmAlertUrl: null,
      representativeCip: null,
      groupId: null,
      isHospital: 0,
      isDental: 0,
      isList1: 0,
      isList2: 0,
      isNarcotic: 0,
      isException: 0,
      isRestricted: 0,
      isOtc: 0,
      clusterId: null,
      parentPrincepsCis: null,
      formId: null,
      isFormInferred: 0,
    ),
  );
}
