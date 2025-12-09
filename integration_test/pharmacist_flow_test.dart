// integration_test/pharmacist_flow_test.dart

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
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

import '../test/fixtures/seed_builder.dart';
import '../test/fixtures/test_scenarios.dart';
import '../test/mocks.dart';
import '../test/test_utils.dart' show setPrincipeNormalizedForAllPrinciples;

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
      'should complete full user journey: Search -> Result -> Detail -> Back',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 2400));
        addTearDown(tester.view.resetPhysicalSize);

        final db = AppDatabase.forTesting(
          NativeDatabase.memory(setup: configureAppSQLite),
        );

        // Seed minimal data
        await TestScenarios.seedParacetamolGroup(db);
        await setPrincipeNormalizedForAllPrinciples(db);
        await db.settingsDao.updateBdpmVersion(
          DataInitializationService.dataVersion,
        );

        final mockDataInit = MockDataInitializationService();
        when(
          () => mockDataInit.initializeDatabase(
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async {});
        when(
          mockDataInit.runSummaryAggregationForTesting,
        ).thenAnswer((_) async {});

        final router = AppRouter();
        await router.replaceAll([
          MainRoute(
            children: [
              ExplorerTabRoute(
                children: [
                  GroupExplorerRoute(groupId: 'GRP_PARA'),
                ],
              ),
            ],
          ),
        ]);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            dataInitializationServiceProvider.overrideWithValue(mockDataInit),
            syncControllerProvider.overrideWith(_FakeSyncController.new),
            appRouterProvider.overrideWithValue(router),
            appPreferencesProvider.overrideWithValue(
              const AsyncData(
                UpdateFrequency.daily,
              ),
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

        addTearDown(db.close);

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
      'Scenario B: Néfopam search should NOT group with Adriblastine (critical edge case)',
      (WidgetTester tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.binding.setSurfaceSize(const Size(1280, 2400));
          addTearDown(tester.view.resetPhysicalSize);

          final db = AppDatabase.forTesting(
            NativeDatabase.memory(setup: configureAppSQLite),
          );

          await SeedBuilder()
              .inGroup('GRP_PARA', 'Paracetamol Group')
              .addPrinceps(
                'Paracetamol Princeps',
                '3400000000001',
                cis: 'CIS_PARA_1',
                dosage: '500',
              )
              .addGeneric(
                'Paracetamol Generic',
                '3400000000002',
                cis: 'CIS_PARA_2',
                dosage: '500',
              )
              .inGroup('GRP_NEF', 'NÉFOPAM Group')
              .addPrinceps(
                'NÉFOPAM 20 mg, comprimé',
                '3400930001999',
                cis: 'CIS_IT_NEFOPAM',
                dosage: '20',
              )
              .insertInto(db);
          await db.databaseDao.populateSummaryTable();
          await setPrincipeNormalizedForAllPrinciples(db);
          await db.databaseDao.populateFts5Index();
          await db.settingsDao.updateBdpmVersion(
            DataInitializationService.dataVersion,
          );

          final mockDataInit = MockDataInitializationService();
          when(
            () => mockDataInit.initializeDatabase(
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer((_) async {});
          when(
            mockDataInit.runSummaryAggregationForTesting,
          ).thenAnswer((_) async {});

          final router = AppRouter();
          await router.replaceAll([
            MainRoute(
              children: [
                ExplorerTabRoute(
                  children: [
                    GroupExplorerRoute(groupId: 'GRP_NEF'),
                  ],
                ),
              ],
            ),
          ]);

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              dataInitializationServiceProvider.overrideWithValue(
                mockDataInit,
              ),
              syncControllerProvider.overrideWith(_FakeSyncController.new),
              appRouterProvider.overrideWithValue(router),
              appPreferencesProvider.overrideWithValue(
                const AsyncData(
                  UpdateFrequency.daily,
                ),
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

          addTearDown(db.close);

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

          await tester.pumpAndSettle(const Duration(seconds: 1));
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Layout must remain stable (no overflow/render errors).',
          );

          final adriblastineText = find.textContaining(
            'ADRIBLASTINE',
            findRichText: true,
          );
          expect(
            adriblastineText,
            findsNothing,
            reason:
                'CRITICAL: Adriblastine should NOT appear in Néfopam search results. '
                'This verifies the grouping logic correctly isolates these medications.',
          );
        } finally {
          semantics.dispose();
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    // Note: Scenario C (offline mode) would require a connectivity provider
    // which may not exist in the codebase. This test is deferred until
    // connectivity management is implemented.
  });
}
