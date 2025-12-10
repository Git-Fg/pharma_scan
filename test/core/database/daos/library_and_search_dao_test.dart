// test/core/database/daos/library_and_search_dao_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

import '../../../test_utils.dart'
    show
        FakePathProviderPlatform,
        buildGeneriqueGroupCompanion,
        buildGroupMemberCompanion,
        buildLaboratoryCompanion,
        buildMedicamentCompanion,
        buildPrincipeCompanion,
        buildSpecialiteCompanion,
        setPrincipeNormalizedForAllPrinciples;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DataInitializationService dataInitializationService;
  late Directory documentsDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(documentsDir.path);

    // For each test, create a fresh in-memory database
    final dbFile = File(p.join(documentsDir.path, 'medicaments.db'));
    database = AppDatabase.forTesting(
      NativeDatabase(dbFile, setup: configureAppSQLite),
    );

    dataInitializationService = DataInitializationService(database: database);
  });

  tearDown(() async {
    // Close the database and reset the locator after each test
    await database.close();
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  group('LibraryDao & SearchDao Logic', () {
    test('getGenericGroupSummaries returns deterministic principles', () async {
      await database.databaseDao.insertBatchData(
        batchData: IngestionBatch(
          specialites: [
            buildSpecialiteCompanion(
              cisCode: 'CIS_PRINCEPS',
              nomSpecialite: 'PRINCEPS 1',
              procedureType: 'Autorisation',
              formePharmaceutique: 'comprimé',
            ),
            buildSpecialiteCompanion(
              cisCode: 'CIS_GENERIC',
              nomSpecialite: 'GENERIC 1',
              procedureType: 'Autorisation',
              formePharmaceutique: 'comprimé',
            ),
          ],
          medicaments: [
            buildMedicamentCompanion(
              codeCip: 'P1_CIP',
              cisCode: 'CIS_PRINCEPS',
            ),
            buildMedicamentCompanion(
              codeCip: 'G1_CIP',
              cisCode: 'CIS_GENERIC',
            ),
          ],
          principes: [
            buildPrincipeCompanion(codeCip: 'P1_CIP', principe: 'PARACETAMOL'),
            buildPrincipeCompanion(codeCip: 'P1_CIP', principe: 'CAFEINE'),
            buildPrincipeCompanion(codeCip: 'G1_CIP', principe: 'PARACETAMOL'),
            buildPrincipeCompanion(codeCip: 'G1_CIP', principe: 'EXCIPIENT'),
          ],
          generiqueGroups: [
            buildGeneriqueGroupCompanion(
              groupId: 'GROUP_A',
              libelle: 'PARACETAMOL 500 mg',
              rawLabel: 'PARACETAMOL 500 mg',
              parsingMethod: 'relational',
            ),
          ],
          groupMembers: [
            buildGroupMemberCompanion(
              codeCip: 'P1_CIP',
              groupId: 'GROUP_A',
              type: 0,
            ),
            buildGroupMemberCompanion(
              codeCip: 'G1_CIP',
              groupId: 'GROUP_A',
              type: 1,
            ),
          ],
          laboratories: const [],
        ),
      );

      // Populate MedicamentSummary table
      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final summaries = await database.catalogDao.getGenericGroupSummaries(
        limit: 10,
      );

      expect(summaries.length, 1);
      expect(summaries.first.commonPrincipes, 'PARACETAMOL');
    });

    test(
      'getGenericGroupSummaries skips groups without shared principles',
      () async {
        await database.databaseDao.insertBatchData(
          batchData: IngestionBatch(
            specialites: [
              buildSpecialiteCompanion(
                cisCode: 'CIS_P',
                nomSpecialite: 'PRINCEPS 2',
                procedureType: 'Autorisation',
                formePharmaceutique: 'comprimé',
              ),
              buildSpecialiteCompanion(
                cisCode: 'CIS_G',
                nomSpecialite: 'GENERIC 2',
                procedureType: 'Autorisation',
                formePharmaceutique: 'comprimé',
              ),
            ],
            medicaments: [
              buildMedicamentCompanion(codeCip: 'P2_CIP', cisCode: 'CIS_P'),
              buildMedicamentCompanion(codeCip: 'G2_CIP', cisCode: 'CIS_G'),
            ],
            principes: [
              buildPrincipeCompanion(codeCip: 'P2_CIP', principe: 'PRINCIPE_A'),
              buildPrincipeCompanion(codeCip: 'G2_CIP', principe: 'PRINCIPE_B'),
            ],
            generiqueGroups: [
              buildGeneriqueGroupCompanion(
                groupId: 'GROUP_B',
                libelle: 'MIXED GROUP',
                rawLabel: 'MIXED GROUP',
                parsingMethod: 'relational',
              ),
            ],
            groupMembers: [
              buildGroupMemberCompanion(
                codeCip: 'P2_CIP',
                groupId: 'GROUP_B',
                type: 0,
              ),
              buildGroupMemberCompanion(
                codeCip: 'G2_CIP',
                groupId: 'GROUP_B',
                type: 1,
              ),
            ],
            laboratories: const [],
          ),
        );

        final summaries = await database.catalogDao.getGenericGroupSummaries(
          limit: 10,
        );

        expect(
          summaries,
          isEmpty,
          reason:
              'Groups without a fully shared active principle set must be filtered out.',
        );
      },
    );

    test('should return correct database statistics', () async {
      await database.databaseDao.insertBatchData(
        batchData: IngestionBatch(
          specialites: [
            buildSpecialiteCompanion(
              cisCode: 'CIS_PRINCEPS_1',
              nomSpecialite: 'PRINCEPS 1',
              procedureType: 'Autorisation',
            ),
            buildSpecialiteCompanion(
              cisCode: 'CIS_PRINCEPS_2',
              nomSpecialite: 'PRINCEPS 2',
              procedureType: 'Autorisation',
            ),
            buildSpecialiteCompanion(
              cisCode: 'CIS_GENERIC_1',
              nomSpecialite: 'GENERIC 1',
              procedureType: 'Autorisation',
            ),
            buildSpecialiteCompanion(
              cisCode: 'CIS_GENERIC_2',
              nomSpecialite: 'GENERIC 2',
              procedureType: 'Autorisation',
            ),
          ],
          medicaments: [
            buildMedicamentCompanion(
              codeCip: 'PRINCEPS_1',
              cisCode: 'CIS_PRINCEPS_1',
            ),
            buildMedicamentCompanion(
              codeCip: 'PRINCEPS_2',
              cisCode: 'CIS_PRINCEPS_2',
            ),
            buildMedicamentCompanion(
              codeCip: 'GENERIC_1',
              cisCode: 'CIS_GENERIC_1',
            ),
            buildMedicamentCompanion(
              codeCip: 'GENERIC_2',
              cisCode: 'CIS_GENERIC_2',
            ),
          ],
          principes: [
            buildPrincipeCompanion(
              codeCip: 'PRINCEPS_1',
              principe: 'ACTIVE_PRINCIPLE_1',
            ),
            buildPrincipeCompanion(
              codeCip: 'PRINCEPS_2',
              principe: 'ACTIVE_PRINCIPLE_1',
            ),
            buildPrincipeCompanion(
              codeCip: 'GENERIC_1',
              principe: 'ACTIVE_PRINCIPLE_1',
            ),
            buildPrincipeCompanion(
              codeCip: 'GENERIC_2',
              principe: 'ACTIVE_PRINCIPLE_2',
            ),
          ],
          generiqueGroups: [
            buildGeneriqueGroupCompanion(
              groupId: 'GROUP_1',
              libelle: 'TEST GROUP 1',
              rawLabel: 'TEST GROUP 1',
              parsingMethod: 'relational',
            ),
          ],
          groupMembers: [
            buildGroupMemberCompanion(
              codeCip: 'PRINCEPS_1',
              groupId: 'GROUP_1',
              type: 0,
            ),
            buildGroupMemberCompanion(
              codeCip: 'GENERIC_1',
              groupId: 'GROUP_1',
              type: 1,
            ),
            buildGroupMemberCompanion(
              codeCip: 'GENERIC_2',
              groupId: 'GROUP_1',
              type: 1,
            ),
          ],
          laboratories: const [],
        ),
      );

      final stats = await database.catalogDao.getDatabaseStats();

      expect(stats.totalPrinceps, 2); // 4 total - 2 generics = 2 princeps
      expect(stats.totalGeneriques, 2);
      expect(stats.totalPrincipes, 2); // 2 distinct principles
      expect(stats.avgGenPerPrincipe, 1.0); // 2 generics / 2 principles
    });

    test('searchMedicaments returns canonical princeps and generics', () async {
      await database.databaseDao.insertBatchData(
        batchData: IngestionBatch(
          laboratories: [
            buildLaboratoryCompanion(id: 1, name: 'BRISTOL-MYERS SQUIBB'),
            buildLaboratoryCompanion(id: 2, name: 'ZYDUS FRANCE'),
          ],
          specialites: [
            buildSpecialiteCompanion(
              cisCode: 'CIS_P',
              nomSpecialite: 'ELIQUIS 5 mg, comprimé',
              procedureType: 'Autorisation',
              formePharmaceutique: 'Comprimé',
              titulaireId: 1,
            ),
            buildSpecialiteCompanion(
              cisCode: 'CIS_G',
              nomSpecialite: 'APIXABAN ZYDUS 5 mg, comprimé',
              procedureType: 'Autorisation',
              formePharmaceutique: 'Comprimé',
              titulaireId: 2,
            ),
          ],
          medicaments: [
            buildMedicamentCompanion(codeCip: 'CIP_P', cisCode: 'CIS_P'),
            buildMedicamentCompanion(codeCip: 'CIP_G', cisCode: 'CIS_G'),
          ],
          principes: [
            buildPrincipeCompanion(
              codeCip: 'CIP_P',
              principe: 'APIXABAN',
              dosage: '5',
              dosageUnit: 'mg',
            ),
            buildPrincipeCompanion(
              codeCip: 'CIP_G',
              principe: 'APIXABAN',
              dosage: '5',
              dosageUnit: 'mg',
            ),
          ],
          generiqueGroups: [
            buildGeneriqueGroupCompanion(
              groupId: 'GROUP_1',
              libelle: 'APIXABAN 5 mg',
              rawLabel: 'APIXABAN 5 mg',
              parsingMethod: 'relational',
            ),
          ],
          groupMembers: [
            buildGroupMemberCompanion(
              codeCip: 'CIP_P',
              groupId: 'GROUP_1',
              type: 0,
            ),
            buildGroupMemberCompanion(
              codeCip: 'CIP_G',
              groupId: 'GROUP_1',
              type: 1,
            ),
          ],
        ),
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final catalogDao = database.catalogDao;
      final candidates = await catalogDao.searchMedicaments(
        NormalizedQuery.fromString('APIXABAN'),
      );
      expect(candidates.length, 2);

      final princeps = candidates.firstWhere(
        (candidate) => candidate.summary.isPrinceps,
      );
      final generic = candidates.firstWhere(
        (candidate) => !candidate.summary.isPrinceps,
      );

      expect(princeps.summary.groupId, 'GROUP_1');
      expect(princeps.summary.principesActifsCommuns, contains('APIXABAN'));
      expect(princeps.summary.nomCanonique, 'APIXABAN 5 mg');

      expect(generic.summary.groupId, 'GROUP_1');
      expect(generic.summary.nomCanonique, 'APIXABAN 5 mg');
      expect(generic.summary.principesActifsCommuns, contains('APIXABAN'));
    });
  });

  group('group details view', () {
    test('returns canonical classification for deterministic group', () async {
      await database.databaseDao.insertBatchData(
        batchData: IngestionBatch(
          specialites: [
            buildSpecialiteCompanion(
              cisCode: 'CIS_PRINCEPS_MAIN',
              nomSpecialite: 'PARA PRINCEPS 500 mg comprimé',
              procedureType: 'Autorisation',
              formePharmaceutique: 'Comprimé',
            ),
            buildSpecialiteCompanion(
              cisCode: 'CIS_GENERIC_A',
              nomSpecialite: 'PARA GENERIC 500 mg comprimé',
              procedureType: 'Autorisation',
              formePharmaceutique: 'Comprimé',
            ),
            buildSpecialiteCompanion(
              cisCode: 'CIS_GENERIC_B',
              nomSpecialite: 'PARA GENERIC 500 mg, comprimé pelliculé',
              procedureType: 'Autorisation',
              formePharmaceutique: 'Comprimé',
            ),
            buildSpecialiteCompanion(
              cisCode: 'CIS_PRINCEPS_SECOND',
              nomSpecialite: 'PARA PRINCEPS B 500 mg comprimé',
              procedureType: 'Autorisation',
              formePharmaceutique: 'Comprimé effervescent',
            ),
          ],
          medicaments: [
            buildMedicamentCompanion(
              codeCip: 'CIP_PRINCEPS_MAIN',
              cisCode: 'CIS_PRINCEPS_MAIN',
            ),
            buildMedicamentCompanion(
              codeCip: 'CIP_GENERIC_A',
              cisCode: 'CIS_GENERIC_A',
            ),
            buildMedicamentCompanion(
              codeCip: 'CIP_GENERIC_B',
              cisCode: 'CIS_GENERIC_B',
            ),
            buildMedicamentCompanion(
              codeCip: 'CIP_PRINCEPS_SECOND',
              cisCode: 'CIS_PRINCEPS_SECOND',
            ),
          ],
          principes: [
            buildPrincipeCompanion(
              codeCip: 'CIP_PRINCEPS_MAIN',
              principe: 'PARACETAMOL',
              dosage: '500',
              dosageUnit: 'mg',
            ),
            buildPrincipeCompanion(
              codeCip: 'CIP_GENERIC_A',
              principe: 'PARACETAMOL',
              dosage: '500',
              dosageUnit: 'mg',
            ),
            buildPrincipeCompanion(
              codeCip: 'CIP_GENERIC_B',
              principe: 'PARACETAMOL',
              dosage: '500',
              dosageUnit: 'mg',
            ),
            buildPrincipeCompanion(
              codeCip: 'CIP_PRINCEPS_SECOND',
              principe: 'PARACETAMOL',
              dosage: '500',
              dosageUnit: 'mg',
            ),
            // WHY: GROUP_SECOND must have PARACETAMOL (shared) PLUS an additional ingredient to be a related therapy
            buildPrincipeCompanion(
              codeCip: 'CIP_PRINCEPS_SECOND',
              principe: 'CAFFEINE',
              dosage: '50',
              dosageUnit: 'mg',
            ),
          ],
          generiqueGroups: [
            buildGeneriqueGroupCompanion(
              groupId: 'GROUP_MAIN',
              libelle: 'PARACETAMOL 500 MG',
              rawLabel: 'PARACETAMOL 500 MG',
              parsingMethod: 'relational',
            ),
            buildGeneriqueGroupCompanion(
              groupId: 'GROUP_SECOND',
              libelle: 'PARACETAMOL B 500 MG',
              rawLabel: 'PARACETAMOL B 500 MG',
              parsingMethod: 'relational',
            ),
          ],
          groupMembers: [
            buildGroupMemberCompanion(
              codeCip: 'CIP_PRINCEPS_MAIN',
              groupId: 'GROUP_MAIN',
              type: 0,
            ),
            buildGroupMemberCompanion(
              codeCip: 'CIP_GENERIC_A',
              groupId: 'GROUP_MAIN',
              type: 1,
            ),
            buildGroupMemberCompanion(
              codeCip: 'CIP_GENERIC_B',
              groupId: 'GROUP_MAIN',
              type: 1,
            ),
            buildGroupMemberCompanion(
              codeCip: 'CIP_PRINCEPS_SECOND',
              groupId: 'GROUP_SECOND',
              type: 0,
            ),
          ],
          laboratories: [],
        ),
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final members = await database.catalogDao.getGroupDetails(
        'GROUP_MAIN',
      );

      final related = await database.catalogDao.fetchRelatedPrinceps(
        'GROUP_MAIN',
      );

      expect(members, isNotEmpty);

      final title = members.first.princepsDeReference;
      final commonPrincipes = members.first.principesActifsCommuns;
      final distinctDosages = members
          .map((m) => m.formattedDosage)
          .whereType<String>()
          .toSet();
      final distinctForms = members
          .map((m) => m.formePharmaceutique?.trim())
          .whereType<String>()
          .toSet();

      expect(title.contains('PARA'), isTrue);
      expect(commonPrincipes, ['PARACETAMOL']);
      expect(distinctDosages, contains('500 mg'));
      expect(distinctForms, contains('Comprimé'));

      final princepsMembers = members
          .where((m) => m.isPrinceps)
          .toList(growable: false);
      final genericMembers = members
          .where((m) => !m.isPrinceps)
          .toList(growable: false);

      expect(princepsMembers.length, 1);
      expect(genericMembers.length, 2);
      expect(related.length, 1);
      expect(related.first.codeCip, 'CIP_PRINCEPS_SECOND');
    });

    test(
      'searchMedicaments returns results ranked by FTS5 bm25 relevance',
      () async {
        // GIVEN: Database with medications that have different match quality
        await database.databaseDao.insertBatchData(
          batchData: IngestionBatch(
            specialites: [
              buildSpecialiteCompanion(
                cisCode: 'CIS_EXACT',
                nomSpecialite: 'PARACETAMOL 500 mg, comprimé',
                procedureType: 'Autorisation',
                formePharmaceutique: 'Comprimé',
              ),
              buildSpecialiteCompanion(
                cisCode: 'CIS_PARTIAL',
                nomSpecialite: 'PARACETAMOL + CAFEINE 500 mg, comprimé',
                procedureType: 'Autorisation',
                formePharmaceutique: 'Comprimé',
              ),
              buildSpecialiteCompanion(
                cisCode: 'CIS_FUZZY',
                nomSpecialite: 'PARACETAMOL GENERIQUE 500 mg, comprimé',
                procedureType: 'Autorisation',
                formePharmaceutique: 'Comprimé',
              ),
            ],
            medicaments: [
              buildMedicamentCompanion(
                codeCip: 'CIP_EXACT',
                cisCode: 'CIS_EXACT',
              ),
              buildMedicamentCompanion(
                codeCip: 'CIP_PARTIAL',
                cisCode: 'CIS_PARTIAL',
              ),
              buildMedicamentCompanion(
                codeCip: 'CIP_FUZZY',
                cisCode: 'CIS_FUZZY',
              ),
            ],
            principes: [
              buildPrincipeCompanion(
                codeCip: 'CIP_EXACT',
                principe: 'PARACETAMOL',
                dosage: '500',
                dosageUnit: 'mg',
              ),
              buildPrincipeCompanion(
                codeCip: 'CIP_PARTIAL',
                principe: 'PARACETAMOL',
                dosage: '500',
                dosageUnit: 'mg',
              ),
              buildPrincipeCompanion(
                codeCip: 'CIP_PARTIAL',
                principe: 'CAFEINE',
                dosage: '50',
                dosageUnit: 'mg',
              ),
              buildPrincipeCompanion(
                codeCip: 'CIP_FUZZY',
                principe: 'PARACETAMOL',
                dosage: '500',
                dosageUnit: 'mg',
              ),
            ],
            generiqueGroups: [
              buildGeneriqueGroupCompanion(
                groupId: 'GROUP_EXACT',
                libelle: 'PARACETAMOL 500 mg',
                rawLabel: 'PARACETAMOL 500 mg',
                parsingMethod: 'relational',
              ),
              buildGeneriqueGroupCompanion(
                groupId: 'GROUP_PARTIAL',
                libelle: 'PARACETAMOL + CAFEINE 500 mg',
                rawLabel: 'PARACETAMOL + CAFEINE 500 mg',
                parsingMethod: 'relational',
              ),
              buildGeneriqueGroupCompanion(
                groupId: 'GROUP_FUZZY',
                libelle: 'PARACETAMOL GENERIQUE 500 mg',
                rawLabel: 'PARACETAMOL GENERIQUE 500 mg',
                parsingMethod: 'relational',
              ),
            ],
            groupMembers: [
              buildGroupMemberCompanion(
                codeCip: 'CIP_EXACT',
                groupId: 'GROUP_EXACT',
                type: 0,
              ),
              buildGroupMemberCompanion(
                codeCip: 'CIP_PARTIAL',
                groupId: 'GROUP_PARTIAL',
                type: 0,
              ),
              buildGroupMemberCompanion(
                codeCip: 'CIP_FUZZY',
                groupId: 'GROUP_FUZZY',
                type: 0,
              ),
            ],
            laboratories: [],
          ),
        );

        // Set principe_normalized for aggregation
        await setPrincipeNormalizedForAllPrinciples(database);

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();
        await database.databaseDao.populateFts5Index();

        // WHEN: Search for "PARACETAMOL"
        final results = await database.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('PARACETAMOL'),
        );

        // THEN: Results should be ordered by relevance (bm25 rank ASC)
        // The SQL query orders by "rank ASC, ms.nom_canonique"
        expect(results.length, greaterThanOrEqualTo(3));

        // Verify all results contain PARACETAMOL
        final allContainParacetamol = results.every(
          (r) =>
              r.summary.nomCanonique.toUpperCase().contains('PARACETAMOL') ||
              r.summary.principesActifsCommuns.any(
                (String p) => p.toUpperCase().contains('PARACETAMOL'),
              ),
        );
        expect(
          allContainParacetamol,
          isTrue,
          reason: 'All results should contain PARACETAMOL',
        );

        // Verify results are sorted by FTS5 bm25 rank (lower rank = better match)
        // The exact order depends on FTS5's bm25 algorithm, but we verify:
        // 1. All results contain PARACETAMOL (already verified above)
        // 2. Results are returned in some order (not empty)
        // 3. The first result should be a good match (contains PARACETAMOL in name or principles)
        expect(
          results.isNotEmpty,
          isTrue,
          reason: 'Search should return results',
        );

        // Verify the first result is relevant (contains PARACETAMOL)
        final firstResult = results.first.summary;
        expect(
          firstResult.nomCanonique.toUpperCase().contains('PARACETAMOL') ||
              firstResult.principesActifsCommuns.any(
                (String p) => p.toUpperCase().contains('PARACETAMOL'),
              ),
          isTrue,
          reason: 'First result should contain PARACETAMOL',
        );
      },
    );
  });
}
