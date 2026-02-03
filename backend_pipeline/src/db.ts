import { Database } from "bun:sqlite";
import { drizzle, type BunSQLiteDatabase } from "drizzle-orm/bun-sqlite";
import { sql, eq } from "drizzle-orm";
import type { SQLiteTable } from "drizzle-orm/sqlite-core";
import fs from "node:fs";
import path from "node:path";
import { normalizeForSearch } from "./sanitizer";
import type {
  Specialite,
  Medicament,
  GeneriqueGroup,
  GroupMember,
} from "./types";
import type { FinalCluster } from "./pipeline/06_integration";
import * as schema from "./db/schema";

export const DEFAULT_DB_PATH = path.join("output", "reference.db");

export class ReferenceDatabase {
  public sqlite: Database;
  public db: BunSQLiteDatabase<typeof schema>;

  constructor(databasePath: string) {
    const fullPath = databasePath === ":memory:" ? databasePath : path.resolve(databasePath);
    if (fullPath !== ":memory:") {
      const dir = path.dirname(fullPath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    }
    this.sqlite = new Database(fullPath, { create: true });
    this.db = drizzle(this.sqlite, { schema });
    this.initSchema();
  }

  // --- ETL CONTROL ---
  public disableForeignKeys() {
    this.sqlite.run("PRAGMA foreign_keys = OFF;");
  }

  public enableForeignKeys() {
    this.sqlite.run("PRAGMA foreign_keys = ON;");
    const violations = this.sqlite.query("PRAGMA foreign_key_check").all();
    if (violations.length > 0) {
      console.warn(`⚠️  Foreign key violations found: ${violations.length}`);
    }
  }

  public initSchema() {
    this.sqlite.run("PRAGMA foreign_keys = ON;");

    // 1. Foundation Tables (no FK dependencies)
    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS specialites (
        cis_code TEXT PRIMARY KEY NOT NULL,
        nom_specialite TEXT NOT NULL,
        forme_pharmaceutique TEXT,
        voies_administration TEXT,
        statut_administratif TEXT,
        procedure_type TEXT,
        etat_commercialisation TEXT,
        date_amm TEXT,
        statut_bdm TEXT,
        numero_europeen TEXT,
        titulaire_id INTEGER,
        is_surveillance INTEGER DEFAULT 0 CHECK (is_surveillance IN (0, 1)),
        conditions_prescription TEXT,
        atc_code TEXT
      ) STRICT;
    `);

    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS laboratories(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE
    ) STRICT;
    `);

    // 2. Clustering & Indexing Tables (dependency foundation)
    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS cluster_names(
      cluster_id TEXT PRIMARY KEY NOT NULL,
      cluster_name TEXT NOT NULL,
      substance_code TEXT,
      cluster_princeps TEXT,
      secondary_princeps TEXT
    ) STRICT;
    `);

    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS cluster_index(
      cluster_id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      subtitle TEXT,
      count_products INTEGER DEFAULT 0,
      search_vector TEXT
    ) STRICT;
    `);

