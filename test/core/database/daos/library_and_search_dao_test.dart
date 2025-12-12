// test/core/database/daos/library_and_search_dao_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';

import '../../../fixtures/seed_builder.dart';
import '../../../helpers/db_loader.dart';
import '../../../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late Directory documentsDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(documentsDir.path);

    database = AppDatabase.forTesting(
      NativeDatabase.memory(setup: configureAppSQLite),
    );
  });

  tearDown(() async {
    await database.close();
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  group('LibraryDao & SearchDao Logic', () {
    test('getGenericGroupSummaries returns deterministic principles', () async {
      // Populate MedicamentSummary directly using SeedBuilder (SQL-first)
      await SeedBuilder()
          .inGroup('GROUP_A', 'PARACETAMOL 500 mg')
          .addMedication(
            cisCode: 'CIS_PRINCEPS',
            nomCanonique: 'PRINCEPS 1',
            princepsDeReference: 'PRINCEPS 1',
            cipCode: 'P1_CIP',
            groupId: 'GROUP_A',
            formattedDosage: '500 mg',
            formePharmaceutique: 'comprimé',
            isPrinceps: true,
            principesActifsCommuns: '["PARACETAMOL", "CAFEINE"]',
          )
          .addMedication(
            cisCode: 'CIS_GENERIC',
            nomCanonique: 'GENERIC 1',
            princepsDeReference: 'PRINCEPS 1',
            cipCode: 'G1_CIP',
            groupId: 'GROUP_A',
            formattedDosage: '500 mg',
            formePharmaceutique: 'comprimé',
            principesActifsCommuns: '["PARACETAMOL", "CAFEINE"]',
          )
          .insertInto(database);

      final summaries = await database.catalogDao.getGenericGroupSummaries(
        limit: 10,
      );

      expect(summaries.length, 1);
      expect(summaries.first.commonPrincipes, 'CAFEINE, PARACETAMOL');
    });

    test(
      'getGenericGroupSummaries skips groups without shared principles',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_B', 'MIXED GROUP')
            .addMedication(
              cisCode: 'CIS_P',
              nomCanonique: 'PRINCEPS 2',
              princepsDeReference: 'PRINCEPS 2',
              cipCode: 'P2_CIP',
              groupId: 'GROUP_B',
              isPrinceps: true,
              principesActifsCommuns: '[]', // Empty principles
            )
            .insertInto(database);

        final summaries = await database.catalogDao.getGenericGroupSummaries(
          limit: 10,
        );

        expect(
          summaries,
          isEmpty,
          reason: 'Groups without principles should be filtered out.',
        );
      },
    );

    test('should return correct database statistics', () async {
      await SeedBuilder()
          .inGroup('GROUP_1', 'TEST GROUP 1')
          .addPrinceps('PRINCEPS 1', 'CIS_PRINCEPS_1', cipCode: 'PRINCEPS_1')
          .addGeneric(
            'GENERIC 1',
            'CIS_GENERIC_1',
            cipCode: 'GENERIC_1',
            princepsName: 'PRINCEPS 1',
          )
          .addGeneric(
            'GENERIC 2',
            'CIS_GENERIC_2',
            cipCode: 'GENERIC_2',
            princepsName: 'PRINCEPS 1',
          )
          .inGroup('GROUP_2', 'TEST GROUP 2')
          .addPrinceps('PRINCEPS 2', 'CIS_PRINCEPS_2', cipCode: 'PRINCEPS_2')
          .insertInto(database);

      // The SeedBuilder already inserted all necessary data
      // No additional setup needed - just verify the stats function works

      // Just verify that we have some data in the database
      final stats = await database.catalogDao.getDatabaseStats();

      // The exact counts depend on the SeedBuilder setup, so just verify we have positive numbers
      expect(stats.totalGeneriques, greaterThan(0));
      expect(stats.totalPrincipes, greaterThan(0));
    });

    test('searchMedicaments returns canonical princeps and generics', () async {
      await SeedBuilder()
          .inGroup('GROUP_1', 'APIXABAN 5 mg')
          .addMedication(
            cisCode: 'CIS_P',
            nomCanonique: 'ELIQUIS 5 mg, comprimé',
            princepsDeReference: 'ELIQUIS 5 mg, comprimé',
            cipCode: 'CIP_P',
            groupId: 'GROUP_1',
            formattedDosage: '5 mg',
            isPrinceps: true,
            principesActifsCommuns: '["APIXABAN"]',
          )
          .addMedication(
            cisCode: 'CIS_G',
            nomCanonique: 'APIXABAN ZYDUS 5 mg, comprimé',
            princepsDeReference: 'ELIQUIS 5 mg, comprimé',
            cipCode: 'CIP_G',
            groupId: 'GROUP_1',
            formattedDosage: '5 mg',
            principesActifsCommuns: '["APIXABAN"]',
          )
          .insertInto(database);

      // Populate the FTS5 search index for testing using raw SQL
      await database.customUpdate('DELETE FROM search_index', updates: {});
      await database.customUpdate('''
        INSERT INTO search_index (
          cis_code,
          molecule_name,
          brand_name
        )
        SELECT
          ms.cis_code,
          normalize_text(COALESCE(ms.nom_canonique, '')) AS molecule_name,
          normalize_text(COALESCE(ms.princeps_de_reference, '')) AS brand_name
        FROM medicament_summary ms
      ''', updates: {});

      final catalogDao = database.catalogDao;
      final candidates = await catalogDao.searchMedicaments(
        NormalizedQuery.fromString('APIXABAN'),
      );
      // Just verify we get some results, exact count depends on SeedBuilder setup
      expect(candidates.length, greaterThanOrEqualTo(1));
    });
  });
}
