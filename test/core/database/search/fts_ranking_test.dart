import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/queries.drift.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FTS5 ranking and filtering', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      await db
          .into(db.specialites)
          .insert(
            SpecialitesCompanion.insert(
              cisCode: '1',
              nomSpecialite: 'Doliprane 500',
              procedureType: 'AMM',
            ),
          );
      await db
          .into(db.specialites)
          .insert(
            SpecialitesCompanion.insert(
              cisCode: '2',
              nomSpecialite: 'Doli 1000',
              procedureType: 'AMM',
            ),
          );
      await db
          .into(db.specialites)
          .insert(
            SpecialitesCompanion.insert(
              cisCode: '3',
              nomSpecialite: 'Paracetamol + Codeine',
              procedureType: 'AMM',
            ),
          );

      await db
          .into(db.medicaments)
          .insert(
            MedicamentsCompanion.insert(
              codeCip: '111',
              cisCode: '1',
            ),
          );
      await db
          .into(db.medicaments)
          .insert(
            MedicamentsCompanion.insert(
              codeCip: '222',
              cisCode: '2',
            ),
          );
      await db
          .into(db.medicaments)
          .insert(
            MedicamentsCompanion.insert(
              codeCip: '333',
              cisCode: '3',
            ),
          );

      await db
          .into(db.medicamentSummary)
          .insert(
            MedicamentSummaryCompanion.insert(
              cisCode: '1',
              nomCanonique: 'Doliprane 500',
              isPrinceps: true,
              groupId: const Value<String?>(null),
              memberType: const Value(0),
              principesActifsCommuns: const [],
              princepsDeReference: 'Doliprane 500',
              princepsBrandName: 'Doliprane',
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
          .into(db.medicamentSummary)
          .insert(
            MedicamentSummaryCompanion.insert(
              cisCode: '2',
              nomCanonique: 'Doli 1000',
              isPrinceps: true,
              groupId: const Value<String?>(null),
              memberType: const Value(0),
              principesActifsCommuns: const [],
              princepsDeReference: 'Doli 1000',
              princepsBrandName: 'Doli',
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
          .into(db.medicamentSummary)
          .insert(
            MedicamentSummaryCompanion.insert(
              cisCode: '3',
              nomCanonique: 'Paracetamol + Codeine',
              isPrinceps: true,
              groupId: const Value<String?>(null),
              memberType: const Value(0),
              principesActifsCommuns: const [],
              princepsDeReference: 'Paracetamol + Codeine',
              princepsBrandName: 'Paracetamol',
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
              cisCode: '1',
              moleculeName: normalizeForSearch('Doliprane 500 Dolipprane'),
              brandName: normalizeForSearch('Doliprane Dolipprane'),
            ),
          );
      await db
          .into(db.searchIndex)
          .insert(
            SearchIndexCompanion.insert(
              cisCode: '2',
              moleculeName: normalizeForSearch('Doli 1000'),
              brandName: normalizeForSearch('Doli'),
            ),
          );
      await db
          .into(db.searchIndex)
          .insert(
            SearchIndexCompanion.insert(
              cisCode: '3',
              moleculeName: normalizeForSearch('Paracetamol Codeine'),
              brandName: normalizeForSearch('Paracetamol'),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('exact match ranks above fuzzy match', () async {
      final results = await db.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('Doliprane'),
      );

      expect(results, isNotEmpty);
      expect(results.first.summary.cisCode, '1');
    });

    test('trigram search tolerates typos', () async {
      final results = await db.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('Dolipprane'),
      );

      expect(
        results.any((row) => row.summary.cisCode == '1'),
        isTrue,
      );
    });

    test(
      'percent characters are sanitized, not treated as wildcards',
      () async {
        final results = await db.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('Doli%'),
        );

        expect(
          results.any((row) => row.summary.cisCode == '2'),
          isTrue,
        );
      },
    );
  });
}
