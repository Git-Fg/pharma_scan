import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/models/database_stats.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search bar stays visible when keyboard insets are applied', (
    tester,
  ) async {
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
