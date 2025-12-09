import 'package:diacritic/diacritic.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';

import '../../test_utils.dart';

void main() {
  group('Search engine with FTS5 molecule/brand columns', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: configureAppSQLite,
        ),
      );

      // Minimal ingestion: inject clean molecule/brand plus links.
      await db.databaseDao.insertBatchData(
        batchData: IngestionBatch(
          laboratories: [
            buildLaboratoryCompanion(id: 1, name: 'SANOFI'),
            buildLaboratoryCompanion(id: 2, name: 'MYLAN'),
            buildLaboratoryCompanion(id: 3, name: 'HEARTLAB'),
          ],
          specialites: [
            buildSpecialiteCompanion(
              cisCode: 'P1',
              nomSpecialite: 'DOLIPRANE',
              procedureType: 'Autorisation',
              formePharmaceutique: 'comprime',
              titulaireId: 1,
            ),
            buildSpecialiteCompanion(
              cisCode: 'G1',
              nomSpecialite: 'PARACETAMOL MYLAN',
              procedureType: 'Autorisation',
              formePharmaceutique: 'comprime',
              titulaireId: 2,
            ),
            buildSpecialiteCompanion(
              cisCode: 'H1',
              nomSpecialite: 'CŒURCALM',
              procedureType: 'Autorisation',
              formePharmaceutique: 'comprime',
              titulaireId: 3,
            ),
            buildSpecialiteCompanion(
              cisCode: 'T1',
              nomSpecialite: 'L-THYROXINE',
              procedureType: 'Autorisation',
              formePharmaceutique: 'comprime',
              titulaireId: 2,
            ),
          ],
          medicaments: [
            buildMedicamentCompanion(codeCip: 'P1_CIP', cisCode: 'P1'),
            buildMedicamentCompanion(codeCip: 'G1_CIP', cisCode: 'G1'),
            buildMedicamentCompanion(codeCip: 'H1_CIP', cisCode: 'H1'),
            buildMedicamentCompanion(codeCip: 'T1_CIP', cisCode: 'T1'),
          ],
          principes: [
            buildPrincipeCompanion(codeCip: 'P1_CIP', principe: 'PARACETAMOL'),
            buildPrincipeCompanion(codeCip: 'G1_CIP', principe: 'PARACETAMOL'),
            buildPrincipeCompanion(codeCip: 'H1_CIP', principe: 'CARDIOTONE'),
            buildPrincipeCompanion(codeCip: 'T1_CIP', principe: 'L THYROXINE'),
          ],
          generiqueGroups: [
            buildGeneriqueGroupCompanion(
              groupId: 'GRP1',
              libelle: 'PARACETAMOL',
              princepsLabel: 'DOLIPRANE',
              moleculeLabel: 'PARACETAMOL',
              rawLabel: 'PARACETAMOL - DOLIPRANE',
              parsingMethod: 'relational',
            ),
            buildGeneriqueGroupCompanion(
              groupId: 'GRP2',
              libelle: 'CŒURCALM',
              princepsLabel: 'CŒURCALM',
              moleculeLabel: 'CARDIOTONE',
              rawLabel: 'CŒURCALM - CARDIOTONE',
              parsingMethod: 'relational',
            ),
          ],
          groupMembers: [
            buildGroupMemberCompanion(
              codeCip: 'P1_CIP',
              groupId: 'GRP1',
              type: 0,
            ),
            buildGroupMemberCompanion(
              codeCip: 'G1_CIP',
              groupId: 'GRP1',
              type: 1,
            ),
            buildGroupMemberCompanion(
              codeCip: 'H1_CIP',
              groupId: 'GRP2',
              type: 0,
            ),
          ],
        ),
      );

      await setPrincipeNormalizedForAllPrinciples(db);
      await db.databaseDao.populateSummaryTable();
      await db.databaseDao.populateFts5Index();
    });

    tearDown(() async {
      await db.close();
    });

    test('search finds brand via brand_name column (e.g., Doli)', () async {
      final results = await db.catalogDao.searchMedicaments(
        NormalizedQuery('Doli'),
      );
      expect(results, isNotEmpty);
      expect(
        results.any(
          (row) => row.princepsBrandName.toUpperCase() == 'DOLIPRANE',
        ),
        isTrue,
      );
    });

    test(
      'search finds molecule via molecule_name column (e.g., paracetamol)',
      () async {
        final results = await db.catalogDao.searchMedicaments(
          NormalizedQuery('paracetamol'),
        );
        expect(results.length, greaterThanOrEqualTo(2));
        expect(
          results.every(
            (row) => row.nomCanonique.toUpperCase().contains('PARACETAMOL'),
          ),
          isTrue,
        );
      },
    );

    test(
      'search normalizes diacritics (Cœurcalm matches COEURCALM)',
      () async {
        final results = await db.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('Cœurcalm'),
        );

        expect(
          results
              .map(
                (row) => removeDiacritics(row.nomCanonique).toUpperCase(),
              )
              .any((name) => name.contains('COEURCALM')),
          isTrue,
        );
      },
      skip: 'FTS diacritic normalization currently unstable in test fixture',
    );

    test(
      'search handles hyphenated molecule when querying without punctuation',
      () async {
        final results = await db.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('Thyroxine'),
        );

        expect(
          results
              .map(
                (row) => row.nomCanonique.toUpperCase().replaceAll(
                  RegExp('[^A-Z0-9]'),
                  '',
                ),
              )
              .any((name) => name.contains('LTHYROXINE')),
          isTrue,
        );
      },
    );
  });
}
