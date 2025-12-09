import 'package:pharma_scan/core/database/database.dart';

import '../test_utils.dart' show setPrincipeNormalizedForAllPrinciples;
import 'seed_builder.dart';

/// Preconfigured database seeds for common integration scenarios.
class TestScenarios {
  const TestScenarios._();

  /// Seeds a basic Paracetamol group with one princeps and one generic,
  /// then refreshes summary + FTS for lookup-heavy tests.
  static Future<void> seedParacetamolGroup(AppDatabase db) async {
    await SeedBuilder()
        .inGroup('GRP_PARA', 'Paracetamol Group')
        .addPrinceps(
          'Paracetamol Princeps',
          '3400000000001',
          cis: 'CIS_PARA_1',
          dosage: '500',
        )
        .addGeneric(
          'Paracetamol Generic',
          '3400000000002',
          cis: 'CIS_PARA_2',
          dosage: '500',
        )
        .insertInto(db);

    await setPrincipeNormalizedForAllPrinciples(db);
    await db.databaseDao.populateSummaryTable();
    await db.databaseDao.populateFts5Index();
  }

  /// Seeds a slightly richer Paracetamol set for restock flows (adds a variant).
  static Future<void> seedParacetamolRestock(AppDatabase db) async {
    await SeedBuilder()
        .inGroup('GRP_PARA', 'Paracetamol Group')
        .addPrinceps(
          'Paracetamol Princeps',
          '3400000000001',
          cis: 'CIS_PARA_1',
          dosage: '500',
        )
        .addGeneric(
          'Paracetamol Generic',
          '3400000000002',
          cis: 'CIS_PARA_2',
          dosage: '500',
        )
        .addPrinceps(
          'Doliprane Extra',
          '3400000000003',
          cis: 'CIS_PARA_3',
          dosage: '1000',
        )
        .insertInto(db);

    await setPrincipeNormalizedForAllPrinciples(db);
    await db.databaseDao.populateSummaryTable();
    await db.databaseDao.populateFts5Index();
  }
}
