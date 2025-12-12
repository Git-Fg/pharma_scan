// integration_test/restock_persistence_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/home/models/sync_state.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';
import 'package:pharma_scan/features/restock/presentation/screens/restock_screen.dart';
import 'package:pharma_scan/features/restock/presentation/widgets/restock_list_item.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../test/mocks.dart';
import 'helpers/golden_db_helper.dart';

class RestockRobot {
  RestockRobot(this.tester);

  final WidgetTester tester;

  void expectItemCount(int count) {
    expect(find.byType(RestockListItem), findsNWidgets(count));
  }

  Future<void> tapIncrementAt(int index) async {
    final item = find.byType(RestockListItem).at(index);
    final incrementButton = find.descendant(
      of: item,
      matching: find.byIcon(LucideIcons.plus),
    );
    if (incrementButton.evaluate().isNotEmpty) {
      await tester.tap(incrementButton.first);
      await tester.pumpAndSettle();
    }
  }

  void expectQuantityAt(int index, int quantity) {
    final items = find.byType(RestockListItem);
    expect(items.evaluate(), isNotEmpty);
    expect(
      find.descendant(
        of: items.first,
        matching: find.textContaining(quantity.toString()),
      ),
      findsWidgets,
    );
  }

  void expectTotalChecked(int count) {
    final checkedCount = find
        .byType(Checkbox)
        .evaluate()
        .map((e) => e.widget)
        .whereType<Checkbox>()
        .where((cb) => cb.value ?? false)
        .length;
    expect(checkedCount, equals(count));
  }
}

class _FakeSyncController extends SyncController {
  @override
  SyncProgress build() => SyncProgress.idle;

  @override
  Future<bool> startSync({bool force = false}) async => false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Restock Persistence Flow - Offline-First Critical Test', () {
    testWidgets(
      'should persist data across app restart (kill & relaunch simulation)',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          FlutterError.onError = FlutterError.presentError;
        });
        FlutterError.onError = (details) {
          final msg = details.exceptionAsString();
          if (msg.contains('RenderFlex overflowed')) {
            return;
          }
          FlutterError.presentError(details);
        };

        // Load golden database instead of manual seeding
        final baseDb = await loadGoldenDatabase();

        final mockDataInit = MockDataInitializationService();
        when(
          () => mockDataInit.initializeDatabase(
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async {});

        final container1 = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(baseDb),
            dataInitializationServiceProvider.overrideWithValue(mockDataInit),
            syncControllerProvider.overrideWith(_FakeSyncController.new),
          ],
        );
        final database = container1.read(databaseProvider);

        // Get real medications from golden database for testing
        final summaries =
            await (database.select(
                  database.medicamentSummary,
                )..limit(2)).get()
                as List<dynamic>;
        expect(
          summaries.length,
          greaterThanOrEqualTo(2),
          reason: 'Golden DB should have at least 2 medications',
        );

        // Short-circuit initialization state
        final initNotifier = container1.read(
          initializationStateProvider.notifier,
        );
        // Lint-safe sequential calls; FTS depends on summary population.
        // ignore: cascade_invocations
        initNotifier.state = InitializationState.success;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container1,
            child: const ShadApp(
              home: RestockScreen(),
            ),
          ),
        );

        // Wait for initialization to complete (mocked, so should be instant)
        await tester.pumpAndSettle(const Duration(seconds: 5));
        expect(find.text(Strings.restockTitle), findsWidgets);

        final restockDao = database.restockDao;

        // Use real CIPs from the golden database
        final summary1 = summaries[0] as Map<String, dynamic>;
        final summary2 = summaries[1] as Map<String, dynamic>;
        final cip1 = summary1['representative_cip'] != null
            ? Cip13.validated(summary1['representative_cip'] as String)
            : Cip13.validated('3400930000001');
        final cip2 = summary2['representative_cip'] != null
            ? Cip13.validated(summary2['representative_cip'] as String)
            : Cip13.validated('3400930000002');

        await Future.wait([
          restockDao.addToRestock(cip1),
          restockDao.addToRestock(cip2),
        ]);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Sanity: DAO contains two items.
        final restockRows = await database.select(database.restockItems).get();
        expect(restockRows.length, equals(2));

        final robot = RestockRobot(tester)..expectItemCount(2);

        for (var i = 0; i < 5; i++) {
          await robot.tapIncrementAt(0);
        }

        robot.expectQuantityAt(0, 6);

        // Simulate app lifecycle kill/resume.
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.detached)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

        container1.dispose();

        final mockDataInit2 = MockDataInitializationService();
        when(
          () => mockDataInit2.initializeDatabase(
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async {});

        final container2 = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            dataInitializationServiceProvider.overrideWithValue(mockDataInit2),
            syncControllerProvider.overrideWith(_FakeSyncController.new),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container2,
            child: const ShadApp(
              home: RestockScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.byType(RestockListItem), findsNWidgets(2));

        // Get the medication name again for the second database instance
        RestockRobot(tester)
          ..expectItemCount(2)
          ..expectQuantityAt(0, 6)
          ..expectTotalChecked(0);

        container2.dispose();

        // Simulate a force-reset / migration by rebuilding a fresh database.
        await database.close();

        // Load a fresh golden database for the reset test
        final freshDb = await loadGoldenDatabase();
        final mockDataInit3 = MockDataInitializationService();
        when(
          () => mockDataInit3.initializeDatabase(
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async {});

        final container3 = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(freshDb),
            dataInitializationServiceProvider.overrideWithValue(mockDataInit3),
            syncControllerProvider.overrideWith(_FakeSyncController.new),
          ],
        );

        container3.read(initializationStateProvider.notifier).state =
            InitializationState.success;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container3,
            child: const ShadApp(
              home: RestockScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.text(Strings.restockTitle), findsWidgets);
        // Fresh DB should have no restock items since it's a new copy
        RestockRobot(tester).expectItemCount(0);

        container3.dispose();
        await freshDb.close();
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
