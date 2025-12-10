// test/core/database/views_logic_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

import '../../fixtures/seed_builder.dart';
import '../../test_utils.dart' show setPrincipeNormalizedForAllPrinciples;

List<SpecialitesCompanion> _specialites(List<Map<String, dynamic>> rows) {
  return rows
      .map(
        (row) => SpecialitesCompanion(
          cisCode: Value(row['cis_code'] as String),
          nomSpecialite: Value(row['nom_specialite'] as String),
          procedureType: Value(
            row['procedure_type'] as String? ?? 'Autorisation',
          ),
          formePharmaceutique: Value(
            row['forme_pharmaceutique'] as String? ?? '',
          ),
          etatCommercialisation: Value(
            row['etat_commercialisation'] as String? ?? '',
          ),
          titulaireId: Value(row['titulaire_id'] as int?),
          conditionsPrescription: Value(
            row['conditions_prescription'] as String?,
          ),
          isSurveillance: Value(row['is_surveillance'] as bool? ?? false),
        ),
      )
      .toList();
}

List<MedicamentsCompanion> _medicaments(List<Map<String, dynamic>> rows) {
  return rows
      .map(
        (row) => MedicamentsCompanion(
          codeCip: Value(row['code_cip'] as String),
          cisCode: Value(row['cis_code'] as String),
          presentationLabel: Value(row['presentation_label'] as String?),
          commercialisationStatut: Value(
            row['commercialisation_statut'] as String?,
          ),
          tauxRemboursement: Value(row['taux_remboursement'] as String?),
          prixPublic: Value(row['prix_public'] as double?),
        ),
      )
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SQL Views Logic - Computed Flags', () {
    late AppDatabase database;
    late DataInitializationService dataInitializationService;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );
      dataInitializationService = DataInitializationService(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('is_narcotic flag activates for "Stupéfiant" and "Liste I"', () async {
      await SeedBuilder()
          .inGroup('GROUP_NARCOTIC_1', 'MORPHINE 10 mg')
          .addPrinceps(
            'MORPHINE 10 mg, comprimé',
            'CIP_NARCOTIC_1',
            cis: 'CIS_NARCOTIC_1',
            dosage: '10',
            form: 'Comprimé',
            lab: 'LAB_NARCOTIC',
          )
          .inGroup('GROUP_NARCOTIC_2', 'CODEINE 30 mg')
          .addPrinceps(
            'CODEINE 30 mg, comprimé',
            'CIP_NARCOTIC_2',
            cis: 'CIS_NARCOTIC_2',
            dosage: '30',
            form: 'Comprimé',
            lab: 'LAB_NARCOTIC',
          )
          .inGroup('GROUP_LIST1', 'DIAZEPAM 5 mg')
          .addPrinceps(
            'DIAZEPAM 5 mg, comprimé',
            'CIP_LIST1',
            cis: 'CIS_LIST1',
            dosage: '5',
            form: 'Comprimé',
            lab: 'LAB_LIST1',
          )
          .inGroup('GROUP_NORMAL', 'PARACETAMOL 500 mg')
          .addPrinceps(
            'PARACETAMOL 500 mg, comprimé',
            'CIP_NORMAL',
            cis: 'CIS_NORMAL',
            dosage: '500',
            form: 'Comprimé',
            lab: 'LAB_NORMAL',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        batchData: const IngestionBatch(
          specialites: [
            SpecialitesCompanion(
              cisCode: Value('CIS_NARCOTIC_1'),
              nomSpecialite: Value('MORPHINE 10 mg, comprimé'),
              procedureType: Value('Autorisation'),
              formePharmaceutique: Value('Comprimé'),
              conditionsPrescription: Value('STUPÉFIANT'),
            ),
            SpecialitesCompanion(
              cisCode: Value('CIS_NARCOTIC_2'),
              nomSpecialite: Value('CODEINE 30 mg, comprimé'),
              procedureType: Value('Autorisation'),
              formePharmaceutique: Value('Comprimé'),
              conditionsPrescription: Value('STUPEFIANT'),
            ),
            SpecialitesCompanion(
              cisCode: Value('CIS_LIST1'),
              nomSpecialite: Value('DIAZEPAM 5 mg, comprimé'),
              procedureType: Value('Autorisation'),
              formePharmaceutique: Value('Comprimé'),
              conditionsPrescription: Value('Liste I'),
            ),
            SpecialitesCompanion(
              cisCode: Value('CIS_NORMAL'),
              nomSpecialite: Value('PARACETAMOL 500 mg, comprimé'),
              procedureType: Value('Autorisation'),
              formePharmaceutique: Value('Comprimé'),
              conditionsPrescription: Value(''),
            ),
          ],
          medicaments: [],
          principes: [],
          generiqueGroups: [],
          groupMembers: [],
          laboratories: [],
        ),
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

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

    test('is_hospital flag activates for hospital-only conditions', () async {
      await SeedBuilder()
          .inGroup('GROUP_HOSPITAL', 'MORPHINE IV')
          .addPrinceps(
            'MORPHINE IV, solution',
            'CIP_HOSPITAL',
            cis: 'CIS_HOSPITAL',
            form: 'Solution',
            lab: 'LAB_HOSPITAL',
          )
          .inGroup('GROUP_NORMAL', 'PARACETAMOL 500 mg')
          .addPrinceps(
            'PARACETAMOL 500 mg, comprimé',
            'CIP_NORMAL',
            cis: 'CIS_NORMAL',
            dosage: '500',
            form: 'Comprimé',
            lab: 'LAB_NORMAL',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        batchData: const IngestionBatch(
          specialites: [
            SpecialitesCompanion(
              cisCode: Value('CIS_HOSPITAL'),
              nomSpecialite: Value('MORPHINE IV, solution'),
              procedureType: Value('Autorisation'),
              formePharmaceutique: Value('Solution'),
              conditionsPrescription: Value("Réservé à l'usage hospitalier"),
            ),
            SpecialitesCompanion(
              cisCode: Value('CIS_NORMAL'),
              nomSpecialite: Value('PARACETAMOL 500 mg, comprimé'),
              procedureType: Value('Autorisation'),
              formePharmaceutique: Value('Comprimé'),
              conditionsPrescription: Value(''),
            ),
          ],
          medicaments: <MedicamentsCompanion>[],
          principes: <PrincipesActifsCompanion>[],
          generiqueGroups: <GeneriqueGroupsCompanion>[],
          groupMembers: <GroupMembersCompanion>[],
          laboratories: <LaboratoriesCompanion>[],
        ),
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final hospital = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_HOSPITAL'))).getSingle();
      final normal = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_NORMAL'))).getSingle();

      expect(
        hospital.isHospitalOnly,
        isTrue,
        reason: 'Hospital condition should activate is_hospital',
      );
      expect(
        normal.isHospitalOnly,
        isFalse,
        reason: 'Normal medication should NOT activate is_hospital',
      );
    });

    test('is_list2 flag activates for "Liste II"', () async {
      await SeedBuilder()
          .inGroup('GROUP_LIST2', 'LORAZEPAM 1 mg')
          .addPrinceps(
            'LORAZEPAM 1 mg, comprimé',
            'CIP_LIST2',
            cis: 'CIS_LIST2',
            dosage: '1',
            form: 'Comprimé',
            lab: 'LAB_LIST2',
          )
          .inGroup('GROUP_LIST1', 'DIAZEPAM 5 mg')
          .addPrinceps(
            'DIAZEPAM 5 mg, comprimé',
            'CIP_LIST1',
            cis: 'CIS_LIST1',
            dosage: '5',
            form: 'Comprimé',
            lab: 'LAB_LIST1',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        batchData: IngestionBatch(
          specialites: _specialites([
            {
              'cis_code': 'CIS_LIST2',
              'nom_specialite': 'LORAZEPAM 1 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire_id': null,
              'conditions_prescription': 'Liste II',
            },
            {
              'cis_code': 'CIS_LIST1',
              'nom_specialite': 'DIAZEPAM 5 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire_id': null,
              'conditions_prescription': 'Liste I',
            },
          ]),
          medicaments: const <MedicamentsCompanion>[],
          principes: const <PrincipesActifsCompanion>[],
          generiqueGroups: const <GeneriqueGroupsCompanion>[],
          groupMembers: const <GroupMembersCompanion>[],
          laboratories: const <LaboratoriesCompanion>[],
        ),
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

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

    test('price_min and price_max computed correctly for groups', () async {
      await SeedBuilder()
          .inGroup('GROUP_PRICE', 'PARACETAMOL 500 mg')
          .addPrinceps(
            'PARACETAMOL 500 mg, comprimé',
            'CIP_P1',
            cis: 'CIS_P1',
            dosage: '500',
            form: 'Comprimé',
            lab: 'LAB_PRINCEPS',
          )
          .addGeneric(
            'PARACETAMOL 500 mg, comprimé',
            'CIP_G1',
            cis: 'CIS_G1',
            dosage: '500',
            form: 'Comprimé',
            lab: 'LAB_GENERIC1',
          )
          .addGeneric(
            'PARACETAMOL 500 mg, comprimé',
            'CIP_G2',
            cis: 'CIS_G2',
            dosage: '500',
            form: 'Comprimé',
            lab: 'LAB_GENERIC2',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        batchData: IngestionBatch(
          specialites: const <SpecialitesCompanion>[],
          medicaments: _medicaments(
            [
              {
                'code_cip': 'CIP_P1',
                'cis_code': 'CIS_P1',
                'prix_public': 12.0,
              },
              {
                'code_cip': 'CIP_G1',
                'cis_code': 'CIS_G1',
                'prix_public': 5.0,
              },
              {
                'code_cip': 'CIP_G2',
                'cis_code': 'CIS_G2',
                'prix_public': 10.0,
              },
            ],
          ),
          principes: const <PrincipesActifsCompanion>[],
          generiqueGroups: const <GeneriqueGroupsCompanion>[],
          groupMembers: const <GroupMembersCompanion>[],
          laboratories: const <LaboratoriesCompanion>[],
        ),
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final summaries = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.groupId.equals('GROUP_PRICE'))).get();

      expect(summaries, isNotEmpty);

      final priceMin = summaries
          .map((s) => s.priceMin)
          .whereType<double>()
          .reduce((a, b) => a < b ? a : b);
      final priceMax = summaries
          .map((s) => s.priceMax)
          .whereType<double>()
          .reduce((a, b) => a > b ? a : b);

      expect(priceMin, equals(5.0), reason: 'price_min should be 5.0');
      expect(priceMax, equals(12.0), reason: 'price_max should be 12.0');
    });

    test(
      'is_surveillance flag activates for surveillance conditions',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_SURVEILLANCE', 'MÉTHOTREXATE 2.5 mg')
            .addPrinceps(
              'MÉTHOTREXATE 2.5 mg, comprimé',
              'CIP_SURVEILLANCE',
              cis: 'CIS_SURVEILLANCE',
              dosage: '2.5',
              form: 'Comprimé',
              lab: 'LAB_SURVEILLANCE',
            )
            .inGroup('GROUP_NORMAL', 'PARACETAMOL 500 mg')
            .addPrinceps(
              'PARACETAMOL 500 mg, comprimé',
              'CIP_NORMAL',
              cis: 'CIS_NORMAL',
              dosage: '500',
              form: 'Comprimé',
              lab: 'LAB_NORMAL',
            )
            .insertInto(database);

        await database.databaseDao.insertBatchData(
          batchData: IngestionBatch(
            specialites: _specialites([
              {
                'cis_code': 'CIS_SURVEILLANCE',
                'nom_specialite': 'MÉTHOTREXATE 2.5 mg, comprimé',
                'procedure_type': 'Autorisation',
                'forme_pharmaceutique': 'Comprimé',
                'titulaire_id': null,
                'conditions_prescription': 'Surveillance particulière',
                'is_surveillance': true,
              },
              {
                'cis_code': 'CIS_NORMAL',
                'nom_specialite': 'PARACETAMOL 500 mg, comprimé',
                'procedure_type': 'Autorisation',
                'forme_pharmaceutique': 'Comprimé',
                'titulaire_id': null,
                'conditions_prescription': '',
                'is_surveillance': false,
              },
            ]),
            medicaments: const <MedicamentsCompanion>[],
            principes: const <PrincipesActifsCompanion>[],
            generiqueGroups: const <GeneriqueGroupsCompanion>[],
            groupMembers: const <GroupMembersCompanion>[],
            laboratories: const <LaboratoriesCompanion>[],
          ),
        );

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

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
      'is_otc flag activates when conditions_prescription is empty',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_OTC', 'PARACETAMOL 500 mg')
            .addPrinceps(
              'PARACETAMOL 500 mg, comprimé',
              'CIP_OTC',
              cis: 'CIS_OTC',
              dosage: '500',
              form: 'Comprimé',
              lab: 'LAB_OTC',
            )
            .inGroup('GROUP_RESTRICTED', 'CODEINE 30 mg')
            .addPrinceps(
              'CODEINE 30 mg, comprimé',
              'CIP_RESTRICTED',
              cis: 'CIS_RESTRICTED',
              dosage: '30',
              form: 'Comprimé',
              lab: 'LAB_RESTRICTED',
            )
            .insertInto(database);

        await database.databaseDao.insertBatchData(
          batchData: IngestionBatch(
            specialites: _specialites([
              {
                'cis_code': 'CIS_OTC',
                'nom_specialite': 'PARACETAMOL 500 mg, comprimé',
                'procedure_type': 'Autorisation',
                'forme_pharmaceutique': 'Comprimé',
                'titulaire_id': null,
                'conditions_prescription': '',
              },
              {
                'cis_code': 'CIS_RESTRICTED',
                'nom_specialite': 'CODEINE 30 mg, comprimé',
                'procedure_type': 'Autorisation',
                'forme_pharmaceutique': 'Comprimé',
                'titulaire_id': null,
                'conditions_prescription': 'Liste II',
              },
            ]),
            medicaments: const [],
            principes: const [],
            generiqueGroups: const [],
            groupMembers: const [],
            laboratories: const [],
          ),
        );

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

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
