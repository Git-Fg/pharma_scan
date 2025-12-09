import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
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

class MockScanOrchestrator extends Mock implements ScanOrchestrator {}

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

  setUpAll(() {
    registerFallbackValue(ScannerMode.analysis);
  });

  group('ScannerNotifier', () {
    late MockScanOrchestrator orchestrator;
    late ScanResult scanResult;
    late ProviderContainer container;

    setUp(() {
      orchestrator = MockScanOrchestrator();
      scanResult = ScanResult(
        summary: _buildEntity('CIS1'),
        cip: Cip13.validated('3400934056781'),
      );

      when(
        () => orchestrator.decide(
          any(),
          any(),
          force: any(named: 'force'),
          scannedCodes: any(named: 'scannedCodes'),
          existingBubbles: any(named: 'existingBubbles'),
        ),
      ).thenAnswer(
        (invocation) async {
          final mode = invocation.positionalArguments[1] as ScannerMode;
          if (mode == ScannerMode.restock) {
            return RestockAdded(
              item: RestockItemEntity(
                cip: scanResult.cip,
                label: scanResult.summary.data.nomCanonique,
                quantity: 1,
                isChecked: false,
                isPrinceps: scanResult.summary.data.isPrinceps,
                form: scanResult.summary.data.formePharmaceutique,
                princepsLabel: scanResult.summary.data.princepsDeReference,
              ),
              scanResult: scanResult,
              toastMessage: '+1 ${scanResult.summary.data.nomCanonique}',
            );
          }
          return AnalysisSuccess(scanResult);
        },
      );
      when(
        () => orchestrator.updateQuantity(any(), any()),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          hapticSettingsProvider.overrideWith(
            (ref) => Stream<bool>.value(true),
          ),
          scanOrchestratorProvider.overrideWithValue(orchestrator),
        ],
      );
    });

    test('emits unknown haptic when barcode has no GTIN', () async {
      when(
        () => orchestrator.decide(
          'NOT_A_GTIN',
          any(),
          force: any(named: 'force'),
          scannedCodes: any(named: 'scannedCodes'),
          existingBubbles: any(named: 'existingBubbles'),
        ),
      ).thenAnswer((_) async => const ProductNotFound());
      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();

      final effects = <ScannerSideEffect>[];
      final sub = notifier.sideEffects.listen(effects.add);

      final barcode = MockBarcode()..rawValue = 'NOT_A_GTIN';
      final capture = MockBarcodeCapture([barcode]);

      await notifier.processBarcodeCapture(capture);

      expect(
        effects.whereType<ScannerHaptic>().any(
          (e) => e.type == ScannerHapticType.unknown,
        ),
        isTrue,
      );

      await sub.cancel();
    });

    test('restock success emits restockSuccess haptic', () async {
      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();
      notifier.setMode(ScannerMode.restock);

      final effects = <ScannerSideEffect>[];
      final sub = notifier.sideEffects.listen(effects.add);

      final barcode = MockBarcode()
        ..rawValue = generateGs1String('3400934056781');
      final capture = MockBarcodeCapture([barcode]);

      await notifier.processBarcodeCapture(capture);

      expect(
        effects.whereType<ScannerHaptic>().any(
          (e) => e.type == ScannerHapticType.restockSuccess,
        ),
        isTrue,
      );

      await sub.cancel();
    });

    test('restock duplicate emits duplicate haptic', () async {
      when(
        () => orchestrator.decide(
          any(),
          ScannerMode.restock,
          force: any(named: 'force'),
          scannedCodes: any(named: 'scannedCodes'),
          existingBubbles: any(named: 'existingBubbles'),
        ),
      ).thenAnswer(
        (_) async => const RestockDuplicate(
          DuplicateScanEvent(
            cip: '3400934056781',
            serial: 'SER123',
            productName: 'Produit CIS1',
            currentQuantity: 1,
          ),
        ),
      );

      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();
      notifier.setMode(ScannerMode.restock);

      final effects = <ScannerSideEffect>[];
      final sub = notifier.sideEffects.listen(effects.add);

      final barcode = MockBarcode()
        ..rawValue = generateGs1String(
          '3400934056781',
          serial: 'SER123',
        );
      final capture = MockBarcodeCapture([barcode]);

      await notifier.processBarcodeCapture(capture);

      expect(
        effects.whereType<ScannerHaptic>().any(
          (e) => e.type == ScannerHapticType.duplicate,
        ),
        isTrue,
      );

      await sub.cancel();
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
          () => orchestrator.decide(
            any(),
            ScannerMode.restock,
            force: any(named: 'force'),
            scannedCodes: any(named: 'scannedCodes'),
            existingBubbles: any(named: 'existingBubbles'),
          ),
        ).thenAnswer(
          (_) async => const RestockDuplicate(
            DuplicateScanEvent(
              cip: '3400934056781',
              serial: 'SER123',
              productName: 'Produit CIS1',
              currentQuantity: 2,
            ),
          ),
        );

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

    test('duplicate scans are cooled down (only one bubble added)', () async {
      var callCount = 0;
      when(
        () => orchestrator.decide(
          any(),
          any(),
          force: any(named: 'force'),
          scannedCodes: any(named: 'scannedCodes'),
          existingBubbles: any(named: 'existingBubbles'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount > 1) {
          return const Ignore();
        }
        return AnalysisSuccess(scanResult);
      });

      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();

      final capture = MockBarcodeCapture([
        MockBarcode()..rawValue = generateGs1String('3400934056781'),
      ]);

      await notifier.processBarcodeCapture(capture);
      await notifier.processBarcodeCapture(capture);

      final bubbles = container
          .read(scannerProvider)
          .maybeWhen(
            data: (state) => state.bubbles,
            orElse: () => <ScanBubble>[],
          );
      expect(bubbles.length, 1);
      expect(callCount, 2);
    });

    test('ignores rapid duplicate scans within cooldown window', () async {
      var callCount = 0;
      when(
        () => orchestrator.decide(
          any(),
          any(),
          force: any(named: 'force'),
          scannedCodes: any(named: 'scannedCodes'),
          existingBubbles: any(named: 'existingBubbles'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount > 1) {
          return const Ignore();
        }
        return AnalysisSuccess(scanResult);
      });

      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();

      final capture = MockBarcodeCapture([
        MockBarcode()..rawValue = generateGs1String('3400934056781'),
      ]);

      final futures = List.generate(
        5,
        (_) => notifier.processBarcodeCapture(capture),
      );
      await Future.wait(futures);

      final bubbles = container
          .read(scannerProvider)
          .maybeWhen(
            data: (state) => state.bubbles,
            orElse: () => <ScanBubble>[],
          );
      expect(bubbles.length, 1);
      expect(callCount, 5);
    });

    test('handles database timeout gracefully', () async {
      when(
        () => orchestrator.decide(
          any(),
          any(),
          force: any(named: 'force'),
          scannedCodes: any(named: 'scannedCodes'),
          existingBubbles: any(named: 'existingBubbles'),
        ),
      ).thenThrow(TimeoutException('db timeout'));

      final notifier = container.read(scannerProvider.notifier);
      await notifier.build();

      final effects = <ScannerSideEffect>[];
      final sub = notifier.sideEffects.listen(effects.add);

      final capture = MockBarcodeCapture([
        MockBarcode()..rawValue = generateGs1String('3400934056781'),
      ]);

      await notifier.processBarcodeCapture(capture);

      final state = container.read(scannerProvider);
      expect(state.hasError, isTrue);
      expect(
        effects.whereType<ScannerHaptic>().any(
          (e) => e.type == ScannerHapticType.error,
        ),
        isTrue,
      );
      await sub.cancel();
    });
  });
}
