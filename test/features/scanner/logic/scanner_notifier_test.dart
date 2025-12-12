import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';

class MockScanOrchestrator extends Mock implements ScanOrchestrator {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScannerNotifier', () {
    late MockScanOrchestrator orchestrator;
    late ProviderContainer container;

    setUp(() {
      orchestrator = MockScanOrchestrator();

      container = ProviderContainer(
        overrides: [
          scanOrchestratorProvider.overrideWithValue(orchestrator),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is correct', () async {
      final state = await container.read(scannerProvider.future);

      expect(state, isNotNull);
      expect(state.mode, equals(ScannerMode.analysis));
    });
  });
}
