import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = createTestDatabase(setup: (db) {
      db.execute("ATTACH DATABASE ':memory:' AS reference_db");
    });

    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS reference_db.laboratories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    // Duplicate tables in the main DB so views can reference them during tests
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS laboratories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS reference_db.medicament_summary (
        cis_code TEXT PRIMARY KEY NOT NULL,
        nom_canonique TEXT NOT NULL,
        group_id TEXT,
        titulaire_id INTEGER,
        is_princeps INTEGER DEFAULT 0,
        princeps_de_reference TEXT DEFAULT ''
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS medicament_summary (
        cis_code TEXT PRIMARY KEY NOT NULL,
        nom_canonique TEXT NOT NULL,
        group_id TEXT,
        titulaire_id INTEGER,
        is_princeps INTEGER DEFAULT 0,
        princeps_de_reference TEXT DEFAULT '',
        princeps_brand_name TEXT DEFAULT '',
        status TEXT DEFAULT '',
        forme_pharmaceutique TEXT DEFAULT '',
        voies_administration TEXT DEFAULT '',
        principes_actifs_communs TEXT DEFAULT '[]',
        formatted_dosage TEXT DEFAULT '',
        procedure_type TEXT DEFAULT '',
        conditions_prescription TEXT DEFAULT '',
        is_surveillance INTEGER DEFAULT 0,
        atc_code TEXT DEFAULT '',
        ansm_alert_url TEXT DEFAULT '',
        is_hospital INTEGER DEFAULT 0,
        is_dental INTEGER DEFAULT 0,
        is_list1 INTEGER DEFAULT 0,
        is_list2 INTEGER DEFAULT 0,
        is_narcotic INTEGER DEFAULT 0,
        is_exception INTEGER DEFAULT 0,
        is_restricted INTEGER DEFAULT 0,
        is_otc INTEGER DEFAULT 0,
        smr_niveau TEXT DEFAULT '',
        smr_date TEXT DEFAULT '',
        asmr_niveau TEXT DEFAULT '',
        asmr_date TEXT DEFAULT '',
        url_notice TEXT DEFAULT '',
        has_safety_alert INTEGER DEFAULT 0
      )
    ''');

    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS reference_db.product_scan_cache (
        cip_code TEXT PRIMARY KEY NOT NULL,
        cis_code TEXT NOT NULL,
        prix_public REAL,
        taux_remboursement TEXT,
        availability_status TEXT,
        lab_name TEXT,
        group_id TEXT
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS product_scan_cache (
        cip_code TEXT PRIMARY KEY NOT NULL,
        cis_code TEXT NOT NULL,
        prix_public REAL,
        taux_remboursement TEXT,
        availability_status TEXT,
        lab_name TEXT,
        group_id TEXT
      )
    ''');

    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS reference_db.medicaments (
        cip_code TEXT PRIMARY KEY NOT NULL,
        cis_code TEXT NOT NULL,
        prix_public REAL,
        taux_remboursement TEXT
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS medicaments (
        cip_code TEXT PRIMARY KEY NOT NULL,
        cis_code TEXT NOT NULL,
        prix_public REAL,
        taux_remboursement TEXT
      )
    ''');

    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS reference_db.medicament_availability (
        cip_code TEXT PRIMARY KEY NOT NULL,
        statut TEXT
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS medicament_availability (
        cip_code TEXT PRIMARY KEY NOT NULL,
        statut TEXT
      )
    ''');

    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS reference_db.generique_groups (
        group_id TEXT PRIMARY KEY NOT NULL,
        raw_label TEXT,
        parsing_method TEXT
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS generique_groups (
        group_id TEXT PRIMARY KEY NOT NULL,
        raw_label TEXT,
        parsing_method TEXT
      )
    ''');

    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS reference_db.group_members (
        group_id TEXT NOT NULL,
        cip_code TEXT NOT NULL,
        type INTEGER DEFAULT 1
      )
    ''');
    await database.customStatement('''
      CREATE TABLE IF NOT EXISTS group_members (
        group_id TEXT NOT NULL,
        cip_code TEXT NOT NULL,
        type INTEGER DEFAULT 1
      )
    ''');

    // Create a small test-local view that exposes the columns used in these tests.
    await database.customStatement('''
      CREATE VIEW IF NOT EXISTS ui_group_details AS
      SELECT
        gm.group_id,
        gm.cip_code,
        gg.raw_label,
        gg.parsing_method,
        (
          SELECT ms2.cis_code
          FROM medicament_summary ms2
          WHERE ms2.group_id = ms.group_id
            AND ms2.is_princeps = 1
          LIMIT 1
        ) AS princeps_cis_reference,
        ms.cis_code,
        ms.nom_canonique,
        COALESCE(ms.princeps_de_reference, '') AS princeps_de_reference,
        COALESCE(ms.princeps_brand_name, '') AS princeps_brand_name,
        COALESCE(ms.is_princeps, 0) AS is_princeps,
        COALESCE(ms.status, '') AS status,
        COALESCE(ms.forme_pharmaceutique, '') AS forme_pharmaceutique,
        COALESCE(ms.voies_administration, '') AS voies_administration,
        COALESCE(ms.principes_actifs_communs, '[]') AS principes_actifs_communs,
        COALESCE(ms.formatted_dosage, '') AS formatted_dosage,
        ls.name AS summary_titulaire,
        ls.name AS official_titulaire,
        COALESCE(ms.nom_canonique, '') AS nom_specialite,
        COALESCE(ms.procedure_type, '') AS procedure_type,
        COALESCE(ms.conditions_prescription, '') AS conditions_prescription,
        COALESCE(ms.is_surveillance, 0) AS is_surveillance,
        COALESCE(ms.atc_code, '') AS atc_code,
        COALESCE(gm.type, 0) AS member_type,
        COALESCE(psc.prix_public, m.prix_public) AS prix_public,
        COALESCE(psc.taux_remboursement, m.taux_remboursement) AS taux_remboursement,
        COALESCE(ms.ansm_alert_url, '') AS ansm_alert_url,
        COALESCE(ms.is_hospital, 0) AS is_hospital_only,
        COALESCE(ms.is_dental, 0) AS is_dental,
        COALESCE(ms.is_list1, 0) AS is_list1,
        COALESCE(ms.is_list2, 0) AS is_list2,
        COALESCE(ms.is_narcotic, 0) AS is_narcotic,
        COALESCE(ms.is_exception, 0) AS is_exception,
        COALESCE(ms.is_restricted, 0) AS is_restricted,
        COALESCE(ms.is_otc, 0) AS is_otc,
        COALESCE(psc.availability_status, ma.statut) AS availability_status
      FROM group_members gm
      LEFT JOIN product_scan_cache psc ON psc.cip_code = gm.cip_code
      LEFT JOIN medicaments m ON m.cip_code = gm.cip_code
      INNER JOIN medicament_summary ms ON ms.cis_code = COALESCE(psc.cis_code, m.cis_code)
      INNER JOIN generique_groups gg ON gg.group_id = gm.group_id
      LEFT JOIN laboratories ls ON ls.id = ms.titulaire_id
      LEFT JOIN medicament_availability ma ON ma.cip_code = gm.cip_code
    ''');
  });

  tearDown(() => database.close());

  test('view_group_details prefers product_scan_cache values when available',
      () async {
    // Arrange
    await database.customStatement(
        "INSERT INTO laboratories (id, name) VALUES (1, 'LAB A')");
    await database.customStatement(
        "INSERT INTO medicament_summary (cis_code, nom_canonique, group_id, titulaire_id, is_princeps, princeps_de_reference) VALUES ('CIS1', 'NOM1', 'G1', 1, 1, 'TEST')");

    await database.customStatement(
        "INSERT INTO product_scan_cache (cip_code, cis_code, prix_public, taux_remboursement, availability_status, lab_name, group_id) VALUES ('111','CIS1', 12.5, '65%', 'COM', 'LAB A', 'G1')");

    await database.customStatement(
        "INSERT INTO generique_groups (group_id, raw_label, parsing_method) VALUES ('G1','Label','by_name')");
    await database.customStatement(
        "INSERT INTO group_members (group_id, cip_code, type) VALUES ('G1','111',1)");

    // Act
    final rows = await (database.select(database.uiGroupDetails)
          ..where((t) => t.groupId.equals('G1')))
        .get();

    // Assert
    expect(rows, isNotEmpty);
    final row = rows.first;
    expect(row.cipCode, '111');
    expect(row.prixPublic, 12.5);
    expect(row.tauxRemboursement, '65%');
    expect(row.availabilityStatus, 'COM');
    expect(row.summaryTitulaire, 'LAB A');
  });

  test(
      'view_group_details falls back to medicaments/availability when cache missing',
      () async {
    // Arrange
    await database.customStatement(
        "INSERT INTO laboratories (id, name) VALUES (2, 'LAB B')");
    await database.customStatement(
        "INSERT INTO medicament_summary (cis_code, nom_canonique, group_id, titulaire_id, is_princeps, princeps_de_reference) VALUES ('CIS2', 'NOM2', 'G2', 2, 0, '')");

    await database.customStatement(
        "INSERT INTO medicaments (cip_code, cis_code, prix_public, taux_remboursement) VALUES ('222','CIS2', 20.0, '100%')");
    await database.customStatement(
        "INSERT INTO medicament_availability (cip_code, statut) VALUES ('222', 'NON COM')");
    await database.customStatement(
        "INSERT INTO generique_groups (group_id, raw_label, parsing_method) VALUES ('G2','Label2','by_name')");
    await database.customStatement(
        "INSERT INTO group_members (group_id, cip_code, type) VALUES ('G2','222',1)");

    // Act
    final rows = await (database.select(database.uiGroupDetails)
          ..where((t) => t.groupId.equals('G2')))
        .get();

    // Assert
    expect(rows, isNotEmpty);
    final row = rows.first;
    expect(row.cipCode, '222');
    expect(row.prixPublic, 20.0);
    expect(row.tauxRemboursement, '100%');
    expect(row.availabilityStatus, 'NON COM');
  });
}
