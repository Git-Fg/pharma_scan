import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'test_bootstrap.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureIntegrationTestDatabase();
  });

  testWidgets(
    'should correctly parse real TXT data, specifically baclofene 10mg from biogaran (3400930302613) with its active ingredients',
    (WidgetTester tester) async {
      // GIVEN: The initialization service
      final dbService = sl<DatabaseService>();
      // Real data from BDPM (verified via data_validator.py):
      // - CIP: 3400930302613
      // - CIS: 62173429
      // - Name: BACLOFENE BIOGARAN 10 mg, comprimé sécable
      // - Laboratory: BIOGARAN
      // - Active Principle: BACLOFÈNE (note the È)
      // - Group ID: 231
      // - Type: GENERIC
      // - Associated Princeps: LIORESAL 10 mg, comprimé sécable
      const targetCip = '3400930302613';
      const expectedGroupId = '231';
      const expectedActivePrinciple = 'BACLOFÈNE'; // Note: È not E
      const expectedPrincepsName = 'LIORESAL 10 mg, comprimé sécable';

      // THEN: Verify that getScanResultByCip returns the correct, fully-formed result
      // This is the single source of truth - if this is correct, the underlying
      // database insertion must have been successful
      final scanResult = await dbService.getScanResultByCip(targetCip);
      expect(
        scanResult,
        isNotNull,
        reason:
            'getScanResultByCip must return a result for CIP $targetCip after initialization',
      );

      // Verify all data is correctly parsed and structured in the ScanResult
      scanResult!.when(
        generic: (medicament, associatedPrinceps, groupId) {
          // Verify the medicament matches the expected CIP
          expect(medicament.codeCip, targetCip);

          // Verify the active principle is correctly extracted
          final resultPrincipesLower = medicament.principesActifs
              .map((p) => p.toLowerCase())
              .toList();
          expect(
            resultPrincipesLower.any(
              (p) => p == expectedActivePrinciple.toLowerCase(),
            ),
            isTrue,
            reason:
                'Active principle must be exactly "$expectedActivePrinciple" (found: ${medicament.principesActifs})',
          );

          // Verify the group ID is correct
          expect(
            groupId,
            expectedGroupId,
            reason: 'Group ID must be $expectedGroupId (found: $groupId)',
          );

          // Verify associated princeps are correctly linked
          expect(associatedPrinceps, isNotEmpty);
          expect(
            associatedPrinceps.any((p) => p.nom.contains('LIORESAL')),
            isTrue,
            reason:
                'Associated princeps "$expectedPrincepsName" must be in the list (found: ${associatedPrinceps.map((p) => p.nom).toList()})',
          );
        },
        princeps: (princeps, moleculeName, genericLabs, groupId) {
          fail(
            'Expected GenericScanResult for CIP $targetCip, but got PrincepsScanResult',
          );
        },
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
