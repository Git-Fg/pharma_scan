// integration_test/search_filter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';
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
      final results = await container.read(searchResultsProvider('').future);

      expect(results, isEmpty);
    });

    testWidgets('search provider handles whitespace-only query', (
      WidgetTester tester,
    ) async {
      // WHY: Use integration test container with initialized database
      await ensureIntegrationTestDatabase();
      final container = integrationTestContainer;

      // WHY: Whitespace-only query should return empty results
      final results = await container.read(searchResultsProvider('   ').future);

      expect(results, isEmpty);
    });
  });
}
