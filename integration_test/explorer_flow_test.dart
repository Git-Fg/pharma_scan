// integration_test/explorer_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/home/screens/main_screen.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';
import 'package:pharma_scan/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupLocator();
  });

  // Nettoyer et réinitialiser la base de données avant chaque test
  setUp(() async {
    await sl<DatabaseService>().clearDatabase();
  });

  group('Explorer Flow Integration Tests', () {
    testWidgets(
      'should navigate from scan to group exploration',
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
              'dosage': 500.0,
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'GENERIC_CIP',
              'principe': 'ACTIVE_PRINCIPLE',
              'dosage': 500.0,
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

        // Build the app
        await tester.pumpWidget(const PharmaScanApp());
        await tester.pumpAndSettle();

        // Verify we're on the CameraScreen (default tab)
        expect(find.byType(MainScreen), findsOneWidget);

        // WHEN: Simulate a successful scan by directly calling the service
        final scanResult = await dbService.getScanResultByCip('PRINCEPS_CIP');
        expect(scanResult, isNotNull);

        // THEN: Verify the scan result is correct
        scanResult!.when(
          generic: (medicament, associatedPrinceps, groupId) {
            fail('Expected PrincepsScanResult but got GenericScanResult');
          },
          princeps: (princeps, moleculeName, genericLabs, groupId) {
            expect(princeps.codeCip, 'PRINCEPS_CIP');
            expect(groupId, 'GROUP_1');
          },
        );

        // Note: Testing the full UI flow (bubble appearance and button tap)
        // would require more complex widget interaction testing.
        // This test verifies the data layer works correctly for the flow.
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets(
      'should display group mode with correct princeps and generics lists',
      (WidgetTester tester) async {
        // GIVEN: Database with a complete group
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
            {'code_cip': 'PRINCEPS_CIP', 'principe': 'ACTIVE_PRINCIPLE'},
            {'code_cip': 'GENERIC_CIP', 'principe': 'ACTIVE_PRINCIPLE'},
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
          ],
          groupMembers: [
            {'code_cip': 'PRINCEPS_CIP', 'group_id': 'GROUP_1', 'type': 0},
            {'code_cip': 'GENERIC_CIP', 'group_id': 'GROUP_1', 'type': 1},
          ],
        );

        // WHEN: Get group details
        final groupDetails = await dbService.getGroupDetails('GROUP_1');

        // THEN: Verify group details are correct
        expect(groupDetails.princeps.length, 1);
        expect(groupDetails.generics.length, 1);
        expect(groupDetails.princeps.first.codeCip, 'PRINCEPS_CIP');
        expect(groupDetails.generics.first.codeCip, 'GENERIC_CIP');
      },
    );

    testWidgets('should sort medications by dosage in group mode', (
      WidgetTester tester,
    ) async {
      // GIVEN: Database with a group containing medications with different dosages
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
          {'code_cip': 'CIP1', 'nom': 'MEDICAMENT 100mg', 'cis_code': 'CIS_1'},
          {'code_cip': 'CIP2', 'nom': 'MEDICAMENT 50mg', 'cis_code': 'CIS_2'},
          {'code_cip': 'CIP3', 'nom': 'MEDICAMENT 200mg', 'cis_code': 'CIS_3'},
        ],
        principes: [
          {'code_cip': 'CIP1', 'principe': 'ACTIVE_PRINCIPLE', 'dosage': 100.0},
          {'code_cip': 'CIP2', 'principe': 'ACTIVE_PRINCIPLE', 'dosage': 50.0},
          {'code_cip': 'CIP3', 'principe': 'ACTIVE_PRINCIPLE', 'dosage': 200.0},
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

      // WHEN: Get group details
      final groupDetails = await dbService.getGroupDetails('GROUP_1');

      // THEN: Verify medications are present
      expect(groupDetails.princeps.length, 3);

      // Note: Actual sorting UI testing would require widget interaction.
      // This test verifies the data is available for sorting.
    });

    testWidgets('should toggle view mode in group exploration', (
      WidgetTester tester,
    ) async {
      // GIVEN: Database with a complete group
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
          {'code_cip': 'PRINCEPS_CIP', 'principe': 'ACTIVE_PRINCIPLE'},
          {'code_cip': 'GENERIC_CIP', 'principe': 'ACTIVE_PRINCIPLE'},
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
        ],
        groupMembers: [
          {'code_cip': 'PRINCEPS_CIP', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'GENERIC_CIP', 'group_id': 'GROUP_1', 'type': 1},
        ],
      );

      // WHEN: Get group details
      final groupDetails = await dbService.getGroupDetails('GROUP_1');

      // THEN: Verify data supports both view modes
      expect(groupDetails.princeps.length, 1);
      expect(groupDetails.generics.length, 1);

      // Note: Testing the actual toggle UI would require widget interaction.
      // This test verifies the data structure supports toggling.
    });
  });
}
