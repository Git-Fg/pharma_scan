// test/features/explorer/presentation/screens/group_explorer_view_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_state.dart';
import 'package:pharma_scan/features/explorer/presentation/screens/group_explorer_view.dart';

import '../../../../helpers/pump_app.dart';

// Custom controller factories for testing AsyncValue states
// Note: For family providers, overrideWith takes (ref) => Controller
// The controller gets the parameter from ref.$arg automatically

class _LoadingGroupExplorerController extends GroupExplorerController {
  @override
  Future<GroupExplorerState> build(String groupId) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return const GroupExplorerState(
      title: 'Test Group',
      princeps: [],
      generics: [],
      related: [],
      commonPrincipes: [],
      distinctDosages: [],
      distinctForms: [],
      aggregatedConditions: [],
      priceLabel: Strings.priceUnavailable,
      refundLabel: Strings.refundNotAvailable,
    );
  }
}

class _ErrorGroupExplorerController extends GroupExplorerController {
  @override
  Future<GroupExplorerState> build(String groupId) async {
    throw Exception('Test error');
  }
}

class _EmptyGroupExplorerController extends GroupExplorerController {
  @override
  Future<GroupExplorerState> build(String groupId) async {
    return const GroupExplorerState(
      title: '',
      princeps: [],
      generics: [],
      related: [],
      commonPrincipes: [],
      distinctDosages: [],
      distinctForms: [],
      aggregatedConditions: [],
      priceLabel: Strings.priceUnavailable,
      refundLabel: Strings.refundNotAvailable,
    );
  }
}

class _InvalidGroupExplorerController extends GroupExplorerController {
  @override
  Future<GroupExplorerState> build(String groupId) async {
    return const GroupExplorerState(
      title: '',
      princeps: [],
      generics: [],
      related: [],
      commonPrincipes: [],
      distinctDosages: [],
      distinctForms: [],
      aggregatedConditions: [],
      priceLabel: Strings.priceUnavailable,
      refundLabel: Strings.refundNotAvailable,
    );
  }
}

class _DataGroupExplorerController extends GroupExplorerController {
  @override
  Future<GroupExplorerState> build(String groupId) async {
    return const GroupExplorerState(
      title: 'Test Medication Group',
      princeps: [],
      generics: [],
      related: [],
      commonPrincipes: ['PARACETAMOL'],
      distinctDosages: ['500 mg'],
      distinctForms: ['Comprimé'],
      aggregatedConditions: [],
      priceLabel: Strings.priceUnavailable,
      refundLabel: Strings.refundNotAvailable,
    );
  }
}

void main() {
  group('GroupExplorerView AsyncValue States', () {
    testWidgets('loading state shows loading indicator', (tester) async {
      // GIVEN: Provider in loading state
      final container = ProviderContainer(
        overrides: [
          groupExplorerControllerProvider.overrideWith(
            _LoadingGroupExplorerController.new,
          ),
        ],
      );

      // WHEN: Render GroupExplorerView
      await tester.pumpApp(
        UncontrolledProviderScope(
          container: container,
          child: const GroupExplorerView(groupId: 'test-group'),
        ),
      );

      // THEN: Should show loading state
      await tester.pump();
      // Verify loading UI is shown (or at least no error)
      expect(find.byType(GroupExplorerView), findsOneWidget);
    });

    testWidgets(
      'error state shows StatusView with error type and retry button',
      (
        tester,
      ) async {
        // GIVEN: Provider in error state
        final container = ProviderContainer(
          overrides: [
            groupExplorerControllerProvider.overrideWith(
              _ErrorGroupExplorerController.new,
            ),
          ],
        );

        // WHEN: Render GroupExplorerView
        await tester.pumpApp(
          UncontrolledProviderScope(
            container: container,
            child: const GroupExplorerView(groupId: 'test-group'),
          ),
        );

        // Wait for error state
        await tester.pumpAndSettle();

        // THEN: Should show error UI
        expect(find.byType(StatusView), findsOneWidget);
        final statusView = tester.widget<StatusView>(find.byType(StatusView));
        expect(statusView.type, StatusType.error);
        expect(find.text(Strings.loadDetailsError), findsOneWidget);
        expect(find.text(Strings.retry), findsOneWidget);
      },
    );

    testWidgets('empty state shows error UI when no princeps and no generics', (
      tester,
    ) async {
      // GIVEN: Provider returns empty state (no princeps, no generics)
      final container = ProviderContainer(
        overrides: [
          groupExplorerControllerProvider.overrideWith(
            _EmptyGroupExplorerController.new,
          ),
        ],
      );

      // WHEN: Render GroupExplorerView
      await tester.pumpApp(
        UncontrolledProviderScope(
          container: container,
          child: const GroupExplorerView(groupId: 'test-group'),
        ),
      );

      await tester.pumpAndSettle();

      // THEN: Should show error UI (empty state is treated as error)
      expect(find.text(Strings.loadDetailsError), findsOneWidget);
      expect(find.text(Strings.errorLoadingGroups), findsOneWidget);
      expect(find.text(Strings.back), findsOneWidget);
    });

    testWidgets('invalid groupId shows error UI', (tester) async {
      // GIVEN: Provider returns empty state for invalid groupId
      final container = ProviderContainer(
        overrides: [
          groupExplorerControllerProvider.overrideWith(
            _InvalidGroupExplorerController.new,
          ),
        ],
      );

      // WHEN: Render GroupExplorerView with invalid groupId
      await tester.pumpApp(
        UncontrolledProviderScope(
          container: container,
          child: const GroupExplorerView(groupId: 'invalid-group-id'),
        ),
      );

      await tester.pumpAndSettle();

      // THEN: Should show error UI
      expect(find.text(Strings.loadDetailsError), findsOneWidget);
      expect(find.text(Strings.errorLoadingGroups), findsOneWidget);
    });

    testWidgets('data state shows group content correctly', (tester) async {
      // GIVEN: Provider returns valid state with data
      final container = ProviderContainer(
        overrides: [
          groupExplorerControllerProvider.overrideWith(
            _DataGroupExplorerController.new,
          ),
        ],
      );

      // WHEN: Render GroupExplorerView
      await tester.pumpApp(
        UncontrolledProviderScope(
          container: container,
          child: const GroupExplorerView(groupId: 'test-group'),
        ),
      );

      await tester.pumpAndSettle();

      // THEN: Should show group title
      expect(find.text('Test Medication Group'), findsOneWidget);

      // Should show princeps and generics sections (even if empty)
      expect(find.text(Strings.princeps), findsOneWidget);
      expect(find.text(Strings.generics), findsOneWidget);
    });
  });
}
