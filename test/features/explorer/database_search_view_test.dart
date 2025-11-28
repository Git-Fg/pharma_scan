import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/theme/pharma_theme_wrapper.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/explorer/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/screens/database_search_view.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search bar stays visible when keyboard insets are applied', (
    tester,
  ) async {
    final view = tester.view;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(390, 844);
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
      view.resetViewInsets();
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
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const PharmaThemeWrapper(
                  updateSystemUi: false,
                  child: DatabaseSearchView(),
                ),
              ),
            ],
          ),
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
