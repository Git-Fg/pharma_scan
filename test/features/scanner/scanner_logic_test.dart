import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';

import '../../test_utils.dart'
    show
        generateGs1String,
        generateSimpleGs1String,
        getRealCip,
        loadRealBdpmData,
        setPrincipeNormalizedForAllPrinciples;

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
    late AppDatabase database;
    late ProviderContainer container;
    late String validCipWithSummary;

    Future<String> findCipWithSummary(AppDatabase db) async {
      final meds = await db.select(db.medicaments).get();
      for (final med in meds) {
        final summary = await (db.select(
          db.medicamentSummary,
        )..where((s) => s.cisCode.equals(med.cisCode))).getSingleOrNull();
        if (summary != null) {
          final scanResult = await db.catalogDao.getProductByCip(
            Cip13(med.codeCip),
          );
          if (scanResult != null) {
            return med.codeCip;
          }
        }
      }
      throw Exception('No medicament with matching MedicamentSummary found');
    }

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      // Load real BDPM data instead of hardcoded values
      await loadRealBdpmData(database);

      // Create MedicamentSummary for lookups
      await setPrincipeNormalizedForAllPrinciples(database);
      final dataInit = DataInitializationService(database: database);
      await dataInit.runSummaryAggregationForTesting();

      validCipWithSummary = await findCipWithSummary(database);

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          catalogDaoProvider.overrideWithValue(database.catalogDao),
          hapticSettingsProvider.overrideWith(
            (ref) => Stream<bool>.value(true),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await database.close();
    });

    test(
      'processBarcodeCapture with valid CIP adds bubble to state',
      () async {
        // Use CIP that is guaranteed to have a MedicamentSummary entry
        final gs1String = generateGs1String(validCipWithSummary);

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();
        final effects = <ScannerSideEffect>[];
        final sub = notifier.sideEffects.listen(effects.add);

        final barcode = MockBarcode()..rawValue = gs1String;
        final capture = MockBarcodeCapture([barcode]);

        await notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(Duration.zero);

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
        expect(bubbles.first.cip.toString(), equals(validCipWithSummary));

        expect(
          effects.whereType<ScannerHaptic>().any(
            (effect) => effect.type == ScannerHapticType.success,
          ),
          isTrue,
          reason: 'Success haptic side effect should be emitted',
        );
        await sub.cancel();
      },
    );

    test(
      'processBarcodeCapture with same CIP twice moves bubble to top (does NOT duplicate)',
      () async {
        // Use real CIP from loaded BDPM data
        final realCip = await getRealCip(database);
        final gs1String = generateGs1String(realCip);

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();

        final barcode = MockBarcode()..rawValue = gs1String;
        final capture = MockBarcodeCapture([barcode]);

        await notifier.processBarcodeCapture(capture);

        final firstState = container.read(scannerProvider);
        final firstBubbles = firstState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );
        expect(firstBubbles.length, equals(1));

        await notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await Future<void>.delayed(Duration.zero);

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
      'processBarcodeCapture debounces duplicate scans but allows re-scan after cooldown',
      () async {
        final realCip = await getRealCip(database);
        final gs1String = generateGs1String(realCip);

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();

        final barcode = MockBarcode()..rawValue = gs1String;
        final capture = MockBarcodeCapture([barcode]);

        // First scan adds a bubble.
        await notifier.processBarcodeCapture(capture);
        final initialState = container.read(scannerProvider);
        final initialBubbles = initialState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );
        expect(initialBubbles.length, equals(1));

        // Immediate duplicate scan is ignored (debounced).
        await notifier.processBarcodeCapture(capture);
        final debouncedState = container.read(scannerProvider);
        final debouncedBubbles = debouncedState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );
        expect(
          debouncedBubbles.length,
          equals(1),
          reason: 'Debounce should ignore immediate duplicate scans',
        );

        // Manually clear the bubble and wait for cleanup to remove code guard.
        notifier.removeBubble(realCip);
        await Future<void>.delayed(AppConfig.scannerCodeCleanupDelay * 2);

        await notifier.processBarcodeCapture(capture);
        final finalState = container.read(scannerProvider);
        final finalBubbles = finalState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );

        expect(
          finalBubbles.length,
          equals(1),
          reason: 'Bubble should reappear after cooldown cleanup',
        );
        expect(finalBubbles.first.cip.toString(), equals(realCip));
      },
    );

    test(
      'processBarcodeCapture bypasses cooldown when force is true and replays bubble',
      () async {
        final realCip = await getRealCip(database);
        final gs1String = generateGs1String(realCip);

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();
        final effects = <ScannerSideEffect>[];
        final sub = notifier.sideEffects.listen(effects.add);

        final barcode = MockBarcode()..rawValue = gs1String;
        final capture = MockBarcodeCapture([barcode]);

        await notifier.processBarcodeCapture(capture);
        await notifier.processBarcodeCapture(capture, force: true);
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final finalState = container.read(scannerProvider);
        final bubbles = finalState.maybeWhen(
          data: (state) => state.bubbles,
          orElse: () => <ScanBubble>[],
        );

        expect(
          bubbles.length,
          equals(1),
          reason:
              'Force processing should refresh the bubble instead of deduping',
        );

        final successCount = effects.whereType<ScannerHaptic>().where(
          (effect) => effect.type == ScannerHapticType.success,
        );
        expect(
          successCount.length,
          equals(2),
          reason: 'Force should bypass cooldown and emit success again',
        );
        await sub.cancel();
      },
    );

    test(
      'processBarcodeCapture cooldown is per-item: different CIPs are not blocked',
      () async {
        final cipA = await findCipWithSummary(database);
        var cipB = await getRealCip(database);
        if (cipB == cipA) {
          final meds = await database.select(database.medicaments).get();
          cipB = meds.firstWhere((m) => m.codeCip != cipA).codeCip;
        }

        final gs1A = generateGs1String(cipA);
        final gs1B = generateGs1String(cipB);

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();

        final barcodeA = MockBarcode()..rawValue = gs1A;
        final barcodeB = MockBarcode()..rawValue = gs1B;
        final capture = MockBarcodeCapture([barcodeA, barcodeB]);

        await notifier.processBarcodeCapture(capture);

        final state = container.read(scannerProvider);
        final bubbles = state.maybeWhen(
          data: (s) => s.bubbles,
          orElse: () => <ScanBubble>[],
        );

        expect(
          bubbles.length,
          equals(2),
          reason: 'Distinct CIPs should both be processed despite cooldown map',
        );
        expect(
          bubbles.map((b) => b.cip.toString()).toSet(),
          containsAll(<String>{cipA, cipB}),
        );
      },
    );

    test(
      'processBarcodeCapture with unknown CIP triggers error effect, no bubble added',
      () async {
        // Use a CIP that doesn't exist in the database
        var nonExistentCip = '9999999999999';
        while (await database.catalogDao.getProductByCip(
              Cip13(nonExistentCip),
            ) !=
            null) {
          nonExistentCip = (int.parse(nonExistentCip) - 1).toString().padLeft(
            13,
            '0',
          );
        }
        final gs1String = generateSimpleGs1String(nonExistentCip);

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();
        final effects = <ScannerSideEffect>[];
        final sub = notifier.sideEffects.listen(effects.add);

        final barcode = MockBarcode()..rawValue = gs1String;
        final capture = MockBarcodeCapture([barcode]);

        final initialState = container.read(scannerProvider);
        expect(
          initialState.maybeWhen(
            data: (state) => state.bubbles.length,
            orElse: () => 0,
          ),
          equals(0),
        );

        await notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(Duration.zero);

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
        await sub.cancel();
      },
    );

    test(
      'setMode(restock) changes behavior to call restockDao instead of updating bubbles',
      () async {
        // Resolve a CIP that can be looked up via CatalogDao
        final restockCip = await findCipWithSummary(database);
        final product = await database.catalogDao.getProductByCip(
          Cip13(restockCip),
        );
        expect(product, isNotNull, reason: 'Restock CIP must exist in catalog');

        final gs1String = generateGs1String(restockCip);

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();
        final effects = <ScannerSideEffect>[];
        final sub = notifier.sideEffects.listen(effects.add);

        notifier.setMode(ScannerMode.restock);

        final barcode = MockBarcode()..rawValue = gs1String;
        final capture = MockBarcodeCapture([barcode]);

        await notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await Future<void>.delayed(Duration.zero);

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
          equals(validCipWithSummary),
          reason: 'Restock item should contain correct CIP from real data',
        );
        expect(
          effects.whereType<ScannerHaptic>().any(
            (effect) => effect.type == ScannerHapticType.success,
          ),
          isTrue,
          reason: 'Restock success should emit haptic side effect',
        );
        await sub.cancel();
      },
    );

    test(
      'restock mode emits duplicate event and does not increment on duplicate serial',
      () async {
        final restockCip = await findCipWithSummary(database);
        final gs1String = generateGs1String(restockCip, serial: 'SER-DEDUP');

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();
        final effects = <ScannerSideEffect>[];
        final sub = notifier.sideEffects.listen(effects.add);

        notifier.setMode(ScannerMode.restock);

        final barcode = MockBarcode()..rawValue = gs1String;
        final capture = MockBarcodeCapture([barcode]);

        await notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 2100));
        await notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(Duration.zero);

        final restockRows = await database.select(database.restockItems).get();
        expect(restockRows.single.quantity, 1);

        final scannedRows = await database.select(database.scannedBoxes).get();
        expect(scannedRows.single.serialNumber, 'SER-DEDUP');
        expect(
          effects.whereType<ScannerDuplicateDetected>().length,
          equals(1),
          reason: 'Duplicate side effect should be emitted once',
        );
        expect(
          effects
              .whereType<ScannerHaptic>()
              .where(
                (effect) => effect.type == ScannerHapticType.warning,
              )
              .length,
          equals(1),
          reason: 'Warning haptic should be emitted on duplicate',
        );
        await sub.cancel();
      },
    );

    test(
      'restock mode respects cooldown: immediate duplicate scan is ignored',
      () async {
        final restockCip = await findCipWithSummary(database);
        final gs1String = generateGs1String(restockCip, serial: 'SER-COOLDOWN');

        final notifier = container.read(scannerProvider.notifier);
        await notifier.build();
        final effects = <ScannerSideEffect>[];
        final sub = notifier.sideEffects.listen(effects.add);

        notifier.setMode(ScannerMode.restock);

        final barcode = MockBarcode()..rawValue = gs1String;
        final capture = MockBarcodeCapture([barcode]);

        await notifier.processBarcodeCapture(capture);
        await notifier.processBarcodeCapture(capture);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final restockItems = await database.restockDao
            .watchRestockItems()
            .first;
        expect(
          restockItems.length,
          equals(1),
          reason: 'Cooldown should prevent immediate duplicate from adding',
        );
        expect(restockItems.single.quantity, equals(1));

        final duplicateEvents = effects
            .whereType<ScannerDuplicateDetected>()
            .length;
        expect(
          duplicateEvents,
          equals(0),
          reason: 'Cooldown skip should avoid duplicate warning',
        );

        final successHaptics = effects.whereType<ScannerHaptic>().where(
          (e) => e.type == ScannerHapticType.success,
        );
        expect(
          successHaptics.length,
          equals(1),
          reason: 'Only first scan should emit success haptic',
        );

        await sub.cancel();
      },
    );
  });
}
