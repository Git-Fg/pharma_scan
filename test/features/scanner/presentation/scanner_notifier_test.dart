import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_traffic_control.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class MockScanOrchestrator extends Mock implements ScanOrchestrator {}

class MockScanTrafficControl extends Mock implements ScanTrafficControl {}

class MockLoggerService extends Mock implements LoggerService {}

void main() {
  late MockScanOrchestrator mockOrchestrator;
  late MockScanTrafficControl mockTrafficControl;
  late MockLoggerService mockLogger;

  setUp(() {
    mockOrchestrator = MockScanOrchestrator();
    mockTrafficControl = MockScanTrafficControl();
    mockLogger = MockLoggerService();

    registerFallbackValue(ScannerMode.analysis);
    registerFallbackValue(BarcodeFormat.dataMatrix);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        scanOrchestratorProvider.overrideWithValue(mockOrchestrator),
        scanTrafficControlProvider.overrideWithValue(mockTrafficControl),
        loggerProvider.overrideWithValue(mockLogger),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('initial state is analysis mode', () async {
    final container = createContainer();
    final state = await container.read(scannerProvider.future);
    expect(state.mode, ScannerMode.analysis);
  });

  test('setMode updates state and resets traffic control', () async {
    final container = createContainer();
    final notifier = container.read(scannerProvider.notifier);

    // Initialize
    await container.read(scannerProvider.future);

    notifier.setMode(ScannerMode.restock);

    await container.pump();
    final state = await container.read(scannerProvider.future);

    expect(state.mode, ScannerMode.restock);
    verify(() => mockTrafficControl.reset()).called(1);
  });

  test('processBarcodeCapture delegates to orchestrator', () async {
    final container = createContainer();
    final notifier = container.read(scannerProvider.notifier);
    await container.read(scannerProvider.future);

    const barcodeValue = '1234567890123';
    final barcode =
        Barcode(rawValue: barcodeValue, format: BarcodeFormat.dataMatrix);
    final capture = BarcodeCapture(barcodes: [barcode]);

    when(() => mockOrchestrator.decide(any(), any(), any(),
        force: any(named: 'force'))).thenAnswer((_) async => const Ignore());

    await notifier.processBarcodeCapture(capture);

    verify(() => mockOrchestrator.decide(
        barcodeValue, BarcodeFormat.dataMatrix, ScannerMode.analysis,
        force: false)).called(1);
  });
}
