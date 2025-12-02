// integration_test/search_filter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';

import 'test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FTS5 search provider integration', () {
    testWidgets('search provider handles empty query gracefully', (
      WidgetTester tester,
    ) async {
      await ensureIntegrationTestDatabase();
      final container = integrationTestContainer;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Builder(
            builder: (context) {
              container.read(searchResultsProvider('')).whenData((results) {
                expect(results, isEmpty);
              });
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('search provider handles whitespace-only query', (
      WidgetTester tester,
    ) async {
      await ensureIntegrationTestDatabase();
      final container = integrationTestContainer;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Builder(
            builder: (context) {
              container.read(searchResultsProvider('   ')).whenData((results) {
                expect(results, isEmpty);
              });
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('search provider returns results for common molecule query', (
      WidgetTester tester,
    ) async {
      await ensureIntegrationTestDatabase();
      final container = integrationTestContainer;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Builder(
            builder: (context) {
              container
                  .read(
                    searchResultsProvider('PARACETAMOL'),
                  )
                  .whenData((results) {
                    expect(
                      results,
                      isNotEmpty,
                      reason:
                          'FTS5 search should return results for a common molecule.',
                    );
                  });
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('search provider returns empty list for unknown query', (
      WidgetTester tester,
    ) async {
      await ensureIntegrationTestDatabase();
      final container = integrationTestContainer;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Builder(
            builder: (context) {
              container
                  .read(
                    searchResultsProvider('XYZ__NO_RESULTS_EXPECTED__123'),
                  )
                  .whenData((results) {
                    expect(results, isEmpty);
                  });
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
