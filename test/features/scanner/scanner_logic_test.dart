import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';

import '../../fixtures/seed_builder.dart';
import '../../helpers/golden_db_helper.dart';
import '../../test_utils.dart' show generateGs1String, generateSimpleGs1String;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scanner Logic - GS1 String -> Parsing -> DB Lookup -> State', () {
    const cipA = '3400934056781';
    const cisA = 'CIS_A';
    const productA = 'Produit A';

    const cipB = '3400934056782';
    const cisB = 'CIS_B';
    const productB = 'Produit B';

    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      await SeedBuilder()
          .inGroup('GROUP_A', productA)
          .addPrinceps(
            productA,
            cisA,
            cipCode: cipA,
            form: 'Comprimé',
            lab: 'LAB_A',
          )
          .inGroup('GROUP_B', productB)
          .addPrinceps(
            productB,
            cisB,
            cipCode: cipB,
            form: 'Comprimé',
            lab: 'LAB_B',
          )
          .insertInto(database);

      container = ProviderContainer(
        overrides: [
          databaseProvider().overrideWithValue(database),
          catalogDaoProvider.overrideWithValue(database.catalogDao),
          hapticSettingsProvider.overrideWith(
            (ref) => true,
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test('processBarcodeCapture with valid CIP adds bubble to state', () async {
      final gs1String = generateGs1String(cipA);
      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();
      final effects = <ScannerSideEffect>[];
      final sub = notifier.sideEffects.listen(effects.add);

      final barcode = MockBarcode()..rawValue = gs1String;
      final capture = MockBarcodeCapture([barcode]);

      await notifier.processBarcodeCapture(capture);

      final bubbles = container.read(scannerProvider).maybeWhen(
            data: (state) => state.bubbles,
            orElse: () => <ScanBubble>[],
          );

      expect(bubbles.length, equals(1));
      expect(bubbles.first.cip.toString(), cipA);
      expect(
        effects.whereType<ScannerHaptic>().any(
              (effect) => effect.type == ScannerHapticType.analysisSuccess,
            ),
        isTrue,
      );
      await sub.cancel();
    });

    test('duplicate scan keeps single bubble', () async {
      final gs1String = generateGs1String(cipA);
      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();

      final capture = MockBarcodeCapture([
        MockBarcode()..rawValue = gs1String,
      ]);

      await notifier.processBarcodeCapture(capture);
      await notifier.processBarcodeCapture(capture);

      final bubbles = container.read(scannerProvider).maybeWhen(
            data: (state) => state.bubbles,
            orElse: () => <ScanBubble>[],
          );
      expect(bubbles.length, equals(1));
    });

    test('force replay refreshes bubble', () async {
      final gs1String = generateGs1String(cipA);
      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();
      final effects = <ScannerSideEffect>[];
      final sub = notifier.sideEffects.listen(effects.add);

      final capture = MockBarcodeCapture([
        MockBarcode()..rawValue = gs1String,
      ]);

      await notifier.processBarcodeCapture(capture);
      await notifier.processBarcodeCapture(capture, force: true);

      final successCount = effects.whereType<ScannerHaptic>().where(
            (effect) => effect.type == ScannerHapticType.analysisSuccess,
          );
      expect(successCount.length, equals(2));
      await sub.cancel();
    });

    test('unknown CIP emits unknown haptic and no bubble', () async {
      final gs1String = generateSimpleGs1String('9999999999999');
      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();
      final effects = <ScannerSideEffect>[];
      final sub = notifier.sideEffects.listen(effects.add);

      final capture = MockBarcodeCapture([
        MockBarcode()..rawValue = gs1String,
      ]);

      await notifier.processBarcodeCapture(capture);

      final bubbles = container.read(scannerProvider).maybeWhen(
            data: (state) => state.bubbles,
            orElse: () => <ScanBubble>[],
          );
      expect(bubbles, isEmpty);
      expect(
        effects.whereType<ScannerHaptic>().any(
              (effect) => effect.type == ScannerHapticType.unknown,
            ),
        isTrue,
      );
      await sub.cancel();
    });

    test('restock mode adds restock entry and emits success haptic', () async {
      final gs1String = generateGs1String(cipB, serial: 'SERIAL1');
      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();
      final effects = <ScannerSideEffect>[];
      final sub = notifier.sideEffects.listen(effects.add);

      notifier.setMode(ScannerMode.restock);

      final capture = MockBarcodeCapture([
        MockBarcode()..rawValue = gs1String,
      ]);

      await notifier.processBarcodeCapture(capture);

      final restockItems = await database.restockDao.watchRestockItems().first;
      expect(restockItems.length, equals(1));
      expect(restockItems.first.cip.toString(), cipB);
      expect(
        effects.whereType<ScannerHaptic>().any(
              (effect) => effect.type == ScannerHapticType.restockSuccess,
            ),
        isTrue,
      );
      await sub.cancel();
    });
  });
}
