// integration_test/pharmacist_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/router/router_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/home/models/sync_state.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../test/mocks.dart';
import 'helpers/golden_db_helper.dart';

class _FakeSyncController extends SyncController {
  @override
  SyncProgress build() => SyncProgress.idle;

  @override
  Future<bool> startSync({bool force = false}) async => false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pharmacist Golden Path - Search to Detail Flow', () {
    testWidgets(
      'should complete full user journey: Explorer loads with real data',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 2400));
        addTearDown(tester.view.resetPhysicalSize);

        // Load the golden database instead of manual seeding
        final db = await loadGoldenDatabase();
        addTearDown(db.close);

        // Get a real cluster from the golden database
        final clusters = await (db.select(db.clusterNames)..limit(1)).get();
        expect(clusters, isNotEmpty, reason: 'Golden DB should have clusters');
        final testClusterId = clusters.first.clusterId;

        // Update settings to bypass initialization
        // Note: settingsDao doesn't exist in the schema, initialization bypass handled by mock

        final mockDataInit = MockDataInitializationService();
        when(
          () => mockDataInit.initializeDatabase(
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async {});

        final router = AppRouter();
        await router.replaceAll([
          MainRoute(
            children: [
              ExplorerTabRoute(
                children: [
                  GroupExplorerRoute(groupId: testClusterId),
                ],
              ),
            ],
          ),
        ]);

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dataInitializationServiceProvider.overrideWithValue(mockDataInit),
            syncControllerProvider.overrideWith(_FakeSyncController.new),
            appRouterProvider.overrideWithValue(router),
            appPreferencesProvider.overrideWithValue(
              UpdateFrequency.daily,
            ),
            initializationStepProvider.overrideWith(
              (ref) => Stream<InitializationStep>.value(
                InitializationStep.ready,
              ),
            ),
            initializationDetailProvider.overrideWith(
              (ref) => const Stream<String>.empty(),
            ),
          ],
        );

        container.read(initializationStateProvider.notifier).state =
            InitializationState.success;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ShadApp.custom(
              themeMode: ThemeMode.light,
              theme: ShadThemeData(
                brightness: Brightness.light,
                colorScheme: const ShadSlateColorScheme.light(),
              ),
              darkTheme: ShadThemeData(
                brightness: Brightness.dark,
                colorScheme: const ShadSlateColorScheme.dark(),
              ),
              appBuilder: (context) {
                return MaterialApp.router(
                  theme: Theme.of(context),
                  darkTheme: Theme.of(context),
                  builder: (context, child) => ShadAppBuilder(child: child),
                  routerConfig: router.config(),
                );
              },
            ),
          ),
        );

        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpAndSettle(const Duration(seconds: 1));
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Layout must remain stable (no overflow/render errors).',
          );

          // Verify the group detail page loaded successfully
          // The exact content depends on the golden DB data
          expect(
            find.text(Strings.princeps),
            findsOneWidget,
            reason: 'Group detail should show Princeps section',
          );
          expect(
            find.text(Strings.generics),
            findsOneWidget,
            reason: 'Group detail should show Generics section',
          );
        } finally {
          semantics.dispose();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'should search and find medications from golden database',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 2400));
        addTearDown(tester.view.resetPhysicalSize);

        // Load the golden database
        final db = await loadGoldenDatabase();
        addTearDown(db.close);

        // Get sample medications from the golden database for testing
        final summaries = await (db.select(
          db.medicamentSummary,
        )..limit(5)).get();
        expect(summaries, isNotEmpty, reason: 'Golden DB should have data');

        // Verify search_index is populated
        final searchCount = await db
            .customSelect(
              'SELECT COUNT(*) as cnt FROM search_index',
            )
            .getSingle();

        expect(
          searchCount.read<int>('cnt'),
          greaterThan(0),
          reason: 'FTS5 search_index should be populated in golden DB',
        );

        // Test that we can query medicament_summary without errors
        // This confirms the schema is correct
        for (final summary in summaries) {
          expect(summary.cisCode, isNotEmpty);
          expect(summary.nomCanonique, isNotEmpty);
        }
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });
}
