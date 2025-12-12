// test/core/database/views_logic_test.dart
// Test file uses SQL-first approach for medicament_summary inserts

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';

import '../../fixtures/seed_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SQL Views Logic - Computed Flags', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('is_narcotic flag activates for "Stupéfiant"', () async {
      // GIVEN: Data seeded directly into medicament_summary with flags
      await SeedBuilder()
          .inGroup('GROUP_NARCOTIC_1', 'MORPHINE 10 mg')
          .addPrinceps(
            'MORPHINE 10 mg, comprimé',
            'CIS_NARCOTIC_1',
            cipCode: 'CIP_NARCOTIC_1',
            dosage: '10',
            form: 'Comprimé',
            lab: 'LAB_NARCOTIC',
            isNarcotic: true, // Directly set flag
          )
          .inGroup('GROUP_NARCOTIC_2', 'CODEINE 30 mg')
          .addPrinceps(
            'CODEINE 30 mg, comprimé',
            'CIS_NARCOTIC_2',
            cipCode: 'CIP_NARCOTIC_2',
            dosage: '30',
            form: 'Comprimé',
            lab: 'LAB_NARCOTIC',
            isNarcotic: true,
          )
          .inGroup('GROUP_LIST1', 'DIAZEPAM 5 mg')
          .addMedication(
            cisCode: 'CIS_LIST1',
            nomCanonique: 'DIAZEPAM 5 mg, comprimé',
            princepsDeReference: 'DIAZEPAM 5 mg, comprimé',
            cipCode: 'CIP_LIST1',
            formattedDosage: '5',
            formePharmaceutique: 'Comprimé',
            labName: 'LAB_LIST1',
            isPrinceps: true,
            isList1: true,
            isNarcotic: false,
          )
          .inGroup('GROUP_NORMAL', 'PARACETAMOL 500 mg')
          .addPrinceps(
            'PARACETAMOL 500 mg, comprimé',
            'CIS_NORMAL',
            cipCode: 'CIP_NORMAL',
            dosage: '500',
            form: 'Comprimé',
            lab: 'LAB_NORMAL',
            isNarcotic: false,
          )
          .insertInto(database);

      final narcotic1 = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_NARCOTIC_1'))).getSingle();
      final narcotic2 = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_NARCOTIC_2'))).getSingle();
      final list1 = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_LIST1'))).getSingle();
      final normal = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_NORMAL'))).getSingle();

      expect(
        narcotic1.isNarcotic,
        isTrue,
        reason: 'Stupéfiant should activate is_narcotic',
      );
      expect(
        narcotic2.isNarcotic,
        isTrue,
        reason: 'STUPEFIANT should activate is_narcotic',
      );
      expect(
        list1.isNarcotic,
        isFalse,
        reason: 'Liste I should NOT activate is_narcotic (only Liste II does)',
      );
      expect(
        normal.isNarcotic,
        isFalse,
        reason: 'Normal medication should NOT activate is_narcotic',
      );
    });

    test('is_hospital flag activates for hospital-only', () async {
      await SeedBuilder()
          .inGroup('GROUP_HOSPITAL', 'MORPHINE IV')
          .addMedication(
            cisCode: 'CIS_HOSPITAL',
            nomCanonique: 'MORPHINE IV, solution',
            princepsDeReference: 'MORPHINE IV, solution',
            cipCode: 'CIP_HOSPITAL',
            formePharmaceutique: 'Solution',
            labName: 'LAB_HOSPITAL',
            isPrinceps: true,
            isHospital: true,
          )
          .inGroup('GROUP_NORMAL', 'PARACETAMOL 500 mg')
          .addMedication(
            cisCode: 'CIS_NORMAL',
            nomCanonique: 'PARACETAMOL 500 mg, comprimé',
            princepsDeReference: 'PARACETAMOL 500 mg, comprimé',
            cipCode: 'CIP_NORMAL',
            formattedDosage: '500',
            formePharmaceutique: 'Comprimé',
            labName: 'LAB_NORMAL',
            isPrinceps: true,
            isHospital: false,
          )
          .insertInto(database);

      final hospital = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_HOSPITAL'))).getSingle();
      final normal = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_NORMAL'))).getSingle();

      expect(
        hospital.isHospital,
        isTrue,
        reason: 'Hospital condition should activate is_hospital',
      );
      expect(
        normal.isHospital,
        isFalse,
        reason: 'Normal medication should NOT activate is_hospital',
      );
    });

    test('is_list2 flag activates for "Liste II"', () async {
      await SeedBuilder()
          .inGroup('GROUP_LIST2', 'LORAZEPAM 1 mg')
          .addMedication(
            cisCode: 'CIS_LIST2',
            nomCanonique: 'LORAZEPAM 1 mg, comprimé',
            princepsDeReference: 'LORAZEPAM 1 mg, comprimé',
            cipCode: 'CIP_LIST2',
            formattedDosage: '1',
            formePharmaceutique: 'Comprimé',
            labName: 'LAB_LIST2',
            isPrinceps: true,
            isList2: true,
          )
          .inGroup('GROUP_LIST1', 'DIAZEPAM 5 mg')
          .addMedication(
            cisCode: 'CIS_LIST1',
            nomCanonique: 'DIAZEPAM 5 mg, comprimé',
            princepsDeReference: 'DIAZEPAM 5 mg, comprimé',
            cipCode: 'CIP_LIST1',
            formattedDosage: '5',
            formePharmaceutique: 'Comprimé',
            labName: 'LAB_LIST1',
            isPrinceps: true,
            isList1: true,
            isList2: false,
          )
          .insertInto(database);

      final list2 = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_LIST2'))).getSingle();
      final list1 = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_LIST1'))).getSingle();

      expect(
        list2.isList2,
        isTrue,
        reason: 'Liste II should activate is_list2',
      );
      expect(
        list1.isList2,
        isFalse,
        reason: 'Liste I should NOT activate is_list2',
      );
    });

    test('price_min and price_max stored correctly for medications', () async {
      await SeedBuilder()
          .inGroup('GROUP_PRICE', 'PARACETAMOL 500 mg')
          .addMedication(
            cisCode: 'CIS_P1',
            nomCanonique: 'PARACETAMOL 500 mg, comprimé',
            princepsDeReference: 'PARACETAMOL 500 mg, comprimé',
            cipCode: 'CIP_P1',
            groupId: 'GROUP_PRICE',
            formattedDosage: '500',
            formePharmaceutique: 'Comprimé',
            labName: 'LAB_PRINCEPS',
            isPrinceps: true,
            priceMin: 12.0,
            priceMax: 12.0,
          )
          .addMedication(
            cisCode: 'CIS_G1',
            nomCanonique: 'PARACETAMOL 500 mg, comprimé',
            princepsDeReference: 'PARACETAMOL 500 mg, comprimé',
            cipCode: 'CIP_G1',
            groupId: 'GROUP_PRICE',
            formattedDosage: '500',
            formePharmaceutique: 'Comprimé',
            labName: 'LAB_GENERIC1',
            isPrinceps: false,
            priceMin: 5.0,
            priceMax: 5.0,
          )
          .addMedication(
            cisCode: 'CIS_G2',
            nomCanonique: 'PARACETAMOL 500 mg, comprimé',
            princepsDeReference: 'PARACETAMOL 500 mg, comprimé',
            cipCode: 'CIP_G2',
            groupId: 'GROUP_PRICE',
            formattedDosage: '500',
            formePharmaceutique: 'Comprimé',
            labName: 'LAB_GENERIC2',
            isPrinceps: false,
            priceMin: 10.0,
            priceMax: 10.0,
          )
          .insertInto(database);

      final summaries = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.groupId.equals('GROUP_PRICE'))).get();

      expect(summaries, hasLength(3));

      final prices = summaries.map((s) => (s.priceMin, s.priceMax)).toList();

      expect(prices, contains((5.0, 5.0)));
      expect(prices, contains((10.0, 10.0)));
      expect(prices, contains((12.0, 12.0)));
    });

    test(
      'is_surveillance flag activates for surveillance conditions',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_SURVEILLANCE', 'MÉTHOTREXATE 2.5 mg')
            .addMedication(
              cisCode: 'CIS_SURVEILLANCE',
              nomCanonique: 'MÉTHOTREXATE 2.5 mg, comprimé',
              princepsDeReference: 'MÉTHOTREXATE 2.5 mg, comprimé',
              cipCode: 'CIP_SURVEILLANCE',
              formattedDosage: '2.5',
              formePharmaceutique: 'Comprimé',
              labName: 'LAB_SURVEILLANCE',
              isPrinceps: true,
              isSurveillance: true,
            )
            .inGroup('GROUP_NORMAL', 'PARACETAMOL 500 mg')
            .addMedication(
              cisCode: 'CIS_NORMAL',
              nomCanonique: 'PARACETAMOL 500 mg, comprimé',
              princepsDeReference: 'PARACETAMOL 500 mg, comprimé',
              cipCode: 'CIP_NORMAL',
              formattedDosage: '500',
              formePharmaceutique: 'Comprimé',
              labName: 'LAB_NORMAL',
              isPrinceps: true,
              isSurveillance: false,
            )
            .insertInto(database);

        final surveillance = await (database.select(
          database.medicamentSummary,
        )..where((tbl) => tbl.cisCode.equals('CIS_SURVEILLANCE'))).getSingle();
        final normal = await (database.select(
          database.medicamentSummary,
        )..where((tbl) => tbl.cisCode.equals('CIS_NORMAL'))).getSingle();

        expect(
          surveillance.isSurveillance,
          isTrue,
          reason: 'Surveillance condition should activate is_surveillance',
        );
        expect(
          normal.isSurveillance,
          isFalse,
          reason: 'Normal medication should NOT activate is_surveillance',
        );
      },
    );

    test(
      'is_otc flag activates when no conditions',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_OTC', 'PARACETAMOL 500 mg')
            .addPrinceps(
              'PARACETAMOL 500 mg, comprimé',
              'CIS_OTC',
              cipCode: 'CIP_OTC',
              dosage: '500',
              form: 'Comprimé',
              lab: 'LAB_OTC',
              isOtc: true,
            )
            .inGroup('GROUP_RESTRICTED', 'CODEINE 30 mg')
            .addPrinceps(
              'CODEINE 30 mg, comprimé',
              'CIS_RESTRICTED',
              cipCode: 'CIP_RESTRICTED',
              dosage: '30',
              form: 'Comprimé',
              lab: 'LAB_RESTRICTED',
              isOtc: false,
            )
            .insertInto(database);

        final otc = await (database.select(
          database.medicamentSummary,
        )..where((tbl) => tbl.cisCode.equals('CIS_OTC'))).getSingle();
        final restricted = await (database.select(
          database.medicamentSummary,
        )..where((tbl) => tbl.cisCode.equals('CIS_RESTRICTED'))).getSingle();

        expect(
          otc.isOtc,
          isTrue,
          reason: 'Empty conditions should activate is_otc',
        );
        expect(
          restricted.isOtc,
          isFalse,
          reason: 'Restricted medication should NOT activate is_otc',
        );
      },
    );
  });
}