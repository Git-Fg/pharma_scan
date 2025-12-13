<<<<<<< HEAD
// Integration tests replaced by Patrol e2e tests.
// Previously this file contained integration tests for `useScannerLogic`.
// They were removed in favor of a more complete Patrol end-to-end test
// located at `patrol_test/scanner_e2e_test.dart`.

void main() {}
=======
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'dart:async';
import 'package:pharma_scan/core/models/scan_models.dart';
import 'package:pharma_scan/core/hooks/use_scanner_logic.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
import 'package:pharma_scan/core/database/reference_schema.drift.dart' as db;
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
  testWidgets('useScannerLogic performs one-time initial sync from Riverpod',
      (tester) async {
    // Arrange: add an initial bubble into the notifier state
    final summaryEntity = MedicamentEntity.fromData(_makeSummary());
    final scan = (
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

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _PrepopulateNotifier(
            scan: scan,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Act: mount a widget that uses the hook and displays counts
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: _ProbeWidget()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Assert: signals were initialized from notifier state (one-time sync)
    expect(find.text('local:1'), findsOneWidget);
    expect(find.text('remote:1'), findsOneWidget);
  });

  testWidgets('useScannerLogic handleScanResult updates Signals immediately and triggers persistence',
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
        overrides: [scanOrchestratorProvider.overrideWithValue(fakeOrchestrator)],
        child: MaterialApp(home: _ProbeScanWidget(result: result)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Initially empty
    expect(find.text('local:0'), findsOneWidget);
    expect(find.text('remote:0'), findsOneWidget);

    // Act: trigger scan via the hook
    await tester.tap(find.text('scan'));
    await tester.pump();

    // Signals should update immediately
    expect(find.text('local:1'), findsOneWidget);

    // After async persistence, Riverpod state should be updated
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('remote:1'), findsOneWidget);
  });
}

class _PrepopulateNotifier extends HookConsumerWidget {
  const _PrepopulateNotifier({required this.scan, required this.child});
  final Widget child;
  final ScanResult scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      unawaited(Future.microtask(() {
        ref.read(scannerProvider.notifier).addBubble(scan);
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
        Text('remote:${remote?.bubbles.length ?? 0}'),
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
    final remote = ref.watch(scannerProvider).value;
      return Column(
        children: <Widget>[
        Text('local:${logic.bubbleCount.value}'),
        Text('remote:${remote?.bubbles.length ?? 0}'),
        ElevatedButton(
          onPressed: () => logic.handleScanResult(result),
          child: const Text('scan'),
        ),
      ],
    );
  }
}
>>>>>>> worktree-2025-12-13T23-31-16
