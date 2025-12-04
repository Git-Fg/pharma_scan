import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';

class MockHapticService extends Mock implements HapticService {}

class MockBarcode extends Mock implements Barcode {
  @override
  String? get rawValue => _rawValue;
  String? _rawValue;

  @override
  BarcodeFormat get format => BarcodeFormat.ean13;

  void setRawValue(String? value) {
    _rawValue = value;
  }
}

class MockBarcodeCapture extends Mock implements BarcodeCapture {
  MockBarcodeCapture(this._barcodes);
  final List<Barcode> _barcodes;

  @override
  List<Barcode> get barcodes => _barcodes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scanner Logic - GS1 String -> Parsing -> DB Lookup -> State', () {
    late AppDatabase database;
    late MockHapticService mockHaptics;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );
      mockHaptics = MockHapticService();

      when(() => mockHaptics.success()).thenAnswer((_) async {});
      when(() => mockHaptics.error()).thenAnswer((_) async {});
      when(() => mockHaptics.warning()).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          catalogDaoProvider.overrideWithValue(database.catalogDao),
          hapticServiceProvider.overrideWithValue(mockHaptics),
          hapticSettingsProvider.overrideWith(
            (ref) => Stream<bool>.value(true),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'processBarcodeCapture with valid CIP adds bubble to state',
      () async {
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_VALID',
              'nom_specialite': 'PARACETAMOL 500 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'LAB_VALID',
            },
          ],
          medicaments: [
            {'code_cip': '3400930302613', 'cis_code': 'CIS_VALID'},
          ],
          principes: [
            {
              'code_cip': '3400930302613',
              'principe': 'PARACETAMOL',
              'dosage': '500',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();

        final barcode = MockBarcode()
          ..setRawValue('01034009303026132132780924334799');
        final capture = MockBarcodeCapture([barcode]);

        notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        verify(() => mockHaptics.success()).called(1);

        final finalState = container.read(scannerProvider);
        final bubbles = finalState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );

        expect(
          bubbles.length,
          equals(1),
          reason: 'Valid CIP should add bubble',
        );
        expect(
          bubbles.first.cip.toString(),
          equals('3400930302613'),
          reason: 'Bubble should contain correct CIP',
        );
      },
    );

    test(
      'processBarcodeCapture with same CIP twice moves bubble to top (does NOT duplicate)',
      () async {
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_DUPLICATE',
              'nom_specialite': 'PARACETAMOL 500 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'LAB_DUPLICATE',
            },
          ],
          medicaments: [
            {'code_cip': '3400930302613', 'cis_code': 'CIS_DUPLICATE'},
          ],
          principes: [
            {
              'code_cip': '3400930302613',
              'principe': 'PARACETAMOL',
              'dosage': '500',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();

        final barcode = MockBarcode()
          ..setRawValue('01034009303026132132780924334799');
        final capture = MockBarcodeCapture([barcode]);

        notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final firstState = container.read(scannerProvider);
        final firstBubbles = firstState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );
        expect(firstBubbles.length, equals(1));

        notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final secondState = container.read(scannerProvider);
        final secondBubbles = secondState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );

        expect(
          secondBubbles.length,
          equals(1),
          reason: 'Same CIP should NOT create duplicate bubble',
        );
      },
    );

    test(
      'processBarcodeCapture with unknown CIP triggers error effect, no bubble added',
      () async {
        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();

        final barcode = MockBarcode()..setRawValue('010123456789012');
        final capture = MockBarcodeCapture([barcode]);

        final initialState = container.read(scannerProvider);
        expect(
          initialState.maybeWhen(
            data: (state) => state.bubbles.length,
            orElse: () => 0,
          ),
          equals(0),
        );

        notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        verify(() => mockHaptics.error()).called(1);

        final finalState = container.read(scannerProvider);
        final bubbles = finalState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );

        expect(
          bubbles.length,
          equals(0),
          reason: 'Unknown CIP should not add bubble',
        );
      },
    );

    test(
      'setMode(restock) changes behavior to call restockDao instead of updating bubbles',
      () async {
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_RESTOCK',
              'nom_specialite': 'PARACETAMOL 500 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'LAB_RESTOCK',
            },
          ],
          medicaments: [
            {'code_cip': '3400930302613', 'cis_code': 'CIS_RESTOCK'},
          ],
          principes: [
            {
              'code_cip': '3400930302613',
              'principe': 'PARACETAMOL',
              'dosage': '500',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();

        notifier.setMode(ScannerMode.restock);

        final barcode = MockBarcode()
          ..setRawValue('01034009303026132132780924334799');
        final capture = MockBarcodeCapture([barcode]);

        notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        verify(() => mockHaptics.success()).called(1);

        final finalState = container.read(scannerProvider);
        final bubbles = finalState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );

        expect(
          bubbles.length,
          equals(0),
          reason: 'Restock mode should NOT add bubbles',
        );

        final restockItems = await database.restockDao
            .watchRestockItems()
            .first;
        expect(
          restockItems.length,
          equals(1),
          reason: 'Restock mode should add item to restock list',
        );
        expect(
          restockItems.first.cip.toString(),
          equals('3400930302613'),
          reason: 'Restock item should contain correct CIP',
        );
      },
    );
  });
}
