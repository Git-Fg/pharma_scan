// test/core/database/fast_search_test.dart

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import '../../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fast Search Test - In-Memory DB', () {
    late Directory documentsDir;

    setUp(() async {
      documentsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
      PathProviderPlatform.instance = FakePathProviderPlatform(
        documentsDir.path,
      );
    });

    tearDown(() async {
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
    });

    test('should find search candidates after aggregation', () async {
      // GIVEN: In-memory database with a simple group (file-based database for aggregation).
      final dbFile = File(p.join(documentsDir.path, 'medicaments.db'));
      final database = AppDatabase.forTesting(
        NativeDatabase(dbFile, setup: configureAppSQLite),
      );
      final dataInitializationService = DataInitializationService(
        database: database,
      );

      // Insert a group with 1 princeps and 1 generic
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_ELIQUIS',
            'nom_specialite': 'ELIQUIS 5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé',
            'titulaire': 'BRISTOL-MYERS SQUIBB',
          },
          {
            'cis_code': 'CIS_APIXABAN_GENERIC',
            'nom_specialite': 'APIXABAN ZYDUS 5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé',
            'titulaire': 'ZYDUS FRANCE',
          },
        ],
        medicaments: [
          {'code_cip': 'CIP_ELIQUIS', 'cis_code': 'CIS_ELIQUIS'},
          {
            'code_cip': 'CIP_APIXABAN_GENERIC',
            'cis_code': 'CIS_APIXABAN_GENERIC',
          },
        ],
        principes: [
          {
            'code_cip': 'CIP_ELIQUIS',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_APIXABAN_GENERIC',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_APIXABAN_5', 'libelle': 'APIXABAN 5 mg'},
        ],
        groupMembers: [
          {
            'code_cip': 'CIP_ELIQUIS',
            'group_id': 'GROUP_APIXABAN_5',
            'type': 0, // Princeps
          },
          {
            'code_cip': 'CIP_APIXABAN_GENERIC',
            'group_id': 'GROUP_APIXABAN_5',
            'type': 1, // Generic
          },
        ],
      );

      // WHEN: Run aggregation to populate MedicamentSummary
      await dataInitializationService.runSummaryAggregationForTesting();

      final catalogDao = database.catalogDao;
      final candidates = await catalogDao.searchMedicaments('APIXABAN');

      // Verify results contain expected medications.
      expect(candidates, isNotEmpty);

      expect(
        candidates.length,
        equals(2),
        reason: 'Should have 2 candidates (princeps + generic)',
      );

      // Verify both candidates have APIXABAN as common principle
      final allHaveApixaban = candidates.every(
        (c) => c.principesActifsCommuns.contains('APIXABAN'),
      );
      expect(
        allHaveApixaban,
        isTrue,
        reason: 'All candidates should have APIXABAN as common principle',
      );

      // Verify both candidates are in the same group
      final allInSameGroup = candidates.every(
        (c) => c.groupId == 'GROUP_APIXABAN_5',
      );
      expect(
        allInSameGroup,
        isTrue,
        reason: 'All candidates should be in GROUP_APIXABAN_5',
      );

      // Verify one is princeps and one is generic
      final princepsCount = candidates.where((c) => c.isPrinceps).length;
      final genericCount = candidates.where((c) => !c.isPrinceps).length;
      expect(
        princepsCount,
        equals(1),
        reason: 'Should have exactly one princeps candidate',
      );
      expect(
        genericCount,
        equals(1),
        reason: 'Should have exactly one generic candidate',
      );

      // Verify nomCanonique is correctly parsed (principle + dosage)
      final allHaveCorrectCanonicalName = candidates.every(
        (c) =>
            c.nomCanonique.toUpperCase().contains('APIXABAN') &&
            c.nomCanonique.contains('5'),
      );
      expect(
        allHaveCorrectCanonicalName,
        isTrue,
        reason: 'All candidates should have APIXABAN 5 mg as canonical name',
      );

      await database.close();
    });
  });
}
