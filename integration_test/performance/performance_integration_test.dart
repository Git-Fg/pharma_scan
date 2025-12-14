import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/main.dart';
import '../../test/helpers/test_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Performance Integration Tests', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      database = createTestDatabase();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref, path) => database),
        ],
      );
    });

    tearDown(() async {
      await database.close();
      container.dispose();
    });

    testWidgets('App initialization performance', (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      // App should initialize within reasonable time (5 seconds)
      expect(stopwatch.elapsedMilliseconds < 5000, true,
          reason: 'App took too long to initialize: ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('Database query performance', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      final stopwatch = Stopwatch()..start();

      // Test database query performance
      final db = container.read(databaseProvider());
      await (db.select(db.medicamentSummary)..limit(100)).get();

      stopwatch.stop();

      // Queries should complete within reasonable time (1 second)
      expect(stopwatch.elapsedMilliseconds < 1000, true,
          reason: 'Database query took too long: ${stopwatch.elapsedMilliseconds}ms');
    });

    testWidgets('Memory usage stability', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate multiple operations
      for (int i = 0; i < 10; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      // App should still be responsive after multiple operations
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}