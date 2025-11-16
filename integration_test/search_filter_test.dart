// integration_test/search_filter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupLocator();
  });

  // Nettoyer et réinitialiser la base de données avant chaque test
  setUp(() async {
    await sl<DatabaseService>().clearDatabase();
  });

  group('Search Filter Integration Tests', () {
    testWidgets('should filter out homeopathic products by default', (
      WidgetTester tester,
    ) async {
      // GIVEN: Database with conventional and homeopathic medications with similar names
      final dbService = sl<DatabaseService>();
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_CONV',
            'nom_specialite': 'MEDICAMENT TEST',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_HOMEO',
            'nom_specialite': 'MEDICAMENT TEST HOMEOPATHIQUE',
            'procedure_type': 'Enreg homéo (Proc. Nat.)',
          },
        ],
        medicaments: [
          {
            'code_cip': 'CIP_CONV',
            'nom': 'MEDICAMENT TEST',
            'cis_code': 'CIS_CONV',
          },
          {
            'code_cip': 'CIP_HOMEO',
            'nom': 'MEDICAMENT TEST HOMEOPATHIQUE',
            'cis_code': 'CIS_HOMEO',
          },
        ],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      // WHEN: Search with showAll: false (default)
      final results = await dbService.searchMedicaments(
        'medicament',
        showAll: false,
      );

      // THEN: Only conventional medication should appear
      expect(results.length, 1);
      expect(results.first.nom, 'MEDICAMENT TEST');
      expect(results.first.codeCip, 'CIP_CONV');
    });

    testWidgets('should include homeopathic products when filter is disabled', (
      WidgetTester tester,
    ) async {
      // GIVEN: Database with conventional and homeopathic medications
      final dbService = sl<DatabaseService>();
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_CONV',
            'nom_specialite': 'MEDICAMENT TEST',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_HOMEO',
            'nom_specialite': 'MEDICAMENT TEST HOMEOPATHIQUE',
            'procedure_type': 'Enreg homéo (Proc. Nat.)',
          },
        ],
        medicaments: [
          {
            'code_cip': 'CIP_CONV',
            'nom': 'MEDICAMENT TEST',
            'cis_code': 'CIS_CONV',
          },
          {
            'code_cip': 'CIP_HOMEO',
            'nom': 'MEDICAMENT TEST HOMEOPATHIQUE',
            'cis_code': 'CIS_HOMEO',
          },
        ],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      // WHEN: Search with showAll: true
      final results = await dbService.searchMedicaments(
        'medicament',
        showAll: true,
      );

      // THEN: Both products should appear
      expect(results.length, 2);
      expect(
        results.map((m) => m.nom),
        containsAll(['MEDICAMENT TEST', 'MEDICAMENT TEST HOMEOPATHIQUE']),
      );
    });

    testWidgets('should re-apply filter when toggled back on', (
      WidgetTester tester,
    ) async {
      // GIVEN: Database with conventional and homeopathic medications
      final dbService = sl<DatabaseService>();
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_CONV',
            'nom_specialite': 'MEDICAMENT TEST',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_HOMEO',
            'nom_specialite': 'MEDICAMENT TEST HOMEOPATHIQUE',
            'procedure_type': 'Enreg homéo (Proc. Nat.)',
          },
        ],
        medicaments: [
          {
            'code_cip': 'CIP_CONV',
            'nom': 'MEDICAMENT TEST',
            'cis_code': 'CIS_CONV',
          },
          {
            'code_cip': 'CIP_HOMEO',
            'nom': 'MEDICAMENT TEST HOMEOPATHIQUE',
            'cis_code': 'CIS_HOMEO',
          },
        ],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      // WHEN: Search with showAll: true (filter off)
      final resultsWithAll = await dbService.searchMedicaments(
        'medicament',
        showAll: true,
      );
      expect(resultsWithAll.length, 2);

      // WHEN: Search again with showAll: false (filter on)
      final resultsFiltered = await dbService.searchMedicaments(
        'medicament',
        showAll: false,
      );

      // THEN: Only conventional medication should appear again
      expect(resultsFiltered.length, 1);
      expect(resultsFiltered.first.nom, 'MEDICAMENT TEST');
      expect(resultsFiltered.first.codeCip, 'CIP_CONV');
    });

    testWidgets('should search by active ingredient with filter applied', (
      WidgetTester tester,
    ) async {
      // GIVEN: Database with medications having active ingredients
      final dbService = sl<DatabaseService>();
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_1',
            'nom_specialite': 'MEDICAMENT CONVENTIONNEL',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_2',
            'nom_specialite': 'MEDICAMENT HOMEOPATHIQUE',
            'procedure_type': 'Enreg homéo (Proc. Nat.)',
          },
        ],
        medicaments: [
          {
            'code_cip': 'CIP1',
            'nom': 'MEDICAMENT CONVENTIONNEL',
            'cis_code': 'CIS_1',
          },
          {
            'code_cip': 'CIP2',
            'nom': 'MEDICAMENT HOMEOPATHIQUE',
            'cis_code': 'CIS_2',
          },
        ],
        principes: [
          {'code_cip': 'CIP1', 'principe': 'PARACETAMOL'},
          {'code_cip': 'CIP2', 'principe': 'PARACETAMOL'},
        ],
        generiqueGroups: [],
        groupMembers: [],
      );

      // WHEN: Search by active ingredient with showAll: false (filter active)
      final results = await dbService.searchMedicaments(
        'paracetamol',
        showAll: false,
      );

      // THEN: Only conventional medication with the active ingredient should be returned
      expect(results.length, 1);
      expect(results.first.nom, 'MEDICAMENT CONVENTIONNEL');
      expect(results.first.codeCip, 'CIP1');
    });
  });
}
