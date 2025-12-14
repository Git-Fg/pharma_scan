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

export const DEFAULT_DB_PATH = path.join("data", "reference.db");

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
    // Register normalize_text function before creating tables
    // Note: createFunction may not be available in test environment
    // Cast to 'any' to work around bun:sqlite typing limitations
    try {
      const sqliteDb = this.db as any;
      if (typeof sqliteDb.createFunction === 'function') {
        sqliteDb.createFunction(
          'normalize_text',
          1,
          true,
          false,
          (args: any[]) => {
            const source = args.length === 0 ? '' : args[0]?.toString() ?? '';
            if (source.trim().length === 0) return '';
            // Basic normalization for now - will be enhanced with sanitizer
            return this.normalizeTextBasic(source);
          }
        );
      }
    } catch (e) {
      // In test environments, createFunction might not be available
      // We'll handle normalization at the application level instead
      console.warn('Warning: Could not register normalize_text function (likely in test environment)');
    }
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
        cis_code TEXT NOT NULL REFERENCES medicament_summary(cis_code) ON DELETE CASCADE,
        presentation_label TEXT NOT NULL DEFAULT '',
        commercialisation_statut TEXT,
        taux_remboursement TEXT,
        prix_public REAL,
        agrement_collectivites TEXT,
        is_hospital INTEGER NOT NULL DEFAULT 0 CHECK (is_hospital IN (0, 1))
      ) STRICT;
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

    // Ajouter la colonne sort_order si elle n'existe pas (pour les bases existantes)
    try {
      this.db.run(`ALTER TABLE group_members ADD COLUMN sort_order INTEGER DEFAULT 0`);
    } catch (e: any) {
      // La colonne existe déjà, ignorer l'erreur
      if (!e.message?.includes('duplicate column')) {
        throw e;
      }
    }

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

    // Ajouter la colonne secondary_princeps si elle n'existe pas (pour les bases existantes)
    try {
      this.db.run(`ALTER TABLE cluster_names ADD COLUMN secondary_princeps TEXT`);
    } catch (e: any) {
      // La colonne existe déjà, ignorer l'erreur
      if (!e.message?.includes('duplicate column')) {
        throw e;
      }
    }

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
        label TEXT NOT NULL UNIQUE
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

    // Index for fast lookups
    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_product_scan_cache_cis ON product_scan_cache(cis_code);
    `);

    // Ajouter les colonnes SMR/ASMR si elles n'existent pas (pour les bases existantes)
    try {
      this.db.run(`ALTER TABLE medicament_summary ADD COLUMN asmr_niveau TEXT`);
    } catch (e: any) {
      if (!e.message?.includes('duplicate column')) {
        throw e;
      }
    }
    try {
      this.db.run(`ALTER TABLE medicament_summary ADD COLUMN smr_date TEXT`);
    } catch (e: any) {
      if (!e.message?.includes('duplicate column')) {
        throw e;
      }
    }
    try {
      this.db.run(`ALTER TABLE medicament_summary ADD COLUMN asmr_date TEXT`);
    } catch (e: any) {
      if (!e.message?.includes('duplicate column')) {
        throw e;
      }
    }

    // NOTE: App settings are intentionally managed by the Flutter app
    // and are not created by the backend pipeline. The FTS5 virtual
    // table for full-text search follows.
    this.db.run(`
      -- FTS5 virtual table for full-text search with TRIGRAM tokenizer
      -- TRIGRAM enables powerful fuzzy matching (e.g., "dolipprane" finds "doliprane")
      -- This tokenizer breaks text into 3-character chunks for substring/typo tolerance
      -- Requires SQLite 3.34+ (bundled via sqlite3_flutter_libs on mobile)
      CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
        cis_code UNINDEXED,   -- Keep unindexed for joining
        molecule_name,        -- Indexed: "Paracetamol"
        brand_name,           -- Indexed: "Doliprane"
        tokenize='trigram'    -- The magic switch for fuzzy search
      );

      -- FTS triggers for keeping search index in sync
      -- Note: search_index uses molecule_name and brand_name (normalized), not raw columns
      CREATE TRIGGER IF NOT EXISTS search_index_ai AFTER INSERT ON medicament_summary BEGIN
        INSERT INTO search_index(
          cis_code,
          molecule_name,
          brand_name
        ) VALUES (
          new.cis_code,
          normalize_text(COALESCE(new.nom_canonique, '')),
          normalize_text(COALESCE(new.princeps_de_reference, ''))
        );
      END;

      CREATE TRIGGER IF NOT EXISTS search_index_ad AFTER DELETE ON medicament_summary BEGIN
        INSERT INTO search_index(
          search_index,
          cis_code,
          molecule_name,
          brand_name
        ) VALUES (
          'delete',
          old.cis_code,
          normalize_text(COALESCE(old.nom_canonique, '')),
          normalize_text(COALESCE(old.princeps_de_reference, ''))
        );
      END;

      CREATE TRIGGER IF NOT EXISTS search_index_au AFTER UPDATE ON medicament_summary BEGIN
        INSERT INTO search_index(
          search_index,
          cis_code,
          molecule_name,
          brand_name
        ) VALUES (
          'delete',
          old.cis_code,
          normalize_text(COALESCE(old.nom_canonique, '')),
          normalize_text(COALESCE(old.princeps_de_reference, ''))
        );
        INSERT INTO search_index(
          cis_code,
          molecule_name,
          brand_name
        ) VALUES (
          new.cis_code,
          normalize_text(COALESCE(new.nom_canonique, '')),
          normalize_text(COALESCE(new.princeps_de_reference, ''))
        );
      END;

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

    // Vue C : Scanner Check (Vérification immédiate)
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
  }

  // Text normalization for SQLite function using sanitizer
  private normalizeTextBasic(input: string): string {
    return normalizeForSearch(input);
  }

  private prepareInsert<T extends Record<string, SQLQueryBindings | null>>(
    table: string,
    columns: ReadonlyArray<keyof T>
  ) {
    const cols = columns.map(String).join(", ");
    const vals = columns.map(() => "?").join(", ");

    return (rows: ReadonlyArray<T>) => {
      for (const row of rows) {
        const values = columns.map((col) => row[col]) as SQLQueryBindings[];
        const stmt = this.db.prepare(`INSERT OR REPLACE INTO ${table} (${cols}) VALUES (${vals})`);
        stmt.run(...values);
      }
    };
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
    this.prepareInsert<any>("specialites", columns)(transformedRows);
    console.log(`✅ Inserted ${rows.length} specialites`);
  }

  public insertMedicaments(rows: ReadonlyArray<Medicament>) {
    console.log(`📊 Inserting ${rows.length} medicaments...`);

    const transformedRows = rows.map(row => ({
      cip_code: row.codeCip,
      cis_code: row.cisCode,
      presentation_label: row.presentationLabel ?? '',
      commercialisation_statut: row.commercialisationStatut,
      taux_remboursement: row.tauxRemboursement,
      prix_public: row.prixPublic,
      agrement_collectivites: row.agrementCollectivites,
      is_hospital: 0  // Will be computed by trigger based on conditions
    }));

    const columns = Object.keys(transformedRows[0] || {}) as (keyof typeof transformedRows[0])[];
    this.prepareInsert<any>("medicaments", columns)(transformedRows);
    console.log(`✅ Inserted ${rows.length} medicaments`);
  }

  public insertMedicamentAvailability(rows: ReadonlyArray<MedicamentAvailability>) {
    console.log(`📊 Inserting ${rows.length} medicament availability records...`);

    const transformedRows = rows.map(row => ({
      cip_code: row.codeCip,
      statut: row.statut ?? '',
      date_debut: row.dateDebut,
      date_fin: row.dateFin,
      lien: row.lien
    }));

    this.prepareInsert<any>("medicament_availability", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
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

    const indexToDbId = new Map<number, number>();

    this.db.transaction(() => {
      alerts.forEach((alert, idx) => {
        insertAlert.run({ $title: alert.message, $url: alert.url ?? null, $start: alert.dateDebut ?? null, $end: alert.dateFin ?? null });
        const row = selectAlertId.get({ $title: alert.message, $url: alert.url ?? null, $start: alert.dateDebut ?? null, $end: alert.dateFin ?? null }) as { id: number };
        if (row && row.id) indexToDbId.set(idx, row.id);
      });

      if (links) {
        links.forEach(link => {
          const id = indexToDbId.get(link.alertIndex);
          if (!id) return;
          // Insert link directly; rely on FK constraints when enabled.
          // In tests FK checks are sometimes disabled, so we avoid pre-checking existence.
          insertLink.run({ $cis: link.cis, $id: id });
        });
      }
    })();

    console.log(`✅ Inserted ${indexToDbId.size} safety_alert records and ${links?.length ?? 0} links`);
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

  public insertLaboratories(rows: ReadonlyArray<Laboratory>) {
    console.log(`📊 Inserting ${rows.length} laboratories...`);

    const transformedRows = rows.map(row => ({
      id: row.id,
      name: row.name
    }));

    this.prepareInsert<any>("laboratories", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} laboratories`);
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

  public runQuery<T = any>(sql: string, params: any[] = []): T[] {
    return this.db.query(sql).all(...params) as T[];
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
}
