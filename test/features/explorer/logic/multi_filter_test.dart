import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/features/explorer/domain/models/explorer_enums.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explorer multi-filter AND logic', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      Future<void> seed({
        required String cis,
        required String codeCip,
        required String name,
        required String route,
        required String atc,
      }) async {
        await db
            .into(db.specialites)
            .insert(
              SpecialitesCompanion.insert(
                cisCode: cis,
                nomSpecialite: name,
                procedureType: 'AMM',
                voiesAdministration: Value(route),
                atcCode: Value(atc),
              ),
            );
        await db
            .into(db.medicaments)
            .insert(
              MedicamentsCompanion.insert(
                codeCip: codeCip,
                cisCode: cis,
              ),
            );
        await db
            .into(db.medicamentSummary)
            .insert(
              MedicamentSummaryCompanion.insert(
                cisCode: cis,
                nomCanonique: name,
                isPrinceps: true,
                groupId: const Value<String?>(null),
                memberType: const Value(0),
                principesActifsCommuns: const [],
                princepsDeReference: name,
                princepsBrandName: name,
                voiesAdministration: Value(route),
                atcCode: Value(atc),
                isHospitalOnly: const Value(false),
                isDental: const Value(false),
                isList1: const Value(false),
                isList2: const Value(false),
                isNarcotic: const Value(false),
                isException: const Value(false),
                isRestricted: const Value(false),
                isOtc: const Value(true),
              ),
            );
        await db
            .into(db.searchIndex)
            .insert(
              SearchIndexCompanion.insert(
                cisCode: cis,
                moleculeName: name.toLowerCase(),
                brandName: name.toLowerCase(),
              ),
            );
      }

      await seed(
        cis: 'A',
        codeCip: '111',
        name: 'Item A',
        route: 'Orale',
        atc: 'A01',
      );
      await seed(
        cis: 'B',
        codeCip: '222',
        name: 'Item B',
        route: 'Orale',
        atc: 'B02',
      );
      await seed(
        cis: 'C',
        codeCip: '333',
        name: 'Item C',
        route: 'Injectable',
        atc: 'A01',
      );
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
      expect(results.first.summary.cisCode, 'A');
    });
  });
}
