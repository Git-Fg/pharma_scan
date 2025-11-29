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
      // WHY: Use integration test container with initialized database
      await ensureIntegrationTestDatabase();
      final container = integrationTestContainer;

      // WHY: Empty query should return empty results immediately
      // Use a widget to watch the provider and get the stream value
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
      // WHY: Use integration test container with initialized database
      await ensureIntegrationTestDatabase();
      final container = integrationTestContainer;

      // WHY: Whitespace-only query should return empty results
      // Use a widget to watch the provider and get the stream value
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
  });
}
