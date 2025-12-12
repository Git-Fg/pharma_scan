// Test file uses SeedBuilder pattern for reliable database setup

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/features/explorer/domain/models/explorer_enums.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';

import '../../../fixtures/seed_builder.dart';
import '../../../helpers/db_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explorer multi-filter AND logic', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      // Seed test data using SeedBuilder pattern (same as working tests)
      await SeedBuilder()
          .addMedication(
            cisCode: 'A',
            nomCanonique: 'Item A',
            princepsDeReference: 'Item A',
            cipCode: '111',
            groupId: 'GROUP_A',
            formattedDosage: '500 mg',
            formePharmaceutique: 'comprimé',
            voiesAdministration: 'Orale',
            atcCode: 'A01',
            isPrinceps: true,
            principesActifsCommuns: '["PARACETAMOL"]',
          )
          .addMedication(
            cisCode: 'B',
            nomCanonique: 'Item B',
            princepsDeReference: 'Item B',
            cipCode: '222',
            groupId: 'GROUP_B',
            formattedDosage: '250 mg',
            formePharmaceutique: 'comprimé',
            voiesAdministration: 'Orale',
            atcCode: 'B02',
            isPrinceps: true,
            principesActifsCommuns: '["IBUPROFEN"]',
          )
          .addMedication(
            cisCode: 'C',
            nomCanonique: 'Item C',
            princepsDeReference: 'Item C',
            cipCode: '333',
            groupId: 'GROUP_C',
            formattedDosage: '5 mg',
            formePharmaceutique: 'solution injectable',
            voiesAdministration: 'Injectable',
            atcCode: 'A01',
            isPrinceps: true,
            principesActifsCommuns: '["MORPHINE"]',
          )
          .insertInto(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('applies route AND ATC filters together', () async {
      const filters = SearchFilters(
        voieAdministration: 'Orale',
        atcClass: AtcLevel1.a,
      );

      final results = await db.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('Item'),
        filters: filters,
      );

      expect(results, hasLength(1));
      expect(results.first.data.cisCode, 'A');
    });
  });
}
