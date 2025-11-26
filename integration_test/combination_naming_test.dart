import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/features/explorer/providers/group_classification_provider.dart';
import 'test_bootstrap.dart';
import '../test/fixtures/seed_builder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DataInitializationService dataInitService;

  setUpAll(() async {
    final container = await ensureIntegrationTestContainer();
    db = container.read(appDatabaseProvider);
    dataInitService = container.read(dataInitializationServiceProvider);
  });

  testWidgets(
    'should preserve both molecules in combination product name',
    (WidgetTester tester) async {
      // GIVEN: Clear database and insert combination drug group
      await db.databaseDao.clearDatabase();

      // Insert test data: TENORDATE group with combination molecules
      await SeedBuilder()
          .inGroup(
            'GRP_TENORDATE',
            'ATENOLOL 50 mg + NIFEDIPINE 20 mg - TENORDATE',
          )
          .addGeneric(
            'ATENOLOL/NIFEDIPINE BIOGARAN',
            '3400930302613',
            dosage: '50',
            form: 'Comprimé',
            lab: 'BIOGARAN',
          )
          .insertInto(db);

      // Run aggregation to populate MedicamentSummary
      await dataInitService.runSummaryAggregationForTesting();

      // WHEN: Query groupDetailViewModelProvider
      final container = integrationTestContainer;
      final viewModel = await container.read(
        groupDetailViewModelProvider('GRP_TENORDATE').future,
      );

      // THEN: Verify that productName contains BOTH molecules
      expect(viewModel, isNotNull, reason: 'ViewModel should not be null');

      // Check generics list (the generic member we inserted)
      expect(
        viewModel!.generics,
        isNotEmpty,
        reason: 'Generics list should contain the inserted generic',
      );

      final firstGeneric = viewModel.generics.first;
      final productName = firstGeneric.productName.toUpperCase();

      // CRITICAL: Product name must contain BOTH molecules
      expect(
        productName,
        contains('ATENOLOL'),
        reason: 'Product name must contain ATENOLOL',
      );
      expect(
        productName,
        contains('NIFEDIPINE'),
        reason: 'Product name must contain NIFEDIPINE',
      );

      // FAIL if it equals only "ATENOLOL" (the bug we're fixing)
      expect(
        productName,
        isNot(equals('ATENOLOL')),
        reason:
            'Product name should not be truncated to only first molecule. '
            'Expected both ATENOLOL and NIFEDIPINE, got: $productName',
      );

      // Verify the format is correct (should contain + separator)
      expect(
        productName,
        contains('+'),
        reason:
            'Combination product name should contain + separator. '
            'Got: $productName',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

