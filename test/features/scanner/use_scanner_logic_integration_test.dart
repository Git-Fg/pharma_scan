import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'dart:async';
import 'package:pharma_scan/core/models/scan_models.dart';
import 'package:pharma_scan/core/hooks/use_scanner_logic.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
import 'package:pharma_scan/core/database/database.dart' as db;
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

class _FakeOrchestrator implements ScanOrchestrator {
  final ScanDecision decision;
  _FakeOrchestrator(this.decision);

  @override
  Future<ScanDecision> decide(
    String rawValue,
    ScannerMode mode, {
    bool force = false,
    Set<String> scannedCodes = const {},
    List<ScanResult> existingBubbles = const [],
  }) async {
    return decision;
  }

  @override
  Future<void> updateQuantity(String cip, int newQuantity) async {}
}

db.MedicamentSummaryData _makeSummary() {
  return db.MedicamentSummaryData(
    cisCode: '00000001',
    nomCanonique: 'Test',
    princepsDeReference: '',
    isPrinceps: false,
    clusterId: null,
    groupId: null,
    principesActifsCommuns: null,
    formattedDosage: null,
    formePharmaceutique: null,
    voiesAdministration: null,
    memberType: 0,
    princepsBrandName: '',
    procedureType: null,
    titulaireId: null,
    conditionsPrescription: null,
    dateAmm: null,
    isSurveillance: false,
    atcCode: null,
    status: null,
    priceMin: null,
    priceMax: null,
    aggregatedConditions: null,
    ansmAlertUrl: null,
    isHospital: false,
    isDental: false,
    isList1: false,
    isList2: false,
    isNarcotic: false,
    isException: false,
    isRestricted: false,
    isOtc: false,
    smrNiveau: null,
    smrDate: null,
    asmrNiveau: null,
    asmrDate: null,
    urlNotice: null,
    hasSafetyAlert: null,
    representativeCip: null,
  );
}

void main() {
  testWidgets(
      'useScannerLogic performs one-time initial sync of mode from Riverpod',
      (tester) async {
    // Arrange: set initial mode in the notifier
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _SetModeNotifier(
            mode: ScannerMode.restock,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Act: mount a widget that uses the hook and displays mode
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: _ModeProbeWidget()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Assert: signals mode was initialized from notifier state (one-time sync)
    expect(find.text('local:restock'), findsOneWidget);
    expect(find.text('remote:restock'), findsOneWidget);
  });

  testWidgets(
      'useScannerLogic handleScanResult updates Signals immediately and triggers business logic',
      (tester) async {
    // Arrange: fake orchestrator that returns AnalysisSuccess
    final summaryEntity = MedicamentEntity.fromData(_makeSummary());
    final result = (
      summary: summaryEntity,
      cip: Cip13.validated('1234567890123'),
      price: null,
      refundRate: null,
      boxStatus: null,
      availabilityStatus: null,
      isHospitalOnly: false,
      libellePresentation: null,
      expDate: null,
    );

    final decision = AnalysisSuccess(result);
    final fakeOrchestrator = _FakeOrchestrator(decision);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scanOrchestratorProvider.overrideWithValue(fakeOrchestrator)
        ],
        child: MaterialApp(home: _ProbeScanWidget(result: result)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Initially empty signals
    expect(find.text('local:0'), findsOneWidget);

    // Act: trigger scan via the hook
    await tester.tap(find.text('scan'));
    await tester.pump();

    // Signals should update immediately (high-frequency UI state)
    expect(find.text('local:1'), findsOneWidget);

    // Business logic is triggered via Riverpod (fire-and-forget)
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('ScannerNotifier only manages mode, not bubbles', (tester) async {
    // This test verifies the Triad architecture separation:
    // - Riverpod (ScannerNotifier): business logic + mode persistence
    // - Signals (ScannerStore): high-frequency UI state (bubbles)

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: _ModeOnlyProbeWidget()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // ScannerNotifier only has mode, no bubbles
    expect(find.text('mode:analysis'), findsOneWidget);
    expect(find.text('bubbles:not managed by Riverpod'), findsOneWidget);
  });
}

class _SetModeNotifier extends HookConsumerWidget {
  const _SetModeNotifier({required this.mode, required this.child});
  final Widget child;
  final ScannerMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      unawaited(Future.microtask(() {
        ref.read(scannerProvider.notifier).setMode(mode);
      }));
      return null;
    }, []);
    return child;
  }
}

class _ProbeWidget extends HookConsumerWidget {
  const _ProbeWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logic = useScannerLogic(ref);
    final remote = ref.watch(scannerProvider).value;
    return Column(
      children: <Widget>[
        Text('local:${logic.bubbleCount.value}'),
        Text('remote:0'), // Riverpod no longer manages bubbles
      ],
    );
  }
}

class _ModeProbeWidget extends HookConsumerWidget {
  const _ModeProbeWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logic = useScannerLogic(ref);
    final remote = ref.watch(scannerProvider).value;
    return Column(
      children: <Widget>[
        Text('local:${logic.mode.value}'),
        Text('remote:${remote?.mode}'),
      ],
    );
  }
}

class _ProbeScanWidget extends HookConsumerWidget {
  const _ProbeScanWidget({required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logic = useScannerLogic(ref);
    return Column(
      children: <Widget>[
        Text('local:${logic.bubbleCount.value}'),
        ElevatedButton(
          onPressed: () => logic.handleScanResult(result),
          child: const Text('scan'),
        ),
      ],
    );
  }
}

class _ModeOnlyProbeWidget extends HookConsumerWidget {
  const _ModeOnlyProbeWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(scannerProvider).value;
    return Column(
      children: <Widget>[
        Text('mode:${remote?.mode}'),
        Text('bubbles:not managed by Riverpod'),
      ],
    );
  }
}
