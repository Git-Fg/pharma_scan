// test/features/scanner/scanner_notifier_logic_test.dart
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

  group('ScannerNotifier State Machine Logic', () {
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
      'processBarcodeCapture with unknown CIP triggers haptic error and state remains analysis',
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
        await Future<void>.delayed(const Duration(milliseconds: 100));

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
      'processBarcodeCapture with known CIP adds bubble and triggers haptic success',
      () async {
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_KNOWN',
              'nom_specialite': 'PARACETAMOL 500 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'LAB_KNOWN',
            },
          ],
          medicaments: [
            {'code_cip': '3400930302613', 'cis_code': 'CIS_KNOWN'},
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
          reason: 'Known CIP should add bubble',
        );
        expect(
          bubbles.first.cip.toString(),
          equals('3400930302613'),
          reason: 'Bubble should contain correct CIP',
        );
      },
    );

    test(
      'duplicate scan does NOT add duplicate bubble',
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

        notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final finalState = container.read(scannerProvider);
        final bubbles = finalState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );

        expect(
          bubbles.length,
          equals(1),
          reason: 'Duplicate scan should NOT add duplicate bubble',
        );
      },
    );

    test(
      'rapid scans are processed correctly (debounce/queue logic)',
      () async {
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_RAPID1',
              'nom_specialite': 'PARACETAMOL 500 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'LAB_RAPID1',
            },
            {
              'cis_code': 'CIS_RAPID2',
              'nom_specialite': 'IBUPROFENE 400 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'LAB_RAPID2',
            },
          ],
          medicaments: [
            {'code_cip': '3400930302613', 'cis_code': 'CIS_RAPID1'},
            {'code_cip': '3400930302614', 'cis_code': 'CIS_RAPID2'},
          ],
          principes: [
            {
              'code_cip': '3400930302613',
              'principe': 'PARACETAMOL',
              'dosage': '500',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': '3400930302614',
              'principe': 'IBUPROFENE',
              'dosage': '400',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();

        final barcode1 = MockBarcode()
          ..setRawValue('01034009303026132132780924334799');
        final barcode2 = MockBarcode()
          ..setRawValue('01034009303026142132780924334800');

        notifier.processBarcodeCapture(MockBarcodeCapture([barcode1]));
        notifier.processBarcodeCapture(MockBarcodeCapture([barcode2]));
        await Future<void>.delayed(const Duration(milliseconds: 1000));

        final finalState = container.read(scannerProvider);
        final bubbles = finalState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );

        expect(
          bubbles.length,
          greaterThanOrEqualTo(1),
          reason: 'Rapid scans should be processed',
        );
      },
    );

    test(
      'state remains in analysis mode when CIP not found',
      () async {
        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();

        final initialState = container.read(scannerProvider);
        final initialMode = initialState.maybeWhen(
          data: (state) => state.mode,
          orElse: () => ScannerMode.analysis,
        );
        expect(initialMode, equals(ScannerMode.analysis));

        final barcode = MockBarcode()..setRawValue('010123456789012');
        final capture = MockBarcodeCapture([barcode]);

        notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final finalState = container.read(scannerProvider);
        final finalMode = finalState.maybeWhen(
          data: (state) => state.mode,
          orElse: () => ScannerMode.analysis,
        );

        expect(
          finalMode,
          equals(ScannerMode.analysis),
          reason: 'State should remain in analysis mode after unknown CIP',
        );
      },
    );
  });
}
