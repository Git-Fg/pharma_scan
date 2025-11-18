// integration_test/explorer_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupLocator();
  });

  // Nettoyer et réinitialiser la base de données avant chaque test
  setUp(() async {
    await sl<DatabaseService>().clearDatabase();
  });

  group('Explorer Flow Integration Tests', () {
    testWidgets(
      'should correctly classify product groups with princeps and generics',
      (WidgetTester tester) async {
        // GIVEN: Database with a complete group (princeps + generics)
        final dbService = sl<DatabaseService>();
        await dbService.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_PRINCEPS',
              'nom_specialite': 'PRINCEPS DRUG',
              'procedure_type': 'Autorisation',
              'titulaire': 'PRINCEPS LAB',
            },
            {
              'cis_code': 'CIS_GENERIC',
              'nom_specialite': 'GENERIC DRUG',
              'procedure_type': 'Autorisation',
              'titulaire': 'GENERIC LAB',
            },
          ],
          medicaments: [
            {
              'code_cip': 'PRINCEPS_CIP',
              'nom': 'PRINCEPS DRUG',
              'cis_code': 'CIS_PRINCEPS',
            },
            {
              'code_cip': 'GENERIC_CIP',
              'nom': 'GENERIC DRUG',
              'cis_code': 'CIS_GENERIC',
            },
          ],
          principes: [
            {
              'code_cip': 'PRINCEPS_CIP',
              'principe': 'ACTIVE_PRINCIPLE',
              'dosage': '500',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'GENERIC_CIP',
              'principe': 'ACTIVE_PRINCIPLE',
              'dosage': '500',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
          ],
          groupMembers: [
            {'code_cip': 'PRINCEPS_CIP', 'group_id': 'GROUP_1', 'type': 0},
            {'code_cip': 'GENERIC_CIP', 'group_id': 'GROUP_1', 'type': 1},
          ],
        );

        // WHEN: Classify the group
        final classification = await dbService.classifyProductGroup('GROUP_1');

        // THEN: Verify classification logic correctly identifies and groups medicaments
        final princepsList = classification!.princeps
            .expand((bucket) => bucket.medicaments)
            .toList();
        final genericsList = classification.generics
            .expand((bucket) => bucket.medicaments)
            .toList();

        expect(princepsList, hasLength(1));
        expect(princepsList.first.codeCip, 'PRINCEPS_CIP');
        expect(princepsList.first.nom, 'PRINCEPS DRUG');

        expect(genericsList, hasLength(1));
        expect(genericsList.first.codeCip, 'GENERIC_CIP');
        expect(genericsList.first.nom, 'GENERIC DRUG');

        // Verify scan result correctly identifies princeps type
        final scanResult = await dbService.getScanResultByCip('PRINCEPS_CIP');
        switch (scanResult!) {
          case GenericScanResult():
            fail('Expected PrincepsScanResult but got GenericScanResult');
          case PrincepsScanResult(
            princeps: final princeps,
            groupId: final groupId,
          ):
            expect(princeps.codeCip, 'PRINCEPS_CIP');
            expect(groupId, 'GROUP_1');
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      'should correctly group multiple princeps by dosage',
      (WidgetTester tester) async {
        // GIVEN: Database with a group containing multiple princeps with different dosages
        final dbService = sl<DatabaseService>();
        await dbService.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_1',
              'nom_specialite': 'MEDICAMENT 100mg',
              'procedure_type': 'Autorisation',
              'titulaire': 'LAB 1',
            },
            {
              'cis_code': 'CIS_2',
              'nom_specialite': 'MEDICAMENT 50mg',
              'procedure_type': 'Autorisation',
              'titulaire': 'LAB 2',
            },
            {
              'cis_code': 'CIS_3',
              'nom_specialite': 'MEDICAMENT 200mg',
              'procedure_type': 'Autorisation',
              'titulaire': 'LAB 3',
            },
          ],
          medicaments: [
            {
              'code_cip': 'CIP1',
              'nom': 'MEDICAMENT 100mg',
              'cis_code': 'CIS_1',
            },
            {'code_cip': 'CIP2', 'nom': 'MEDICAMENT 50mg', 'cis_code': 'CIS_2'},
            {
              'code_cip': 'CIP3',
              'nom': 'MEDICAMENT 200mg',
              'cis_code': 'CIS_3',
            },
          ],
          principes: [
            {
              'code_cip': 'CIP1',
              'principe': 'ACTIVE_PRINCIPLE',
              'dosage': '100',
            },
            {
              'code_cip': 'CIP2',
              'principe': 'ACTIVE_PRINCIPLE',
              'dosage': '50',
            },
            {
              'code_cip': 'CIP3',
              'principe': 'ACTIVE_PRINCIPLE',
              'dosage': '200',
            },
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
          ],
          groupMembers: [
            {'code_cip': 'CIP1', 'group_id': 'GROUP_1', 'type': 0},
            {'code_cip': 'CIP2', 'group_id': 'GROUP_1', 'type': 0},
            {'code_cip': 'CIP3', 'group_id': 'GROUP_1', 'type': 0},
          ],
        );

        // WHEN: Classify the group
        final classification = await dbService.classifyProductGroup('GROUP_1');

        // THEN: Verify all princeps are correctly identified and grouped
        final princepsList = classification!.princeps
            .expand((bucket) => bucket.medicaments)
            .toList();
        expect(princepsList, hasLength(3));
        expect(princepsList.map((m) => m.codeCip).toSet(), {
          'CIP1',
          'CIP2',
          'CIP3',
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
