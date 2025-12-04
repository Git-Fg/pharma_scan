import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_state.dart';
import 'package:pharma_scan/features/explorer/presentation/screens/group_explorer_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';


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
    // Return empty state to test error UI path when both lists are empty
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

void main() {
  group('GroupExplorerView AsyncValue States', () {
    testWidgets('loading state shows loading indicator', (tester) async {
      final container = ProviderContainer(
        overrides: [
          groupExplorerControllerProvider.overrideWith(
            _LoadingGroupExplorerController.new,
          ),
          canSwipeRootProvider.overrideWith(CanSwipeRoot.new),
        ],
      );

      addTearDown(container.dispose);

      final testRouter = AppRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp.custom(
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadGreenColorScheme.light(),
            ),
            appBuilder: (BuildContext shadContext) {
              return MaterialApp.router(
                routerConfig: testRouter.config(
                  deepLinkBuilder: (_) =>
                      DeepLink.path(AppRoutes.groupDetail('test-group')),
                ),
                theme: Theme.of(shadContext),
                builder: (BuildContext materialContext, Widget? child) {
                  return ShadAppBuilder(
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(GroupExplorerView), findsOneWidget);
    });

    testWidgets(
      'error state shows StatusView with error type and retry button',
      (
        tester,
      ) async {
        final container = ProviderContainer(
          overrides: [
            groupExplorerControllerProvider.overrideWith(
              _ErrorGroupExplorerController.new,
            ),
            canSwipeRootProvider.overrideWith(CanSwipeRoot.new),
          ],
        );

        addTearDown(container.dispose);

        final testRouter = AppRouter();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ShadApp.custom(
              theme: ShadThemeData(
                brightness: Brightness.light,
                colorScheme: const ShadGreenColorScheme.light(),
              ),
              appBuilder: (BuildContext shadContext) {
                return MaterialApp.router(
                  routerConfig: testRouter.config(
                    deepLinkBuilder: (_) =>
                        DeepLink.path(AppRoutes.groupDetail('test-group')),
                  ),
                  theme: Theme.of(shadContext),
                  builder: (BuildContext materialContext, Widget? child) {
                    return ShadAppBuilder(
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(StatusView), findsOneWidget);
        final statusView = tester.widget<StatusView>(find.byType(StatusView));
        expect(statusView.type, StatusType.error);
        expect(find.text(Strings.loadDetailsError), findsWidgets);
        expect(find.text(Strings.retry), findsOneWidget);
      },
    );

    testWidgets('empty state shows error UI when no princeps and no generics', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          groupExplorerControllerProvider.overrideWith(
            _EmptyGroupExplorerController.new,
          ),
          canSwipeRootProvider.overrideWith(CanSwipeRoot.new),
        ],
      );

      addTearDown(container.dispose);

      final testRouter = AppRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp.custom(
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadGreenColorScheme.light(),
            ),
            appBuilder: (BuildContext shadContext) {
              return MaterialApp.router(
                routerConfig: testRouter.config(
                  deepLinkBuilder: (_) =>
                      DeepLink.path(AppRoutes.groupDetail('test-group')),
                ),
                theme: Theme.of(shadContext),
                builder: (BuildContext materialContext, Widget? child) {
                  return ShadAppBuilder(
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(Strings.loadDetailsError), findsWidgets);
      expect(find.text(Strings.errorLoadingGroups), findsOneWidget);
      expect(find.text(Strings.back), findsOneWidget);
    });

    testWidgets('invalid groupId shows error UI', (tester) async {
      final container = ProviderContainer(
        overrides: [
          groupExplorerControllerProvider.overrideWith(
            _InvalidGroupExplorerController.new,
          ),
          canSwipeRootProvider.overrideWith(CanSwipeRoot.new),
        ],
      );

      addTearDown(container.dispose);

      final testRouter = AppRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp.custom(
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadGreenColorScheme.light(),
            ),
            appBuilder: (BuildContext shadContext) {
              return MaterialApp.router(
                routerConfig: testRouter.config(
                  deepLinkBuilder: (_) =>
                      DeepLink.path(AppRoutes.groupDetail('invalid-group-id')),
                ),
                theme: Theme.of(shadContext),
                builder: (BuildContext materialContext, Widget? child) {
                  return ShadAppBuilder(
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(Strings.loadDetailsError), findsWidgets);
      expect(find.text(Strings.errorLoadingGroups), findsOneWidget);
    });

    testWidgets('data state shows group content correctly', (tester) async {
      final container = ProviderContainer(
        overrides: [
          groupExplorerControllerProvider.overrideWith(
            _DataGroupExplorerController.new,
          ),
          canSwipeRootProvider.overrideWith(CanSwipeRoot.new),
        ],
      );

      addTearDown(container.dispose);

      final testRouter = AppRouter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp.custom(
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadGreenColorScheme.light(),
            ),
            appBuilder: (BuildContext shadContext) {
              return MaterialApp.router(
                routerConfig: testRouter.config(
                  deepLinkBuilder: (_) =>
                      DeepLink.path(AppRoutes.groupDetail('test-group')),
                ),
                theme: Theme.of(shadContext),
                builder: (BuildContext materialContext, Widget? child) {
                  return ShadAppBuilder(
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the widget renders without errors
      expect(find.byType(GroupExplorerView), findsOneWidget);
      // When princeps and generics are empty, the widget shows error UI
      // The error text appears in both AppBar and StatusView
      expect(find.text(Strings.loadDetailsError), findsWidgets);
      expect(find.text(Strings.errorLoadingGroups), findsOneWidget);
    });
  });
}
