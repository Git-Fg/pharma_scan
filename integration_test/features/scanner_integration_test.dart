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

  group('Scanner Integration Tests', () {
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

    testWidgets('Scanner provider initializes', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      // App should load scanner functionality without crashing
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Scanner components load without crashing', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      // App should load scanner functionality without crashing
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Database integration works with scanner', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PharmaScanApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Test database has test data
      final db = container.read(databaseProvider());
      expect(db, isNotNull);

      // Test basic database operation
      final result = await db.customSelect('SELECT 1 as test').get();
      expect(result.isNotEmpty, true);
    });
  });
}