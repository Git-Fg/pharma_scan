// integration_test/search_filter_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/features/explorer/models/search_candidate_model.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Fuzzy search provider integration', () {
    testWidgets('filters out homeopathic entries by default', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          searchCandidatesProvider.overrideWith(
            (ref) async => [
              _buildCandidate(
                cisCode: 'CIS_CONV',
                nomCanonique: 'MEDICAMENT TEST',
                groupId: 'GROUP_CONV',
                isPrinceps: true,
                procedureType: 'Autorisation',
                medicamentName: 'MEDICAMENT TEST',
              ),
              _buildCandidate(
                cisCode: 'CIS_HOMEO',
                nomCanonique: 'MEDICAMENT HOMEO',
                groupId: 'GROUP_HOMEO',
                isPrinceps: true,
                procedureType: 'Enreg homéo (Proc. Nat.)',
                medicamentName: 'MEDICAMENT HOMEO',
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final results = await container.read(
        searchResultsProvider('medicament').future,
      );

      expect(results, isA<List<SearchResultItem>>());
      expect(results.length, 1);
      results.first.when(
        princepsResult:
            (unusedPrinceps, unusedGenerics, groupId, unusedPrinciples) {
              expect(groupId, 'GROUP_CONV');
            },
        genericResult:
            (unusedGeneric, unusedPrinceps, groupId, unusedPrinciples) {
              expect(groupId, 'GROUP_CONV');
            },
        standaloneResult: (unusedMedicament, unusedPrinciples) {
          fail('Expected grouped result for filtered search');
        },
      );
    });

    testWidgets('returns grouped princeps results with generics', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          searchCandidatesProvider.overrideWith(
            (ref) async => [
              _buildCandidate(
                cisCode: 'CIS_PRINCEPS',
                nomCanonique: 'DOLIPRANE',
                groupId: 'GROUP_1',
                isPrinceps: true,
                procedureType: 'Autorisation',
                medicamentName: 'DOLIPRANE 500mg',
                commonPrinciples: ['PARACETAMOL'],
              ),
              _buildCandidate(
                cisCode: 'CIS_GENERIC',
                nomCanonique: 'DOLIPRANE GENERIQUE',
                groupId: 'GROUP_1',
                isPrinceps: false,
                procedureType: 'Autorisation',
                medicamentName: 'DOLIPRANE GENERIQUE',
                commonPrinciples: ['PARACETAMOL'],
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final results = await container.read(
        searchResultsProvider('doliprane').future,
      );

      expect(results.length, 1);
      final first = results.first;
      first.when(
        princepsResult: (princeps, generics, groupId, commonPrinciples) {
          expect(groupId, 'GROUP_1');
          expect(princeps.nom, contains('DOLIPRANE'));
          expect(generics.length, 1);
          expect(commonPrinciples, contains('PARACETAMOL'));
        },
        genericResult:
            (
              unusedGeneric,
              unusedPrincepsList,
              unusedGroupId,
              unusedPrinciples,
            ) => fail('Expected princeps result for group'),
        standaloneResult: (unusedMedicament, unusedPrinciples) =>
            fail('Expected grouped result, not standalone'),
      );
    });
  });
}

SearchCandidate _buildCandidate({
  required String cisCode,
  required String nomCanonique,
  required bool isPrinceps,
  required String procedureType,
  required String medicamentName,
  String? groupId,
  List<String> commonPrinciples = const ['PARACETAMOL'],
}) {
  return SearchCandidate(
    cisCode: cisCode,
    nomCanonique: nomCanonique,
    isPrinceps: isPrinceps,
    groupId: groupId,
    commonPrinciples: commonPrinciples,
    princepsDeReference: 'PRINCEPS REF',
    formePharmaceutique: 'Comprimé',
    procedureType: procedureType,
    medicament: Medicament(
      nom: medicamentName,
      codeCip: '$cisCode-CIP',
      principesActifs: commonPrinciples,
      formePharmaceutique: 'Comprimé',
    ),
  );
}
