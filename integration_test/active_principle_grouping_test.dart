// integration_test/active_principle_grouping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/database_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupLocator();
  });

  testWidgets(
    'getGenericGroupSummaries should group by cleaned official label and not have duplicates',
    (WidgetTester tester) async {
      // GIVEN: The database is initialized with real data.
      final dataService = sl<DataInitializationService>();
      final dbService = sl<DatabaseService>();
      await dataService.initializeDatabase();

      // WHEN: We fetch the group summaries for oral medications.
      final summaries = await dbService.getGenericGroupSummaries(limit: 500);

      // THEN: The list should not be empty.
      expect(summaries, isNotEmpty);

      // AND: There should be no duplicate entries for the same cleaned principle name.
      final activePrinciples = summaries.map((s) => s.commonPrincipes).toList();
      final uniqueActivePrinciples = activePrinciples.toSet();

      expect(
        activePrinciples.length,
        uniqueActivePrinciples.length,
        reason: 'Each cleaned active principle label should only appear once.',
      );

      // AND: Specifically verify the "ACICLOVIR" case.
      final aciclovirEntries = summaries
          .where((s) => s.commonPrincipes.toUpperCase().startsWith('ACICLOVIR'))
          .toList();

      expect(
        aciclovirEntries.length,
        1,
        reason:
            'There should be exactly one summary for ACICLOVIR, aggregating all groups.',
      );

      // AND: The reference name should be the clean base name "ZOVIRAX".
      final aciclovirSummary = aciclovirEntries.first;
      expect(
        aciclovirSummary.princepsReferenceName.toUpperCase(),
        startsWith('ZOVIRAX'),
        reason: 'The reference name should be the common base name "ZOVIRAX".',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
