import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/main.dart';
import '../../test/helpers/test_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Database Integration Tests', () {
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

    testWidgets('Database provider integration works', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Test database access through provider
      final db = container.read(databaseProvider());
      expect(db, isNotNull);

      // Test database operations work
      final testResult = await db.customSelect('SELECT 1 as test').get();
      expect(testResult.isNotEmpty, true);
    });

    testWidgets('App initializes with test database', (tester) async {
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

    testWidgets('Database operations execute correctly', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      final db = container.read(databaseProvider());
      expect(db, isNotNull);

      // Test basic database operation
      final result = await db.customSelect('SELECT COUNT(*) as count FROM sqlite_master').get();
      expect(result.first.read<int>('count'), greaterThan(0));
    });
  });
}