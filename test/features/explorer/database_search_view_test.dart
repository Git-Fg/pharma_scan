import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/models/database_stats.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search bar stays visible when keyboard insets are applied', (
    tester,
  ) async {
    final view = tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(430, 844);
    addTearDown(() {
      view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio()
        ..resetViewInsets();
    });

    final overrides = [
      genericGroupsProvider.overrideWith(_StaticGenericGroupsNotifier.new),
      databaseStatsProvider.overrideWith(
        (ref) => Future<DatabaseStats>.value(
          (
            totalPrinceps: 0,
            totalGeneriques: 0,
            totalPrincipes: 0,
            avgGenPerPrincipe: 0.0,
          ),
        ),
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
    await tester.pumpAndSettle();

    final searchField = find.bySemanticsLabel(Strings.searchLabel);
    expect(searchField, findsOneWidget);

    await tester.tap(searchField);
    await tester.pump();

    view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final fieldRect = tester.getRect(searchField);

    expect(fieldRect.bottom, lessThanOrEqualTo(screenHeight));
    expect(tester.takeException(), isNull);

    // Clean up: ensure all timers are cancelled before test ends
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.binding.pump();
  });

  testWidgets(
    'index bar is visible when idle and hidden during search',
    (tester) async {
      final view = tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(430, 844);
      addTearDown(() {
        view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      final overrides = [
        genericGroupsProvider.overrideWith(_StaticGenericGroupsNotifier.new),
        databaseStatsProvider.overrideWith(
          (ref) => Future<DatabaseStats>.value(
            (
              totalPrinceps: 0,
              totalGeneriques: 0,
              totalPrincipes: 0,
              avgGenPerPrincipe: 0.0,
            ),
          ),
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
                  deepLinkBuilder: (_) =>
                      const DeepLink.path(AppRoutes.explorer),
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

      expect(find.byType(IndexBar), findsOneWidget);

      await tester.enterText(
        find.bySemanticsLabel(Strings.searchLabel),
        'paracetamol',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(IndexBar), findsNothing);
    },
  );

  testWidgets(
    'index bar jumps to the first matching letter',
    (tester) async {
      final view = tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(430, 844);
      addTearDown(() {
        view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });

      final overrides = [
        genericGroupsProvider.overrideWith(_LongListGroupsNotifier.new),
        databaseStatsProvider.overrideWith(
          (ref) => Future<DatabaseStats>.value(
            (
              totalPrinceps: 0,
              totalGeneriques: 0,
              totalPrincipes: 0,
              avgGenPerPrincipe: 0.0,
            ),
          ),
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
                  deepLinkBuilder: (_) =>
                      const DeepLink.path(AppRoutes.explorer),
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

      expect(find.byType(IndexBar), findsOneWidget);
      expect(find.text('Mystic Molecule'), findsNothing);

      await tester.tap(
        find.descendant(of: find.byType(IndexBar), matching: find.text('M')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.text('Mystic Molecule'), findsOneWidget);
    },
  );
}

class _StaticGenericGroupsNotifier extends GenericGroupsNotifier {
  @override
  Future<GenericGroupsState> build() async {
    return GenericGroupsState(
      items: <GenericGroupEntity>[
        GenericGroupEntity(
          groupId: GroupId.validated('GRP_A'),
          commonPrincipes: 'AP1',
          princepsReferenceName: 'Alpha',
        ),
        GenericGroupEntity(
          groupId: GroupId.validated('GRP_M'),
          commonPrincipes: 'AP2',
          princepsReferenceName: 'Molecule',
        ),
        GenericGroupEntity(
          groupId: GroupId.validated('GRP_Z'),
          commonPrincipes: 'AP3',
          princepsReferenceName: 'Zeta',
        ),
      ],
    );
  }
}

class _LongListGroupsNotifier extends GenericGroupsNotifier {
  @override
  Future<GenericGroupsState> build() async {
    return GenericGroupsState(items: _buildLongListGroups());
  }
}

List<GenericGroupEntity> _buildLongListGroups() {
  const letters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    'M',
    'N',
    'P',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  return [
    for (var i = 0; i < letters.length; i++)
      GenericGroupEntity(
        groupId: GroupId.validated('GRP_${letters[i]}_$i'),
        commonPrincipes: 'Principe ${letters[i]}',
        princepsReferenceName: letters[i] == 'M'
            ? 'Mystic Molecule'
            : 'Group ${letters[i]}',
      ),
    // Duplicate some early letters to ensure the list is long enough to scroll.
    GenericGroupEntity(
      groupId: GroupId.validated('GRP_A_EXTRA'),
      commonPrincipes: 'Principe A2',
      princepsReferenceName: 'Alpha Extra',
    ),
    GenericGroupEntity(
      groupId: GroupId.validated('GRP_B_EXTRA'),
      commonPrincipes: 'Principe B2',
      princepsReferenceName: 'Beta Extra',
    ),
  ];
}