    // 3. Medicament Summary (must exist before medicaments)
    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS medicament_summary(
      cis_code TEXT PRIMARY KEY NOT NULL,
      nom_canonique TEXT NOT NULL,
      princeps_de_reference TEXT NOT NULL,
      parent_princeps_cis TEXT,
      is_princeps INTEGER NOT NULL DEFAULT 0 CHECK(is_princeps IN(0, 1)),
      cluster_id TEXT,
      group_id TEXT,
      principes_actifs_communs TEXT,
      formatted_dosage TEXT,
      forme_pharmaceutique TEXT,
      form_id INTEGER,
      is_form_inferred INTEGER NOT NULL DEFAULT 0 CHECK(is_form_inferred IN(0, 1)),
      voies_administration TEXT,
      member_type INTEGER NOT NULL DEFAULT 0,
      princeps_brand_name TEXT NOT NULL,
      procedure_type TEXT,
      titulaire_id INTEGER,
      conditions_prescription TEXT,
      date_amm TEXT,
      is_surveillance INTEGER NOT NULL DEFAULT 0 CHECK(is_surveillance IN(0, 1)),
      atc_code TEXT,
      status TEXT,
      price_min REAL,
      price_max REAL,
      aggregated_conditions TEXT,
      ansm_alert_url TEXT,
      is_hospital INTEGER NOT NULL DEFAULT 0 CHECK(is_hospital IN(0, 1)),
      is_dental INTEGER NOT NULL DEFAULT 0 CHECK(is_dental IN(0, 1)),
      is_list1 INTEGER NOT NULL DEFAULT 0 CHECK(is_list1 IN(0, 1)),
      is_list2 INTEGER NOT NULL DEFAULT 0 CHECK(is_list2 IN(0, 1)),
      is_narcotic INTEGER NOT NULL DEFAULT 0 CHECK(is_narcotic IN(0, 1)),
      is_exception INTEGER NOT NULL DEFAULT 0 CHECK(is_exception IN(0, 1)),
      is_restricted INTEGER NOT NULL DEFAULT 0 CHECK(is_restricted IN(0, 1)),
      is_otc INTEGER NOT NULL DEFAULT 1 CHECK(is_otc IN(0, 1)),
      smr_niveau TEXT,
      smr_date TEXT,
      asmr_niveau TEXT,
      asmr_date TEXT,
      url_notice TEXT,
      has_safety_alert INTEGER DEFAULT 0 CHECK(has_safety_alert IN(0, 1)),
      representative_cip TEXT,
      FOREIGN KEY(titulaire_id) REFERENCES laboratories(id),
      FOREIGN KEY(cluster_id) REFERENCES cluster_names(cluster_id)
    ) STRICT;
    `);

    // 4. Product Tables (depend on medicament_summary)
    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS medicaments (
        cip_code TEXT PRIMARY KEY NOT NULL,
        cip7 TEXT GENERATED ALWAYS AS (SUBSTR(cip_code, 6, 7)) STORED,
        cis_code TEXT NOT NULL REFERENCES medicament_summary(cis_code) ON DELETE CASCADE,
        presentation_label TEXT NOT NULL DEFAULT '',
        commercialisation_statut TEXT,
        taux_remboursement TEXT,
        prix_public REAL,
        agrement_collectivites TEXT,
        is_hospital INTEGER NOT NULL DEFAULT 0 CHECK (is_hospital IN (0, 1))
      ) STRICT;
    `);

    this.sqlite.run(`CREATE INDEX IF NOT EXISTS idx_medicaments_cip7 ON medicaments(cip7);`);

    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS principes_actifs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cip_code TEXT NOT NULL REFERENCES medicaments(cip_code) ON DELETE CASCADE,
        principe TEXT NOT NULL,
        principe_normalized TEXT,
        dosage TEXT,
        dosage_unit TEXT
      ) STRICT;
    `);

    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS product_scan_cache (
        cip_code TEXT PRIMARY KEY NOT NULL,
        cip7 TEXT,
        cis_code TEXT NOT NULL,
        nom_canonique TEXT NOT NULL,
        princeps_de_reference TEXT NOT NULL,
        princeps_brand_name TEXT NOT NULL DEFAULT '',
        is_princeps INTEGER NOT NULL DEFAULT 0,
        forme_pharmaceutique TEXT,
        voies_administration TEXT,
        formatted_dosage TEXT,
        titulaire_id INTEGER,
        conditions_prescription TEXT,
        is_surveillance INTEGER NOT NULL DEFAULT 0,
        atc_code TEXT,
        representative_cip TEXT,
        is_hospital INTEGER NOT NULL DEFAULT 0,
        is_narcotic INTEGER NOT NULL DEFAULT 0,
        lab_name TEXT,
        cluster_id TEXT,
        group_id TEXT,
        prix_public REAL,
        taux_remboursement TEXT,
        commercialisation_statut TEXT,
        availability_status TEXT
      ) STRICT;
    `);

    this.sqlite.run(`CREATE INDEX IF NOT EXISTS idx_product_scan_cache_cip7 ON product_scan_cache(cip7);`);

    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS medicament_detail(
      cis_code TEXT PRIMARY KEY,
      cluster_id TEXT,
      nom_complet TEXT,
      is_princeps INTEGER CHECK(is_princeps IN(0, 1)),
      FOREIGN KEY(cluster_id) REFERENCES cluster_index(cluster_id)
    ) STRICT;
    `);

    // 5. Generic Groups (no dependencies)
    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS generique_groups (
        group_id TEXT PRIMARY KEY NOT NULL,
        libelle TEXT NOT NULL,
        princeps_label TEXT,
        molecule_label TEXT,
        raw_label TEXT,
        parsing_method TEXT
      ) STRICT;
    `);

    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS group_members (
        cip_code TEXT NOT NULL REFERENCES medicaments(cip_code) ON DELETE CASCADE,
        group_id TEXT NOT NULL REFERENCES generique_groups(group_id) ON DELETE CASCADE,
        type INTEGER NOT NULL,
        sort_order INTEGER DEFAULT 0,
        PRIMARY KEY (cip_code, group_id)
      ) STRICT;
    `);

    // 6. FTS5 Virtual Table (for search)
    this.sqlite.run(`
      CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
      cluster_id UNINDEXED,
      search_vector,
      tokenize = 'trigram'
    );
    `);

    // 7. Views
    this.sqlite.run(`DROP VIEW IF EXISTS view_search_results`);
    this.sqlite.run(`
      CREATE VIEW view_search_results AS
    SELECT
    si.cluster_id,
      ci.title,
      ci.subtitle,
      ci.count_products,
      bm25(search_index) as rank
      FROM search_index si
      JOIN cluster_index ci ON si.cluster_id = ci.cluster_id
      ORDER BY rank;
    `);

    this.sqlite.run(`DROP VIEW IF EXISTS view_explorer_list`);
    this.sqlite.run(`
      CREATE VIEW view_explorer_list AS
    SELECT
    cn.cluster_id,
      cn.cluster_name AS title,
      cn.cluster_princeps AS subtitle,
          cn.secondary_princeps,
          MAX(ms.is_narcotic) as is_narcotic,
          COUNT(ms.cis_code) AS variant_count,
            MIN(ms.cis_code) AS representative_cis
      FROM cluster_names cn
      JOIN medicament_summary ms ON cn.cluster_id = ms.cluster_id
      GROUP BY cn.cluster_id;
    `);

    // 8. UI Tables
    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS ui_group_details(
      group_id TEXT NOT NULL,
      cip_code TEXT NOT NULL,
      cis_code TEXT NOT NULL,
      nom_canonique TEXT NOT NULL,
      princeps_de_reference TEXT NOT NULL,
      princeps_brand_name TEXT NOT NULL,
      is_princeps INTEGER DEFAULT 0,
      status TEXT,
      forme_pharmaceutique TEXT,
      voies_administration TEXT,
      principes_actifs_communs TEXT,
      formatted_dosage TEXT,
      summary_titulaire TEXT,
      official_titulaire TEXT,
      nom_specialite TEXT,
      procedure_type TEXT,
      conditions_prescription TEXT,
      is_surveillance INTEGER DEFAULT 0,
      atc_code TEXT,
      member_type INTEGER DEFAULT 0,
      prix_public REAL,
      taux_remboursement TEXT,
      ansm_alert_url TEXT,
      is_hospital_only INTEGER DEFAULT 0,
      is_dental INTEGER DEFAULT 0,
      is_list1 INTEGER DEFAULT 0,
      is_list2 INTEGER DEFAULT 0,
      is_narcotic INTEGER DEFAULT 0,
      is_exception INTEGER DEFAULT 0,
      is_restricted INTEGER DEFAULT 0,
      is_otc INTEGER DEFAULT 1,
      availability_status TEXT,
      smr_niveau TEXT,
      smr_date TEXT,
      asmr_niveau TEXT,
      asmr_date TEXT,
      url_notice TEXT,
      has_safety_alert INTEGER DEFAULT 0,
      raw_label TEXT,
      parsing_method TEXT,
      princeps_cis_reference TEXT,
      PRIMARY KEY(group_id, cip_code)
    ) STRICT;
    `);

    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS ui_stats(
      id INTEGER PRIMARY KEY CHECK(id = 1),
      total_princeps INTEGER DEFAULT 0,
      total_generiques INTEGER DEFAULT 0,
      total_principes INTEGER DEFAULT 0,
      last_updated TEXT DEFAULT CURRENT_TIMESTAMP
    ) STRICT;
    `);

    this.sqlite.run(`
      CREATE TABLE IF NOT EXISTS ui_explorer_list(
      cluster_id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      subtitle TEXT,
      secondary_princeps TEXT,
      is_narcotic INTEGER DEFAULT 0,
      variant_count INTEGER DEFAULT 0,
      representative_cis TEXT
    ) STRICT;
    `);

    // 5. Triggers for is_hospital
    this.sqlite.run(`
      CREATE TRIGGER IF NOT EXISTS update_hospital_flag_after_insert AFTER INSERT ON medicaments BEGIN
        UPDATE medicament_summary
        SET is_hospital = (
      LOWER(medicament_summary.conditions_prescription) LIKE '%hospitalier%' OR
        (LOWER(NEW.agrement_collectivites) = 'oui' AND(NEW.prix_public IS NULL OR NEW.prix_public = 0) AND NEW.taux_remboursement IS NOT NULL AND NEW.taux_remboursement != '')
        )
        WHERE medicament_summary.cis_code = NEW.cis_code;
    END;
    `);

    // --- 5. AUDIT VIEWS ---
    this.sqlite.run(`DROP VIEW IF EXISTS v_clusters_audit`);
    this.sqlite.run(`
      CREATE VIEW v_clusters_audit AS
    SELECT
    cn.cluster_id,
      cn.cluster_name AS unified_name,
        cn.cluster_princeps,
        cn.secondary_princeps,
        GROUP_CONCAT(DISTINCT ms.formatted_dosage) AS dosages_available,
          GROUP_CONCAT(DISTINCT ms.princeps_de_reference) AS all_princeps_names,
            GROUP_CONCAT(DISTINCT ms.princeps_brand_name) AS all_brand_names,
              (SELECT json_group_array(v) FROM(SELECT DISTINCT trim(value) AS v FROM json_each('["' || REPLACE(ms.principes_actifs_communs, ', ', '","') || '"]'))) as substance_label_json
      FROM cluster_names cn
      JOIN medicament_summary ms ON cn.cluster_id = ms.cluster_id
      GROUP BY cn.cluster_id;
    `);

    this.sqlite.run(`DROP VIEW IF EXISTS v_groups_audit`);
    this.sqlite.run(`
      CREATE VIEW v_groups_audit AS
    SELECT
    ms.group_id,
      gg.libelle,
      GROUP_CONCAT(DISTINCT ms.forme_pharmaceutique) AS forms_available,
        ms.principes_actifs_communs
      FROM medicament_summary ms
      JOIN generique_groups gg ON ms.group_id = gg.group_id
      WHERE ms.group_id IS NOT NULL
      GROUP BY ms.group_id;
    `);

    this.sqlite.run(`DROP VIEW IF EXISTS v_samples_audit`);
    this.sqlite.run(`
      CREATE VIEW v_samples_audit AS
    SELECT
    cis_code,
      nom_canonique,
      principes_actifs_communs AS principes_actifs_communs_json,
        has_safety_alert
      FROM medicament_summary;
    `);
  }

  // --- HELPERS ---
  public normalizeTextBasic(input: string): string {
    return normalizeForSearch(input);
  }

  /**
   * Helper to insert rows in chunks to avoid SQLite parameter limit (usually 999 or 32766)
   */
  private chunkedInsert<T extends Record<string, any>>(
    table: SQLiteTable,
    rows: T[],
    chunkSize: number = 2000
  ) {
    if (rows.length === 0) return;

    for (let i = 0; i < rows.length; i += chunkSize) {
      const chunk = rows.slice(i, i + chunkSize);
      this.db.insert(table).values(chunk).onConflictDoNothing().run();
    }
  }

  // --- PHASE 1 INSERT METHODS (Refactored to Drizzle) ---

  public insertSpecialites(rows: ReadonlyArray<Specialite>) {
    console.log(`📊 Inserting ${rows.length} specialites...`);
    const transformed = rows.map(r => ({
      cis_code: r.cisCode,
      nom_specialite: r.nomSpecialite,
      forme_pharmaceutique: r.formePharmaceutique,
      voies_administration: r.voiesAdministration,
      statut_administratif: r.statutAdministratif,
      procedure_type: r.procedureType,
      etat_commercialisation: r.etatCommercialisation,
      date_amm: r.dateAmm,
      titulaire_id: r.titulaireId,
      is_surveillance: r.isSurveillance ? 1 : 0,
      conditions_prescription: r.conditionsPrescription,
      atc_code: r.atcCode
    }));

    this.chunkedInsert(schema.specialites, transformed, 1000);
  }

  public insertMedicaments(rows: ReadonlyArray<Medicament>) {
    console.log(`📊 Inserting ${rows.length} medicaments...`);
    const transformed = rows.map(r => ({
      cip_code: r.codeCip,
      cis_code: r.cisCode,
      presentation_label: r.presentationLabel,
      commercialisation_statut: r.commercialisationStatut,
      taux_remboursement: r.tauxRemboursement,
      prix_public: r.prixPublic,
      agrement_collectivites: r.agrementCollectivites,
      is_hospital: 0
    }));
    this.chunkedInsert(schema.medicaments, transformed, 1000);
  }

  public insertLaboratories(data: { id?: number; name: string }[]) {
    console.log(`📊 Inserting ${data.length} laboratories...`);
    this.chunkedInsert(schema.laboratories, data, 1000);
  }

  public getLaboratoryMap(): Map<string, number> {
    const rows = this.db.select({ id: schema.laboratories.id, name: schema.laboratories.name }).from(schema.laboratories).all();
    return new Map(rows.map(row => [row.name, row.id]));
  }

  public insertGeneriqueGroups(rows: ReadonlyArray<GeneriqueGroup>) {
    console.log(`📊 Inserting ${rows.length} generic groups...`);
    const transformed = rows.map(r => ({
      group_id: r.groupId,
      libelle: r.libelle,
      princeps_label: r.princepsLabel,
      molecule_label: r.moleculeLabel
    }));
    this.chunkedInsert(schema.generiqueGroups, transformed, 1000);
  }

  public insertGroupMembers(rows: ReadonlyArray<GroupMember>) {
    console.log(`📊 Inserting ${rows.length} group members...`);
    const transformed = rows.map(r => ({
      cip_code: r.codeCip,
      group_id: r.groupId,
      type: r.type,
      sort_order: r.sortOrder
    }));
    this.chunkedInsert(schema.groupMembers, transformed, 1000);
  }

  // --- PHASE 2 INTEGRATION ---
  public populateMedicamentSummary() {
    console.log("📝 Populating initial medicament_summary...");
    this.sqlite.run("DELETE FROM medicament_summary");
    this.sqlite.run(`
      INSERT INTO medicament_summary(
      cis_code, nom_canonique, is_princeps, princeps_de_reference, princeps_brand_name,
      forme_pharmaceutique, voies_administration, titulaire_id, procedure_type,
      conditions_prescription, date_amm, is_surveillance, atc_code, status
    )
      SELECT cis_code, nom_specialite, 1, nom_specialite, nom_specialite,
      forme_pharmaceutique, voies_administration, titulaire_id, procedure_type,
      conditions_prescription, date_amm, is_surveillance, atc_code, statut_administratif
      FROM specialites
      `);
  }

  public populateProductScanCache() {
    console.log("📝 Populating product_scan_cache...");
    this.sqlite.run("DELETE FROM product_scan_cache");
    this.sqlite.run(`
      INSERT INTO product_scan_cache(
        cip_code, cip7, cis_code, nom_canonique, princeps_de_reference, princeps_brand_name,
        is_princeps, forme_pharmaceutique, voies_administration, formatted_dosage,
        titulaire_id, conditions_prescription, is_surveillance, atc_code,
        representative_cip, is_hospital, is_narcotic, lab_name, cluster_id, group_id,
        prix_public, taux_remboursement, commercialisation_statut, availability_status
      )
    SELECT
    m.cip_code,
      m.cip7,
      ms.cis_code,
      ms.nom_canonique,
      ms.princeps_de_reference,
      ms.princeps_brand_name,
      ms.is_princeps,
      ms.forme_pharmaceutique,
      ms.voies_administration,
      ms.formatted_dosage,
      ms.titulaire_id,
      ms.conditions_prescription,
      ms.is_surveillance,
      ms.atc_code,
      ms.representative_cip,
      m.is_hospital,
      ms.is_narcotic,
      l.name as lab_name,
      ms.cluster_id,
      ms.group_id,
      m.prix_public,
      m.taux_remboursement,
      m.commercialisation_statut,
      m.commercialisation_statut
      FROM medicaments m
      JOIN medicament_summary ms ON m.cis_code = ms.cis_code
      LEFT JOIN laboratories l ON ms.titulaire_id = l.id
      `);
  }

  public updateMedicamentSummaryPrinciples(profiles: Map<string, { substances: { name: string }[] }>) {
    console.log(`🧪 Updating principles for ${profiles.size} profiles...`);
    this.db.transaction((tx) => {
      for (const [cis, profile] of profiles) {
        tx.update(schema.medicamentSummary)
          .set({ principes_actifs_communs: profile.substances.map(s => s.name).join(", ") })
          .where(eq(schema.medicamentSummary.cis_code, cis))
          .run();
      }
    });
  }

  public insertFinalClusters(clusters: FinalCluster[]) {
    console.log(`📊 Inserting ${clusters.length} final clusters and updating summary...`);

    this.db.transaction((tx) => {
      for (const c of clusters) {
        const princepsRef = c.sampleNames[0] || c.displayName;

        tx.insert(schema.clusterNames).values({
          cluster_id: c.superClusterId,
          cluster_name: c.displayName,
          cluster_princeps: princepsRef,
          secondary_princeps: JSON.stringify(c.secondaryPrinceps)
        }).onConflictDoUpdate({
          target: schema.clusterNames.cluster_id,
          set: {
            cluster_name: c.displayName,
            cluster_princeps: princepsRef,
            secondary_princeps: JSON.stringify(c.secondaryPrinceps)
          }
        }).run();

        tx.insert(schema.clusterIndex).values({
          cluster_id: c.superClusterId,
          title: c.displayName,
          subtitle: `Ref: ${princepsRef} `,
          count_products: c.totalCIS,
          search_vector: c.search_vector
        }).onConflictDoUpdate({
          target: schema.clusterIndex.cluster_id,
          set: {
            title: c.displayName,
            subtitle: `Ref: ${princepsRef} `,
            count_products: c.totalCIS,
            search_vector: c.search_vector
          }
        }).run();

        tx.run(sql`INSERT OR REPLACE INTO search_index (cluster_id, search_vector) VALUES (${c.superClusterId}, ${c.search_vector})`);

        for (const cis of [...c.sourceCIS, ...c.orphansCIS]) {
          tx.update(schema.medicamentSummary)
            .set({ cluster_id: c.superClusterId, princeps_de_reference: princepsRef })
            .where(eq(schema.medicamentSummary.cis_code, cis))
            .run();
        }
      }
    });
  }

  public refreshMaterializedViews() {
    console.log("🔋 Refreshing UI Materialized Views...");
    this.sqlite.run("DELETE FROM ui_explorer_list");
    this.sqlite.run(`
      INSERT INTO ui_explorer_list(cluster_id, title, subtitle, secondary_princeps, is_narcotic, variant_count, representative_cis)
      SELECT cn.cluster_id, cn.cluster_name, cn.cluster_princeps, cn.secondary_princeps,
      MAX(ms.is_narcotic), COUNT(ms.cis_code), MIN(ms.cis_code)
      FROM cluster_names cn
      JOIN medicament_summary ms ON cn.cluster_id = ms.cluster_id
      GROUP BY cn.cluster_id
      `);

    this.sqlite.run("DELETE FROM ui_stats");
    this.sqlite.run(`
      INSERT INTO ui_stats(id, total_princeps, total_generiques, total_principes)
      SELECT 1, COUNT(ms.cis_code), 0, 0 FROM medicament_summary ms
      `);
  }

  public runQuery<T>(sql: string): T[] {
    return this.sqlite.query(sql).all() as T[];
  }

  public optimize() {
    this.sqlite.exec("PRAGMA wal_checkpoint(TRUNCATE); VACUUM; ANALYZE;");
  }

  public close() {
    this.sqlite.close();
  }
}
