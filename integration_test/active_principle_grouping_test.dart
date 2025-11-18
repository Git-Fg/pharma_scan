// integration_test/active_principle_grouping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'test_bootstrap.dart';
import 'package:pharma_scan/core/utils/string_normalizer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureIntegrationTestDatabase();
  });

  testWidgets(
    'getGenericGroupSummaries should use deterministic BDPM data and avoid duplicates',
    (WidgetTester tester) async {
      // GIVEN: The database is initialized with real data.
      final dbService = sl<DatabaseService>();

      // WHEN: We fetch the group summaries for oral medications.
      final summaries = await dbService.getGenericGroupSummaries(limit: 2000);

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

      // AND: The ESOMEPRAZOLE group should expose the pure molecule name without dosage noise.
      final esomeprazoleEntry = summaries.firstWhere(
        (s) => normalize(s.commonPrincipes).contains('esomeprazole'),
      );
      expect(
        normalize(esomeprazoleEntry.commonPrincipes),
        startsWith('esomeprazole'),
        reason:
            'Deterministic extraction must return the exact active principle from principes_actifs (without dosage or units).',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
