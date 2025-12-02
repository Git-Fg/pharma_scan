import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_classification_provider.dart';

import '../test/fixtures/seed_builder.dart';
import 'test_bootstrap.dart';

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
      // Use a widget to watch the provider and get the stream value
      final container = integrationTestContainer;
      GroupDetailsList? viewModel;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, child) {
              final asyncValue = ref.watch(
                groupDetailViewModelProvider('GRP_TENORDATE'),
              );
              return asyncValue.when(
                data: (vm) {
                  viewModel = vm;
                  return const SizedBox();
                },
                loading: () => const SizedBox(),
                error: (err, stack) => const SizedBox(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Ensure we got the viewModel
      expect(viewModel, isNotNull, reason: 'ViewModel should be loaded');

      // THEN: Verify that productName contains BOTH molecules
      final generics = viewModel!.where((m) => !m.isPrinceps).toList();
      expect(
        generics,
        isNotEmpty,
        reason: 'Generics list should contain the inserted generic',
      );

      final firstGeneric = generics.first;
      final productName = firstGeneric.displayName.toUpperCase();

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
