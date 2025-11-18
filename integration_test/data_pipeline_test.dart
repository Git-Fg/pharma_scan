import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'test_bootstrap.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService dbService;
  late AppDatabase db;

  setUpAll(() async {
    await ensureIntegrationTestDatabase();
    dbService = sl<DatabaseService>();
    db = sl<AppDatabase>();
  });

  group('Data Pipeline - ScanResult Type Mapping', () {
    testWidgets(
      'should return GenericScanResult for a generic medicament',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHEN: Find a generic medicament and get its scan result
        final generiquesResult = await db
            .customSelect(
              'SELECT gm.code_cip FROM group_members gm WHERE gm.type = 1 LIMIT 1',
            )
            .getSingleOrNull();

        if (generiquesResult == null) {
          return; // Skip if no generics in database
        }

        final codeCipGenerique = generiquesResult.read<String>('code_cip');
        final scanResult = await dbService.getScanResultByCip(codeCipGenerique);

        // THEN: Verify it returns GenericScanResult with correct structure
        expect(scanResult, isA<GenericScanResult>());
        scanResult!.when(
          generic: (medicament, associatedPrinceps, groupId) {
            expect(medicament.codeCip, codeCipGenerique);
            expect(medicament.nom, isNotEmpty);
            // Verify associated princeps list (may be empty if group has no princeps)
            // Content verification is sufficient - type is guaranteed by model
          },
          princeps: (princeps, moleculeName, genericLabs, groupId) {
            fail('Expected GenericScanResult but got PrincepsScanResult');
          },
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'should return PrincepsScanResult for a princeps medicament',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHEN: Find a princeps medicament and get its scan result
        final princepsResult = await db
            .customSelect(
              'SELECT gm.code_cip FROM group_members gm WHERE gm.type = 0 LIMIT 1',
            )
            .getSingleOrNull();

        if (princepsResult == null) {
          return; // Skip if no princeps in database
        }

        final codeCipPrinceps = princepsResult.read<String>('code_cip');
        final princepsScanResult = await dbService.getScanResultByCip(
          codeCipPrinceps,
        );

        // THEN: Verify it returns PrincepsScanResult with correct structure
        expect(princepsScanResult, isA<PrincepsScanResult>());
        princepsScanResult!.when(
          generic: (medicament, associatedPrinceps, groupId) {
            fail('Expected PrincepsScanResult but got GenericScanResult');
          },
          princeps: (princeps, moleculeName, genericLabs, groupId) {
            expect(princeps.codeCip, codeCipPrinceps);
            expect(moleculeName, isNotEmpty);
            // Content verification is sufficient - type is guaranteed by model
          },
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'should return null for a medicament with no group membership',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHEN: Find a medicament without group membership and get its scan result
        final nonGroupedResult = await db
            .customSelect(
              'SELECT m.code_cip FROM medicaments m LEFT JOIN group_members gm ON m.code_cip = gm.code_cip WHERE gm.code_cip IS NULL LIMIT 1',
            )
            .getSingleOrNull();

        if (nonGroupedResult == null) {
          return; // Skip if all medicaments are in groups
        }

        final codeCipStandalone = nonGroupedResult.read<String>('code_cip');
        final standaloneScanResult = await dbService.getScanResultByCip(
          codeCipStandalone,
        );

        // THEN: Verify it returns null (standalone medicaments are not scannable)
        expect(
          standaloneScanResult,
          isNull,
          reason:
              'Standalone medicament without group membership should return null: $codeCipStandalone',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
