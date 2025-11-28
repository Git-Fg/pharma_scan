// test/core/services/drift_database_service_test.dart

import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import '../../fixtures/seed_builder.dart';
import '../../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DataInitializationService dataInitializationService;
  late Directory documentsDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(documentsDir.path);

    // WHY: Use file-based database for tests that need aggregation
    // Aggregation requires a file path to open database in isolate
    final dbFile = File(p.join(documentsDir.path, 'medicaments.db'));
    database = AppDatabase.forTesting(
      NativeDatabase(dbFile, setup: configureAppSQLite),
    );
    dataInitializationService = DataInitializationService(database: database);
  });

  tearDown(() async {
    // WHY: Clean isolation - close database after each test
    await database.close();
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  group('classifyProductGroup - Complex SQL Logic', () {
    test('correctly splits Princeps, Generics, and Related Princeps', () async {
      // GIVEN: A group with princeps and generics, plus a related princeps from another group
      await SeedBuilder()
          .inGroup('GROUP_A', 'APIXABAN 5 mg')
          .addPrinceps(
            'ELIQUIS 5 mg, comprimé',
            'CIP_PRINCEPS_A',
            cis: 'CIS_PRINCEPS_A',
            dosage: '5',
            form: 'Comprimé',
            lab: 'BRISTOL-MYERS SQUIBB',
          )
          .addGeneric(
            'APIXABAN ZYDUS 5 mg, comprimé',
            'CIP_GENERIC_A',
            cis: 'CIS_GENERIC_A',
            dosage: '5',
            form: 'Comprimé',
            lab: 'ZYDUS FRANCE',
          )
          .inGroup('GROUP_B', 'APIXABAN 2.5 mg')
          .addPrinceps(
            'ELIQUIS 2.5 mg, comprimé',
            'CIP_PRINCEPS_B',
            cis: 'CIS_PRINCEPS_B',
            dosage: '2.5',
            form: 'Comprimé',
            lab: 'BRISTOL-MYERS SQUIBB',
          )
          .addGeneric(
            'APIXABAN TEVA 2.5 mg, comprimé',
            'CIP_GENERIC_B',
            cis: 'CIS_GENERIC_B',
            dosage: '2.5',
            form: 'Comprimé',
            lab: 'TEVA SANTE',
          )
          .insertInto(database);

      // WHY: Override default principes with specific ones for this test
      // GROUP_A: APIXABAN 5 mg
      // GROUP_B: APIXABAN 2.5 mg (related therapy)
      await database.databaseDao.insertBatchData(
        specialites: [],
        medicaments: [],
        principes: [
          {
            'code_cip': 'CIP_PRINCEPS_A',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_GENERIC_A',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_PRINCEPS_B',
            'principe': 'APIXABAN',
            'dosage': '2.5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_GENERIC_B',
            'principe': 'APIXABAN',
            'dosage': '2.5',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [],
        groupMembers: [],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      // WHEN: We fetch GROUP_A details
      final members = await database.libraryDao.getGroupDetails('GROUP_A');
      final related = await database.libraryDao.fetchRelatedPrinceps('GROUP_A');

      // THEN: Should have member rows for princeps, generic, and no related princeps
      expect(members.length, greaterThanOrEqualTo(2));

      // Verify princeps member
      final princepsMember = members.firstWhere((m) => m.isPrinceps);
      expect(princepsMember.codeCip, 'CIP_PRINCEPS_A');

      // Verify generic member
      final genericMember = members.firstWhere((m) => !m.isPrinceps);
      expect(genericMember.codeCip, 'CIP_GENERIC_A');

      // WHY: Related princeps must contain all common principles PLUS additional ones
      expect(
        related,
        isEmpty,
        reason:
            'GROUP_B has same principles as GROUP_A (only APIXABAN), so it does not qualify as related princeps.',
      );
    });

    test(
      'Triangulation: Broken Generic inherits dosage from Princeps via SQL Join',
      () async {
        // GIVEN: A group with a clean Princeps and a "messy" Generic
        // The Generic has NO dosage in its name or composition (simulating bad data)
        await SeedBuilder()
            .inGroup('GROUP_BROKEN', 'MOLECULE 500 mg')
            .addPrinceps(
              'PRINCEPS 500 mg, comprimé',
              'CIP_P',
              cis: 'CIS_PRINCEPS',
              dosage: '500',
              form: 'Comprimé',
              lab: 'LABO PRINCEPS',
            )
            .addGeneric(
              'GENERIC LABO', // No dosage in name!
              'CIP_G',
              cis: 'CIS_GENERIC',
              form: 'Comprimé',
              lab: 'LABO GENERIC',
            )
            .insertInto(database);

        // WHY: Override default principes - Princeps has clean dosage, Generic has MISSING dosage
        // This simulates parsing failure or empty data for the generic
        await database.databaseDao.insertBatchData(
          specialites: [],
          medicaments: [],
          principes: [
            {
              'code_cip': 'CIP_P',
              'principe': 'MOLECULE',
              'dosage': '500',
              'dosage_unit': 'mg',
            },
            // Generic has missing dosage (simulating parsing failure or empty data)
            {'code_cip': 'CIP_G', 'principe': 'MOLECULE'},
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        await dataInitializationService.runSummaryAggregationForTesting();

        // WHEN: We fetch details, expecting dosage inheritance in view
        final members = await database.libraryDao.getGroupDetails(
          'GROUP_BROKEN',
        );

        // THEN: The group data should contain both princeps and generic
        expect(members.length, 2);

        final princepsMember = members.firstWhere((m) => m.isPrinceps);
        final genericMember = members.firstWhere((m) => !m.isPrinceps);

        expect(princepsMember.codeCip, 'CIP_P');
        expect(genericMember.codeCip, 'CIP_G');

        // Verify formatted dosage is available for both entries
        expect(
          princepsMember.formattedDosage,
          isNotEmpty,
          reason: 'Princeps should expose formatted dosage from principes',
        );
        expect(
          genericMember.formattedDosage,
          equals(princepsMember.formattedDosage),
          reason:
              'Generic without dosage should inherit princeps dosage through SQL view',
        );
      },
    );
  });

  group('getGenericGroupSummaries - Algorithmic Grouping', () {
    test('groups medications by shared principles correctly', () async {
      // GIVEN: Multiple groups with different principle combinations
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_P1',
            'nom_specialite': 'ELIQUIS 5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'BRISTOL-MYERS SQUIBB',
          },
          {
            'cis_code': 'CIS_G1',
            'nom_specialite': 'APIXABAN ZYDUS 5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'ZYDUS FRANCE',
          },
          {
            'cis_code': 'CIS_P2',
            'nom_specialite': 'ELIQUIS 2.5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'BRISTOL-MYERS SQUIBB',
          },
          {
            'cis_code': 'CIS_G2',
            'nom_specialite': 'APIXABAN TEVA 2.5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'TEVA SANTE',
          },
        ],
        medicaments: [
          {'code_cip': 'CIP_P1', 'cis_code': 'CIS_P1'},
          {'code_cip': 'CIP_G1', 'cis_code': 'CIS_G1'},
          {'code_cip': 'CIP_P2', 'cis_code': 'CIS_P2'},
          {'code_cip': 'CIP_G2', 'cis_code': 'CIS_G2'},
        ],
        principes: [
          {
            'code_cip': 'CIP_P1',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_G1',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_P2',
            'principe': 'APIXABAN',
            'dosage': '2.5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_G2',
            'principe': 'APIXABAN',
            'dosage': '2.5',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'APIXABAN 5 mg'},
          {'group_id': 'GROUP_2', 'libelle': 'APIXABAN 2.5 mg'},
        ],
        groupMembers: [
          {'code_cip': 'CIP_P1', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'CIP_G1', 'group_id': 'GROUP_1', 'type': 1},
          {'code_cip': 'CIP_P2', 'group_id': 'GROUP_2', 'type': 0},
          {'code_cip': 'CIP_G2', 'group_id': 'GROUP_2', 'type': 1},
        ],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      // WHEN: We get generic group summaries
      final summaries = await database.libraryDao.getGenericGroupSummaries(
        limit: 10,
        offset: 0,
      );

      // THEN: Should return both groups with correct common principles
      expect(summaries.length, 2);
      expect(
        summaries.map((s) => s.commonPrincipes).toSet(),
        containsAll(['APIXABAN']),
      );
    });

    test('filters groups without shared principles', () async {
      // GIVEN: A group where princeps and generic have different principles
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_P',
            'nom_specialite': 'PRINCEPS A 500 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'LAB_P',
          },
          {
            'cis_code': 'CIS_G',
            'nom_specialite': 'GENERIC B 500 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'LAB_G',
          },
        ],
        medicaments: [
          {'code_cip': 'CIP_P', 'cis_code': 'CIS_P'},
          {'code_cip': 'CIP_G', 'cis_code': 'CIS_G'},
        ],
        principes: [
          {'code_cip': 'CIP_P', 'principe': 'PRINCIPE_A'},
          {'code_cip': 'CIP_G', 'principe': 'PRINCIPE_B'},
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_MIXED', 'libelle': 'MIXED GROUP'},
        ],
        groupMembers: [
          {'code_cip': 'CIP_P', 'group_id': 'GROUP_MIXED', 'type': 0},
          {'code_cip': 'CIP_G', 'group_id': 'GROUP_MIXED', 'type': 1},
        ],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      // WHEN: We get generic group summaries
      final summaries = await database.libraryDao.getGenericGroupSummaries(
        limit: 10,
        offset: 0,
      );

      // THEN: Should filter out groups without shared principles
      expect(
        summaries,
        isEmpty,
        reason:
            'Groups without a fully shared active principle set must be filtered out',
      );
    });
  });
}
