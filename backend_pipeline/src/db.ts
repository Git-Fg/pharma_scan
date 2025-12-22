import { Database, type SQLQueryBindings } from "bun:sqlite";
import fs from "node:fs";
import path from "node:path";
import { normalizeForSearch, normalizeForSearchIndex } from "./sanitizer";
import type {
  Specialite,
  Medicament,
  MedicamentAvailability,
  PrincipeActif,
  GeneriqueGroup,
  GroupMember,
  MedicamentSummary,
  Laboratory,
  SafetyAlert
} from "./types";
import { formatPrinciples } from "./sanitizer";
import { type ClusterMetadata } from "./types";
import { readBdpmFile, streamBdpmFile, buildSearchVector, findCommonWordPrefix } from "./utils";
import type { FinalCluster } from "./pipeline/06_integration";

export const DEFAULT_DB_PATH = path.join("output", "reference.db");

export class ReferenceDatabase {
  public db: Database;

  constructor(databasePath: string) {
    const fullPath = databasePath === ":memory:" ? databasePath : path.resolve(databasePath);
    if (fullPath !== ":memory:") {
      fs.mkdirSync(path.dirname(fullPath), { recursive: true });
    }
    console.log(`📂 Opening database at: ${fullPath}`);
    this.db = new Database(fullPath, { create: true, readwrite: true });
    // Use DELETE mode during initialization to avoid WAL locking issues
    this.db.exec("PRAGMA journal_mode = DELETE;");
    this.db.exec("PRAGMA synchronous = NORMAL;");
    this.db.exec("PRAGMA foreign_keys = ON;");
    this.db.exec("PRAGMA locking_mode = NORMAL;");
    this.db.exec("PRAGMA busy_timeout = 30000;"); // 30 second timeout for locks
    this.initSchema();
    this.initMetadataTable(); // Initialize metadata table
    // Switch to WAL mode after schema is initialized
    this.db.exec("PRAGMA journal_mode = WAL;");
    console.log(`✅ Database initialized successfully`);
  }

  /**
   * Disable foreign key constraints during bulk ETL operations.
   * This allows inserting rows in any order during the pipeline.
   * IMPORTANT: Call enableForeignKeys() after all inserts to validate.
   */
  public disableForeignKeys() {
    this.db.exec("PRAGMA foreign_keys = OFF;");
    console.log("⚠️  Foreign key constraints DISABLED for bulk insert");
  }

  /**
   * Re-enable foreign key constraints and validate all relationships.
   * Should be called after all ETL inserts are complete.
   */
  public enableForeignKeys() {
    this.db.exec("PRAGMA foreign_keys = ON;");
    // Run a foreign key integrity check
    const violations = this.db.query<{ table: string; rowid: number; parent: string; fkid: number }, []>(
      "PRAGMA foreign_key_check"
    ).all();
    if (violations.length > 0) {
      console.error(`❌ Found ${violations.length} FK violations:`, violations.slice(0, 5));
      throw new Error(`Foreign key integrity check failed with ${violations.length} violations`);
    }
    console.log("✅ Foreign key constraints ENABLED and validated");
  }

  public initSchema() {
    // SQLite function registration removed in favor of TS-based population
    this.db.run("PRAGMA foreign_keys = ON;");
    // Keep DELETE mode during initialization, switch to WAL after all inserts are done
    // this.db.run("PRAGMA journal_mode = WAL;");

    // 1. Raw Data Tables (Staging)
    this.db.run(`
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

    // Phase 1: Standardize FK relationships for Drift's withReferences()
    // medicaments is a CHILD of medicament_summary (via cis_code)
    // This enables: managers.medicaments.withReferences((prefetch) => prefetch(medicamentSummary: true))
    this.db.run(`
      CREATE TABLE IF NOT EXISTS medicaments (
        cip_code TEXT PRIMARY KEY NOT NULL,
        
        -- ✨ NOUVEAU : Extraction automatique du CIP7
        -- On prend 7 caractères à partir du 6ème (34009 3030261 3)
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

    // Indexer le CIP7 pour des recherches ultra-rapides (Fallback Scanner)
    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_medicaments_cip7 ON medicaments(cip7);
    `);

    // Phase 1.1: Standardize on cip_code
    this.db.run(`
      CREATE TABLE IF NOT EXISTS medicament_availability (
        cip_code TEXT PRIMARY KEY NOT NULL REFERENCES medicaments(cip_code) ON DELETE CASCADE,
        statut TEXT NOT NULL DEFAULT '',
        date_debut TEXT,
        date_fin TEXT,
        lien TEXT
      ) STRICT;
    `);

    // Safety alerts: deduplicated messages stored centrally
    this.db.run(`
      CREATE TABLE IF NOT EXISTS safety_alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        url TEXT,
        date_debut TEXT, -- Format YYYY-MM-DD
        date_fin TEXT,   -- Format YYYY-MM-DD
        CONSTRAINT unique_alert UNIQUE(title, url, date_debut, date_fin)
      ) STRICT;
    `);

    // Link table between CIS and deduplicated alerts
    this.db.run(`
      CREATE TABLE IF NOT EXISTS cis_safety_links (
        cis_code TEXT NOT NULL REFERENCES specialites(cis_code) ON DELETE CASCADE,
        alert_id INTEGER NOT NULL REFERENCES safety_alerts(id) ON DELETE CASCADE,
        PRIMARY KEY (cis_code, alert_id)
      ) STRICT;
    `);

    // Phase 1: principes_actifs is a CHILD of medicaments (via cip_code)
    // This enables: managers.medicaments.withReferences((prefetch) => prefetch(principesActifs: true))
    this.db.run(`
      CREATE TABLE IF NOT EXISTS principes_actifs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cip_code TEXT NOT NULL REFERENCES medicaments(cip_code) ON DELETE CASCADE,
        principe TEXT NOT NULL,
        principe_normalized TEXT,
        dosage TEXT,
        dosage_unit TEXT
      ) STRICT;
    `);

    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_principes_cip ON principes_actifs(cip_code);
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS generique_groups (
        group_id TEXT PRIMARY KEY NOT NULL,
        libelle TEXT NOT NULL,
        princeps_label TEXT,
        molecule_label TEXT,
        raw_label TEXT,
        parsing_method TEXT
      ) STRICT;
    `);

    // Phase 1.1: Standardize on cip_code
    this.db.run(`
      CREATE TABLE IF NOT EXISTS group_members (
        cip_code TEXT NOT NULL REFERENCES medicaments(cip_code) ON DELETE CASCADE,
        group_id TEXT NOT NULL REFERENCES generique_groups(group_id) ON DELETE CASCADE,
        type INTEGER NOT NULL,
        sort_order INTEGER DEFAULT 0,
        PRIMARY KEY (cip_code, group_id)
      ) STRICT;
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS laboratories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      ) STRICT;
    `);

    // 2. Aggregated Summary Table (The "View" optimized for Flutter)
    // Schema matches lib/core/database/database.dart MedicamentSummary table exactly
    // --- 2. TABLE EXPLORER (Cluster Names) ---
    // Table optimisée pour la liste "Tiroir à pharmacie"
    this.db.run(`
      CREATE TABLE IF NOT EXISTS cluster_names (
        cluster_id TEXT PRIMARY KEY NOT NULL,
        cluster_name TEXT NOT NULL,       -- Titre "Clean" (ex: "DOLIPRANE")
        substance_code TEXT,              -- Sous-titre (ex: "Paracétamol")
        cluster_princeps TEXT,            -- Nom princeps pour référence interne
        secondary_princeps TEXT           -- JSON Array ["NUROFEN", "SPEDIFEN"] pour co-marketing/rachats
      ) STRICT;
    `);

    // --- NEW CLUSTER-FIRST TABLES ---
    // 1. Light table for UI display list (Cluster-First Architecture)
    this.db.run(`
      CREATE TABLE IF NOT EXISTS cluster_index (
        cluster_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,              -- Ex: "Ibuprofène 400mg" (Substance Clean)
        subtitle TEXT,                    -- Ex: "Réf: Advil" (Princeps Principal)
        count_products INTEGER DEFAULT 0,
        search_vector TEXT                -- The search vector for FTS5
      ) STRICT;
    `);

    // 2. Detailed table for drawer content (Cluster-First Architecture)
    this.db.run(`
      CREATE TABLE IF NOT EXISTS medicament_detail (
        cis_code TEXT PRIMARY KEY,
        cluster_id TEXT,
        nom_complet TEXT,
        is_princeps INTEGER CHECK (is_princeps IN (0, 1)),
        FOREIGN KEY(cluster_id) REFERENCES cluster_index(cluster_id)
      ) STRICT;
      CREATE INDEX IF NOT EXISTS idx_med_cluster ON medicament_detail(cluster_id);
    `);

    // 3. FTS table for search (Cluster-First Architecture)
    this.db.run(`
      CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
        cluster_id UNINDEXED,
        search_vector,
        tokenize='trigram'                -- The magic for fuzzy matching
      );
    `);

    // --- PHASE 2: CONTROLLED VOCABULARY ---
    this.db.run(`
      CREATE TABLE IF NOT EXISTS ref_forms (
        id INTEGER PRIMARY KEY,
        label TEXT NOT NULL UNIQUE
      ) STRICT;
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS ref_routes (
        id INTEGER PRIMARY KEY,
        label TEXT NOT NULL UNIQUE
      ) STRICT;
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS cis_routes (
        cis_code TEXT NOT NULL REFERENCES medicament_summary(cis_code) ON DELETE CASCADE,
        route_id INTEGER NOT NULL REFERENCES ref_routes(id),
        is_inferred INTEGER NOT NULL DEFAULT 0 CHECK (is_inferred IN (0, 1)),
        PRIMARY KEY (cis_code, route_id)
      ) STRICT;
    `);

    // --- PHASE 3: ATOMIC INGREDIENTS ---
    this.db.run(`
      CREATE TABLE IF NOT EXISTS ref_substances (
        id INTEGER PRIMARY KEY,
        code TEXT UNIQUE, -- Optional code if available (e.g. SNOMED/BDPM code if parsed)
        label TEXT NOT NULL UNIQUE,
        canonical_name TEXT  -- Salt-stripped base molecule (e.g., "MORPHINE" from "CHLORHYDRATE DE MORPHINE")
      ) STRICT;
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS composition_link (
        cis_code TEXT NOT NULL REFERENCES medicament_summary(cis_code) ON DELETE CASCADE,
        substance_id INTEGER NOT NULL REFERENCES ref_substances(id),
        dosage TEXT,
        nature TEXT, -- SA (Substance Active) or FT (Fraction Thérapeutique)
        PRIMARY KEY (cis_code, substance_id, dosage) -- Composite key
      ) STRICT;
    `);

    // --- 3. SOURCE DE VÉRITÉ (Medicament Summary) ---
    // Table dénormalisée pour l'accès rapide
    this.db.run(`
      CREATE TABLE IF NOT EXISTS medicament_summary (
        cis_code TEXT PRIMARY KEY NOT NULL,
        -- Identification
        nom_canonique TEXT NOT NULL,
        princeps_de_reference TEXT NOT NULL,
        parent_princeps_cis TEXT, -- NEW Explicit Link to Princeps CIS
        is_princeps INTEGER NOT NULL DEFAULT 0 CHECK (is_princeps IN (0, 1)),
        
        -- Clustering & Grouping
        cluster_id TEXT,
        group_id TEXT,
        
        -- Composition & Galénique
        principes_actifs_communs TEXT, -- JSON Array: ["Amoxicilline"]
        formatted_dosage TEXT,
        forme_pharmaceutique TEXT,
        form_id INTEGER REFERENCES ref_forms(id), -- NEW Normalized ID
        is_form_inferred INTEGER NOT NULL DEFAULT 0 CHECK (is_form_inferred IN (0, 1)), -- NEW Flag
        voies_administration TEXT,
        
        -- Métadonnées
        member_type INTEGER NOT NULL DEFAULT 0,
        princeps_brand_name TEXT NOT NULL,
        procedure_type TEXT,
        titulaire_id INTEGER,
        conditions_prescription TEXT,
        date_amm TEXT,
        is_surveillance INTEGER NOT NULL DEFAULT 0 CHECK (is_surveillance IN (0, 1)),
        atc_code TEXT,
        status TEXT,
        price_min REAL,
        price_max REAL,
        aggregated_conditions TEXT,
        ansm_alert_url TEXT,
        
        -- Flags
        is_hospital INTEGER NOT NULL DEFAULT 0 CHECK (is_hospital IN (0, 1)),
        is_dental INTEGER NOT NULL DEFAULT 0 CHECK (is_dental IN (0, 1)),
        is_list1 INTEGER NOT NULL DEFAULT 0 CHECK (is_list1 IN (0, 1)),
        is_list2 INTEGER NOT NULL DEFAULT 0 CHECK (is_list2 IN (0, 1)),
        is_narcotic INTEGER NOT NULL DEFAULT 0 CHECK (is_narcotic IN (0, 1)),
        is_exception INTEGER NOT NULL DEFAULT 0 CHECK (is_exception IN (0, 1)),
        is_restricted INTEGER NOT NULL DEFAULT 0 CHECK (is_restricted IN (0, 1)),
        is_otc INTEGER NOT NULL DEFAULT 1 CHECK (is_otc IN (0, 1)),
        
        -- SMR & ASMR & Safety
        smr_niveau TEXT,
        smr_date TEXT,
        asmr_niveau TEXT,
        asmr_date TEXT,
        url_notice TEXT,
        has_safety_alert INTEGER DEFAULT 0 CHECK (has_safety_alert IN (0, 1)),
        
        representative_cip TEXT,
        
        FOREIGN KEY(titulaire_id) REFERENCES laboratories(id),
        FOREIGN KEY(cluster_id) REFERENCES cluster_names(cluster_id)
      ) STRICT;
    `);

