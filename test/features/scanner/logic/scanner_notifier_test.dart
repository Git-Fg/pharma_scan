import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';

import '../../../test_utils.dart' show generateGs1String;

class MockBarcode extends Mock implements Barcode {
  @override
  String? get rawValue => _rawValue;
  String? _rawValue;

  @override
  BarcodeFormat get format => BarcodeFormat.ean13;

  set rawValue(String? value) => _rawValue = value;
}

class MockBarcodeCapture extends Mock implements BarcodeCapture {
  MockBarcodeCapture(this._barcodes);
  final List<Barcode> _barcodes;

  @override
  List<Barcode> get barcodes => _barcodes;
}

class MockCatalogDao extends Mock implements CatalogDao {}

class MockRestockDao extends Mock implements RestockDao {}

class MockAppDatabase extends Mock implements AppDatabase {}

MedicamentEntity _buildEntity(String cis) {
  return MedicamentEntity.fromData(
    MedicamentSummaryData(
      cisCode: cis,
      nomCanonique: 'Produit $cis',
      isPrinceps: true,
      memberType: 0,
      principesActifsCommuns: const [],
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScannerNotifier', () {
    late MockCatalogDao catalogDao;
    late MockRestockDao restockDao;
    late MockAppDatabase database;
    late ProviderContainer container;

    setUp(() {
      catalogDao = MockCatalogDao();
      restockDao = MockRestockDao();
      database = MockAppDatabase();

      when(() => database.restockDao).thenReturn(restockDao);
      when(
        () => catalogDao.getProductByCip(any(), expDate: any(named: 'expDate')),
      ).thenAnswer(
        (_) async => ScanResult(
          summary: _buildEntity('CIS1'),
          cip: Cip13.validated('3400934056781'),
        ),
      );
      when(
        () => restockDao.addUniqueBox(
          cip: any(named: 'cip'),
          serial: any(named: 'serial'),
          batchNumber: any(named: 'batchNumber'),
          expiryDate: any(named: 'expiryDate'),
        ),
      ).thenAnswer((_) async => ScanOutcome.added);
      when(
        () => restockDao.isDuplicate(
          cip: any(named: 'cip'),
          serial: any(named: 'serial'),
        ),
      ).thenAnswer((_) async => false);
      when(
        () => restockDao.getRestockQuantity(any()),
      ).thenAnswer((_) async => 1);

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          catalogDaoProvider.overrideWithValue(catalogDao),
          hapticSettingsProvider.overrideWith(
            (ref) => Stream<bool>.value(true),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('mode switch keeps bubbles and restock adds items', () async {
      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();

      final captureAnalysis = MockBarcodeCapture([
        MockBarcode()..rawValue = generateGs1String('3400934056781'),
      ]);
      await notifier.processBarcodeCapture(captureAnalysis);

      final beforeSwitch = container
          .read(scannerProvider)
          .maybeWhen(
            data: (state) => state.bubbles,
            orElse: () => <ScanBubble>[],
          );
      expect(beforeSwitch, isNotEmpty);

      notifier.setMode(ScannerMode.restock);

      final captureRestock = MockBarcodeCapture([
        MockBarcode()..rawValue = generateGs1String('3400934056782'),
      ]);
      await notifier.processBarcodeCapture(captureRestock);

      verify(
        () => restockDao.addUniqueBox(
          cip: Cip13.validated('3400934056782'),
          serial: any(named: 'serial'),
          batchNumber: any(named: 'batchNumber'),
          expiryDate: any(named: 'expiryDate'),
        ),
      ).called(1);

      final afterSwitch = container
          .read(scannerProvider)
          .maybeWhen(
            data: (state) => state.bubbles,
            orElse: () => <ScanBubble>[],
          );
      expect(
        afterSwitch,
        isNotEmpty,
        reason: 'Bubbles should persist across mode change',
      );
    });

    test(
      'duplicate scan in restock mode emits duplicate side-effect',
      () async {
        when(
          () => restockDao.isDuplicate(
            cip: any(named: 'cip'),
            serial: any(named: 'serial'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => restockDao.getRestockQuantity(any()),
        ).thenAnswer((_) async => 2);

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();
        notifier.setMode(ScannerMode.restock);

        final effects = <ScannerSideEffect>[];
        final sub = notifier.sideEffects.listen(effects.add);

        final capture = MockBarcodeCapture([
          MockBarcode()..rawValue = generateGs1String('3400934056781'),
        ]);
        await notifier.processBarcodeCapture(capture);

        expect(
          effects.any((e) => e is ScannerDuplicateDetected),
          isTrue,
        );
        await sub.cancel();
      },
    );

    test('duplicate scans are cooled down (catalog lookup once)', () async {
      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();

      final capture = MockBarcodeCapture([
        MockBarcode()..rawValue = generateGs1String('3400934056781'),
      ]);

      await notifier.processBarcodeCapture(capture);
      await notifier.processBarcodeCapture(capture);

      verify(
        () => catalogDao.getProductByCip(
          Cip13.validated('3400934056781'),
          expDate: any(named: 'expDate'),
        ),
      ).called(1);
    });
  });
}
