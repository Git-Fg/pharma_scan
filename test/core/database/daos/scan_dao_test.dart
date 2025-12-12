import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

void main() {
  late AppDatabase db;
  late CatalogDao scanDao;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: configureAppSQLite),
    );
    scanDao = db.catalogDao;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedData({
    String? agrement,
    double? price,
    String? availability,
  }) async {
    // Insert laboratory first (for titulaire_id FK)
    await db.customInsert(
      'INSERT OR IGNORE INTO laboratories (id, name) VALUES (?, ?)',
      variables: [
        Variable.withInt(1),
        Variable.withString('Test Lab'),
      ],
      updates: {db.laboratories},
    );

    // Insert specialites using raw SQL
    await db.customInsert(
      'INSERT INTO specialites (cis_code, nom_specialite, procedure_type, forme_pharmaceutique, etat_commercialisation, titulaire_id) VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('123456'),
        Variable.withString('Test Specialite'),
        Variable.withString('Procédure'),
        Variable.withString('Comprimé'),
        Variable.withString('Commercialisée'),
        Variable.withInt(1),
      ],
      updates: {db.specialites},
    );

    // Insert medicaments using raw SQL
    await db.customInsert(
      'INSERT INTO medicaments (code_cip, cis_code, presentation_label, commercialisation_statut, taux_remboursement, prix_public, agrement_collectivites) VALUES (?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('3400000000012'),
        Variable.withString('123456'),
        Variable.withString('Boîte de 30 gélules'),
        Variable.withString('Commercialisée'),
        Variable.withString('65%'),
        Variable.withReal(price ?? 0.0),
        Variable.withString(agrement ?? ''),
      ],
      updates: {db.medicaments},
    );

    // Insert medicament_summary using raw SQL
    await db.customInsert(
      '''
      INSERT INTO medicament_summary (
        cis_code, nom_canonique, is_princeps, principes_actifs_communs,
        princeps_de_reference, forme_pharmaceutique, princeps_brand_name,
        procedure_type, titulaire_id, is_hospital, is_dental, is_list1,
        is_list2, is_narcotic, is_exception, is_restricted, is_otc, member_type
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString('123456'),
        Variable.withString('Test Médicament'),
        Variable.withBool(false),
        Variable.withString('["Test"]'),
        Variable.withString('Test Princeps'),
        Variable.withString('Comprimé'),
        Variable.withString('Test Brand'),
        Variable.withString('Procédure'),
        Variable.withInt(1),
        Variable.withBool(false),
        Variable.withBool(false),
        Variable.withBool(false),
        Variable.withBool(false),
        Variable.withBool(false),
        Variable.withBool(false),
        Variable.withBool(false),
        Variable.withBool(true),
        Variable.withInt(0),
      ],
      updates: {db.medicamentSummary},
    );

    if (availability != null) {
      // Insert medicament_availability using raw SQL
      await db.customInsert(
        'INSERT INTO medicament_availability (code_cip, statut, date_debut) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('3400000000012'),
          Variable.withString(availability),
          Variable.withString('2025-01-01'),
        ],
        updates: {db.medicamentAvailability},
      );
    }
  }

  test('returns availability status when shortage entry exists', () async {
    await seedData(
      agrement: 'non',
      price: 12.5,
      availability: 'Rupture de stock',
    );

    final result = await scanDao.getProductByCip(
      Cip13.validated('3400000000012'),
    );

    expect(result, isNotNull);
    expect(result!.availabilityStatus, equals('Rupture de stock'));
    expect(result.isHospitalOnly, isFalse);
    expect(result.libellePresentation, equals('Boîte de 30 gélules'));
  });

  test(
    'flags hospital-only presentations with agrement and no price',
    () async {
      await seedData(agrement: 'oui');

      final result = await scanDao.getProductByCip(
        Cip13.validated('3400000000012'),
      );
      expect(result, isNotNull);
      expect(result!.isHospitalOnly, isTrue);
      expect(result.availabilityStatus, isNull);
      expect(result.libellePresentation, equals('Boîte de 30 gélules'));
    },
  );
}
