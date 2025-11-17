// integration_test/generic_group_summaries_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_summary_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupLocator();
  });

  group('Generic Group Summaries Integration Tests', () {
    testWidgets(
      'should fetch group summaries with real TXT data and use algorithmic grouping',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real TXT files
        final dataService = sl<DataInitializationService>();
        final dbService = sl<DatabaseService>();

        // WHEN: Initialize database with real data
        await dataService.initializeDatabase();

        // THEN: Verify we can get group summaries for oral forms
        final summaries = await dbService.getGenericGroupSummaries(
          formKeywords: [
            'comprimé',
            'gélule',
            'capsule',
            'lyophilisat',
            'solution buvable',
            'sirop',
            'suspension buvable',
            'comprimé orodispersible',
          ],
          excludeKeywords: ['injectable', 'injection', 'vaginal', 'vaginale'],
          limit: 10,
          offset: 0,
        );

        // Verify we got results
        expect(
          summaries.length,
          greaterThan(0),
          reason: 'Should have at least one group summary for oral forms',
        );

        // Verify each summary has the new structure
        for (final summary in summaries) {
          expect(summary.groupId, isNotEmpty);
          expect(summary.commonPrincipes, isNotEmpty);
          expect(
            summary.princepsReferenceName,
            isNotEmpty,
            reason:
                'princepsReferenceName should be computed using algorithmic grouping',
          );

          // Verify princepsReferenceName is a single string (not a list)
          expect(summary.princepsReferenceName, isA<String>());

          // Verify the common name is reasonable (not empty, not "N/A" unless truly no common prefix)
          expect(
            summary.princepsReferenceName.length,
            greaterThan(0),
            reason: 'princepsReferenceName should not be empty',
          );
        }

        // Verify pagination works
        final nextPage = await dbService.getGenericGroupSummaries(
          formKeywords: ['comprimé', 'gélule', 'capsule'],
          excludeKeywords: ['injectable', 'injection', 'vaginal', 'vaginale'],
          limit: 10,
          offset: 10,
        );

        // Next page should have different results (or be empty if we've exhausted)
        expect(nextPage, isA<List<GenericGroupSummary>>());
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'should handle different form categories correctly',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real TXT files
        final dataService = sl<DataInitializationService>();
        final dbService = sl<DatabaseService>();

        await dataService.initializeDatabase();

        // WHEN: Get summaries for different form categories
        final injectableSummaries = await dbService.getGenericGroupSummaries(
          formKeywords: [
            'injectable',
            'injection',
            'perfusion',
            'solution pour perfusion',
            'poudre pour solution injectable',
            'solution pour injection',
          ],
          excludeKeywords: [],
          limit: 5,
          offset: 0,
        );

        final externalSummaries = await dbService.getGenericGroupSummaries(
          formKeywords: [
            'crème',
            'pommade',
            'gel',
            'lotion',
            'pâte',
            'cutanée',
            'cutané',
            'application locale',
            'application cutanée',
            'dispositif transdermique',
          ],
          excludeKeywords: ['vaginal', 'vaginale'],
          limit: 5,
          offset: 0,
        );

        // THEN: Verify results are appropriate for each category
        // (Some categories might have fewer results, which is fine)
        expect(injectableSummaries, isA<List<GenericGroupSummary>>());
        expect(externalSummaries, isA<List<GenericGroupSummary>>());

        // Verify all summaries have the correct structure
        for (final summary in [...injectableSummaries, ...externalSummaries]) {
          expect(summary.groupId, isNotEmpty);
          expect(summary.commonPrincipes, isNotEmpty);
          expect(summary.princepsReferenceName, isNotEmpty);
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'should compute common princeps names algorithmically',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real TXT files
        final dataService = sl<DataInitializationService>();
        final dbService = sl<DatabaseService>();

        await dataService.initializeDatabase();

        // WHEN: Get summaries
        final summaries = await dbService.getGenericGroupSummaries(
          limit: 20,
          offset: 0,
        );

        // THEN: Verify algorithmic grouping produces reasonable results
        for (final summary in summaries) {
          // The common name should be a meaningful prefix
          // It should not be just punctuation or whitespace
          final trimmed = summary.princepsReferenceName.trim();
          expect(trimmed.length, greaterThan(0));

          // The common name should typically be shorter than a full medication name
          // (unless there's only one princeps, in which case it might be the full name)
          // This is a soft check - we just verify it's not obviously wrong
          expect(
            summary.princepsReferenceName,
            isNot(contains('undefined')),
            reason: 'princepsReferenceName should not contain undefined',
          );
          expect(
            summary.princepsReferenceName,
            isNot(contains('null')),
            reason: 'princepsReferenceName should not contain null',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
