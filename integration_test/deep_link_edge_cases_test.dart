// integration_test/deep_link_edge_cases_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/router/router_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/main.dart';
import 'test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Deep Link Edge Cases', () {
    testWidgets(
      'invalid groupId shows error UI',
      (WidgetTester tester) async {
        await ensureIntegrationTestDatabase();
        final container = integrationTestContainer;

        // WHEN: Launch the app
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PharmaScanApp(),
          ),
        );

        // Wait for app to initialize
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Navigate to invalid groupId via router
        final router = container.read(appRouterProvider);
        await router.push(
          GroupExplorerRoute(groupId: 'invalid-group-id-that-does-not-exist'),
        );
        await tester.pumpAndSettle();

        // THEN: Should show error UI
        expect(find.text(Strings.loadDetailsError), findsOneWidget);
        expect(find.text(Strings.errorLoadingGroups), findsOneWidget);
        expect(find.text(Strings.back), findsOneWidget);

        // Verify StatusView with error type is shown
        expect(find.byType(StatusView), findsOneWidget);
        final statusView = tester.widget<StatusView>(find.byType(StatusView));
        expect(statusView.type, StatusType.error);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'empty groupId parameter is handled gracefully',
      (WidgetTester tester) async {
        await ensureIntegrationTestDatabase();
        final container = integrationTestContainer;

        // WHEN: Launch the app
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PharmaScanApp(),
          ),
        );

        // Wait for app to initialize
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Try to navigate with empty groupId (if route allows it)
        // Note: AutoRoute may prevent this at route level, but we test the view's handling
        final router = container.read(appRouterProvider);
        try {
          await router.push(GroupExplorerRoute(groupId: ''));
          await tester.pumpAndSettle();
        } on Exception {
          // Route may reject empty groupId - that's acceptable
          // The test verifies the app doesn't crash
        }

        // THEN: App should not crash
        expect(tester.takeException(), isNull);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