    // --- PRODUCT SCAN CACHE (Denormalized for Flutter Scanner) ---
    // This table pre-computes JOINs for getProductByCip()
    // Also has FK to medicament_summary for validation
    this.db.run(`
      CREATE TABLE IF NOT EXISTS product_scan_cache (
        cip_code TEXT PRIMARY KEY NOT NULL REFERENCES medicaments(cip_code) ON DELETE CASCADE,

        -- ✨ NOUVEAU : On expose aussi le CIP7 ici
        cip7 TEXT GENERATED ALWAYS AS (SUBSTR(cip_code, 6, 7)) STORED,

        cis_code TEXT NOT NULL REFERENCES medicament_summary(cis_code) ON DELETE CASCADE,
        nom_canonique TEXT NOT NULL,
        lab_name TEXT,
        prix_public REAL,
        taux_remboursement TEXT,
        availability_status TEXT,
        is_hospital INTEGER NOT NULL DEFAULT 0 CHECK (is_hospital IN (0, 1)),
        is_princeps INTEGER NOT NULL DEFAULT 0 CHECK (is_princeps IN (0, 1)),
        is_surveillance INTEGER NOT NULL DEFAULT 0 CHECK (is_surveillance IN (0, 1)),
        is_narcotic INTEGER NOT NULL DEFAULT 0 CHECK (is_narcotic IN (0, 1)),
        princeps_de_reference TEXT NOT NULL DEFAULT '',
        princeps_brand_name TEXT NOT NULL DEFAULT '',
        forme_pharmaceutique TEXT,
        voies_administration TEXT,
        formatted_dosage TEXT,
        group_id TEXT,
        cluster_id TEXT,
        conditions_prescription TEXT,
        commercialisation_statut TEXT,
        titulaire_id INTEGER REFERENCES laboratories(id) ON DELETE SET NULL,
        atc_code TEXT,
        representative_cip TEXT
      ) STRICT;
    `);

    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_product_scan_cache_cip7 ON product_scan_cache(cip7);
    `);

    // Index for fast lookups
    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_product_scan_cache_cis ON product_scan_cache(cis_code);
    `);

    // NOTE: App settings are intentionally managed by the Flutter app
    // and are not created by the backend pipeline. The FTS5 virtual
    // table for full-text search follows.
    this.db.run(`
      -- Legacy FTS table and triggers removed. 
      -- The correct FTS table is created in the Cluster-First section (lines ~260).

      -- Indexes matching Flutter app definitions
      CREATE INDEX IF NOT EXISTS idx_medicaments_cis_code ON medicaments(cis_code);
      CREATE INDEX IF NOT EXISTS idx_principes_cip_code ON principes_actifs(cip_code);
      CREATE INDEX IF NOT EXISTS idx_principes_normalized_cip ON principes_actifs(principe_normalized, cip_code);
      CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
      CREATE INDEX IF NOT EXISTS idx_group_members_cip_code ON group_members(cip_code);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_group_id ON medicament_summary(group_id);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_forme_pharmaceutique ON medicament_summary(forme_pharmaceutique);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_voies_administration ON medicament_summary(voies_administration);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_procedure_type ON medicament_summary(procedure_type);
      CREATE INDEX IF NOT EXISTS idx_summary_princeps_ref ON medicament_summary(princeps_de_reference);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_principes_actifs_communs ON medicament_summary(principes_actifs_communs);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_cluster_id ON medicament_summary(cluster_id);
      CREATE INDEX IF NOT EXISTS idx_summary_cluster ON medicament_summary(cluster_id);
      CREATE INDEX IF NOT EXISTS idx_summary_group ON medicament_summary(group_id);

      -- Trigger to update is_hospital flag based on comprehensive logic
      -- This ensures the medicament_summary.is_hospital flag matches the mobile app's logic
      CREATE TRIGGER IF NOT EXISTS update_hospital_flag_after_insert AFTER INSERT ON medicaments BEGIN
        UPDATE medicament_summary
        SET is_hospital = (
          -- Condition 1: Prescription conditions contain "HOSPITALIER"
          LOWER(medicament_summary.conditions_prescription) LIKE '%hospitalier%' OR
          -- Condition 2: Agreement logic matching mobile app's _isHospitalOnly
          (LOWER(m.agrement_collectivites) = 'oui' AND (m.prix_public IS NULL OR m.prix_public = 0) AND m.taux_remboursement IS NOT NULL AND m.taux_remboursement != '')
        )
        FROM medicaments m
        WHERE medicament_summary.cis_code = m.cis_code;
      END;

      CREATE TRIGGER IF NOT EXISTS update_hospital_flag_after_update AFTER UPDATE ON medicaments BEGIN
        UPDATE medicament_summary
        SET is_hospital = (
          -- Condition 1: Prescription conditions contain "HOSPITALIER"
          LOWER(medicament_summary.conditions_prescription) LIKE '%hospitalier%' OR
          -- Condition 2: Agreement logic matching mobile app's _isHospitalOnly
          (LOWER(m.agrement_collectivites) = 'oui' AND (m.prix_public IS NULL OR m.prix_public = 0) AND m.taux_remboursement IS NOT NULL AND m.taux_remboursement != '')
        )
        FROM medicaments m
        WHERE medicament_summary.cis_code = m.cis_code;
      END;

      CREATE TRIGGER IF NOT EXISTS update_hospital_flag_after_summary_update AFTER UPDATE ON medicament_summary WHEN NEW.conditions_prescription != OLD.conditions_prescription BEGIN
        UPDATE medicament_summary
        SET is_hospital = (
          -- Condition 1: Prescription conditions contain "HOSPITALIER"
          LOWER(NEW.conditions_prescription) LIKE '%hospitalier%' OR
          -- Condition 2: Agreement logic matching mobile app's _isHospitalOnly
          (LOWER(m.agrement_collectivites) = 'oui' AND (m.prix_public IS NULL OR m.prix_public = 0) AND m.taux_remboursement IS NOT NULL AND m.taux_remboursement != '')
        )
        FROM medicaments m
        WHERE medicament_summary.cis_code = m.cis_code AND medicament_summary.cis_code = NEW.cis_code;
      END;
    `);

    // --- 4. VUES OPTIMISÉES POUR LE MOBILE ---

    // Vue A : Explorer List (Liste principale)
    this.db.run(`DROP VIEW IF EXISTS view_explorer_list`);
    this.db.run(`
      CREATE VIEW view_explorer_list AS
      SELECT 
        cn.cluster_id,
        cn.cluster_name AS title,
        cn.cluster_princeps AS subtitle,
        cn.secondary_princeps, -- JSON Array des princeps secondaires pour recherche/affichage
        -- On agrège les flags critiques du cluster (si un seul est stupéfiant, le cluster l'est)
        MAX(ms.is_narcotic) as is_narcotic,
        COUNT(ms.cis_code) AS variant_count,
        MIN(ms.cis_code) AS representative_cis
      FROM cluster_names cn
      JOIN medicament_summary ms ON cn.cluster_id = ms.cluster_id
      GROUP BY cn.cluster_id;
    `);

    // Vue B : Cluster Variants (Détail d'un médicament)
    this.db.run(`DROP VIEW IF EXISTS view_cluster_variants`);
    this.db.run(`
      CREATE VIEW view_cluster_variants AS
      SELECT 
        ms.cluster_id,
        ms.cis_code,
        ms.nom_canonique AS label,
        ms.formatted_dosage AS dosage,
        ms.forme_pharmaceutique AS form,
        ms.is_princeps,
        ms.voies_administration AS routes,
        ms.is_otc,
        COALESCE(ms.representative_cip, (SELECT m.cip_code FROM medicaments m WHERE m.cis_code = ms.cis_code LIMIT 1)) AS default_cip,
        (SELECT m.prix_public FROM medicaments m WHERE m.cis_code = ms.cis_code LIMIT 1) AS prix_public
      FROM medicament_summary ms
      WHERE ms.cluster_id IS NOT NULL;
    `);

    this.db.run(`DROP VIEW IF EXISTS view_scanner_check`);
    this.db.run(`
      CREATE VIEW view_scanner_check AS
      SELECT
        m.cip_code,
        ms.cis_code,
        ms.nom_canonique,
        ms.cluster_id,
        cn.cluster_name AS ref_name,
        ms.group_id,
        ms.is_princeps
      FROM medicaments m
      JOIN medicament_summary ms ON m.cis_code = ms.cis_code
      LEFT JOIN cluster_names cn ON ms.cluster_id = cn.cluster_id;
    `);

    // Vue D : Search Results (FTS5 with BM25 ranking)
    this.db.run(`DROP VIEW IF EXISTS view_search_results`);
    this.db.run(`
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

    // --- 5. UI MATERIALIZED VIEWS (Pre-computed for Flutter TableManager) ---
    // These tables replace complex Flutter views and enable simple Manager API access

    // Table: ui_group_details - Materialized view replacing Flutter's view_group_details
    this.db.run(`
      CREATE TABLE IF NOT EXISTS ui_group_details (
        -- Composite Primary Key for fast direct access
        group_id TEXT NOT NULL,
        cip_code TEXT NOT NULL,

        -- Pre-joined fields from (group_members + medicaments + medicament_summary + generique_groups)
        cis_code TEXT NOT NULL,
        nom_canonique TEXT NOT NULL,
        princeps_de_reference TEXT NOT NULL,
        princeps_brand_name TEXT NOT NULL,
        is_princeps INTEGER DEFAULT 0 CHECK (is_princeps IN (0, 1)),
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
        is_surveillance INTEGER DEFAULT 0 CHECK (is_surveillance IN (0, 1)),
        atc_code TEXT,
        member_type INTEGER DEFAULT 0,
        prix_public REAL,
        taux_remboursement TEXT,
        ansm_alert_url TEXT,
        is_hospital_only INTEGER DEFAULT 0 CHECK (is_hospital_only IN (0, 1)),
        is_dental INTEGER DEFAULT 0 CHECK (is_dental IN (0, 1)),
        is_list1 INTEGER DEFAULT 0 CHECK (is_list1 IN (0, 1)),
        is_list2 INTEGER DEFAULT 0 CHECK (is_list2 IN (0, 1)),
        is_narcotic INTEGER DEFAULT 0 CHECK (is_narcotic IN (0, 1)),
        is_exception INTEGER DEFAULT 0 CHECK (is_exception IN (0, 1)),
        is_restricted INTEGER DEFAULT 0 CHECK (is_restricted IN (0, 1)),
        is_otc INTEGER DEFAULT 1 CHECK (is_otc IN (0, 1)),
        availability_status TEXT,
        smr_niveau TEXT,
        smr_date TEXT,
        asmr_niveau TEXT,
        asmr_date TEXT,
        url_notice TEXT,
        has_safety_alert INTEGER DEFAULT 0 CHECK (has_safety_alert IN (0, 1)),
        raw_label TEXT,
        parsing_method TEXT,
        princeps_cis_reference TEXT,

        PRIMARY KEY (group_id, cip_code),
        FOREIGN KEY(group_id) REFERENCES generique_groups(group_id)
      ) STRICT;
    `);

    // Table: ui_stats - Pre-computed database statistics
    this.db.run(`
      CREATE TABLE IF NOT EXISTS ui_stats (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        total_princeps INTEGER DEFAULT 0,
        total_generiques INTEGER DEFAULT 0,
        total_principes INTEGER DEFAULT 0,
        last_updated TEXT DEFAULT CURRENT_TIMESTAMP
      ) STRICT;
    `);

    // Table: ui_explorer_list - Materialized view replacing Flutter's view_explorer_list
    this.db.run(`
      CREATE TABLE IF NOT EXISTS ui_explorer_list (
        cluster_id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT,
        secondary_princeps TEXT, -- JSON Array
        is_narcotic INTEGER DEFAULT 0 CHECK (is_narcotic IN (0, 1)),
        variant_count INTEGER DEFAULT 0,
        representative_cis TEXT,

        FOREIGN KEY(cluster_id) REFERENCES cluster_names(cluster_id)
      ) STRICT;
    `);
  }

  // Text normalization for SQLite function using sanitizer
  private normalizeTextBasic(input: string): string {
    return normalizeForSearch(input);
  }

  private prepareInsert<T extends Record<string, any>>(
    table: string,
    columns: ReadonlyArray<keyof T>
  ) {
    const cols = columns.map(String).join(", ");
    const vals = columns.map(() => "?").join(", ");
    const sql = `INSERT OR REPLACE INTO ${table} (${cols}) VALUES (${vals})`;
    const stmt = this.db.prepare(sql);

    return (rows: ReadonlyArray<T>) => {
      const BATCH_SIZE = 2000;
      for (let i = 0; i < rows.length; i += BATCH_SIZE) {
        const batch = rows.slice(i, i + BATCH_SIZE);
        const transaction = this.db.transaction((data: ReadonlyArray<T>) => {
          for (const row of data) {
            const values = columns.map((col) => row[col]);
            stmt.run(...values as SQLQueryBindings[]);
          }
        });
        transaction(batch);
        console.log(`   ... inserted ${Math.min(i + BATCH_SIZE, rows.length)} / ${rows.length} rows into ${table}`);
      }
    };
  }

  public insertFinalClusters(clusters: FinalCluster[]) {
    console.log(`📊 Inserting ${clusters.length} final clusters...`);

    // 1. Prepare statements
    const insertName = this.db.prepare(`
      INSERT OR REPLACE INTO cluster_names (cluster_id, cluster_name, substance_code, cluster_princeps, secondary_princeps)
      VALUES ($id, $name, $substance, $princeps, $secondary)
    `);

    const insertIndex = this.db.prepare(`
      INSERT OR REPLACE INTO cluster_index (cluster_id, title, subtitle, count_products, search_vector)
      VALUES ($id, $title, $subtitle, $count, $vector)
    `);

    const insertSearch = this.db.prepare(`
      INSERT OR REPLACE INTO search_index (cluster_id, search_vector)
      VALUES ($id, $vector)
    `);

    const updateSummary = this.db.prepare(`
        UPDATE medicament_summary 
        SET cluster_id = $clusterId,
            princeps_de_reference = COALESCE(NULLIF(princeps_de_reference, ''), $princepsRef)
        WHERE cis_code = $cis
    `);

    // 2. Transaction
    const runTransaction = this.db.transaction(() => {
      for (const c of clusters) {
        const princepsRef = c.sampleNames[0] || c.displayName;
        const secondaryJson = JSON.stringify(c.secondaryPrinceps);

        // A. Insert Names
        insertName.run({
          $id: c.superClusterId,
          $name: c.displayName,
          $substance: c.chemicalId,
          $princeps: princepsRef,
          $secondary: secondaryJson
        });

        // B. Build Search Vector
        const vector = buildSearchVector(
          c.displayName,
          princepsRef,
          c.secondaryPrinceps,
          ""
        );

        // C. Insert Index & FTS
        insertIndex.run({
          $id: c.superClusterId,
          $title: c.displayName,
          $subtitle: `Ref: ${princepsRef}`,
          $count: c.totalCIS,
          $vector: vector
        });

        insertSearch.run({
          $id: c.superClusterId,
          $vector: vector
        });

        // D. Update Members
        const allCis = [...c.sourceCIS, ...c.orphansCIS];
        for (const cis of allCis) {
          updateSummary.run({
            $clusterId: c.superClusterId,
            $princepsRef: princepsRef,
            $cis: cis
          });
        }
      }
    });

    runTransaction();
    console.log(`✅ Cluster persistence complete.`);
  }

  public refreshMaterializedViews() {
    console.log('🔄 Refreshing materialized views...');
    this.db.exec("DELETE FROM ui_explorer_list");
    this.db.exec("INSERT INTO ui_explorer_list SELECT * FROM view_explorer_list");

    this.db.exec("DELETE FROM ui_stats");
    this.db.exec(`
        INSERT INTO ui_stats (id, total_princeps, total_generiques, total_principes, last_updated)
        SELECT 1, 
            (SELECT COUNT(*) FROM medicament_summary WHERE is_princeps = 1),
            (SELECT COUNT(*) FROM medicament_summary WHERE is_princeps = 0),
            (SELECT COUNT(*) FROM ref_substances),
            CURRENT_TIMESTAMP
    `);

    // Attempt to populate ui_group_details if possible (best effort based on schema)
    // This query mirrors the table definition joins
    this.db.exec("DELETE FROM ui_group_details");
    this.db.exec(`
      INSERT INTO ui_group_details
      SELECT 
        gm.group_id,
        gm.cip_code,
        ms.cis_code,
        ms.nom_canonique,
        ms.princeps_de_reference,
        ms.princeps_brand_name,
        ms.is_princeps,
        ms.status,
        ms.forme_pharmaceutique,
        ms.voies_administration,
        ms.principes_actifs_communs,
        ms.formatted_dosage,
        '' as summary_titulaire, -- Deprecated/Empty in summary
        l.name as official_titulaire,
        '' as nom_specialite, -- Not in summary
        ms.procedure_type,
        ms.conditions_prescription,
        ms.is_surveillance,
        ms.atc_code,
        ms.member_type,
        m.prix_public,
        m.taux_remboursement,
        ms.ansm_alert_url,
        ms.is_hospital,
        ms.is_dental,
        ms.is_list1,
        ms.is_list2,
        ms.is_narcotic,
        ms.is_exception,
        ms.is_restricted,
        ms.is_otc,
        ma.statut as availability_status,
        ms.smr_niveau,
        ms.smr_date,
        ms.asmr_niveau,
        ms.asmr_date,
        ms.url_notice,
        ms.has_safety_alert,
        gg.raw_label,
        gg.parsing_method,
        gg.princeps_label as princeps_cis_reference
      FROM group_members gm
      JOIN medicaments m ON gm.cip_code = m.cip_code
      JOIN medicament_summary ms ON m.cis_code = ms.cis_code
      JOIN generique_groups gg ON gm.group_id = gg.group_id
      LEFT JOIN laboratories l ON ms.titulaire_id = l.id
      LEFT JOIN medicament_availability ma ON gm.cip_code = ma.cip_code
    `);

    console.log('✅ Materialized views refreshed');
  }

  public initMetadataTable() {
    this.db.run(`
      CREATE TABLE IF NOT EXISTS _metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      ) STRICT;
    `);
  }

  public setMetadata(key: string, value: string) {
    this.db.run(`INSERT OR REPLACE INTO _metadata (key, value) VALUES (?, ?)`, [key, value]);
  }

  // New insert methods for Flutter schema
  public insertSpecialites(rows: ReadonlyArray<Specialite>) {
    console.log(`📊 Inserting ${rows.length} specialites...`);

    // Convert camelCase to snake_case for database columns
    const transformedRows = rows.map(row => ({
      cis_code: row.cisCode,
      nom_specialite: row.nomSpecialite,
      procedure_type: row.procedureType,
      statut_administratif: row.statutAdministratif,
      forme_pharmaceutique: row.formePharmaceutique,
      voies_administration: row.voiesAdministration,
      etat_commercialisation: row.etatCommercialisation,
      titulaire_id: row.titulaireId,
      conditions_prescription: row.conditionsPrescription,
      date_amm: row.dateAmm,
      atc_code: row.atcCode,
      is_surveillance: row.isSurveillance ? 1 : 0
    }));

    const columns = Object.keys(transformedRows[0] || {}) as (keyof typeof transformedRows[0])[];
    // Use defined interfaces for type safety matching the DB schema
    interface SpecialiteRow {
      cis_code: string;
      nom_specialite: string;
      procedure_type: string;
      statut_administratif?: string | null;
      forme_pharmaceutique?: string | null;
      voies_administration?: string | null;
      etat_commercialisation?: string | null;
      titulaire_id?: number | null;
      conditions_prescription?: string | null;
      date_amm?: string | null;
      atc_code?: string | null;
      is_surveillance: number;
      [key: string]: any; // Required for Record constraint
    }

    this.prepareInsert<SpecialiteRow>("specialites", columns)(transformedRows);
    console.log(`✅ Inserted ${rows.length} specialites`);
  }

  public insertMedicaments(rows: ReadonlyArray<Medicament>) {
    console.log(`📊 Inserting ${rows.length} medicaments...`);

    interface MedicamentRow {
      cip_code: string;
      cis_code: string;
      presentation_label: string;
      commercialisation_statut?: string | null;
      taux_remboursement?: string | null;
      prix_public?: number | null;
      agrement_collectivites?: string | null;
      is_hospital: number;
      [key: string]: any;
    }

    const transformedRows: MedicamentRow[] = rows.map(row => ({
      cip_code: row.codeCip,
      cis_code: row.cisCode,
      presentation_label: row.presentationLabel ?? '',
      commercialisation_statut: row.commercialisationStatut,
      taux_remboursement: row.tauxRemboursement,
      prix_public: row.prixPublic,
      agrement_collectivites: row.agrementCollectivites,
      is_hospital: 0  // Will be computed by trigger based on conditions
    }));

    const columns = Object.keys(transformedRows[0] || {}) as (keyof MedicamentRow)[];
    this.prepareInsert<MedicamentRow>("medicaments", columns)(transformedRows);
    console.log(`✅ Inserted ${rows.length} medicaments`);
  }

  public insertMedicamentAvailability(rows: ReadonlyArray<MedicamentAvailability>) {
    console.log(`📊 Inserting ${rows.length} medicament availability records...`);

    interface AvailabilityRow {
      cip_code: string;
      statut: string;
      date_debut?: string | null;
      date_fin?: string | null;
      lien?: string | null;
      [key: string]: any;
    }

    const transformedRows: AvailabilityRow[] = rows.map(row => ({
      cip_code: row.codeCip,
      statut: row.statut ?? '',
      date_debut: row.dateDebut,
      date_fin: row.dateFin,
      lien: row.lien
    }));

    this.prepareInsert<AvailabilityRow>("medicament_availability", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} availability records`);
  }

  /**
   * Insert deduplicated safety alerts + cis links.
   * @param alerts Array of alerts objects { message, url, dateDebut, dateFin }
   * @param links Optional array of { cis, alertIndex } linking cis codes to alerts by index
   */
  public insertSafetyAlerts(
    alerts: ReadonlyArray<{ message: string; url?: string; dateDebut?: string; dateFin?: string }>,
    links?: ReadonlyArray<{ cis: string; alertIndex: number }>
  ) {
    console.log(`📊 Inserting ${alerts.length} unique safety alerts (+ ${links?.length ?? 0} links)...`);

    const insertAlert = this.db.prepare(
      `INSERT OR IGNORE INTO safety_alerts (title, url, date_debut, date_fin) VALUES ($title, $url, $start, $end)`
    );

    const selectAlertId = this.db.prepare(
      `SELECT id FROM safety_alerts WHERE title = $title AND COALESCE(url,'') = COALESCE($url,'') AND COALESCE(date_debut,'') = COALESCE($start,'') AND COALESCE(date_fin,'') = COALESCE($end,'') LIMIT 1`
    );

    const insertLink = this.db.prepare(
      `INSERT OR IGNORE INTO cis_safety_links (cis_code, alert_id) VALUES ($cis, $id)`
    );
    // Check current foreign_keys PRAGMA: if disabled, allow inserting links without pre-checks
    const fkPragma = this.db.query("PRAGMA foreign_keys").get() as Record<string, number> | undefined;
    const foreignKeysEnabled = fkPragma ? Object.values(fkPragma)[0] === 1 : true;

    // Pre-load valid CIS codes into a Set to avoid an extra SELECT per link.
    // This is faster and avoids per-link queries. We will validate links
    // against this set whenever the table contains entries (i.e. in the
    // real pipeline). If the table is empty (unit tests), we allow inserts
    // to simplify test setup where FK checks may be disabled.
    const cisRows = this.db.query<{ cis_code: string }, []>("SELECT cis_code FROM specialites").all();
    const validCisSet = new Set<string>(cisRows.map(r => r.cis_code));

    const indexToDbId = new Map<number, number>();

    this.db.transaction(() => {
      alerts.forEach((alert, idx) => {
        insertAlert.run({ $title: alert.message, $url: alert.url ?? null, $start: alert.dateDebut ?? null, $end: alert.dateFin ?? null });
        const row = selectAlertId.get({ $title: alert.message, $url: alert.url ?? null, $start: alert.dateDebut ?? null, $end: alert.dateFin ?? null }) as { id: number };
        if (row && row.id) indexToDbId.set(idx, row.id);
      });

      if (links) {
        let skipped = 0;
        let insertedLinks = 0;
        links.forEach(link => {
          const id = indexToDbId.get(link.alertIndex);
          if (!id) return;

          // Validate link only if we have known CIS codes in the DB.
          // This avoids blocking unit tests that intentionally disable FK
          // checks and don't populate `specialites`.
          if (validCisSet.size > 0 && !validCisSet.has(link.cis)) {
            skipped++;
            return;
          }

          insertLink.run({ $cis: link.cis, $id: id });
          insertedLinks++;
        });
        if (skipped > 0) console.log(`⚠️ Skipped ${skipped} alert links for unknown CIS codes.`);
        // Replace the logged links count with the actually inserted number for clarity
        console.log(`✅ Inserted ${indexToDbId.size} safety_alert records and ${insertedLinks} links`);
        // Exit the transaction early to avoid the old log below duplicating info
        return;
      }
    })();

    console.log(`✅ Inserted ${indexToDbId.size} safety_alert records and ${links?.length ?? 0} links`);
  }



  public populateMedicamentSummary() {
    console.log('🏗️ Populating medicament_summary from specialites...');

    this.db.exec(`
        INSERT OR IGNORE INTO medicament_summary (
            cis_code, 
            nom_canonique, 
            princeps_de_reference, 
            princeps_brand_name, 
            forme_pharmaceutique, 
            voies_administration, 
            status, 
            procedure_type, 
            titulaire_id, 
            conditions_prescription, 
            date_amm, 
            is_surveillance, 
            atc_code,
            is_hospital,
            is_otc
        )
        SELECT 
            s.cis_code, 
            s.nom_specialite, 
            '', 
            '', 
            s.forme_pharmaceutique, 
            s.voies_administration, 
            s.etat_commercialisation, 
            s.procedure_type,
            s.titulaire_id, 
            s.conditions_prescription, 
            s.date_amm, 
            s.is_surveillance, 
            s.atc_code,
            0,
            1
        FROM specialites s;
      `);

    console.log('✅ medicament_summary populated.');
  }

  public insertPrincipesActifs(rows: ReadonlyArray<PrincipeActif>) {
    console.log(`📊 Inserting ${rows.length} principes actifs...`);

    const transformedRows = rows.map(row => ({
      id: row.id,
      cip_code: row.codeCip,
      principe: row.principe,
      principe_normalized: row.principeNormalized,
      dosage: row.dosage,
      dosage_unit: row.dosageUnit
    }));

    this.prepareInsert<any>("principes_actifs", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} principes actifs`);
  }

  public insertGeneriqueGroups(rows: ReadonlyArray<GeneriqueGroup>) {
    console.log(`📊 Inserting ${rows.length} generique groups...`);

    const transformedRows = rows.map(row => ({
      group_id: row.groupId,
      libelle: row.libelle,
      princeps_label: row.princepsLabel,
      molecule_label: row.moleculeLabel,
      raw_label: row.rawLabel,
      parsing_method: row.parsingMethod
    }));

    this.prepareInsert<any>("generique_groups", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} generique groups`);
  }

  public insertGroupMembers(rows: ReadonlyArray<GroupMember>) {
    console.log(`📊 Inserting ${rows.length} group members...`);

    const transformedRows = rows.map(row => ({
      cip_code: row.codeCip,
      group_id: row.groupId,
      type: row.type,
      sort_order: row.sortOrder ?? 0
    }));

    this.prepareInsert<any>("group_members", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} group members`);
  }

  public insertMedicamentSummary(rows: ReadonlyArray<MedicamentSummary>) {
    console.log(`📊 Inserting ${rows.length} medicament summaries...`);

    const transformedRows = rows.map(row => {
      // Enhanced hospital-only logic matching mobile app's _isHospitalOnly
      // This centralizes the logic in the backend as the single source of truth
      let isHospital = row.isHospitalOnly;

      // If not already hospital-only based on conditions, check additional criteria
      if (!isHospital && row.conditionsPrescription) {
        // Check if conditions contain "HOSPITALIER"
        const hasHospitalCondition = row.conditionsPrescription.toLowerCase().includes('hospitalier');

        if (!hasHospitalCondition) {
          // Apply the same logic as mobile app's _isHospitalOnly
          // This requires access to medicaments table data for agrement, price, and refund
          // For now, we'll use the existing isHospitalOnly flag and enhance it with a trigger
          isHospital = hasHospitalCondition;
        }
      }

      return {
        cis_code: row.cisCode,
        nom_canonique: row.nomCanonique,
        is_princeps: row.isPrinceps ? 1 : 0,
        group_id: row.groupId,
        member_type: row.memberType || 0,
        principes_actifs_communs: row.principesActifsCommuns,
        princeps_de_reference: row.princepsDeReference,
        forme_pharmaceutique: row.formePharmaceutique,
        voies_administration: row.voiesAdministration,
        princeps_brand_name: row.princepsBrandName,
        procedure_type: row.procedureType,
        titulaire_id: row.titulaireId,
        conditions_prescription: row.conditionsPrescription,
        date_amm: row.dateAmm,
        is_surveillance: row.isSurveillance ? 1 : 0,
        formatted_dosage: row.formattedDosage,
        atc_code: row.atcCode,
        status: row.status,
        price_min: row.priceMin,
        price_max: row.priceMax,
        aggregated_conditions: row.aggregatedConditions,
        ansm_alert_url: row.ansmAlertUrl,
        is_hospital: isHospital ? 1 : 0,
        is_dental: row.isDental ? 1 : 0,
        is_list1: row.isList1 ? 1 : 0,
        is_list2: row.isList2 ? 1 : 0,
        is_narcotic: row.isNarcotic ? 1 : 0,
        is_exception: row.isException ? 1 : 0,
        is_restricted: row.isRestricted ? 1 : 0,
        is_otc: row.isOtc ? 1 : 0,
        smr_niveau: row.smrNiveau,
        smr_date: row.smrDate,
        asmr_niveau: row.asmrNiveau,
        asmr_date: row.asmrDate,
        url_notice: row.urlNotice,
        has_safety_alert: row.hasSafetyAlert ? 1 : 0,
        representative_cip: row.representativeCip,
        cluster_id: row.clusterId // NEW - cluster assignment
      };
    });

    this.prepareInsert<any>("medicament_summary", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} medicament summaries`);
  }

  public updateMedicamentSummaryPrinciples(profiles: Map<string, { substances: { name: string }[] }>) {
    console.log(`🧪 Updating medicament_summary principles for ${profiles.size} profiles...`);

    // Batch updates for performance
    const BATCH_SIZE = 2000;
    const entries = Array.from(profiles.entries());
    const stmt = this.db.prepare(`
      UPDATE medicament_summary 
      SET principes_actifs_communs = ? 
      WHERE cis_code = ?
    `);

    for (let i = 0; i < entries.length; i += BATCH_SIZE) {
      const batch = entries.slice(i, i + BATCH_SIZE);
      const transaction = this.db.transaction((items: [string, { substances: { name: string }[] }][]) => {
        for (const [cis, profile] of items) {
          // Format: "Amoxicilline, Acide clavulanique"
          const principles = profile.substances.map(s => s.name).join(", ");
          stmt.run(principles, cis);
        }
      });
      transaction(batch);
      process.stdout.write(`   ... updated ${Math.min(i + BATCH_SIZE, entries.length)} / ${entries.length} rows\r`);
    }
    console.log(`\n✅ Updated principles for ${entries.length} CIS`);
  }



  // --- PHASE 2 INSERT METHODS ---
  public insertRefForms(rows: ReadonlyArray<{ id: number; label: string }>) {
    console.log(`📊 Inserting ${rows.length} forms...`);
    this.prepareInsert<any>("ref_forms", ["id", "label"])(rows);
    console.log(`✅ Inserted ${rows.length} forms`);
  }

  public insertRefRoutes(rows: ReadonlyArray<{ id: number; label: string }>) {
    console.log(`📊 Inserting ${rows.length} routes...`);
    this.prepareInsert<any>("ref_routes", ["id", "label"])(rows);
    console.log(`✅ Inserted ${rows.length} routes`);
  }

  public insertCisRoutes(rows: ReadonlyArray<{ cis_code: string; route_id: number; is_inferred: number }>) {
    console.log(`📊 Inserting ${rows.length} CIS-Route links...`);
    this.prepareInsert<any>("cis_routes", ["cis_code", "route_id", "is_inferred"])(rows);
    console.log(`✅ Inserted ${rows.length} CIS-Route links`);
  }

  public insertRefSubstances(rows: ReadonlyArray<{ id: number; label: string; code?: string }>) {
    console.log(`🧪 Inserting ${rows.length} substances...`);
    this.prepareInsert<any>("ref_substances", ["id", "label", "code"])(rows);
    console.log(`✅ Inserted ${rows.length} substances`);
  }

  public insertCompositionLinks(rows: ReadonlyArray<{ cis_code: string; substance_id: number; dosage: string; nature: string }>) {
    console.log(`🔗 Inserting ${rows.length} composition links...`);
    this.prepareInsert<any>("composition_link", ["cis_code", "substance_id", "dosage", "nature"])(rows);
    console.log(`✅ Inserted ${rows.length} composition links`);
  }


  // Search methods for FTS
  public searchMedicaments(query: string, limit?: number): ReadonlyArray<MedicamentSummary> {
    let sql = `
      SELECT ms.*
      FROM medicament_summary ms
      JOIN search_index fts ON ms.content_rowid = fts.rowid
      WHERE search_index MATCH ?
      ORDER BY rank
    `;

    // Note: older sqlite versions used fts.docid, newer use fts.rowid or content_rowid logic.
    // In our initSchema we defined content_rowid='rowid'.
    // The JOIN might need to be on ms.rowid = fts.rowid if using external content.
    // Or we can just query the virtual table if we want columns from it, but we want ms.*.
    // Correct standard FTS5 external content query:
    // SELECT * FROM search_index WHERE search_index MATCH ? ORDER BY rank;
    // But we need the full summary.

    sql = `
      SELECT ms.*
      FROM medicament_summary ms
      JOIN search_index fts ON ms.rowid = fts.rowid
      WHERE search_index MATCH ?
      ORDER BY fts.rank
    `;

    if (limit) {
      sql += ` LIMIT ${limit}`;
    }

    const rows = this.db.query<any, []>(sql).all();

    return rows.map(row => ({
      cisCode: row.cis_code,
      nomCanonique: row.nom_canonique,
      isPrinceps: Boolean(row.is_princeps),
      groupId: row.group_id,
      memberType: row.member_type,
      principesActifsCommuns: row.principes_actifs_communs,
      princepsDeReference: row.princeps_de_reference,
      formePharmaceutique: row.forme_pharmaceutique,
      voiesAdministration: row.voies_administration,
      princepsBrandName: row.princeps_brand_name,
      procedureType: row.procedure_type,
      titulaireId: row.titulaire_id,
      conditionsPrescription: row.conditions_prescription,
      dateAmm: row.date_amm,
      isSurveillance: Boolean(row.is_surveillance),
      formattedDosage: row.formatted_dosage,
      atcCode: row.atc_code,
      status: row.status,
      priceMin: row.price_min,
      priceMax: row.price_max,
      aggregatedConditions: row.aggregated_conditions,
      ansmAlertUrl: row.ansm_alert_url,
      isHospitalOnly: Boolean(row.is_hospital),
      isDental: Boolean(row.is_dental),
      isList1: Boolean(row.is_list1),
      isList2: Boolean(row.is_list2),
      isNarcotic: Boolean(row.is_narcotic),
      isException: Boolean(row.is_exception),
      isRestricted: Boolean(row.is_restricted),
      isOtc: Boolean(row.is_otc),
      smrNiveau: row.smr_niveau,
      smrDate: row.smr_date,
      asmrNiveau: row.asmr_niveau,
      asmrDate: row.asmr_date,
      urlNotice: row.url_notice,
      hasSafetyAlert: Boolean(row.has_safety_alert),
      representativeCip: row.representative_cip,
      clusterId: row.cluster_id
    }));
  }



  public insertManufacturers(rows: ReadonlyArray<{ id: number; label: string }>) {
    console.log(`📊 Inserting ${rows.length} manufacturers (as laboratories)...`);

    const labs: Laboratory[] = rows.map(row => ({
      id: row.id,
      name: row.label
    }));

    this.insertLaboratories(labs);
    console.log(`✅ Inserted ${rows.length} manufacturers as laboratories`);
  }




  /**
   * Populates the search_index FTS5 table from medicament_summary.
   * This should be called after bulk inserts/updates to ensure search index is populated.
   * Drops and recreates the index to avoid rowid synchronization issues.
   */
  public populateSearchIndex() {
    console.log("📇 Populating search_index from cluster data...");

    // Drop triggers for the old search_index first
    this.db.run("DROP TRIGGER IF EXISTS search_index_ai");
    this.db.run("DROP TRIGGER IF EXISTS search_index_au");
    this.db.run("DROP TRIGGER IF EXISTS search_index_ad");

    // Drop and recreate the FTS5 table to use cluster-based search with trigram tokenizer
    this.db.run("DROP TABLE IF EXISTS search_index");
    this.db.run(`
      CREATE VIRTUAL TABLE search_index USING fts5(
        cluster_id UNINDEXED,
        search_vector,
        tokenize='trigram'                -- The magic for fuzzy matching
      )
    `);

    // Fetch cluster data and populate the search index with search vectors
    const clusters = this.db.query<{
      cluster_id: string;
      search_vector: string;
    }, []>(`
      SELECT cluster_id, search_vector
      FROM cluster_index
    `).all();

    const stmt = this.db.prepare(`
      INSERT INTO search_index (cluster_id, search_vector)
      VALUES (?, ?)
    `);

    for (const cluster of clusters) {
      stmt.run(cluster.cluster_id, cluster.search_vector);
    }

    console.log("✅ Search index populated with cluster data");
  }

  /**
   * Populates the ui_group_details table by pre-computing complex JOINs.
   * This replaces Flutter's view_group_details and enables simple TableManager access.
   * Should be called after all base tables are populated.
   */
  public populateUiGroupDetails() {
    console.log("🏗️ Populating ui_group_details from joined data...");

    // Clear existing data
    this.db.run("DELETE FROM ui_group_details");

    // Insert pre-computed data with all required JOINs
    this.db.run(`
      INSERT INTO ui_group_details (
        group_id,
        cip_code,
        cis_code,
        nom_canonique,
        princeps_de_reference,
        princeps_brand_name,
        is_princeps,
        status,
        forme_pharmaceutique,
        voies_administration,
        principes_actifs_communs,
        formatted_dosage,
        summary_titulaire,
        official_titulaire,
        nom_specialite,
        procedure_type,
        conditions_prescription,
        is_surveillance,
        atc_code,
        member_type,
        prix_public,
        taux_remboursement,
        ansm_alert_url,
        is_hospital_only,
        is_dental,
        is_list1,
        is_list2,
        is_narcotic,
        is_exception,
        is_restricted,
        is_otc,
        availability_status,
        smr_niveau,
        smr_date,
        asmr_niveau,
        asmr_date,
        url_notice,
        has_safety_alert,
        raw_label,
        parsing_method,
        princeps_cis_reference
      )
      SELECT
        gm.group_id,
        gm.cip_code,
        ms.cis_code,
        ms.nom_canonique,
        ms.princeps_de_reference,
        ms.princeps_brand_name,
        COALESCE(ms.is_princeps, 0),
        ms.status,
        ms.forme_pharmaceutique,
        ms.voies_administration,
        ms.principes_actifs_communs,
        ms.formatted_dosage,
        l.name AS summary_titulaire,
        l.name AS official_titulaire,
        ms.nom_canonique AS nom_specialite,
        ms.procedure_type,
        ms.conditions_prescription,
        COALESCE(ms.is_surveillance, 0),
        ms.atc_code,
        gm.type AS member_type,
        COALESCE(m.prix_public, 0) AS prix_public,
        m.taux_remboursement,
        ms.ansm_alert_url,
        COALESCE(ms.is_hospital, 0) AS is_hospital_only,
        COALESCE(ms.is_dental, 0),
        COALESCE(ms.is_list1, 0),
        COALESCE(ms.is_list2, 0),
        COALESCE(ms.is_narcotic, 0),
        COALESCE(ms.is_exception, 0),
        COALESCE(ms.is_restricted, 0),
        COALESCE(ms.is_otc, 1),
        COALESCE(ma.statut, '') AS availability_status,
        ms.smr_niveau,
        ms.smr_date,
        ms.asmr_niveau,
        ms.asmr_date,
        ms.url_notice,
        COALESCE(ms.has_safety_alert, 0),
        gg.raw_label,
        gg.parsing_method,
        (
          SELECT ms2.cis_code
          FROM medicament_summary ms2
          WHERE ms2.group_id = ms.group_id
            AND ms2.is_princeps = 1
          LIMIT 1
        ) AS princeps_cis_reference
      FROM group_members gm
      INNER JOIN medicaments m ON m.cip_code = gm.cip_code
      INNER JOIN medicament_summary ms ON ms.cis_code = m.cis_code
      INNER JOIN generique_groups gg ON gg.group_id = gm.group_id
      LEFT JOIN laboratories l ON l.id = ms.titulaire_id
      LEFT JOIN medicament_availability ma ON ma.cip_code = gm.cip_code
    `);

    const count = this.db.query<{ count: number }, []>("SELECT COUNT(*) as count FROM ui_group_details").get();
    console.log(`✅ UI group details populated with ${count?.count ?? 0} entries`);
  }

  public insertLaboratories(data: { id?: number; name: string }[]) {
    console.log(`📊 Inserting ${data.length} laboratories...`);
    const stmt = this.db.prepare("INSERT OR IGNORE INTO laboratories (name) VALUES (?)");

    // Explicit ID insertion if provided (for Unknown lab id=0)
    const stmtWithId = this.db.prepare("INSERT OR IGNORE INTO laboratories (id, name) VALUES (?, ?)");

    const transaction = this.db.transaction((labs: { id?: number; name: string }[]) => {
      for (const lab of labs) {
        if (lab.id !== undefined) {
          stmtWithId.run(lab.id, lab.name);
        } else {
          stmt.run(lab.name);
        }
      }
    });

    transaction(data);
    console.log(`✅ Inserted ${data.length} laboratories`);
  }

  public getLaboratoryMap(): Map<string, number> {
    const rows = this.db.prepare("SELECT id, name FROM laboratories").all() as { id: number; name: string }[];
    return new Map(rows.map(row => [row.name, row.id]));
  }

  /**
   * Populates the ui_stats table with pre-computed database statistics.
   * Replaces Flutter's complex COUNT() queries with a single row fetch.
   */
  public populateUiStats() {
    console.log("📊 Populating ui_stats from computed data...");

    // Clear existing data
    this.db.run("DELETE FROM ui_stats");

    // Insert computed statistics
    this.db.run(`
      INSERT INTO ui_stats (id, total_princeps, total_generiques, total_principes)
      SELECT
        1,
        COUNT(*) - COUNT(CASE WHEN gm.type = 1 THEN 1 END) AS total_princeps,
        COUNT(CASE WHEN gm.type = 1 THEN 1 END) AS total_generiques,
        (SELECT COUNT(DISTINCT principe) FROM principes_actifs) AS total_principes
      FROM medicaments m
      LEFT JOIN group_members gm ON gm.cip_code = m.cip_code
    `);

    const stats = this.db.query<{ total_princeps: number; total_generiques: number; total_principes: number }, []>(
      "SELECT total_princeps, total_generiques, total_principes FROM ui_stats WHERE id = 1"
    ).get();

    console.log(`✅ UI stats populated: ${stats?.total_princeps ?? 0} princeps, ${stats?.total_generiques ?? 0} generics, ${stats?.total_principes ?? 0} principles`);
  }

  /**
   * Populates the ui_explorer_list table from cluster data.
   * Replaces Flutter's view_explorer_list with a materialized table.
   */
  public populateUiExplorerList() {
    console.log("📋 Populating ui_explorer_list from cluster data...");

    // Clear existing data
    this.db.run("DELETE FROM ui_explorer_list");

    // Insert cluster-based data
    this.db.run(`
      INSERT INTO ui_explorer_list (
        cluster_id,
        title,
        subtitle,
        secondary_princeps,
        is_narcotic,
        variant_count,
        representative_cis
      )
      SELECT
        cn.cluster_id,
        cn.cluster_name AS title,
        cn.cluster_princeps AS subtitle,
        cn.secondary_princeps,
        MAX(COALESCE(ms.is_narcotic, 0)) AS is_narcotic,
        COUNT(ms.cis_code) AS variant_count,
        MIN(ms.cis_code) AS representative_cis
      FROM cluster_names cn
      JOIN medicament_summary ms ON cn.cluster_id = ms.cluster_id
      GROUP BY cn.cluster_id
    `);

    const count = this.db.query<{ count: number }, []>("SELECT COUNT(*) as count FROM ui_explorer_list").get();
    console.log(`✅ UI explorer list populated with ${count?.count ?? 0} entries`);
  }

  /**
   * Populates all UI materialized view tables.
   * Call this after all base tables are populated.
   */
  public populateAllUiTables() {
    console.log("🏗️ Populating all UI materialized view tables...");
    this.populateUiGroupDetails();
    this.populateUiStats();
    this.populateUiExplorerList();
    console.log("✅ All UI tables populated successfully");
  }

  /**
   * Populates the product_scan_cache table by pre-computing all JOINs.
   * This eliminates the need for runtime JOINs in Flutter's CatalogDao.getProductByCip().
   * Should be called after all base tables are populated.
   */
  public populateProductScanCache() {
    console.log("📦 Populating product_scan_cache from joined data...");

    // Clear existing cache
    this.db.run("DELETE FROM product_scan_cache");

    // Insert pre-computed data from all joined tables
    this.db.run(`
      INSERT INTO product_scan_cache (
        cip_code,
        cis_code,
        nom_canonique,
        lab_name,
        prix_public,
        taux_remboursement,
        availability_status,
        is_hospital,
        is_princeps,
        is_surveillance,
        is_narcotic,
        princeps_de_reference,
        princeps_brand_name,
        forme_pharmaceutique,
        voies_administration,
        formatted_dosage,
        group_id,
        cluster_id,
        conditions_prescription,
        commercialisation_statut,
        titulaire_id,
        atc_code,
        representative_cip
      )
      SELECT
        m.cip_code,
        m.cis_code,
        ms.nom_canonique,
        l.name AS lab_name,
        m.prix_public,
        m.taux_remboursement,
        ma.statut AS availability_status,
        COALESCE(ms.is_hospital, 0) AS is_hospital,
        COALESCE(ms.is_princeps, 0) AS is_princeps,
        COALESCE(ms.is_surveillance, 0) AS is_surveillance,
        COALESCE(ms.is_narcotic, 0) AS is_narcotic,
        COALESCE(ms.princeps_de_reference, '') AS princeps_de_reference,
        COALESCE(ms.princeps_brand_name, '') AS princeps_brand_name,
        ms.forme_pharmaceutique,
        ms.voies_administration,
        ms.formatted_dosage,
        ms.group_id,
        ms.cluster_id,
        ms.conditions_prescription,
        m.commercialisation_statut,
        ms.titulaire_id,
        ms.atc_code,
        ms.representative_cip
      FROM medicaments m
      INNER JOIN medicament_summary ms ON m.cis_code = ms.cis_code
      LEFT JOIN laboratories l ON ms.titulaire_id = l.id
      LEFT JOIN medicament_availability ma ON m.cip_code = ma.cip_code
    `);

    const count = this.db.query<{ count: number }, []>("SELECT COUNT(*) as count FROM product_scan_cache").get();
    console.log(`✅ Product scan cache populated with ${count?.count ?? 0} entries`);
  }

  public insertClusterData(rows: Array<{
    cluster_id: string;
    title: string;
    subtitle: string;
    count_products: number;
    search_vector: string;
  }>) {
    console.log(`📊 Inserting ${rows.length} cluster entries...`);

    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO cluster_index (
        cluster_id,
        title,
        subtitle,
        count_products,
        search_vector
      ) VALUES (?, ?, ?, ?, ?)
    `);

    for (const row of rows) {
      stmt.run(
        row.cluster_id,
        row.title,
        row.subtitle,
        row.count_products,
        row.search_vector
      );

      if (row.title.includes('TAGAMET')) {
        console.log(`[DB-DEBUG] Inserting Tagamet vector: "${row.search_vector}"`);
      }
    }

    console.log(`✅ Inserted ${rows.length} cluster entries`);
  }

  public insertClusterMedicamentDetails(rows: Array<{
    cis_code: string;
    cluster_id: string;
    nom_complet: string;
    is_princeps: boolean;
  }>) {
    console.log(`📊 Inserting ${rows.length} cluster medicament details...`);

    const stmt = this.db.prepare(`
      INSERT OR REPLACE INTO medicament_detail (
        cis_code,
        cluster_id,
        nom_complet,
        is_princeps
      ) VALUES (?, ?, ?, ?)
    `);

    for (const row of rows) {
      stmt.run(
        row.cis_code,
        row.cluster_id,
        row.nom_complet,
        row.is_princeps ? 1 : 0
      );
    }

    console.log(`✅ Inserted ${rows.length} cluster medicament details`);
  }

  /**
   * Aggregates data into the medicament_summary table.
   * This is the "Source of Truth" table optimized for the Flutter app.
   */
  public aggregateMedicamentSummary() {
    console.log("📊 Aggregating MedicamentSummary...");

    // Insert grouped medicaments (without cluster_id first, then update)
    this.db.run(`
      INSERT OR REPLACE INTO medicament_summary (
        cis_code, nom_canonique, is_princeps, group_id, member_type,
        principes_actifs_communs, princeps_de_reference, parent_princeps_cis, forme_pharmaceutique, form_id, is_form_inferred,
        voies_administration, princeps_brand_name, procedure_type, titulaire_id,
        conditions_prescription, date_amm, is_surveillance, formatted_dosage,
        atc_code, status, price_min, price_max, aggregated_conditions,
        ansm_alert_url, is_hospital, is_dental, is_list1, is_list2,
        is_narcotic, is_exception, is_restricted, is_otc,
        smr_niveau, smr_date, asmr_niveau, asmr_date, url_notice, has_safety_alert,
        representative_cip
      )
      SELECT
        s.cis_code,
        COALESCE(
          (SELECT nom_clean FROM medicament_names_clean WHERE cis_code = s.cis_code LIMIT 1),
          s.nom_specialite
        ) AS nom_canonique,
        CASE WHEN gm.type = 0 THEN 1 ELSE 0 END AS is_princeps,
        gg.group_id,
        gm.type AS member_type,
        NULL AS principes_actifs_communs, -- Filled via update later
        COALESCE(gg.princeps_label, gg.libelle, s.nom_specialite, 'Inconnu') AS princeps_de_reference,
        (
          SELECT m0.cis_code 
          FROM group_members gm0 
          JOIN medicaments m0 ON gm0.cip_code = m0.cip_code 
          WHERE gm0.group_id = gg.group_id AND gm0.type = 0 
          ORDER BY gm0.sort_order DESC 
          LIMIT 1
        ) AS parent_princeps_cis,
        s.forme_pharmaceutique,
        rf.id AS form_id,
        0 AS is_form_inferred,
        s.voies_administration,
        COALESCE(gg.princeps_label, gg.libelle, s.nom_specialite, 'Inconnu') AS princeps_brand_name,
        s.procedure_type,
        s.titulaire_id,
        s.conditions_prescription,
        s.date_amm,
        s.is_surveillance,
        NULL AS formatted_dosage,
        s.atc_code,
        s.statut_administratif AS status,
        (
          SELECT MIN(m3.prix_public)
          FROM medicaments m3
          INNER JOIN group_members gm3 ON m3.cip_code = gm3.cip_code
          WHERE gm3.group_id = gg.group_id
        ) AS price_min,
        (
          SELECT MAX(m4.prix_public)
          FROM medicaments m4
          INNER JOIN group_members gm4 ON m4.cip_code = gm4.cip_code
          WHERE gm4.group_id = gg.group_id
        ) AS price_max,
        '[]' AS aggregated_conditions,
        NULL AS ansm_alert_url,
        -- Computed flags based on conditions_prescription
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%LISTE II%' THEN 0 
             WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%LISTE I%' 
              AND UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE II%' THEN 1 
             ELSE 0 END AS is_list1,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%LISTE II%' THEN 1 ELSE 0 END AS is_list2,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%STUPÉFIANT%' OR UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%STUPEFIANT%' THEN 1 ELSE 0 END AS is_narcotic,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%HOSPITALIER%' THEN 1 ELSE 0 END AS is_hospital,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%EXCEPTION%' THEN 1 ELSE 0 END AS is_exception,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%RESTREINTE%' THEN 1 ELSE 0 END AS is_restricted,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%DENTAIRE%' THEN 1 ELSE 0 END AS is_dental,
        -- OTC Logic
        CASE WHEN (
            UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE I%' AND 
            UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE II%' AND 
            (UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%STUPÉFIANT%' AND UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%STUPEFIANT%')
        ) THEN 1 ELSE 0 END AS is_otc,
        NULL AS smr_niveau, NULL AS smr_date, NULL AS asmr_niveau, NULL AS asmr_date,
        'https://base-donnees-publique.medicaments.gouv.fr/affichageDoc.php?specid=' || s.cis_code || '&typedoc=N' AS url_notice,
        CASE WHEN EXISTS(SELECT 1 FROM cis_safety_links l WHERE l.cis_code = s.cis_code) THEN 1 ELSE 0 END AS has_safety_alert,
        (
          SELECT MIN(m5.cip_code)
          FROM medicaments m5
          INNER JOIN group_members gm5 ON m5.cip_code = gm5.cip_code
          WHERE gm5.group_id = gg.group_id AND m5.cis_code = s.cis_code
        ) AS representative_cip
      FROM generique_groups gg
      INNER JOIN group_members gm ON gg.group_id = gm.group_id
      INNER JOIN medicaments m ON gm.cip_code = m.cip_code
      INNER JOIN specialites s ON m.cis_code = s.cis_code
      LEFT JOIN ref_forms rf ON s.forme_pharmaceutique = rf.label
    `);

    // Insert standalone medicaments
    this.db.run(`
      INSERT OR REPLACE INTO medicament_summary (
        cis_code, nom_canonique, is_princeps, group_id, member_type,
        principes_actifs_communs, princeps_de_reference, parent_princeps_cis, forme_pharmaceutique, form_id, is_form_inferred,
        voies_administration, princeps_brand_name, procedure_type, titulaire_id,
        conditions_prescription, date_amm, is_surveillance, formatted_dosage,
        atc_code, status, price_min, price_max, aggregated_conditions,
        ansm_alert_url, is_hospital, is_dental, is_list1, is_list2,
        is_narcotic, is_exception, is_restricted, is_otc,
        smr_niveau, smr_date, asmr_niveau, asmr_date, url_notice, has_safety_alert, representative_cip
      )
      SELECT
        s.cis_code,
        COALESCE(
          (SELECT nom_clean FROM medicament_names_clean WHERE cis_code = s.cis_code LIMIT 1),
          s.nom_specialite
        ) AS nom_canonique,
        1 AS is_princeps,
        NULL AS group_id,
        0 AS member_type,
        json_array() AS principes_actifs_communs, -- Placeholder
        s.nom_specialite AS princeps_de_reference,
        s.cis_code AS parent_princeps_cis,
        s.forme_pharmaceutique,
        rf.id AS form_id,
        0 AS is_form_inferred,
        s.voies_administration,
        s.nom_specialite AS princeps_brand_name,
        s.procedure_type,
        s.titulaire_id,
        s.conditions_prescription,
        s.date_amm,
        s.is_surveillance,
        NULL AS formatted_dosage,
        s.atc_code,
        s.statut_administratif AS status,
        (SELECT MIN(m3.prix_public) FROM medicaments m3 WHERE m3.cis_code = s.cis_code) AS price_min,
        (SELECT MAX(m4.prix_public) FROM medicaments m4 WHERE m4.cis_code = s.cis_code) AS price_max,
        '[]' AS aggregated_conditions,
        NULL AS ansm_alert_url,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%LISTE II%' THEN 0 
             WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%LISTE I%' AND UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE II%' THEN 1 
             ELSE 0 END AS is_list1,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%LISTE II%' THEN 1 ELSE 0 END AS is_list2,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%STUPÉFIANT%' OR UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%STUPEFIANT%' THEN 1 ELSE 0 END AS is_narcotic,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%HOSPITALIER%' THEN 1 ELSE 0 END AS is_hospital,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%EXCEPTION%' THEN 1 ELSE 0 END AS is_exception,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%RESTREINTE%' THEN 1 ELSE 0 END AS is_restricted,
        CASE WHEN UPPER(COALESCE(s.conditions_prescription, '')) LIKE '%DENTAIRE%' THEN 1 ELSE 0 END AS is_dental,
        CASE WHEN (
            UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE I%' AND 
            UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE II%' AND 
            (UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%STUPÉFIANT%' AND UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%STUPEFIANT%')
        ) THEN 1 ELSE 0 END AS is_otc,
        NULL AS smr_niveau, NULL AS smr_date, NULL AS asmr_niveau, NULL AS asmr_date,
        'https://base-donnees-publique.medicaments.gouv.fr/affichageDoc.php?specid=' || s.cis_code || '&typedoc=N' AS url_notice,
        CASE WHEN EXISTS(SELECT 1 FROM cis_safety_links l WHERE l.cis_code = s.cis_code) THEN 1 ELSE 0 END AS has_safety_alert,
        (SELECT MIN(m5.cip_code) FROM medicaments m5 WHERE m5.cis_code = s.cis_code) AS representative_cip
      FROM specialites s
      LEFT JOIN ref_forms rf ON s.forme_pharmaceutique = rf.label
      WHERE NOT EXISTS (
        SELECT 1 FROM group_members gm JOIN medicaments m ON gm.cip_code = m.cip_code WHERE m.cis_code = s.cis_code
      )
    `);

    // Update compositions for standalone CIS
    this.db.run(`
      UPDATE medicament_summary
      SET principes_actifs_communs = (
        SELECT json_group_array(
          TRIM(
            pa.principe_normalized || 
            CASE WHEN pa.dosage IS NOT NULL THEN ' ' || pa.dosage ELSE '' END ||
            CASE WHEN pa.dosage_unit IS NOT NULL THEN ' ' || pa.dosage_unit ELSE '' END
          )
        )
        FROM principes_actifs pa
        JOIN medicaments m ON pa.cip_code = m.cip_code
        WHERE m.cis_code = medicament_summary.cis_code
        AND pa.principe_normalized IS NOT NULL AND pa.principe_normalized != ''
        ORDER BY pa.principe_normalized
      )
      WHERE group_id IS NULL
    `);

    const count = this.db.query<{ count: number }, []>("SELECT COUNT(*) AS count FROM medicament_summary").get();
    console.log(`✅ Aggregated ${count?.count} medicament summaries`);
  }

  /**
   * Propagates group-level data (e.g., flags) to all members of the group.
   * This ensures consistency, e.g., if most generics are 'List I', all should be.
   */
  public propagateGroupData() {
    console.log("⚖️  Harmonizing missing data (Propagation by Group Majority)...");

    // 1. Fetch raw data
    const groupDataQuery = this.db.query<{
      group_id: string;
      is_list1: number;
      is_list2: number;
      is_narcotic: number;
      is_hospital: number;
      is_dental: number;
      is_exception: number;
      is_restricted: number;
      atc_code: string | null;
      conditions_prescription: string | null;
    }, []>(`
        SELECT group_id, is_list1, is_list2, is_narcotic, is_hospital, is_dental, is_exception, is_restricted, atc_code, conditions_prescription
        FROM medicament_summary WHERE group_id IS NOT NULL
      `).all();

    // 2. Compute consensus
    const groupConsensus = new Map<string, any>();
    const groupsBuffer = new Map<string, typeof groupDataQuery>();

    for (const row of groupDataQuery) {
      if (!groupsBuffer.has(row.group_id)) groupsBuffer.set(row.group_id, []);
      groupsBuffer.get(row.group_id)!.push(row);
    }

    for (const [groupId, members] of groupsBuffer.entries()) {
      const count = members.length;
      if (count === 0) continue;

      const sumList1 = members.reduce((acc, m) => acc + m.is_list1, 0);
      const sumList2 = members.reduce((acc, m) => acc + m.is_list2, 0);
      const sumNarc = members.reduce((acc, m) => acc + m.is_narcotic, 0);
      const sumHosp = members.reduce((acc, m) => acc + m.is_hospital, 0);
      const sumDental = members.reduce((acc, m) => acc + m.is_dental, 0);
      const sumException = members.reduce((acc, m) => acc + m.is_exception, 0);
      const sumRestricted = members.reduce((acc, m) => acc + m.is_restricted, 0);

      const getMode = (extractor: (m: typeof members[0]) => string | null) => {
        const counts = new Map<string, number>();
        for (const m of members) {
          const val = extractor(m);
          if (val && val.trim().length > 0) counts.set(val, (counts.get(val) || 0) + 1);
        }
        const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]);
        return sorted.length > 0 ? sorted[0][0] : null;
      };

      groupConsensus.set(groupId, {
        list1: sumList1 / count > 0.5 ? 1 : 0,
        list2: sumList2 / count > 0.5 ? 1 : 0,
        narcotic: sumNarc / count > 0.5 ? 1 : 0,
        hospital: sumHosp / count > 0.5 ? 1 : 0,
        dental: sumDental / count > 0.5 ? 1 : 0,
        exception: sumException / count > 0.5 ? 1 : 0,
        restricted: sumRestricted / count > 0.5 ? 1 : 0,
        atc: getMode(m => m.atc_code),
        conditions: getMode(m => m.conditions_prescription)
      });
    }

    // 3. Apply updates
    const updateStmt = this.db.prepare(`
      UPDATE medicament_summary
      SET is_list1 = ?, is_list2 = ?, is_narcotic = ?, is_hospital = ?, is_dental = ?, is_exception = ?, is_restricted = ?,
          atc_code = COALESCE(atc_code, ?), conditions_prescription = COALESCE(conditions_prescription, ?)
      WHERE group_id = ?
    `);

    this.db.transaction(() => {
      for (const [groupId, consensus] of groupConsensus.entries()) {
        updateStmt.run(
          consensus.list1, consensus.list2, consensus.narcotic, consensus.hospital, consensus.dental, consensus.exception, consensus.restricted,
          consensus.atc, consensus.conditions, groupId
        );
      }
    })();

    // Recalculate OTC
    this.db.run(`
      UPDATE medicament_summary
      SET is_otc = CASE WHEN (is_list1 = 0 AND is_list2 = 0 AND is_narcotic = 0) THEN 1 ELSE 0 END
      WHERE group_id IS NOT NULL
    `);

    console.log(`✅ Propagated consensus data for ${groupConsensus.size} groups`);
  }

  /**
   * Updates cluster_names and medicament_summary with cluster information.
   */
  public updateClusters(clusterMap: Map<string, ClusterMetadata>) {
    console.log("📊 Updating clusters in DB...");

    // 1. Build helper map
    const groupIdToClusterId = new Map<string, string>();
    for (const [groupId, meta] of clusterMap.entries()) {
      groupIdToClusterId.set(groupId, meta.clusterId);
    }

    // 2. Insert into cluster_names
    const insertClusterNameStmt = this.db.prepare(`
      INSERT OR REPLACE INTO cluster_names (cluster_id, cluster_name, substance_code, cluster_princeps, secondary_princeps)
      VALUES (?, ?, ?, ?, ?)
    `);

    // Helper map to deduplicate cluster inserts (multiple groups -> same cluster)
    // clusterMap is GroupID -> Metadata. Multiple groups map to same ClusterMetadata object (same ref)?
    // Yes, in computeClusters: groupToCluster.set(item.groupId, metadata); 
    // metadata is shared.
    const uniqueClusters = new Set<string>();

    this.db.transaction(() => {
      for (const [groupId, meta] of clusterMap.entries()) {
        if (!uniqueClusters.has(meta.clusterId)) {
          uniqueClusters.add(meta.clusterId);
          const secondariesJson = meta.secondaryPrinceps && meta.secondaryPrinceps.length > 0
            ? JSON.stringify(meta.secondaryPrinceps)
            : null;
          // Initial cluster_name is princepsLabel. Will be updated later if needed.
          insertClusterNameStmt.run(meta.clusterId, meta.princepsLabel, meta.substanceCode, null, secondariesJson);
        }
      }
    })();

    // 3. Update medicament_summary
    // We update cluster_id and princeps_de_reference based on the cluster map
    const updateSummaryStmt = this.db.prepare(`
      UPDATE medicament_summary
      SET cluster_id = ?, princeps_de_reference = ?
      WHERE group_id = ?
    `);

    // Also handle orphans?
    // In index.ts, orphans had groupId = "ORPHAN_{cis}" and were handled specifically.
    // Logic in index.ts:
    // if (groupId.startsWith("ORPHAN_")) { ... WHERE cis_code = ? } else { ... WHERE group_id = ? }
    // Let's replicate this logic.

    const updateOrphanStmt = this.db.prepare(`
      UPDATE medicament_summary
      SET cluster_id = ?, princeps_de_reference = ?
      WHERE cis_code = ?
    `);

    this.db.transaction(() => {
      for (const [groupId, meta] of clusterMap.entries()) {
        if (groupId.startsWith("ORPHAN_")) {
          const cisCode = groupId.replace("ORPHAN_", "");
          updateOrphanStmt.run(meta.clusterId, meta.princepsLabel, cisCode);
        } else {
          updateSummaryStmt.run(meta.clusterId, meta.princepsLabel, groupId);
        }
      }
    })();

    console.log(`✅ Updated clusters for ${clusterMap.size} groups/orphans`);
  }

  /**
   * Computes the final cluster names using LCP (Longest Common Prefix) on clean princeps names.
   * This ensures the cluster name is cleaner/shorter (e.g. "DOLIPRANE" instead of "DOLIPRANE 1000mg").
   */
  public computeAndStoreClusterPrinceps() {
    console.log("🔍 Computing cluster_princeps via LCP...");

    // Retrieve all clean princeps names per cluster with sort_order
    const princepsNamesQuery = this.db.query<{
      cluster_id: string;
      princeps_name_clean: string;
      sort_order: number;
    }, []>(`
      SELECT DISTINCT
        ms.cluster_id,
        COALESCE(gpc.princeps_name_clean, mnc.nom_clean, s.nom_specialite) as princeps_name_clean,
        COALESCE(gm.sort_order, 0) as sort_order
      FROM medicament_summary ms
      JOIN group_members gm ON ms.group_id = gm.group_id
      JOIN medicaments m ON gm.cip_code = m.cip_code
      JOIN specialites s ON m.cis_code = s.cis_code
      LEFT JOIN group_princeps_clean gpc ON ms.group_id = gpc.group_id AND gm.type = 0
      LEFT JOIN medicament_names_clean mnc ON m.cis_code = mnc.cis_code
      WHERE ms.cluster_id IS NOT NULL
        AND ms.group_id IS NOT NULL
        AND gm.type = 0 -- Only princeps
        AND COALESCE(gpc.princeps_name_clean, mnc.nom_clean, s.nom_specialite) IS NOT NULL
        AND LENGTH(TRIM(COALESCE(gpc.princeps_name_clean, mnc.nom_clean, s.nom_specialite))) > 0
      ORDER BY ms.cluster_id, sort_order DESC, princeps_name_clean
    `).all();

    // Group by cluster
    const clusterPrincepsMap = new Map<string, Array<{ name: string; sortOrder: number }>>();
    for (const row of princepsNamesQuery) {
      if (!clusterPrincepsMap.has(row.cluster_id)) {
        clusterPrincepsMap.set(row.cluster_id, []);
      }
      const existing = clusterPrincepsMap.get(row.cluster_id)!;
      const exists = existing.some(e => e.name === row.princeps_name_clean && e.sortOrder === row.sort_order);
      if (!exists) {
        existing.push({ name: row.princeps_name_clean, sortOrder: row.sort_order });
      }
    }

    const updateClusterNameStmt = this.db.prepare(`
      UPDATE cluster_names
      SET cluster_princeps = ?
      WHERE cluster_id = ?
    `);

    let updatedCount = 0;
    this.db.transaction(() => {
      for (const [clusterId, names] of clusterPrincepsMap.entries()) {
        if (names.length === 0) continue;

        // 1. Sort by sortOrder DESC (primary princeps first)
        names.sort((a, b) => b.sortOrder - a.sortOrder);

        // 2. Identify primary group (highest sortOrder)
        const maxSort = names[0].sortOrder;
        // Keep only names from the primary group for LCP (to avoid mixing distinct princeps brands)
        const primaryNames = names.filter(n => n.sortOrder === maxSort).map(n => n.name);

        // 3. Compute LCP
        let lcpName = "";
        if (primaryNames.length === 1) {
          lcpName = primaryNames[0];
        } else {
          try {
            lcpName = findCommonWordPrefix(primaryNames);
          } catch (e) {
            lcpName = primaryNames[0]; // Fallback
          }
        }

        // 4. Fallback if LCP is too short
        if (!lcpName || lcpName.length < 3) {
          lcpName = primaryNames[0];
        }

        updateClusterNameStmt.run(lcpName, clusterId);
        updatedCount++;
      }
    })();

    console.log(`✅ Updated cluster_princeps for ${updatedCount} clusters`);

    // Final touch: Set cluster_name = cluster_princeps (unified)
    this.db.run(`UPDATE cluster_names SET cluster_name = cluster_princeps WHERE cluster_princeps IS NOT NULL`);
  }

  public computeGroupCanonicalCompositions() {
    console.log("🗳️  Computing canonical group compositions (Majority Vote)...");
    const rawCompositions = this.db.query<{
      group_id: string;
      cis_code: string;
      principe: string;
      dosage: string | null;
      dosage_unit: string | null;
    }, []>(`
        SELECT 
        gm.group_id,
        m.cis_code,
        pa.principe_normalized as principe,
        pa.dosage,
        pa.dosage_unit
        FROM group_members gm
        JOIN medicaments m ON gm.cip_code = m.cip_code
        JOIN principes_actifs pa ON m.cip_code = pa.cip_code
        WHERE gm.group_id IS NOT NULL 
        AND pa.principe_normalized IS NOT NULL
        AND pa.principe_normalized != ''
    `).all();

    const groupVotes = new Map<string, Map<string, number>>();
    const signatureToData = new Map<string, Array<{ p: string; d: string | null }>>();
    const cisCompoBuffer = new Map<string, Array<{ p: string; d: string | null }>>();

    for (const row of rawCompositions) {
      const key = `${row.group_id}|${row.cis_code}`;
      if (!cisCompoBuffer.has(key)) cisCompoBuffer.set(key, []);
      const dosageStr = row.dosage && row.dosage_unit
        ? `${row.dosage} ${row.dosage_unit}`.trim()
        : row.dosage || null;
      cisCompoBuffer.get(key)!.push({ p: row.principe, d: dosageStr });
    }

    for (const [key, ingredients] of cisCompoBuffer.entries()) {
      const groupId = key.split('|')[0];
      ingredients.sort((a, b) => {
        const nameCompare = a.p.localeCompare(b.p);
        if (nameCompare !== 0) return nameCompare;
        return (a.d || '').localeCompare(b.d || '');
      });
      const signature = JSON.stringify(ingredients);
      if (!signatureToData.has(signature)) signatureToData.set(signature, ingredients);
      if (!groupVotes.has(groupId)) groupVotes.set(groupId, new Map());
      const votes = groupVotes.get(groupId)!;
      votes.set(signature, (votes.get(signature) || 0) + 1);
    }

    const updateCompoStmt = this.db.prepare(`UPDATE medicament_summary SET principes_actifs_communs = ? WHERE group_id = ?`);
    this.db.transaction(() => {
      for (const [groupId, votes] of groupVotes.entries()) {
        let bestSignature = "";
        let maxVotes = -1;
        for (const [sig, count] of votes.entries()) {
          if (count > maxVotes) {
            maxVotes = count;
            bestSignature = sig;
          }
        }
        if (bestSignature) {
          const winnerData = signatureToData.get(bestSignature);
          if (winnerData) {
            const displayStrings = winnerData.map((i) => i.d ? `${i.p} ${i.d}`.trim() : i.p);
            updateCompoStmt.run(JSON.stringify(displayStrings), groupId);
          }
        }
      }
    })();
    console.log(`✅ Calculated canonical compositions for ${groupVotes.size} groups`);
  }

  public computeClusterCanonicalCompositions() {
    console.log("🗳️  Harmonizing compositions at CLUSTER level (Substance Only)...");
    const clusterSubstancesQuery = this.db.query<{
      cluster_id: string;
      group_id: string;
      principe: string;
    }, []>(`
        SELECT DISTINCT
          ms.cluster_id,
          ms.group_id,
          pa.principe_normalized as principe
        FROM medicament_summary ms
        JOIN group_members gm ON ms.group_id = gm.group_id
        JOIN medicaments m ON gm.cip_code = m.cip_code
        JOIN principes_actifs pa ON m.cip_code = pa.cip_code
        WHERE ms.cluster_id IS NOT NULL
          AND ms.group_id IS NOT NULL
          AND pa.principe_normalized IS NOT NULL
      `).all();

    const clusterStructure = new Map<string, Map<string, string[]>>();
    for (const row of clusterSubstancesQuery) {
      if (!clusterStructure.has(row.cluster_id)) clusterStructure.set(row.cluster_id, new Map());
      const groups = clusterStructure.get(row.cluster_id)!;
      if (!groups.has(row.group_id)) groups.set(row.group_id, []);
      groups.get(row.group_id)!.push(formatPrinciples(row.principe));
    }

    const clusterCanonicalCompo = new Map<string, string>();
    for (const [clusterId, groups] of clusterStructure.entries()) {
      const voteCounts = new Map<string, number>();
      for (const [_, substances] of groups.entries()) {
        substances.sort((a, b) => a.localeCompare(b));
        const uniqueSubstances = Array.from(new Set(substances));
        const signature = JSON.stringify(uniqueSubstances);
        voteCounts.set(signature, (voteCounts.get(signature) || 0) + 1);
      }
      let winningSignature = "";
      let maxVotes = -1;
      for (const [sig, count] of voteCounts.entries()) {
        if (count > maxVotes) {
          maxVotes = count;
          winningSignature = sig;
        } else if (count === maxVotes) {
          if (sig.length < winningSignature.length) winningSignature = sig;
        }
      }
      if (winningSignature) clusterCanonicalCompo.set(clusterId, winningSignature);
    }

    const updateClusterCompoStmt = this.db.prepare(`UPDATE medicament_summary SET principes_actifs_communs = ? WHERE cluster_id = ?`);
    const updateClusterNameStmt = this.db.prepare(`UPDATE cluster_names SET cluster_name = ? WHERE cluster_id = ?`);

    this.db.transaction(() => {
      for (const [clusterId, compoJson] of clusterCanonicalCompo.entries()) {
        updateClusterCompoStmt.run(compoJson, clusterId);
        try {
          const substances = JSON.parse(compoJson);
          if (Array.isArray(substances) && substances.length > 0) {
            updateClusterNameStmt.run(substances.join(", "), clusterId);
          }
        } catch (e) { /* ignore */ }
      }
    })();
    console.log(`✅ Calculated substance-only compositions for ${clusterCanonicalCompo.size} clusters`);
  }

  public injectSmrAsmr(smrMap: Map<string, { niveau: string; date: string }>, asmrMap: Map<string, { niveau: string; date: string }>) {
    console.log("💉 Injecting SMR and ASMR levels and dates...");
    const updateSmrStmt = this.db.prepare("UPDATE medicament_summary SET smr_niveau = ?, smr_date = ? WHERE cis_code = ?");
    const updateAsmrStmt = this.db.prepare("UPDATE medicament_summary SET asmr_niveau = ?, asmr_date = ? WHERE cis_code = ?");

    this.db.transaction(() => {
      for (const [cis, smr] of smrMap.entries()) updateSmrStmt.run(smr.niveau, smr.date, cis);
      for (const [cis, asmr] of asmrMap.entries()) updateAsmrStmt.run(asmr.niveau, asmr.date, cis);
    })();
    console.log(`✅ Injected SMR levels and dates for ${smrMap.size} CIS`);
    console.log(`✅ Injected ASMR levels and dates for ${asmrMap.size} CIS`);
  }

  public populateClusterIndex() {
    console.log("🏗️  Populating cluster-indexed tables for Cluster-First Architecture...");

    // Fetch cluster metadata + representative substance composition
    const clusterInfo = this.db.query<{
      cluster_id: string;
      cluster_name: string;
      cluster_princeps: string | null;
      secondary_princeps: string | null;
      principes_actifs_communs: string | null;
    }, []>(`
      SELECT 
        cn.cluster_id, 
        cn.cluster_name, 
        cn.cluster_princeps, 
        cn.secondary_princeps,
        ms.principes_actifs_communs
      FROM cluster_names cn
      LEFT JOIN medicament_summary ms 
        ON cn.cluster_id = ms.cluster_id AND ms.is_princeps = 1
      GROUP BY cn.cluster_id
    `).all();

    const clusterDataToInsert = clusterInfo.map(row => {
      const substance = row.cluster_name || '';
      const primaryPrinceps = row.cluster_princeps || '';
      let secondaryPrincepsList: string[] = [];
      if (row.secondary_princeps) {
        try {
          const parsed = JSON.parse(row.secondary_princeps);
          if (Array.isArray(parsed)) secondaryPrincepsList = parsed.map((s: any) => String(s));
        } catch (e) { console.warn(`⚠️  Failed to parse secondary_princeps for cluster ${row.cluster_id}:`, e); }
      }

      const countProductsRow = this.db.query('SELECT COUNT(*) AS count FROM medicament_summary WHERE cluster_id = ?').get(row.cluster_id) as { count: number };

      return {
        cluster_id: row.cluster_id,
        title: substance,
        subtitle: row.cluster_princeps ?? '',
        count_products: countProductsRow?.count ?? 0,
        search_vector: buildSearchVector(
          substance,
          primaryPrinceps,
          secondaryPrincepsList,
          row.principes_actifs_communs ?? undefined
        )
      };
    });

    this.insertClusterData(clusterDataToInsert);

    const medicamentDetailData = this.db.query<{
      cis_code: string;
      cluster_id: string;
      nom_canonique: string;
      is_princeps: number;
    }, []>(`SELECT cis_code, cluster_id, nom_canonique, is_princeps FROM medicament_summary WHERE cluster_id IS NOT NULL`).all();

    this.insertClusterMedicamentDetails(medicamentDetailData.map(row => ({
      cis_code: row.cis_code,
      cluster_id: row.cluster_id,
      nom_complet: row.nom_canonique,
      is_princeps: row.is_princeps === 1
    })));

    console.log(`✅ Populated cluster_index with ${clusterDataToInsert.length} entries`);
    console.log(`✅ Populated medicament_detail with ${medicamentDetailData.length} entries`);
  }

  // Type helper for generic query
  public runQuery<T>(sql: string): T[] {
    return this.db.query(sql).all() as T[];
  }



  // New query methods for Flutter schema
  public getMedicamentSummaries(limit?: number): ReadonlyArray<MedicamentSummary> {
    let sql = `
      SELECT
        cis_code,
        nom_canonique,
        is_princeps,
        group_id,
        member_type,
        principes_actifs_communs,
        princeps_de_reference,
        forme_pharmaceutique,
        voies_administration,
        princeps_brand_name,
        procedure_type,
        titulaire_id,
        conditions_prescription,
        date_amm,
        is_surveillance,
        formatted_dosage,
        atc_code,
        status,
        price_min,
        price_max,
        aggregated_conditions,
        ansm_alert_url,
        is_hospital,
        is_dental,
        is_list1,
        is_list2,
        is_narcotic,
        is_exception,
        is_restricted,
        is_otc,
        smr_niveau,
        smr_date,
        asmr_niveau,
        asmr_date,
        url_notice,
        has_safety_alert,
        representative_cip,
        cluster_id
      FROM medicament_summary
    `;

    if (limit) {
      sql += ` LIMIT ${limit}`;
    }

    const rows = this.db.query<any, []>(sql).all();

    return rows.map(row => ({
      cisCode: row.cis_code,
      nomCanonique: row.nom_canonique,
      isPrinceps: Boolean(row.is_princeps),
      groupId: row.group_id,
      memberType: row.member_type,
      principesActifsCommuns: row.principes_actifs_communs,
      princepsDeReference: row.princeps_de_reference,
      formePharmaceutique: row.forme_pharmaceutique,
      voiesAdministration: row.voies_administration,
      princepsBrandName: row.princeps_brand_name,
      procedureType: row.procedure_type,
      titulaireId: row.titulaire_id,
      conditionsPrescription: row.conditions_prescription,
      dateAmm: row.date_amm,
      isSurveillance: Boolean(row.is_surveillance),
      formattedDosage: row.formatted_dosage,
      atcCode: row.atc_code,
      status: row.status,
      priceMin: row.price_min,
      priceMax: row.price_max,
      aggregatedConditions: row.aggregated_conditions,
      ansmAlertUrl: row.ansm_alert_url,
      isHospitalOnly: Boolean(row.is_hospital),
      isDental: Boolean(row.is_dental),
      isList1: Boolean(row.is_list1),
      isList2: Boolean(row.is_list2),
      isNarcotic: Boolean(row.is_narcotic),
      isException: Boolean(row.is_exception),
      isRestricted: Boolean(row.is_restricted),
      isOtc: Boolean(row.is_otc),
      smrNiveau: row.smr_niveau,
      smrDate: row.smr_date,
      asmrNiveau: row.asmr_niveau,
      asmrDate: row.asmr_date,
      urlNotice: row.url_notice,
      hasSafetyAlert: Boolean(row.has_safety_alert),
      representativeCip: row.representative_cip,
      clusterId: row.cluster_id
    }));
  }

  public getMedicamentSummaryByCis(cisCode: string): MedicamentSummary | null {
    const stmt = this.db.prepare(`
      SELECT
        cis_code,
        nom_canonique,
        is_princeps,
        group_id,
        member_type,
        principes_actifs_communs,
        princeps_de_reference,
        forme_pharmaceutique,
        voies_administration,
        princeps_brand_name,
        procedure_type,
        titulaire_id,
        conditions_prescription,
        date_amm,
        is_surveillance,
        formatted_dosage,
        atc_code,
        status,
        price_min,
        price_max,
        aggregated_conditions,
        ansm_alert_url,
        is_hospital,
        is_dental,
        is_list1,
        is_list2,
        is_narcotic,
        is_exception,
        is_restricted,
        is_otc,
        smr_niveau,
        smr_date,
        asmr_niveau,
        asmr_date,
        url_notice,
        has_safety_alert,
        representative_cip,
        cluster_id
      FROM medicament_summary
      WHERE cis_code = ?
    `);

    const row = stmt.get(cisCode) as any;

    if (!row) return null;

    return {
      cisCode: row.cis_code,
      nomCanonique: row.nom_canonique,
      isPrinceps: Boolean(row.is_princeps),
      groupId: row.group_id,
      memberType: row.member_type,
      principesActifsCommuns: row.principes_actifs_communs,
      princepsDeReference: row.princeps_de_reference,
      formePharmaceutique: row.forme_pharmaceutique,
      voiesAdministration: row.voies_administration,
      princepsBrandName: row.princeps_brand_name,
      procedureType: row.procedure_type,
      titulaireId: row.titulaire_id,
      conditionsPrescription: row.conditions_prescription,
      dateAmm: row.date_amm,
      isSurveillance: Boolean(row.is_surveillance),
      formattedDosage: row.formatted_dosage,
      atcCode: row.atc_code,
      status: row.status,
      priceMin: row.price_min,
      priceMax: row.price_max,
      aggregatedConditions: row.aggregated_conditions,
      ansmAlertUrl: row.ansm_alert_url,
      isHospitalOnly: Boolean(row.is_hospital),
      isDental: Boolean(row.is_dental),
      isList1: Boolean(row.is_list1),
      isList2: Boolean(row.is_list2),
      isNarcotic: Boolean(row.is_narcotic),
      isException: Boolean(row.is_exception),
      isRestricted: Boolean(row.is_restricted),
      isOtc: Boolean(row.is_otc),
      smrNiveau: row.smr_niveau,
      asmrNiveau: row.asmr_niveau,
      urlNotice: row.url_notice,
      hasSafetyAlert: Boolean(row.has_safety_alert),
      representativeCip: row.representative_cip,
      clusterId: row.cluster_id
    };
  }

  public updateMedicamentSummaryClusterId(cisCode: string, clusterId: string): void {
    const stmt = this.db.prepare(`
      UPDATE medicament_summary
      SET cluster_id = ?
      WHERE cis_code = ?
    `);
    stmt.run(clusterId, cisCode);
  }

  public getSpecialites(): ReadonlyArray<Specialite> {
    const rows = this.db.query(`
      SELECT
        cis_code,
        nom_specialite,
        procedure_type,
        statut_administratif,
        forme_pharmaceutique,
        voies_administration,
        etat_commercialisation,
        titulaire_id,
        conditions_prescription,
        date_amm,
        atc_code,
        is_surveillance
      FROM specialites
    `).all();

    return (rows as any[]).map(row => ({
      cisCode: row.cis_code,
      nomSpecialite: row.nom_specialite,
      procedureType: row.procedure_type,
      statutAdministratif: row.statut_administratif,
      formePharmaceutique: row.forme_pharmaceutique,
      voiesAdministration: row.voies_administration,
      etatCommercialisation: row.etat_commercialisation,
      titulaireId: row.titulaire_id,
      conditionsPrescription: row.conditions_prescription,
      dateAmm: row.date_amm,
      atcCode: row.atc_code,
      isSurveillance: Boolean(row.is_surveillance)
    }));
  }

  public optimize() {
    // WAL mode requires checkpoint before vacuum to avoid IOERR on some FS
    this.db.exec("PRAGMA wal_checkpoint(TRUNCATE); VACUUM; ANALYZE;");
  }

  public close() {
    this.db.close();
  }

  // Testing helper: raw query access (read-only usage in tests)
  public rawQuery<T extends Record<string, unknown>>(sql: string): ReadonlyArray<T> {
    return this.db.query<T, []>(sql).all();
  }

  public rebuildSearchIndex() {
    console.log("🔍 Rebuilding FTS Search Index...");

    // Clear existing index
    this.db.run("DELETE FROM search_index");

    // Fetch all summaries
    const rows = this.db.query<{ cis_code: string; nom_canonique: string; princeps_de_reference: string }, []>(
      "SELECT cis_code, nom_canonique, princeps_de_reference FROM medicament_summary"
    ).all();

    console.log(`   Processing ${rows.length} rows for search index...`);

    const stmt = this.db.prepare(`
      INSERT INTO search_index (cis_code, molecule_name, brand_name)
      VALUES (?, ?, ?)
    `);

    // Use transaction for speed
    const transaction = this.db.transaction((items: typeof rows) => {
      for (const row of items) {
        stmt.run(
          row.cis_code,
          normalizeForSearch(row.nom_canonique || ''),
          normalizeForSearch(row.princeps_de_reference || '')
        );
      }
    });

    transaction(rows);
    console.log("✅ FTS Search Index rebuilt successfully");
  }
}
