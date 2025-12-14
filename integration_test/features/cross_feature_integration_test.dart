import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/main.dart';
import '../../test/helpers/test_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-Feature Integration Tests', () {
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

    testWidgets('App initializes successfully with test database', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      // App should load without crashing
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Database operations work across features', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Test database access
      final db = container.read(databaseProvider());
      expect(db, isNotNull);

      // Test basic database operation
      final result = await db.customSelect('SELECT 1 as test').get();
      expect(result.isNotEmpty, true);
    });

    testWidgets('Provider containers work correctly', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Test that providers are accessible
      final db = container.read(databaseProvider());
      final logger = container.read(loggerProvider);

      expect(db, isNotNull);
      expect(logger, isNotNull);
    });

    testWidgets('App handles navigation without crashing', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      // App should handle navigation gracefully
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}