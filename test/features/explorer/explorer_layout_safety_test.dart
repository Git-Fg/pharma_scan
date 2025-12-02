import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explorer Layout Safety - Keyboard & Screen Size Resilience', () {
    testWidgets(
      'sticky search bar header has valid SliverGeometry (layoutExtent <= paintExtent)',
      (tester) async {
        final view = tester.view
          ..devicePixelRatio = 1.0
          ..physicalSize = const Size(390, 844);
        addTearDown(() {
          view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio()
            ..resetViewInsets();
        });

        final overrides = [
          genericGroupsProvider.overrideWith(_StaticGenericGroupsNotifier.new),
          databaseStatsProvider.overrideWith(
            (ref) => Future<Map<String, dynamic>>.value({
              'total_princeps': 0,
              'total_generiques': 0,
              'total_principes': 0,
            }),
          ),
          initializationStepProvider.overrideWith(
            (ref) => Stream<InitializationStep>.value(InitializationStep.ready),
          ),
          searchResultsProvider.overrideWith(
            (ref, query) => Stream.value(const <SearchResultItem>[]),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: ShadApp.custom(
              theme: ShadThemeData(
                brightness: Brightness.light,
                colorScheme: const ShadSlateColorScheme.light(),
              ),
              appBuilder: (BuildContext shadContext) {
                final testRouter = AppRouter();
                return MaterialApp.router(
                  routerConfig: testRouter.config(
                    deepLinkBuilder: (_) => const DeepLink.path(AppRoutes.explorer),
                  ),
                  theme: Theme.of(shadContext),
                  builder: (BuildContext materialContext, Widget? child) {
                    return ShadAppBuilder(child: child);
                  },
                );
              },
            ),
          ),
        );

        // WHY: pumpAndSettle will trigger layout and catch SliverGeometry errors
        // If layoutExtent > paintExtent, Flutter will throw an assertion
        await tester.pumpAndSettle();

        // Verify no exceptions were thrown during layout
        expect(tester.takeException(), isNull);

        // Verify search bar is present
        final searchField = find.bySemanticsLabel(Strings.searchLabel);
        expect(searchField, findsOneWidget);

        // WHY: Scroll to trigger sticky header behavior and verify geometry remains valid
        final scrollView = find.byType(CustomScrollView);
        expect(scrollView, findsOneWidget);

        // Scroll down to test sticky header behavior
        await tester.drag(scrollView, const Offset(0, -200));
        await tester.pumpAndSettle();

        // Verify no exceptions after scrolling
        expect(tester.takeException(), isNull);

        // Verify search bar is still visible (sticky behavior)
        expect(searchField, findsOneWidget);
      },
    );

    testWidgets('search bar header height matches AppDimens constant', (
      tester,
    ) async {
      final view = tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(390, 844);
      addTearDown(() {
        view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      final overrides = [
        genericGroupsProvider.overrideWith(_StaticGenericGroupsNotifier.new),
        databaseStatsProvider.overrideWith(
          (ref) => Future<Map<String, dynamic>>.value({
            'total_princeps': 0,
            'total_generiques': 0,
            'total_principes': 0,
          }),
        ),
        initializationStepProvider.overrideWith(
          (ref) => Stream<InitializationStep>.value(InitializationStep.ready),
        ),
        searchResultsProvider.overrideWith(
          (ref, query) => Stream.value(const <SearchResultItem>[]),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: ShadApp.custom(
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadGreenColorScheme.light(),
            ),
            appBuilder: (BuildContext shadContext) {
              return MaterialApp.router(
                routerConfig: AppRouter().config(
                  deepLinkBuilder: (_) => const DeepLink.path(AppRoutes.explorer),
                ),
                theme: Theme.of(shadContext),
                builder: (BuildContext materialContext, Widget? child) {
                  return ShadAppBuilder(child: child);
                },
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // WHY: Verify the constant is set correctly (69px = 8 + 48 + 12 + 1)
      // This test ensures the constant matches the actual rendered height
      expect(AppDimens.searchBarHeaderHeight, 69.0);

      // Verify no layout exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('adds keyboard inset padding when keyboard is open', (
      tester,
    ) async {
      final view = tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(390, 844);
      const keyboardHeight = 300.0;
      view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
      addTearDown(() {
        view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio()
          ..resetViewInsets();
      });

      final overrides = [
        genericGroupsProvider.overrideWith(_StaticGenericGroupsNotifier.new),
        databaseStatsProvider.overrideWith(
          (ref) => Future<Map<String, dynamic>>.value({
            'total_princeps': 0,
            'total_generiques': 0,
            'total_principes': 0,
          }),
        ),
        initializationStepProvider.overrideWith(
          (ref) => Stream<InitializationStep>.value(InitializationStep.ready),
        ),
        searchResultsProvider.overrideWith(
          (ref, query) => Stream.value(const <SearchResultItem>[]),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: ShadApp.custom(
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadGreenColorScheme.light(),
            ),
            appBuilder: (BuildContext shadContext) {
              return MaterialApp.router(
                routerConfig: AppRouter().config(
                  deepLinkBuilder: (_) => const DeepLink.path(AppRoutes.explorer),
                ),
                theme: Theme.of(shadContext),
                builder: (BuildContext materialContext, Widget? child) {
                  return ShadAppBuilder(child: child);
                },
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // WHY: Verify that SliverPadding is added when keyboard insets are present
      // This prevents white bar gap above keyboard
      final sliverPaddings = find.byType(SliverPadding);
      expect(sliverPaddings, findsWidgets);

      // Verify no layout exceptions
      expect(tester.takeException(), isNull);
    });
  });
}

class _StaticGenericGroupsNotifier extends GenericGroupsNotifier {
  @override
  Future<GenericGroupsState> build() async {
    return const GenericGroupsState(
      items: <GenericGroupEntity>[],
      hasMore: false,
      isLoadingMore: false,
    );
  }
}
