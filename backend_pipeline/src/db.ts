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
  RestockItem,
  ScannedBox,
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
        is_surveillance BOOLEAN DEFAULT 0,
        conditions_prescription TEXT,
        atc_code TEXT
      );
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS medicaments (
        code_cip TEXT PRIMARY KEY NOT NULL,
        cis_code TEXT NOT NULL REFERENCES specialites(cis_code) ON DELETE CASCADE,
        presentation_label TEXT,
        commercialisation_statut TEXT,
        taux_remboursement TEXT,
        prix_public REAL,
        agrement_collectivites TEXT
      );
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS medicament_availability (
        code_cip TEXT PRIMARY KEY NOT NULL REFERENCES medicaments(code_cip) ON DELETE CASCADE,
        statut TEXT,
        date_debut TEXT,
        date_fin TEXT,
        lien TEXT
      );
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS safety_alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cis_code TEXT NOT NULL REFERENCES specialites(cis_code) ON DELETE CASCADE,
        date_debut TEXT,
        date_fin TEXT,
        texte TEXT
      );
    `);

    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_safety_alerts_cis ON safety_alerts(cis_code);
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS principes_actifs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_cip TEXT,
        principe TEXT NOT NULL,
        principe_normalized TEXT,
        dosage TEXT,
        dosage_unit TEXT
      );
    `);

    this.db.run(`
      CREATE INDEX IF NOT EXISTS idx_principes_cip ON principes_actifs(code_cip);
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS generique_groups (
        group_id TEXT PRIMARY KEY NOT NULL,
        libelle TEXT NOT NULL,
        princeps_label TEXT,
        molecule_label TEXT,
        raw_label TEXT,
        parsing_method TEXT
      );
    `);

    this.db.run(`
      CREATE TABLE IF NOT EXISTS group_members (
        code_cip TEXT NOT NULL REFERENCES medicaments(code_cip) ON DELETE CASCADE,
        group_id TEXT NOT NULL REFERENCES generique_groups(group_id) ON DELETE CASCADE,
        type INTEGER NOT NULL,
        sort_order INTEGER DEFAULT 0,
        PRIMARY KEY (code_cip, group_id)
      );
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
      );
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

    // --- 3. SOURCE DE VÉRITÉ (Medicament Summary) ---
    // Table dénormalisée pour l'accès rapide
    this.db.run(`
      CREATE TABLE IF NOT EXISTS medicament_summary (
        cis_code TEXT PRIMARY KEY NOT NULL,
        -- Identification
        nom_canonique TEXT NOT NULL,
        princeps_de_reference TEXT NOT NULL,
        is_princeps BOOLEAN NOT NULL DEFAULT 0,
        
        -- Clustering & Grouping
        cluster_id TEXT,
        group_id TEXT,
        
        -- Composition & Galénique
        principes_actifs_communs TEXT, -- JSON Array: ["Amoxicilline"]
        formatted_dosage TEXT,
        forme_pharmaceutique TEXT,
        voies_administration TEXT,
        
        -- Métadonnées
        member_type INTEGER NOT NULL DEFAULT 0,
        princeps_brand_name TEXT NOT NULL,
        procedure_type TEXT,
        titulaire_id INTEGER,
        conditions_prescription TEXT,
        date_amm TEXT,
        is_surveillance BOOLEAN NOT NULL DEFAULT 0,
        atc_code TEXT,
        status TEXT,
        price_min REAL,
        price_max REAL,
        aggregated_conditions TEXT,
        ansm_alert_url TEXT,
        
        -- Flags
        is_hospital BOOLEAN NOT NULL DEFAULT 0,
        is_dental BOOLEAN NOT NULL DEFAULT 0,
        is_list1 BOOLEAN NOT NULL DEFAULT 0,
        is_list2 BOOLEAN NOT NULL DEFAULT 0,
        is_narcotic BOOLEAN NOT NULL DEFAULT 0,
        is_exception BOOLEAN NOT NULL DEFAULT 0,
        is_restricted BOOLEAN NOT NULL DEFAULT 0,
        is_otc BOOLEAN NOT NULL DEFAULT 1,
        
        -- SMR & ASMR & Safety
        smr_niveau TEXT,
        smr_date TEXT,
        asmr_niveau TEXT,
        asmr_date TEXT,
        url_notice TEXT,
        has_safety_alert BOOLEAN DEFAULT 0,
        
        representative_cip TEXT,
        
        FOREIGN KEY(titulaire_id) REFERENCES laboratories(id),
        FOREIGN KEY(cluster_id) REFERENCES cluster_names(cluster_id)
      );
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

    // App settings table (from Flutter)
    this.db.run(`
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value BLOB NOT NULL
      );

      -- Restock items table (from Flutter)
      CREATE TABLE IF NOT EXISTS restock_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cis_code TEXT NOT NULL,
        cip_code TEXT NOT NULL,
        nom_canonique TEXT NOT NULL,
        is_princeps INTEGER NOT NULL,
        princeps_de_reference TEXT,
        forme_pharmaceutique TEXT,
        voies_administration TEXT,
        formatted_dosage TEXT,
        representative_cip TEXT,
        expiry_date TEXT,
        stock_count INTEGER NOT NULL DEFAULT 1,
        location TEXT,
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- Scanned boxes table (from Flutter)
      CREATE TABLE IF NOT EXISTS scanned_boxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        box_label TEXT NOT NULL,
        cis_code TEXT,
        cip_code TEXT,
        scan_timestamp TEXT NOT NULL DEFAULT (datetime('now'))
      );

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
      CREATE INDEX IF NOT EXISTS idx_principes_code_cip ON principes_actifs(code_cip);
      CREATE INDEX IF NOT EXISTS idx_principes_normalized_cip ON principes_actifs(principe_normalized, code_cip);
      CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
      CREATE INDEX IF NOT EXISTS idx_group_members_code_cip ON group_members(code_cip);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_group_id ON medicament_summary(group_id);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_forme_pharmaceutique ON medicament_summary(forme_pharmaceutique);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_voies_administration ON medicament_summary(voies_administration);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_procedure_type ON medicament_summary(procedure_type);
      CREATE INDEX IF NOT EXISTS idx_summary_princeps_ref ON medicament_summary(princeps_de_reference);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_principes_actifs_communs ON medicament_summary(principes_actifs_communs);
      CREATE INDEX IF NOT EXISTS idx_medicament_summary_cluster_id ON medicament_summary(cluster_id);
      CREATE INDEX IF NOT EXISTS idx_summary_cluster ON medicament_summary(cluster_id);
      CREATE INDEX IF NOT EXISTS idx_summary_group ON medicament_summary(group_id);
      CREATE INDEX IF NOT EXISTS idx_restock_items_cis_code ON restock_items(cis_code);
      CREATE INDEX IF NOT EXISTS idx_restock_items_expiry_date ON restock_items(expiry_date);
      CREATE INDEX IF NOT EXISTS idx_scanned_boxes_scan_timestamp ON scanned_boxes(scan_timestamp);

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
        COALESCE(ms.representative_cip, (SELECT m.code_cip FROM medicaments m WHERE m.cis_code = ms.cis_code LIMIT 1)) AS default_cip,
        (SELECT m.prix_public FROM medicaments m WHERE m.cis_code = ms.cis_code LIMIT 1) AS prix_public
      FROM medicament_summary ms
      WHERE ms.cluster_id IS NOT NULL;
    `);

    // Vue C : Scanner Check (Vérification immédiate)
    this.db.run(`DROP VIEW IF EXISTS view_scanner_check`);
    this.db.run(`
      CREATE VIEW view_scanner_check AS
      SELECT 
        m.code_cip,
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
      code_cip: row.codeCip,
      cis_code: row.cisCode,
      presentation_label: row.presentationLabel,
      commercialisation_statut: row.commercialisationStatut,
      taux_remboursement: row.tauxRemboursement,
      prix_public: row.prixPublic,
      agrement_collectivites: row.agrementCollectivites
    }));

    const columns = Object.keys(transformedRows[0] || {}) as (keyof typeof transformedRows[0])[];
    this.prepareInsert<any>("medicaments", columns)(transformedRows);
    console.log(`✅ Inserted ${rows.length} medicaments`);
  }

  public insertMedicamentAvailability(rows: ReadonlyArray<MedicamentAvailability>) {
    console.log(`📊 Inserting ${rows.length} medicament availability records...`);

    const transformedRows = rows.map(row => ({
      code_cip: row.codeCip,
      statut: row.statut,
      date_debut: row.dateDebut,
      date_fin: row.dateFin,
      lien: row.lien
    }));

    this.prepareInsert<any>("medicament_availability", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} availability records`);
  }

  public insertSafetyAlerts(rows: ReadonlyArray<SafetyAlert>) {
    console.log(`📊 Inserting ${rows.length} safety alerts...`);

    const transformedRows = rows.map(row => ({
      cis_code: row.cisCode,
      date_debut: row.dateDebut,
      date_fin: row.dateFin,
      texte: row.texte
    }));

    this.prepareInsert<any>("safety_alerts", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} safety alerts`);
  }

  public insertPrincipesActifs(rows: ReadonlyArray<PrincipeActif>) {
    console.log(`📊 Inserting ${rows.length} principes actifs...`);

    const transformedRows = rows.map(row => ({
      id: row.id,
      code_cip: row.codeCip,
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
      code_cip: row.codeCip,
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

  // Additional tables from Flutter app
  public insertAppSettings(rows: ReadonlyArray<{ key: string; value: Uint8Array }>) {
    console.log(`📊 Inserting ${rows.length} app settings...`);

    this.prepareInsert<any>("app_settings", ["key", "value"])(rows);
    console.log(`✅ Inserted ${rows.length} app settings`);
  }

  public insertRestockItems(rows: ReadonlyArray<RestockItem>) {
    console.log(`📊 Inserting ${rows.length} restock items...`);

    const transformedRows = rows.map(row => ({
      id: row.id,
      cis_code: row.cisCode,
      cip_code: row.cipCode,
      nom_canonique: row.nomCanonique,
      is_princeps: row.isPrinceps ? 1 : 0,
      princeps_de_reference: row.princepsDeReference,
      forme_pharmaceutique: row.formePharmaceutique,
      voies_administration: row.voiesAdministration,
      formatted_dosage: row.formattedDosage,
      representative_cip: row.representativeCip,
      expiry_date: row.expiryDate,
      stock_count: row.stockCount,
      location: row.location,
      notes: row.notes,
      created_at: row.createdAt,
      updated_at: row.updatedAt
    }));

    this.prepareInsert<any>("restock_items", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} restock items`);
  }

  public insertScannedBoxes(rows: ReadonlyArray<ScannedBox>) {
    console.log(`📊 Inserting ${rows.length} scanned boxes...`);

    const transformedRows = rows.map(row => ({
      id: row.id,
      box_label: row.boxLabel,
      cis_code: row.cisCode,
      cip_code: row.cipCode,
      scan_timestamp: row.scanTimestamp
    }));

    this.prepareInsert<any>("scanned_boxes", Object.keys(transformedRows[0] || {}) as any)(transformedRows);
    console.log(`✅ Inserted ${rows.length} scanned boxes`);
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
    console.log("📇 Populating search_index from medicament_summary...");

    // Drop triggers first
    this.db.run("DROP TRIGGER IF EXISTS search_index_ai");
    this.db.run("DROP TRIGGER IF EXISTS search_index_au");
    this.db.run("DROP TRIGGER IF EXISTS search_index_ad");

    // Drop and recreate the FTS5 table to avoid rowid issues
    // IMPORTANT: Use trigram tokenizer for fuzzy search support
    this.db.run("DROP TABLE IF EXISTS search_index");
    this.db.run(`
      CREATE VIRTUAL TABLE search_index USING fts5(
        cis_code UNINDEXED,
        molecule_name,
        brand_name,
        tokenize='trigram'
      )
    `);

    // Fetch all summaries and insert with normalized text (using TypeScript normalization)
    const summaries = this.db.query<{
      cis_code: string;
      nom_canonique: string | null;
      princeps_de_reference: string | null;
    }, []>(`
      SELECT cis_code, nom_canonique, princeps_de_reference
      FROM medicament_summary
    `).all();

    const stmt = this.db.prepare(`
      INSERT INTO search_index (cis_code, molecule_name, brand_name)
      VALUES (?, ?, ?)
    `);

    for (const summary of summaries) {
      const moleculeName = normalizeForSearch(summary.nom_canonique || '');
      const brandName = normalizeForSearch(summary.princeps_de_reference || '');
      stmt.run(summary.cis_code, moleculeName, brandName);
    }

    // Recreate triggers for future updates
    this.db.run(`
      CREATE TRIGGER search_index_ai AFTER INSERT ON medicament_summary BEGIN
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

      CREATE TRIGGER search_index_ad AFTER DELETE ON medicament_summary BEGIN
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

      CREATE TRIGGER search_index_au AFTER UPDATE ON medicament_summary BEGIN
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
    `);

    console.log("✅ Search index populated");
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
