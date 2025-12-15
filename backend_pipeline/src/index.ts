import fs from "fs";
import path from "path";
import { parse } from "csv-parse";
import iconv from "iconv-lite";
import { ReferenceDatabase } from "./db";
import {
  parseCompositions,
  parseGeneriques,
  parsePrincipesActifs,
  parseAtcCodes,
  parseConditions,
  parseAvailability,
  parseSafetyAlerts,
  parseSafetyAlertsOptimized,
  parseSMR,
  parseASMR,
  type SmrEvaluation,
  type AsmrEvaluation,
} from "./parsing";
import { computeClusters, type ClusteringInput, findCommonWordPrefix, buildSearchVector, generateClusterId } from "./clustering";
import { applyPharmacologicalMask, formatPrinciples, isPureGalenicDescription } from "./sanitizer";
import { extractForms, extractRoutes } from "./normalization";
import type { Specialite, MedicamentAvailability, GeneriqueGroup, GroupMember, PrincipeActif, MedicamentSummary } from "./types";

const DATA_DIR = process.env.DATA_DIR || "./data";
const DB_PATH = process.env.DB_PATH || "./data/reference.db";

// File names matching BDPM conventions
const FILES = {
  CIS: "CIS_bdpm.txt",
  CIS_CIP: "CIS_CIP_bdpm.txt",
  CIS_COMPO: "CIS_COMPO_bdpm.txt",
  CIS_GENER: "CIS_GENER_bdpm.txt",
  CIS_CPD: "CIS_CPD_bdpm.txt",
  CIS_MITM: "CIS_MITM.txt",
  CIS_DISPO: "CIS_CIP_Dispo_Spec.txt",
  CIS_INFO: "CIS_InfoImportante.txt",
  CIS_SMR: "CIS_HAS_SMR_bdpm.txt",
  CIS_ASMR: "CIS_HAS_ASMR_bdpm.txt",
};

async function main() {
  console.log("🚀 Starting PharmaScan Backend Pipeline");
  console.log(`📂 Data Directory: ${DATA_DIR}`);
  console.log(`💾 Database Path: ${DB_PATH}`);

  // Note: BDPM files are expected to be present before running the pipeline.
  // Use `bun run download:bdpm` to fetch them (this is handled via package.json scripts).

  // Supprimer la base de données existante si elle existe (pour garantir une reconstruction complète)
  // Cela évite les problèmes de schéma obsolète et garantit que les vues sont toujours à jour
  if (fs.existsSync(DB_PATH)) {
    console.log("🗑️  Removing existing database...");
    try {
      // Supprimer aussi les fichiers WAL et SHM si présents (doit être fait avant la DB principale)
      const walPath = `${DB_PATH}-wal`;
      const shmPath = `${DB_PATH}-shm`;
      if (fs.existsSync(walPath)) {
        fs.unlinkSync(walPath);
        console.log("   Removed WAL file");
      }
      if (fs.existsSync(shmPath)) {
        fs.unlinkSync(shmPath);
        console.log("   Removed SHM file");
      }
      // Fermer toutes les connexions possibles avant suppression
      fs.unlinkSync(DB_PATH);
      console.log("✅ Existing database removed");
    } catch (error: any) {
      console.warn(`⚠️  Could not remove existing database: ${error.message}`);
      console.warn("   Database might be locked. Continuing anyway...");
    }
  }

  const db = new ReferenceDatabase(DB_PATH);
  // initSchema is called in constructor
  console.log("✅ Database initialized");

  // --- 0. Truncate Tables ---
  console.log("🗑️  Truncating staging tables...");

  // Triggers removed in favor of TS population
  // db.db.run("DROP TRIGGER IF EXISTS search_index_ai");
  // db.db.run("DROP TRIGGER IF EXISTS search_index_au");
  // db.db.run("DROP TRIGGER IF EXISTS search_index_ad");

  db.db.run("DELETE FROM group_members");
  db.db.run("DELETE FROM generique_groups");
  db.db.run("DELETE FROM principes_actifs");
  db.db.run("DELETE FROM medicament_availability");
  db.db.run("DELETE FROM safety_alerts");
  db.db.run("DELETE FROM medicaments");
  db.db.run("DELETE FROM specialites");
  db.db.run("DELETE FROM medicament_summary");
  db.db.run("DELETE FROM search_index");

  console.log("✅ Tables truncated");

  // Disable FK constraints during bulk insert (enables out-of-order ETL)
  db.disableForeignKeys();

  // --- 0b. Pre-load Enrichment Data (ATC & Conditions & SMR) ---
  console.log("📥 Pre-loading enrichment data (ATC & Conditions & SMR)...");

  let atcMap = new Map<string, string>();
  const mitmPath = path.join(DATA_DIR, FILES.CIS_MITM);
  if (fs.existsSync(mitmPath)) {
    atcMap = await parseAtcCodes(streamBdpmFile(mitmPath));
    console.log(`   ✅ Mapped ATC codes for ${atcMap.size} CIS`);
  } else {
    console.warn(`   ⚠️ File not found: ${mitmPath}`);
  }

  let conditionsMap = new Map<string, string>();
  const cpdPath = path.join(DATA_DIR, FILES.CIS_CPD);
  if (fs.existsSync(cpdPath)) {
    conditionsMap = await parseConditions(streamBdpmFile(cpdPath));
    console.log(`   ✅ Mapped conditions for ${conditionsMap.size} CIS`);
  } else {
    console.warn(`   ⚠️ File not found: ${cpdPath}`);
  }

  let smrMap = new Map<string, SmrEvaluation>();
  const smrPath = path.join(DATA_DIR, FILES.CIS_SMR);
  if (fs.existsSync(smrPath)) {
    smrMap = await parseSMR(streamBdpmFile(smrPath));
    console.log(`   ✅ Mapped SMR for ${smrMap.size} CIS`);
  } else {
    console.warn(`   ⚠️ File not found: ${smrPath}`);
  }

  let asmrMap = new Map<string, AsmrEvaluation>();
  const asmrPath = path.join(DATA_DIR, FILES.CIS_ASMR);
  if (fs.existsSync(asmrPath)) {
    asmrMap = await parseASMR(streamBdpmFile(asmrPath));
    console.log(`   ✅ Mapped ASMR for ${asmrMap.size} CIS`);
  } else {
    console.warn(`   ⚠️ File not found: ${asmrPath}`);
  }

  // --- 1. Load & Insert Specialites (CIS) ---
  console.log("📦 Processing Specialites (CIS)...");
  const specialitesPath = path.join(DATA_DIR, FILES.CIS);
  if (fs.existsSync(specialitesPath)) {
    const rows = await readBdpmFile(specialitesPath);

    // 1a. Extract & Insert Laboratories (Titulaires)
    const uniqueTitulaires = new Set<string>();
    rows.forEach(r => {
      const titulaire = r[10]?.trim();
      if (titulaire) uniqueTitulaires.add(titulaire);
    });

    console.log(`🏭 Found ${uniqueTitulaires.size} laboratories`);

    const labStmt = db['db'].prepare("INSERT OR IGNORE INTO laboratories (name) VALUES (?)");
    // Insert without transaction to avoid disk I/O errors blocking everything
    // The OR IGNORE handles duplicates gracefully
    let insertedCount = 0;
    for (const t of uniqueTitulaires) {
      try {
        labStmt.run(t);
        insertedCount++;
      } catch (e: any) {
        // Skip duplicates or other errors (OR IGNORE should handle most cases)
        if (!e.message?.includes('UNIQUE constraint') && !e.message?.includes('disk I/O')) {
          console.warn(`⚠️ Failed to insert laboratory ${t}: ${e.message}`);
        }
      }
    }
    console.log(`✅ Inserted ${insertedCount} laboratories`);

    // 1b. Load Lab Map
    const labRows = db.runQuery<{ id: number, name: string }>("SELECT id, name FROM laboratories");
    const labMap = new Map<string, number>();
    labRows.forEach(l => labMap.set(l.name, l.id));

    // 1c. Insert Specialites WITH ENRICHMENT
    const specialites: Specialite[] = rows.map((row) => {
      const cis = row[0];
      const titulaireName = row[10]?.trim();
      return {
        cisCode: cis,
        nomSpecialite: row[1],
        formePharmaceutique: row[2],
        voiesAdministration: row[3],
        statutAdministratif: row[4],
        procedureType: row[5],
        etatCommercialisation: row[6],
        dateAmm: row[7],
        statutBdm: row[8],
        numeroEuropeen: row[9],
        titulaireId: titulaireName ? (labMap.get(titulaireName) || undefined) : undefined,
        isSurveillance: (row[11]?.trim().toUpperCase() === 'OUI'),
        // ENRICHISSEMENT ICI
        atcCode: atcMap.get(cis) ?? undefined,
        conditionsPrescription: conditionsMap.get(cis) ?? undefined,
      };
    });
    db.insertSpecialites(specialites);
    console.log(`✅ Inserted ${specialites.length} specialites (with ATC & Conditions)`);

    // --- PHASE 2: CONTROLLED VOCABULARY ---
    console.log("📚 extracting Controlled Vocabulary (Forms & Routes)...");

    // 1. Forms
    const formSet = extractForms(specialites);
    const formList = Array.from(formSet).sort().map((label, idx) => ({ id: idx + 1, label }));
    db.insertRefForms(formList);

    // 2. Routes
    const routeSet = extractRoutes(specialites);
    const routeList = Array.from(routeSet).sort().map((label, idx) => ({ id: idx + 1, label }));
    db.insertRefRoutes(routeList);

    // Maps for lookup
    const routeMap = new Map<string, number>();
    routeList.forEach(r => routeMap.set(r.label, r.id));

    // 3. Populate cis_routes
    const cisRoutesInputs: { cis_code: string; route_id: number; is_inferred: number }[] = [];

    for (const s of specialites) {
      if (s.voiesAdministration) {
        const parts = s.voiesAdministration.split(';');
        for (const part of parts) {
          const trimmed = part.trim();
          if (trimmed && routeMap.has(trimmed)) {
            cisRoutesInputs.push({
              cis_code: s.cisCode,
              route_id: routeMap.get(trimmed)!,
              is_inferred: 0
            });
          }
        }
      }
    }

    if (cisRoutesInputs.length > 0) {
      db.insertCisRoutes(cisRoutesInputs);
    }
  } else {
    console.warn(`⚠️ File not found: ${specialitesPath}`);
  }

  // --- 2. Load & Insert Availability/CIPs (CIS_CIP) ---
  console.log("📦 Processing Availability (CIS_CIP)...");
  const availabilityPath = path.join(DATA_DIR, FILES.CIS_CIP);
  // Map CIS -> CIP13s for later stages
  const cisToCip13 = new Map<string, string[]>();
  const cipToCis = new Map<string, string>(); // NEW: CIP -> CIS map for composition linking
  const activeCips = new Set<string>();

  if (fs.existsSync(availabilityPath)) {
    const rows = await readBdpmFile(availabilityPath);
    const availabilities: MedicamentAvailability[] = rows.map((row) => {
      const cis = row[0];
      const cip7 = row[1];
      const libelle = row[2];
      const statut = row[3];
      const etat = row[4];
      const dateComm = row[5];
      const cip13 = row[6];
      // const codeCollectivite = row[7];

      if (cis && cip13) {
        if (!cisToCip13.has(cis)) cisToCip13.set(cis, []);
        cisToCip13.get(cis)!.push(cip13);
        activeCips.add(cip13); // Assuming all in BDPM are "active" in terms of reference
      }

      return {
        codeCip: cip13 || cip7, // Prefer 13
        statut: statut, // Mapped correctly
        dateDebut: undefined, // Not in CIS_CIP
        dateFin: undefined, // Not in CIS_CIP
        lien: undefined, // Not in CIS_CIP
      };
    });

    // Note: The `medicament_availability` table in `db.ts` expects { cip_code, statut, date_debut, date_fin, lien }.
    // CIS_CIP_bdpm.txt provides CIS, CIP, Label, Statut, Etat, Date, CIP13.
    // Ideally we should also populate `medicaments` table here using CIP info, but `db.ts` `insertMedicaments` expects `Medicament` interface.
    // `Medicament` interface: { codeCip, cisCode, presentationLabel, commercialisationStatut... }
    // Let's populate `medicaments` table as it is more critical for linking.

    // Filter out orphaned medicaments (not in specialites)
    const validCisRows = db.runQuery<{ cis_code: string }>("SELECT cis_code FROM specialites");
    const validCisSet = new Set(validCisRows.map(s => s.cis_code));

    // Map to Medicament interface for `medicaments` table
    const medicamentsInput = rows.map(row => {
      const cip = row[6] || row[1];
      const cis = row[0];
      if (cip && cis) cipToCis.set(cip, cis); // Populate map

      return {
        codeCip: cip, // CIP13 or CIP7
        cisCode: cis,
        presentationLabel: row[2],
        commercialisationStatut: row[4], // Etat commercialisation
      };
    })
      .filter(m => m.codeCip && m.cisCode && validCisSet.has(m.cisCode));

    db.insertMedicaments(medicamentsInput);

    // Also insert availability if needed, but `medicaments` covers the basics. 
    // We'll skip `insertMedicamentAvailability` unless we have specific availability data file (CIS_CIP_Dispo_Spec?).
    // The previous error was about `statut` missing in `availabilities` mapping.
    // `availabilities` in my previous code was trying to map to `MedicamentAvailability` but using `CIS_CIP` columns which don't perfectly match.
    // I will comment out explicit availability insert for now as `medicaments` table is what triggered the "Availability" section intention.

    console.log(`✅ Loaded ${medicamentsInput.length} medicament records (CIPs)`);
  } else {
    console.warn(`⚠️ File not found: ${availabilityPath}`);
  }

  // --- 2b. Insert Availability (Shortages) ---
  const dispoPath = path.join(DATA_DIR, FILES.CIS_DISPO);
  if (fs.existsSync(dispoPath)) {
    console.log("⚠️ Processing Stock Shortages...");
    // Note: cisToCip13 is needed to handle CIS-level alerts (when CIP13 is empty)
    const dispoRows = await parseAvailability(streamBdpmFile(dispoPath), activeCips, cisToCip13);
    if (dispoRows.length > 0) {
      db.insertMedicamentAvailability(dispoRows);
      console.log(`✅ Inserted ${dispoRows.length} active shortage records`);
    } else {
      console.log("   No active shortages found");
    }
  } else {
    console.warn(`⚠️ File not found: ${dispoPath}`);
  }

  // --- 3. Parse & Insert Compositions & Principes ---
  console.log("🧪 Processing Compositions (CIS_COMPO)...");
  const compoPath = path.join(DATA_DIR, FILES.CIS_COMPO);

  // Flattened composition map for aggregation
  let compositionMap = new Map<string, string>();

  if (fs.existsSync(compoPath)) {
    // 3.1 Flattened Compositions
    compositionMap = await parseCompositions(streamBdpmFile(compoPath));
    console.log(`✅ Parsed ${compositionMap.size} flattened compositions`);

    // 3.2 Principes Actifs (Normalized)
    // Re-read stream for second pass
    const principes = await parsePrincipesActifs(streamBdpmFile(compoPath), cisToCip13);
    db.insertPrincipesActifs(principes);
    console.log(`✅ Inserted ${principes.length} principes actifs`);

    // --- PHASE 3: SUBSTANCES NORMALIZATION ---
    console.log("🧪 Normalizing Substances...");

    // 1. Extract unique substances
    const substSet = new Set<string>();
    for (const p of principes) {
      if (p.principeNormalized) substSet.add(p.principeNormalized);
    }
    const substList = Array.from(substSet).sort().map((label, idx) => ({ id: idx + 1, label }));
    db.insertRefSubstances(substList);

    // 2. Map Label -> ID
    const substMap = new Map<string, number>();
    substList.forEach(s => substMap.set(s.label, s.id));

    // 3. Create Composition Links (CIS-based)
    // We aggregate unique (CIS, Substance, Dosage) tuples to avoid duplicates from multiple CIPs
    const compoLinkSet = new Set<string>(); // Key: "CIS|SubstID|Dosage"
    const compoLinksParams: { cis_code: string; substance_id: number; dosage: string; nature: string }[] = [];

    for (const p of principes) {
      if (!p.principeNormalized || !p.codeCip) continue;

      const cis = cipToCis.get(p.codeCip);
      const subId = substMap.get(p.principeNormalized);

      if (cis && subId) {
        const dosageStr = (p.dosage && p.dosageUnit)
          ? `${p.dosage} ${p.dosageUnit}`
          : (p.dosage || '');

        const key = `${cis}|${subId}|${dosageStr}`;
        if (!compoLinkSet.has(key)) {
          compoLinkSet.add(key);
          compoLinksParams.push({
            cis_code: cis,
            substance_id: subId,
            dosage: dosageStr,
            nature: 'SA' // Logic to determine SA vs FT? Typically principes_actifs are SA.
          });
        }
      }
    }

    if (compoLinksParams.length > 0) {
      db.insertCompositionLinks(compoLinksParams);
    }
  } else {
    console.warn(`⚠️ File not found: ${compoPath}`);
  }

  // --- 4. Parse & Insert Generiques ---
  console.log("🧬 Processing Generiques (CIS_GENER)...");
  const generPath = path.join(DATA_DIR, FILES.CIS_GENER);
  let generiqueGroups: GeneriqueGroup[] = [];
  let groupMembers: GroupMember[] = [];

  if (fs.existsSync(generPath)) {
    // Need specialites map for relational parsing (CIS -> Nom)
    const specialitesMap = new Map<string, string>();
    const allSpecs = db.runQuery<{ cis_code: string; nom_specialite: string }>("SELECT cis_code, nom_specialite FROM specialites");
    for (const s of allSpecs) specialitesMap.set(s.cis_code, s.nom_specialite);

    // Quick validation: detect CIS referenced in CIS_GENER that are not present
    // in the master `specialites` file. This helps diagnose "orphans" caused
    // by mismatched BDPM file versions or download issues.
    const generCisSet = new Set<string>();
    for await (const row of streamBdpmFile(generPath)) {
      if (row.length >= 3) generCisSet.add(row[2]?.trim());
    }
    const missingInSpecialites = Array.from(generCisSet).filter(c => c && !specialitesMap.has(c));
    if (missingInSpecialites.length > 0) {
      console.warn(`⚠️ Found ${missingInSpecialites.length} CIS referenced in CIS_GENER but missing from CIS_bdpm.txt. Example(s): ${missingInSpecialites.slice(0, 10).join(", ")}`);
      try {
        const outPath = path.join(DATA_DIR, "missing_generique_cis.json");
        fs.writeFileSync(outPath, JSON.stringify({ generated_at: new Date().toISOString(), total_referenced: generCisSet.size, missing_count: missingInSpecialites.length, sample: missingInSpecialites.slice(0, 100) }, null, 2), "utf8");
        console.log(`✅ Wrote ${outPath} with ${Math.min(100, missingInSpecialites.length)} sample CIS`);
      } catch (e) {
        console.warn("⚠️ Failed to write missing_generique_cis.json", e);
      }
    }

    const result = await parseGeneriques(
      streamBdpmFile(generPath),
      cisToCip13,
      activeCips,
      compositionMap,
      specialitesMap
    );
    generiqueGroups = result.groups;
    groupMembers = result.members;

    db.insertGeneriqueGroups(generiqueGroups);
    db.insertGroupMembers(groupMembers);
    console.log(`✅ Inserted ${generiqueGroups.length} groups and ${groupMembers.length} members`);
  } else {
    console.warn(`⚠️ File not found: ${generPath}`);
  }

  // --- 4. Refine Group Metadata (TS + Relational Masking) ---
  console.log("🔧 Refining group metadata with Relational Masking...");

  // 1. Récupérer les infos nécessaires : GroupID + Info du Princeps (Nom & Forme)
  // TRI CRITIQUE : On trie par ordre décroissant de sort_order pour prioriser le princeps le plus récent/primaire
  const groupsToRefine = db.runQuery<{
    group_id: string;
    original_libelle: string;
    princeps_nom: string;
    princeps_forme: string;
  }>(`
    SELECT 
      gg.group_id,
      gg.libelle as original_libelle,
      s.nom_specialite as princeps_nom,
      s.forme_pharmaceutique as princeps_forme
    FROM generique_groups gg
    JOIN (
       SELECT group_id, cip_code 
       FROM group_members 
       WHERE type = 0 
       ORDER BY sort_order DESC, cip_code
    ) sorted_gm ON gg.group_id = sorted_gm.group_id
    JOIN medicaments m ON sorted_gm.cip_code = m.cip_code
    JOIN specialites s ON m.cis_code = s.cis_code
    GROUP BY gg.group_id
    -- SQLite prendra le premier du groupe (donc le max sort_order grâce à la sous-requête)
  `);

  const updateStmt = db['db'].prepare(`
    UPDATE generique_groups 
    SET princeps_label = ? 
    WHERE group_id = ?
  `);

  db['db'].transaction(() => {
    for (const row of groupsToRefine) {
      // C'est ici que la magie opère : Dénomination - Forme = Nom Clean
      const cleanLabel = applyPharmacologicalMask(row.princeps_nom, row.princeps_forme);

      updateStmt.run(cleanLabel, row.group_id);
    }
  })();

  // Mise à jour du molecule_label (inchangée)
  db.db.run(`
    UPDATE generique_groups
    SET molecule_label = COALESCE(
      NULLIF(molecule_label, ''),
      NULLIF(TRIM(libelle), '')
    )
  `);

  console.log(`✅ Refined names for ${groupsToRefine.length} groups using mask logic`);

  // Créer une table unifiée pour stocker tous les noms nettoyés (princeps ET génériques) par CIS
  // Cette table permet d'avoir les noms propres sans polluants pour l'audit et l'affichage
  console.log("🧹 Creating clean medication names table...");
  db.db.run(`
    CREATE TABLE IF NOT EXISTS medicament_names_clean (
      cis_code TEXT NOT NULL,
      nom_clean TEXT NOT NULL,
      PRIMARY KEY (cis_code, nom_clean)
    )
  `);

  // Récupérer tous les noms de médicaments (princeps ET génériques) et appliquer le masque
  const allMedicationNames = db.runQuery<{
    cis_code: string;
    nom_specialite: string;
    forme_pharmaceutique: string;
  }>(`
    SELECT DISTINCT
      s.cis_code,
      s.nom_specialite,
      s.forme_pharmaceutique
    FROM specialites s
    WHERE s.nom_specialite IS NOT NULL
      AND LENGTH(TRIM(s.nom_specialite)) > 0
  `);

  // Nettoyer et insérer tous les noms (princeps et génériques)
  const insertCleanNameStmt = db['db'].prepare(`
    INSERT OR REPLACE INTO medicament_names_clean (cis_code, nom_clean)
    VALUES (?, ?)
  `);

  db['db'].transaction(() => {
    for (const row of allMedicationNames) {
      // Appliquer le masque galénique pour nettoyer le nom
      const cleanName = applyPharmacologicalMask(row.nom_specialite, row.forme_pharmaceutique);
      // Ne garder que les noms significatifs (>= 3 caractères et commencent par une majuscule)
      if (cleanName.length >= 3 && cleanName[0] === cleanName[0].toUpperCase()) {
        insertCleanNameStmt.run(row.cis_code, cleanName);
      }
    }
  })();

  console.log(`✅ Created clean medication names for ${allMedicationNames.length} CIS entries`);

  // Créer également la table group_princeps_clean pour compatibilité avec audit_data.ts
  // (récupère les noms princeps nettoyés par groupe)
  console.log("🧹 Creating group princeps clean table (for compatibility)...");
  db.db.run(`
    CREATE TABLE IF NOT EXISTS group_princeps_clean (
      group_id TEXT NOT NULL,
      princeps_name_clean TEXT NOT NULL,
      PRIMARY KEY (group_id, princeps_name_clean)
    )
  `);

  // Remplir group_princeps_clean depuis medicament_names_clean
  db.db.run(`
    INSERT OR REPLACE INTO group_princeps_clean (group_id, princeps_name_clean)
    SELECT DISTINCT
      gm.group_id,
      mnc.nom_clean
    FROM group_members gm
    JOIN medicaments m ON gm.cip_code = m.cip_code
    JOIN medicament_names_clean mnc ON m.cis_code = mnc.cis_code
    WHERE gm.type = 0 -- Seulement les princeps
  `);

  console.log(`✅ Populated group_princeps_clean from medicament_names_clean`);

  // Créer des vues SQL pour simplifier audit_data.ts (toute la logique dans la DB)
  console.log("📊 Creating SQL views for audit reports...");

  // Vue 1: Clusters avec toutes les données formatées (JSON arrays au lieu de GROUP_CONCAT)
  // Supprimer puis recréer pour que les modifications soient toujours appliquées
  db.db.run(`DROP VIEW IF EXISTS v_clusters_audit`);
  db.db.run(`
    CREATE VIEW v_clusters_audit AS
    SELECT 
      ms.cluster_id,
      cn.cluster_name as unified_name, -- Nom unifié (substance clean)
      cn.cluster_princeps, -- Princeps primaire (pour référence)
      cn.secondary_princeps, -- JSON Array des princeps secondaires
      -- Retourner le JSON brut pour parsing dans le script TypeScript (plus fiable)
      (SELECT principes_actifs_communs 
       FROM medicament_summary ms2 
       WHERE ms2.cluster_id = ms.cluster_id 
         AND ms2.principes_actifs_communs IS NOT NULL
         AND typeof(ms2.principes_actifs_communs) = 'text'
         AND json_valid(ms2.principes_actifs_communs) = 1
       LIMIT 1) as substance_label_json,
      COUNT(*) as cis_count,
      SUM(ms.is_princeps) as princeps_count,
      -- Utiliser GROUP_CONCAT avec séparateur '|' (dédupliquer d'abord dans une sous-requête)
      (SELECT GROUP_CONCAT(value, '|') 
       FROM (SELECT DISTINCT ms2.formatted_dosage as value 
             FROM medicament_summary ms2 
             WHERE ms2.cluster_id = ms.cluster_id AND ms2.formatted_dosage IS NOT NULL)) as dosages_available,
      (SELECT GROUP_CONCAT(value, '|') 
       FROM (SELECT DISTINCT gpc2.princeps_name_clean as value 
             FROM medicament_summary ms2
             JOIN group_princeps_clean gpc2 ON ms2.group_id = gpc2.group_id
             WHERE ms2.cluster_id = ms.cluster_id AND gpc2.princeps_name_clean IS NOT NULL)) as all_princeps_names,
      (SELECT GROUP_CONCAT(value, '|') 
       FROM (SELECT DISTINCT gpc2.princeps_name_clean as value 
             FROM medicament_summary ms2
             JOIN group_princeps_clean gpc2 ON ms2.group_id = gpc2.group_id
             WHERE ms2.cluster_id = ms.cluster_id AND gpc2.princeps_name_clean IS NOT NULL)) as all_brand_names
    FROM medicament_summary ms
    LEFT JOIN cluster_names cn ON ms.cluster_id = cn.cluster_id
    WHERE ms.cluster_id IS NOT NULL
    GROUP BY ms.cluster_id
  `);

  // Vue 2: Groupes génériques avec données formatées
  db.db.run(`DROP VIEW IF EXISTS v_groups_audit`);
  db.db.run(`
    CREATE VIEW v_groups_audit AS
    SELECT 
      gg.group_id,
      gg.libelle as raw_label,
      gg.princeps_label,
      gg.molecule_label,
      gg.parsing_method,
      (
        SELECT DISTINCT cluster_id
        FROM medicament_summary ms_cluster
        WHERE ms_cluster.group_id = gg.group_id
        LIMIT 1
      ) as cluster_id,
      (SELECT COUNT(*) FROM (SELECT DISTINCT gm2.cip_code FROM group_members gm2 WHERE gm2.group_id = gg.group_id)) as member_count,
      (SELECT COUNT(*) FROM (SELECT DISTINCT gm2.cip_code FROM group_members gm2 WHERE gm2.group_id = gg.group_id AND gm2.type = 0)) as princeps_count,
      (SELECT COUNT(*) FROM (SELECT DISTINCT gm2.cip_code FROM group_members gm2 WHERE gm2.group_id = gg.group_id AND gm2.type > 0)) as generic_count,
      (SELECT GROUP_CONCAT(value, '|') 
       FROM (SELECT DISTINCT s2.forme_pharmaceutique as value 
             FROM group_members gm2
             JOIN medicaments m2 ON gm2.cip_code = m2.cip_code
             JOIN specialites s2 ON m2.cis_code = s2.cis_code
             WHERE gm2.group_id = gg.group_id AND s2.forme_pharmaceutique IS NOT NULL)) as forms_available,
      (
        SELECT principes_actifs_communs
        FROM medicament_summary ms2
        WHERE ms2.group_id = gg.group_id
        LIMIT 1
      ) as principes_actifs_communs
    FROM generique_groups gg
    LEFT JOIN group_members gm ON gg.group_id = gm.group_id
    GROUP BY gg.group_id
  `);

  // Vue 3: Échantillons avec principes_actifs_communs déjà parsé en JSON
  // Note: SQLite retourne déjà les JSON comme text, mais on peut utiliser json() pour validation
  // Cette vue inclut tous les champs de medicament_summary via ms.*, notamment :
  // - smr_niveau, smr_date (Service Médical Rendu)
  // - asmr_niveau, asmr_date (Amélioration du Service Médical Rendu)
  // - url_notice (Lien vers PDF Notice officielle)
  // - has_safety_alert (Flag pour présence d'alerte de sécurité active)
  // - Tous les flags de prescription (is_narcotic, is_list1, is_list2, etc.)
  db.db.run(`DROP VIEW IF EXISTS v_samples_audit`);
  db.db.run(`
    CREATE VIEW v_samples_audit AS
    SELECT 
      ms.*,
      -- Valider et parser principes_actifs_communs si c'est une string JSON valide
      CASE 
        WHEN ms.principes_actifs_communs IS NOT NULL 
         AND json_valid(ms.principes_actifs_communs) = 1 
        THEN ms.principes_actifs_communs
        ELSE NULL
      END as principes_actifs_communs_json
    FROM medicament_summary ms
  `);

  console.log(`✅ Created 3 SQL views for audit reports`);

  // --- 5. Compute Clusters (TS) ---
  console.log("🧮 Computing Clusters...");

  // 5a. Calculate common principles for each group via SQL
  const groupsWithCommonPrincipes = db.runQuery<{
    group_id: string;
    common_principes: string;
    princeps_cis_code: string | null;
    princeps_form: string | null;
    has_type_0: number;
  }>(`
    WITH
    group_cip_counts AS (
      SELECT
        gm.group_id,
        COUNT(DISTINCT gm.cip_code) AS total_cips
      FROM group_members gm
      GROUP BY gm.group_id
    ),
    principle_counts_normalized AS (
      SELECT
        gm.group_id,
        pa.principe_normalized,
        COUNT(DISTINCT m.cip_code) AS cip_count
      FROM principes_actifs pa
      INNER JOIN medicaments m ON pa.cip_code = m.cip_code
      INNER JOIN group_members gm ON m.cip_code = gm.cip_code
      WHERE pa.principe_normalized IS NOT NULL AND pa.principe_normalized != ''
      GROUP BY gm.group_id, pa.principe_normalized
    ),
    group_cips_with_principles AS (
      SELECT
        gm.group_id,
        COUNT(DISTINCT m.cip_code) AS cips_with_principles
      FROM principes_actifs pa
      INNER JOIN medicaments m ON pa.cip_code = m.cip_code
      INNER JOIN group_members gm ON m.cip_code = gm.cip_code
      WHERE pa.principe_normalized IS NOT NULL AND pa.principe_normalized != ''
      GROUP BY gm.group_id
    ),
    common_normalized_principles AS (
      SELECT
        pc.group_id,
        GROUP_CONCAT(pc.principe_normalized, ', ') AS common_principes
      FROM principle_counts_normalized pc
      INNER JOIN group_cips_with_principles gcwp ON pc.group_id = gcwp.group_id
      WHERE pc.cip_count = gcwp.cips_with_principles
      GROUP BY pc.group_id
    ),
    princeps_cis AS (
      SELECT
        gm.group_id,
        m.cis_code AS princeps_cis_code,
        s.forme_pharmaceutique AS princeps_forme,
        1 AS is_type_0
      FROM group_members gm
      INNER JOIN medicaments m ON gm.cip_code = m.cip_code
      INNER JOIN specialites s ON m.cis_code = s.cis_code
      WHERE gm.type = 0
      GROUP BY gm.group_id
      LIMIT 1
    )
    SELECT
      gg.group_id,
      COALESCE(cnp.common_principes, '') AS common_principes,
      pc.princeps_cis_code,
      pc.princeps_forme AS princeps_form,
      COALESCE(pc.is_type_0, 0) AS has_type_0
    FROM generique_groups gg
    LEFT JOIN common_normalized_principles cnp ON gg.group_id = cnp.group_id
    LEFT JOIN princeps_cis pc ON gg.group_id = pc.group_id
  `);

  // 5b. Build ClusteringInputs
  const clusteringInputs: ClusteringInput[] = groupsWithCommonPrincipes.map(row => {
    const group = generiqueGroups.find(g => g.groupId === row.group_id);
    return {
      groupId: row.group_id,
      princepsCisCode: row.princeps_cis_code,
      princepsReferenceName: group?.princepsLabel || "Référence inconnue",
      princepsForm: row.princeps_form || null,
      commonPrincipes: row.common_principes || group?.libelle || "",
      isPrincepsGroup: row.has_type_0 === 1
    };
  });

  // 5c. Compute clusters
  const clusterMap = computeClusters(clusteringInputs);
  console.log(`✅ Computed clusters for ${clusterMap.size} groups`);

  // 5d. Update generique_groups with cluster_id (via groupId -> clusterId mapping)
  // Note: cluster_id is stored in medicament_summary, not generique_groups

  // --- 5bis. Compute Canonical Group Composition (Majority Vote) ---
  console.log("🗳️  Computing canonical group compositions (Majority Vote)...");

  // A. Récupérer les ingrédients bruts pour chaque CIS membre d'un groupe
  const rawCompositions = db.runQuery<{
    group_id: string;
    cis_code: string;
    principe: string;
    dosage: string | null;
    dosage_unit: string | null;
  }>(`
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
  `);

  // B. Construire la Map de vote
  // Structure : Map<GroupId, Map<SignatureString, Count>>
  const groupVotes = new Map<string, Map<string, number>>();

  // Map temporaire pour stocker la composition structurée associée à une signature
  // Map<SignatureString, StructuredComposition[]>
  const signatureToData = new Map<string, Array<{ p: string; d: string | null }>>();

  // Regroupement par CIS d'abord
  const cisCompoBuffer = new Map<string, Array<{ p: string; d: string | null }>>();

  for (const row of rawCompositions) {
    // Clé unique par CIS dans le scope du traitement
    const key = `${row.group_id}|${row.cis_code}`;
    if (!cisCompoBuffer.has(key)) {
      cisCompoBuffer.set(key, []);
    }

    const dosageStr = row.dosage && row.dosage_unit
      ? `${row.dosage} ${row.dosage_unit}`.trim()
      : row.dosage || null;

    cisCompoBuffer.get(key)!.push({
      p: row.principe,
      d: dosageStr
    });
  }

  // C. Dépouillement du vote
  for (const [key, ingredients] of cisCompoBuffer.entries()) {
    const groupId = key.split('|')[0];

    // 1. Trier les ingrédients pour garantir l'unicité de la signature
    // (A + B doit être égal à B + A)
    ingredients.sort((a, b) => {
      const nameCompare = a.p.localeCompare(b.p);
      if (nameCompare !== 0) return nameCompare;
      // Si même nom, trier par dosage
      const dA = a.d || '';
      const dB = b.d || '';
      return dA.localeCompare(dB);
    });

    // 2. Créer la signature (JSON string)
    const signature = JSON.stringify(ingredients);

    // 3. Sauvegarder la donnée réelle pour plus tard
    if (!signatureToData.has(signature)) {
      signatureToData.set(signature, ingredients);
    }

    // 4. Voter
    if (!groupVotes.has(groupId)) {
      groupVotes.set(groupId, new Map());
    }
    const votes = groupVotes.get(groupId)!;
    votes.set(signature, (votes.get(signature) || 0) + 1);
  }

  // D. Élection des vainqueurs
  // Map<GroupId, JSONStringForDB>
  const groupCanonicalCompo = new Map<string, string>();

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
      // On récupère l'objet structuré
      const winnerData = signatureToData.get(bestSignature);
      if (winnerData) {
        // On le transforme en format simple pour la DB (Liste de strings formatées)
        const displayStrings = winnerData.map((i) => {
          return i.d ? `${i.p} ${i.d}`.trim() : i.p;
        });

        groupCanonicalCompo.set(groupId, JSON.stringify(displayStrings));
      }
    }
  }

  console.log(`✅ Calculated canonical compositions for ${groupCanonicalCompo.size} groups`);

  // --- 5ter. Load Safety Alerts (BEFORE aggregation so table exists) ---
  console.log("🚨 Processing Safety Alerts (Info Importante)...");
  const safetyAlertsCis = new Set<string>(); // Pour mettre à jour le flag has_safety_alert

  const infoPath = path.join(DATA_DIR, FILES.CIS_INFO);
  if (fs.existsSync(infoPath)) {
    const { alerts, links } = await parseSafetyAlertsOptimized(streamBdpmFile(infoPath));

    if (alerts.length > 0) {
      db.insertSafetyAlerts(alerts.map(a => ({ message: a.message, url: a.url, dateDebut: a.dateDebut, dateFin: a.dateFin })), links);
      for (const link of links) safetyAlertsCis.add(link.cis);
      console.log(`✅ Inserted ${alerts.length} unique safety alerts for ${links.length} medications.`);
    } else {
      console.log("   No active safety alerts found");
    }
  } else {
    console.warn(`⚠️ File not found: ${infoPath}`);
  }

  // --- 6. Aggregate (SQL) ---
  console.log("📊 Aggregating MedicamentSummary...");

  // Build cluster_id map: groupId -> clusterId
  const groupIdToClusterId = new Map<string, string>();
  for (const [groupId, meta] of clusterMap.entries()) {
    groupIdToClusterId.set(groupId, meta.clusterId);
  }

  // Insert grouped medicaments (without cluster_id first, then update)
  db.db.run(`
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
      NULL AS principes_actifs_communs, -- Sera rempli par le vote majoritaire TS (étape 5bis)
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
      -- Calcul dynamique des flags depuis conditions_prescription
      -- Note: "LISTE I" est contenu dans "LISTE II", donc on vérifie d'abord LISTE II, puis LISTE I seul (sans II)
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
      -- Logique OTC : Si pas Liste I, pas Liste II, pas Stupéfiant -> OTC
      CASE WHEN (
          UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE I%' AND 
          UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE II%' AND 
          (UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%STUPÉFIANT%' AND UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%STUPEFIANT%')
      ) THEN 1 ELSE 0 END AS is_otc,
      -- SMR & ASMR & Safety (sera mis à jour après insertion)
      NULL AS smr_niveau,
      NULL AS smr_date,
      NULL AS asmr_niveau,
      NULL AS asmr_date,
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

  // Insert standalone medicaments (without groups)
  db.db.run(`
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
      (
        SELECT json_group_array(
          TRIM(
            pa.principe_normalized || 
            CASE WHEN pa.dosage IS NOT NULL THEN ' ' || pa.dosage ELSE '' END ||
            CASE WHEN pa.dosage_unit IS NOT NULL THEN ' ' || pa.dosage_unit ELSE '' END
          )
        )
        FROM principes_actifs pa
        INNER JOIN medicaments m2 ON pa.cip_code = m2.cip_code
        WHERE m2.cis_code = s.cis_code
          AND pa.principe_normalized IS NOT NULL
          AND pa.principe_normalized != ''
        ORDER BY pa.principe_normalized
      ) AS principes_actifs_communs,
      s.nom_specialite AS princeps_de_reference,
      s.cis_code AS parent_princeps_cis, -- Self reference for standalone princeps
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
      (
        SELECT MIN(m3.prix_public)
        FROM medicaments m3
        WHERE m3.cis_code = s.cis_code
      ) AS price_min,
      (
        SELECT MAX(m4.prix_public)
        FROM medicaments m4
        WHERE m4.cis_code = s.cis_code
      ) AS price_max,
      '[]' AS aggregated_conditions,
      NULL AS ansm_alert_url,
      -- Calcul dynamique des flags depuis conditions_prescription
      -- Note: "LISTE I" est contenu dans "LISTE II", donc on vérifie d'abord LISTE II, puis LISTE I seul (sans II)
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
      -- Logique OTC : Si pas Liste I, pas Liste II, pas Stupéfiant -> OTC
      CASE WHEN (
          UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE I%' AND 
          UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%LISTE II%' AND 
          (UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%STUPÉFIANT%' AND UPPER(COALESCE(s.conditions_prescription, '')) NOT LIKE '%STUPEFIANT%')
      ) THEN 1 ELSE 0 END AS is_otc,
      -- SMR & ASMR & Safety (sera mis à jour après insertion)
      NULL AS smr_niveau,
      NULL AS smr_date,
      NULL AS asmr_niveau,
      NULL AS asmr_date,
      'https://base-donnees-publique.medicaments.gouv.fr/affichageDoc.php?specid=' || s.cis_code || '&typedoc=N' AS url_notice,
      CASE WHEN EXISTS(SELECT 1 FROM cis_safety_links l WHERE l.cis_code = s.cis_code) THEN 1 ELSE 0 END AS has_safety_alert,
      (
        SELECT MIN(m5.cip_code)
        FROM medicaments m5
        WHERE m5.cis_code = s.cis_code
      ) AS representative_cip
    FROM specialites s
    LEFT JOIN ref_forms rf ON s.forme_pharmaceutique = rf.label
    WHERE NOT EXISTS (
      SELECT 1
      FROM group_members gm
      INNER JOIN medicaments m ON gm.cip_code = m.cip_code
      WHERE m.cis_code = s.cis_code
    )
  `);

  const summaryCount = db.runQuery<{ count: number }>("SELECT COUNT(*) AS count FROM medicament_summary")[0];
  console.log(`✅ Inserted ${summaryCount.count} medicament summaries`);

  // Inject canonical compositions into grouped medicaments (Majority Vote)
  console.log("💉 Injecting canonical compositions into Summary...");

  const updateCompoStmt = db['db'].prepare(`
    UPDATE medicament_summary 
    SET principes_actifs_communs = ? 
    WHERE group_id = ?
  `);

  db['db'].transaction(() => {
    for (const [groupId, compoJson] of groupCanonicalCompo.entries()) {
      updateCompoStmt.run(compoJson, groupId);
    }
  })();

  // Cas des médicaments sans groupe (Orphelins)
  // On garde la logique SQL simple pour eux (car pas de "vote" possible, un seul CIS)
  console.log("💉 Computing compositions for standalone CIS...");
  db.db.run(`
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
      AND pa.principe_normalized IS NOT NULL
      AND pa.principe_normalized != ''
      ORDER BY pa.principe_normalized
    )
    WHERE group_id IS NULL
  `);

  // Inject SMR and ASMR levels and dates from pre-loaded maps
  console.log("💉 Injecting SMR and ASMR levels and dates...");
  const updateSmrStmt = db['db'].prepare("UPDATE medicament_summary SET smr_niveau = ?, smr_date = ? WHERE cis_code = ?");
  const updateAsmrStmt = db['db'].prepare("UPDATE medicament_summary SET asmr_niveau = ?, asmr_date = ? WHERE cis_code = ?");

  db['db'].transaction(() => {
    for (const [cis, smr] of smrMap.entries()) {
      updateSmrStmt.run(smr.niveau, smr.date, cis);
    }
    for (const [cis, asmr] of asmrMap.entries()) {
      updateAsmrStmt.run(asmr.niveau, asmr.date, cis);
    }
  })();

  console.log(`✅ Injected SMR levels and dates for ${smrMap.size} CIS`);
  console.log(`✅ Injected ASMR levels and dates for ${asmrMap.size} CIS`);

  // --- 6bis. Harmonisation & Propagation des Données Manquantes ---
  console.log("⚖️  Harmonizing missing data (Propagation by Group Majority)...");

  // 1. Récupérer les données brutes par groupe pour calculer les consensus
  // On ne prend que les colonnes "structurelles" (pas les prix ni les ruptures)
  const groupDataQuery = db.runQuery<{
    group_id: string;
    cis_code: string;
    is_list1: number;
    is_list2: number;
    is_narcotic: number;
    is_hospital: number;
    is_dental: number;
    is_exception: number;
    is_restricted: number;
    atc_code: string | null;
    conditions_prescription: string | null;
  }>(`
    SELECT 
      group_id, cis_code, 
      is_list1, is_list2, is_narcotic, is_hospital, is_dental, is_exception, is_restricted,
      atc_code, conditions_prescription
    FROM medicament_summary
    WHERE group_id IS NOT NULL
  `);

  // 2. Calculer le consensus par groupe
  const groupConsensus = new Map<string, {
    list1: number;
    list2: number;
    narcotic: number;
    hospital: number;
    dental: number;
    exception: number;
    restricted: number;
    atc: string | null;
    conditions: string | null;
  }>();

  // Regroupement temporaire
  const groupsBuffer = new Map<string, Array<typeof groupDataQuery[0]>>();

  for (const row of groupDataQuery) {
    if (!groupsBuffer.has(row.group_id)) groupsBuffer.set(row.group_id, []);
    groupsBuffer.get(row.group_id)!.push(row);
  }

  // Analyse statistique par groupe
  for (const [groupId, members] of groupsBuffer.entries()) {
    const count = members.length;
    if (count === 0) continue;

    // Calcul des moyennes pour les booléens (vote majoritaire > 50%)
    const sumList1 = members.reduce((acc, m) => acc + m.is_list1, 0);
    const sumList2 = members.reduce((acc, m) => acc + m.is_list2, 0);
    const sumNarc = members.reduce((acc, m) => acc + m.is_narcotic, 0);
    const sumHosp = members.reduce((acc, m) => acc + m.is_hospital, 0);
    const sumDental = members.reduce((acc, m) => acc + m.is_dental, 0);
    const sumException = members.reduce((acc, m) => acc + m.is_exception, 0);
    const sumRestricted = members.reduce((acc, m) => acc + m.is_restricted, 0);

    // Pour le texte (ATC et Conditions), on cherche le mode (valeur la plus fréquente non nulle)
    const getMode = (extractor: (m: typeof members[0]) => string | null) => {
      const counts = new Map<string, number>();
      for (const m of members) {
        const val = extractor(m);
        if (val && val.trim().length > 0) {
          counts.set(val, (counts.get(val) || 0) + 1);
        }
      }
      // Trier par fréquence décroissante
      const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]);
      return sorted.length > 0 ? sorted[0][0] : null;
    };

    groupConsensus.set(groupId, {
      // Vote majoritaire pour les drapeaux de sécurité (> 50% = vrai pour tout le groupe)
      // Logique : Si > 50% du groupe a le flag, c'est une propriété de la molécule, donc vrai pour tous
      list1: sumList1 / count > 0.5 ? 1 : 0,
      list2: sumList2 / count > 0.5 ? 1 : 0,
      narcotic: sumNarc / count > 0.5 ? 1 : 0,
      hospital: sumHosp / count > 0.5 ? 1 : 0,
      dental: sumDental / count > 0.5 ? 1 : 0,
      exception: sumException / count > 0.5 ? 1 : 0,
      restricted: sumRestricted / count > 0.5 ? 1 : 0,
      // Mode (valeur la plus fréquente) pour le texte (ATC et Conditions)
      // Utilisé pour remplir les trous avec COALESCE, pas pour forcer
      atc: getMode(m => m.atc_code),
      conditions: getMode(m => m.conditions_prescription)
    });
  }

  // 3. Appliquer la propagation (Batch Update)
  // Stratégie différenciée selon le type de données :
  // - Drapeaux de sécurité (is_list1, is_narcotic, etc.) : FORCE la valeur majoritaire sur TOUS les membres
  //   Car c'est une propriété chimique/légale de la molécule. Si 8 génériques sont Liste I et le 9ème non (erreur ANSM),
  //   il DOIT être considéré comme Liste I. On force donc la valeur majoritaire (> 50%).
  // - Codes texte (atc_code, conditions_prescription) : Ne remplace que les valeurs NULL (COALESCE)
  //   Car un groupe générique partage la même molécule, donc le même code ATC. On remplit seulement les trous.
  const updateHarmonizedStmt = db['db'].prepare(`
    UPDATE medicament_summary
    SET 
      -- Drapeaux de sécurité : FORCE la valeur majoritaire (propriété de la molécule)
      is_list1 = ?,
      is_list2 = ?,
      is_narcotic = ?,
      is_hospital = ?,
      is_dental = ?,
      is_exception = ?,
      is_restricted = ?,
      -- Codes texte : Ne remplace que les valeurs NULL (remplissage des trous)
      atc_code = COALESCE(atc_code, ?),
      conditions_prescription = COALESCE(conditions_prescription, ?)
    WHERE group_id = ?
  `);

  let updatedGroups = 0;
  try {
    db['db'].transaction(() => {
      for (const [groupId, consensus] of groupConsensus.entries()) {
        updateHarmonizedStmt.run(
          consensus.list1,
          consensus.list2,
          consensus.narcotic,
          consensus.hospital,
          consensus.dental,
          consensus.exception,
          consensus.restricted,
          consensus.atc,
          consensus.conditions,
          groupId
        );
        updatedGroups++;
      }
    })();
    console.log(`✅ Harmonized data for ${updatedGroups} generics groups`);
  } catch (err: any) {
    console.error("❌ Error during harmonization:", err);
    // Fallback: insert without transaction if transaction fails
    console.warn(`⚠️ Transaction failed, retrying without transaction: ${err.message}`);
    for (const [groupId, consensus] of groupConsensus.entries()) {
      try {
        updateHarmonizedStmt.run(
          consensus.list1,
          consensus.list2,
          consensus.narcotic,
          consensus.hospital,
          consensus.dental,
          consensus.exception,
          consensus.restricted,
          consensus.atc,
          consensus.conditions,
          groupId
        );
        updatedGroups++;
      } catch (e: any) {
        console.warn(`⚠️ Failed to harmonize group ${groupId}: ${e.message}`);
      }
    }
  }

  console.log(`✅ Propagated majority data across ${updatedGroups} groups`);

  // Recalculer is_otc après harmonisation (car il dépend des autres flags)
  console.log("🔄 Recalculating OTC flags after harmonization...");
  db.db.run(`
    UPDATE medicament_summary
    SET is_otc = CASE WHEN (
        is_list1 = 0 AND 
        is_list2 = 0 AND 
        is_narcotic = 0
    ) THEN 1 ELSE 0 END
    WHERE group_id IS NOT NULL
  `);
  console.log(`✅ Recalculated OTC flags`);

  // Créer une table de mapping cluster_id -> cluster_name pour faciliter les requêtes
  // Cette table stocke le nom du cluster calculé par LCP et le princeps clean
  db.db.run(`
    CREATE TABLE IF NOT EXISTS cluster_names (
      cluster_id TEXT PRIMARY KEY NOT NULL,
      cluster_name TEXT NOT NULL,
      cluster_princeps TEXT,
      substance_code TEXT,
      secondary_princeps TEXT
    )
  `);

  // Ajouter les colonnes si elles n'existent pas (pour les bases existantes)
  try {
    db.db.run(`ALTER TABLE cluster_names ADD COLUMN cluster_princeps TEXT`);
  } catch (e: any) {
    if (!e.message?.includes('duplicate column')) {
      throw e;
    }
  }
  try {
    db.db.run(`ALTER TABLE cluster_names ADD COLUMN secondary_princeps TEXT`);
  } catch (e: any) {
    if (!e.message?.includes('duplicate column')) {
      throw e;
    }
  }

  // Remplir la table avec les noms de clusters calculés
  const clusterNameMap = new Map<string, string>();
  for (const [groupId, meta] of clusterMap.entries()) {
    const clusterId = groupIdToClusterId.get(groupId);
    if (clusterId && !clusterNameMap.has(clusterId)) {
      clusterNameMap.set(clusterId, meta.princepsLabel);
    }
  }

  const insertClusterNameStmt = db['db'].prepare(`
    INSERT OR REPLACE INTO cluster_names (cluster_id, cluster_name, substance_code, cluster_princeps, secondary_princeps)
    VALUES (?, ?, ?, ?, ?)
  `);

  db['db'].transaction(() => {
    for (const [groupId, meta] of clusterMap.entries()) {
      const clusterId = groupIdToClusterId.get(groupId);
      if (clusterId) {
        // Initialement, cluster_name = princepsLabel (sera remplacé par substance clean plus tard)
        // substance_code = substanceCode (pour référence)
        // cluster_princeps sera calculé plus tard via LCP
        // secondary_princeps = tableau JSON des princeps secondaires
        const secondariesJson = meta.secondaryPrinceps && meta.secondaryPrinceps.length > 0
          ? JSON.stringify(meta.secondaryPrinceps)
          : null;
        insertClusterNameStmt.run(clusterId, meta.princepsLabel, meta.substanceCode, null, secondariesJson);
      }
    }
  })();

  // Update cluster_id and cluster princeps name for grouped medicaments (post-insert)
  // Le clusterMap contient le princepsLabel calculé avec LCP
  for (const [groupId, meta] of clusterMap.entries()) {
    const clusterId = groupIdToClusterId.get(groupId);
    if (clusterId) {
      db.db.run(`
        UPDATE medicament_summary
        SET cluster_id = ?, princeps_de_reference = ?
        WHERE group_id = ?
      `, [clusterId, meta.princepsLabel, groupId]);
    }
  }

  // Calculer cluster_princeps via LCP des noms princeps PROPRES pour chaque cluster
  // IMPORTANT : Cette étape doit être APRÈS l'assignation du cluster_id dans medicament_summary
  // CRITIQUE : Utiliser les noms propres (après masque galénique) et pondérer par sort_order
  console.log("🔍 Computing cluster_princeps via LCP (using clean names, weighted by sort_order)...");

  // Récupérer tous les noms princeps PROPRES par cluster avec leur sort_order
  const princepsNamesQuery = db.runQuery<{
    cluster_id: string;
    princeps_name_clean: string;
    sort_order: number;
  }>(`
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
      AND gm.type = 0 -- Seulement les princeps
      AND COALESCE(gpc.princeps_name_clean, mnc.nom_clean, s.nom_specialite) IS NOT NULL
      AND LENGTH(TRIM(COALESCE(gpc.princeps_name_clean, mnc.nom_clean, s.nom_specialite))) > 0
    ORDER BY ms.cluster_id, sort_order DESC, princeps_name_clean
  `);

  // Grouper par cluster_id avec sort_order pour pondération
  const clusterPrincepsMap = new Map<string, Array<{ name: string; sortOrder: number }>>();
  for (const row of princepsNamesQuery) {
    if (!clusterPrincepsMap.has(row.cluster_id)) {
      clusterPrincepsMap.set(row.cluster_id, []);
    }
    const existing = clusterPrincepsMap.get(row.cluster_id)!;
    // Éviter les doublons exacts (même nom + même sort_order)
    const exists = existing.some(e => e.name === row.princeps_name_clean && e.sortOrder === row.sort_order);
    if (!exists) {
      existing.push({ name: row.princeps_name_clean, sortOrder: row.sort_order });
    }
  }

  // Calculer le LCP pour chaque cluster avec vote pondéré + secondaires
  const updateClusterPrincepsStmt = db['db'].prepare(`
    UPDATE cluster_names 
    SET cluster_princeps = ?, secondary_princeps = ?
    WHERE cluster_id = ?
  `);

  db['db'].transaction(() => {
    for (const [clusterId, princepsData] of clusterPrincepsMap.entries()) {
      // Filtrer les formes galéniques pures et les descriptions invalides
      const validPrincepsData = princepsData.filter(({ name }) => {
        // Exclure les formes galéniques pures
        if (isPureGalenicDescription(name)) return false;
        // Exclure les descriptions qui commencent par une minuscule
        if (name.length > 0 && name[0] === name[0].toLowerCase()) return false;
        // Exclure les descriptions trop longues
        if (name.length > 50) return false;
        return true;
      });

      if (validPrincepsData.length > 0) {
        // Extraire les noms propres uniquement pour le LCP
        const validPrincepsNames = validPrincepsData.map(d => d.name);

        // Tentative 1 : LCP sur tous les noms propres
        const commonPrefix = findCommonWordPrefix(validPrincepsNames);

        let clusterPrinceps: string;
        let secondaryPrinceps: string[] = [];

        if (commonPrefix.length >= 3) {
          // Le LCP a trouvé un préfixe significatif (ex: "CONTRAMAL LP" -> "CONTRAMAL")
          clusterPrinceps = commonPrefix;

          // Si il n'y a qu'un seul princeps unique, pas de secondary_princeps
          const uniquePrinceps = new Set(validPrincepsNames);
          if (uniquePrinceps.size === 1) {
            secondaryPrinceps = [];
          } else {
            // Pour les secondaires, on prend les premiers mots uniques qui ne sont pas le préfixe commun
            const firstWords = new Set(validPrincepsData.map(({ name }) => {
              const firstWord = name.trim().split(/\s+/)[0];
              return firstWord || name;
            }));
            secondaryPrinceps = Array.from(firstWords).filter(w => w !== clusterPrinceps);
          }
        } else {
          // Le LCP a échoué (ex: "CONTRAMAL" vs "TOPALGIC")
          // Utiliser la logique de vote PONDÉRÉ par sort_order sur le PREMIER MOT
          // Les princeps avec sort_order élevé (plus récents) ont plus de poids
          const firstWordVotes = new Map<string, number>();

          for (const { name, sortOrder } of validPrincepsData) {
            const firstWord = name.trim().split(/\s+/)[0];
            if (firstWord) {
              // Poids = sort_order + 1 (pour éviter les poids négatifs ou nuls)
              // Plus le sort_order est élevé, plus le vote compte
              const weight = sortOrder + 1;
              firstWordVotes.set(firstWord, (firstWordVotes.get(firstWord) || 0) + weight);
            }
          }

          // Trier par vote pondéré décroissant
          const sortedWords = Array.from(firstWordVotes.entries()).sort((a, b) => {
            const voteCompare = b[1] - a[1];
            if (voteCompare !== 0) return voteCompare;
            // En cas d'égalité parfaite, le plus court gagne (souvent le plus générique)
            return a[0].length - b[0].length;
          });

          // Le vainqueur est le premier mot avec le plus de votes pondérés
          // Cela privilégie les princeps les plus récents (sort_order élevé)
          clusterPrinceps = sortedWords.length > 0 ? sortedWords[0][0] : validPrincepsNames[0];

          // Les secondaires sont tous les autres premiers mots uniques (triés par vote décroissant)
          secondaryPrinceps = sortedWords.slice(1).map(e => e[0]);
        }

        // Convertir en JSON pour stockage
        const secondariesJson = secondaryPrinceps.length > 0
          ? JSON.stringify(secondaryPrinceps)
          : null;

        updateClusterPrincepsStmt.run(clusterPrinceps, secondariesJson, clusterId);
      }
    }
  })();

  console.log(`✅ Computed cluster_princeps for ${clusterPrincepsMap.size} clusters`);

  // --- 5ter. Compute Canonical CLUSTER Composition (Substance-Only Majority Vote) ---
  // IMPORTANT : Cette étape doit être APRÈS l'assignation du cluster_id
  // Stratégie : Vote uniquement sur les substances (sans dosages) pour créer des clusters conceptuels abstraits
  console.log("🗳️  Harmonizing compositions at CLUSTER level (Substance Only)...");

  // 1. Récupérer les substances normalisées brutes (sans dosages)
  // On récupère : Pour chaque Cluster -> Pour chaque Groupe -> Les Substances qu'il contient
  const clusterSubstancesQuery = db.runQuery<{
    cluster_id: string;
    group_id: string;
    principe: string;
  }>(`
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
  `);

  // 2. Construire les signatures de composition par Groupe
  // Map<ClusterID, Map<GroupID, List<Substances>>>
  const clusterStructure = new Map<string, Map<string, string[]>>();

  for (const row of clusterSubstancesQuery) {
    if (!clusterStructure.has(row.cluster_id)) {
      clusterStructure.set(row.cluster_id, new Map());
    }
    const groups = clusterStructure.get(row.cluster_id)!;

    if (!groups.has(row.group_id)) {
      groups.set(row.group_id, []);
    }

    // Formatage "Title Case" pour un affichage propre dans l'application
    // "PARACETAMOL" devient "Paracétamol"
    const prettyPrincipe = formatPrinciples(row.principe);

    groups.get(row.group_id)!.push(prettyPrincipe);
  }

  // 3. Voter : Un Groupe = Une Voix
  // Map<ClusterID, CanonicalCompositionJSON>
  const clusterCanonicalCompo = new Map<string, string>();

  for (const [clusterId, groups] of clusterStructure.entries()) {
    const voteCounts = new Map<string, number>();

    // Pour chaque groupe du cluster
    for (const [groupId, substances] of groups.entries()) {
      // On trie pour que ["Amox", "Acide"] soit égal à ["Acide", "Amox"]
      substances.sort((a, b) => a.localeCompare(b));

      // Dédupliquer les substances (au cas où un groupe aurait plusieurs CIS avec la même substance)
      const uniqueSubstances = Array.from(new Set(substances));

      // Signature unique de la substance (sans dosage !)
      const signature = JSON.stringify(uniqueSubstances);

      voteCounts.set(signature, (voteCounts.get(signature) || 0) + 1);
    }

    // Dépouillement
    let winningSignature = "";
    let maxVotes = -1;

    for (const [sig, count] of voteCounts.entries()) {
      if (count > maxVotes) {
        maxVotes = count;
        winningSignature = sig;
      }
      // En cas d'égalité (ex: 1 groupe "Paracétamol" vs 1 groupe "Paracétamol + Codeine" mal classé)
      // On privilégie la liste la plus courte (principe de parcimonie / rasoir d'Ockham)
      else if (count === maxVotes) {
        if (sig.length < winningSignature.length) winningSignature = sig;
      }
    }

    if (winningSignature) {
      clusterCanonicalCompo.set(clusterId, winningSignature);
    }
  }

  console.log(`✅ Calculated substance-only compositions for ${clusterCanonicalCompo.size} clusters`);

  // 4. Injection Finale (Mise à jour de la colonne display)
  // ATTENTION : On écrase ce qui a été mis à l'étape 5bis pour les groupes membres d'un cluster.
  // C'est voulu : dans l'Explorer, on veut voir "PARACETAMOL", pas "PARACETAMOL 500 MG".

  console.log("💉 Injecting CLUSTER compositions (Substances Only) into Summary...");

  const updateClusterCompoStmt = db['db'].prepare(`
    UPDATE medicament_summary
    SET principes_actifs_communs = ?
    WHERE cluster_id = ?
  `);

  db['db'].transaction(() => {
    for (const [clusterId, compoJson] of clusterCanonicalCompo.entries()) {
      updateClusterCompoStmt.run(compoJson, clusterId);
    }
  })();

  // 5. Mettre à jour cluster_names avec les substances harmonisées (cluster_name)
  // Le cluster_name devient la substance clean (ex: "Paracétamol"), cluster_princeps reste le princeps (ex: "DOLIPRANE")
  console.log("📝 Updating cluster_names with harmonized substances...");

  const updateClusterNameStmt = db['db'].prepare(`
    UPDATE cluster_names
    SET cluster_name = ?
    WHERE cluster_id = ?
  `);

  let updatedCount = 0;
  db['db'].transaction(() => {
    for (const [clusterId, compoJson] of clusterCanonicalCompo.entries()) {
      try {
        // Parser le JSON array et convertir en chaîne lisible pour cluster_name
        // Ex: ["Pregabaline"] -> "Pregabaline"
        // Ex: ["Ethinylestradiol","Levonorgestrel"] -> "Ethinylestradiol, Levonorgestrel"
        const substances = JSON.parse(compoJson);
        if (Array.isArray(substances) && substances.length > 0) {
          const substanceLabel = substances.join(", ");
          const result = updateClusterNameStmt.run(substanceLabel, clusterId);
          if (result.changes > 0) {
            updatedCount++;
          }
        }
      } catch (e) {
        // Si le parsing échoue, ignorer silencieusement
        console.warn(`⚠️  Failed to parse composition for cluster ${clusterId}:`, e);
      }
    }
  })();

  console.log(`✅ Updated ${updatedCount} cluster_names with harmonized substances (cluster_name)`);

  // --- 5quater. Handle Orphans (Items without cluster_id) ---
  console.log("🦅 Handling Orphans (Single-Item Clusters)...");

  // Fetch orphans (items not in any generic group)
  const orphans = db.runQuery<{ cis_code: string; nom_canonique: string; princeps_de_reference: string }>(
    "SELECT cis_code, nom_canonique, princeps_de_reference FROM medicament_summary WHERE cluster_id IS NULL"
  );

  console.log(`   Found ${orphans.length} orphans`);

  // Group orphans by nom_canonique to reduce cluster count and group same-substance orphans
  const orphanGroups = new Map<string, typeof orphans>();
  for (const o of orphans) {
    const key = o.nom_canonique || "UNKNOWN";
    if (!orphanGroups.has(key)) orphanGroups.set(key, []);
    orphanGroups.get(key)!.push(o);
  }

  const insertOrphanClusterStmt = db['db'].prepare(`
    INSERT OR IGNORE INTO cluster_names (cluster_id, cluster_name, cluster_princeps)
    VALUES (?, ?, ?)
  `);

  const updateOrphanSummaryStmt = db['db'].prepare(`
    UPDATE medicament_summary SET cluster_id = ? WHERE cis_code = ?
  `);

  let orphanClusterCount = 0;
  db['db'].transaction(() => {
    for (const [key, items] of orphanGroups.entries()) {
      // Generate ID based on key (prefix ORPHAN_ to avoid collision with legitimate clusters)
      const clusterId = generateClusterId("ORPHAN_" + key);

      // Create Cluster
      // Name = Prettified Substance (e.g. "Paracétamol")
      const prettyName = formatPrinciples(key);

      // Princeps = First item's princeps reference (or key if null)
      // Ideally we pick the "most princeps-like" label, but for orphans, the first is fine.
      const representative = items[0];
      const princepsLabel = representative.princeps_de_reference || prettyName;

      insertOrphanClusterStmt.run(clusterId, prettyName, princepsLabel);
      orphanClusterCount++;

      // Assign Cluster ID to members
      for (const item of items) {
        updateOrphanSummaryStmt.run(clusterId, item.cis_code);
      }
    }
  })();
  console.log(`✅ Created ${orphanClusterCount} orphan clusters for ${orphans.length} items`);

  // --- CLUSTER-FIRST ARCHITECTURE: Populate cluster_index and medicament_detail tables ---
  console.log("🏗️  Populating cluster-indexed tables for Cluster-First Architecture...");

  // 1. Populate cluster_index table with search vectors
  // Get cluster information to build search vectors
  const clusterInfo = db.runQuery<{
    cluster_id: string;
    cluster_name: string;
    cluster_princeps: string | null;
    secondary_princeps: string | null;
  }>(`
    SELECT
      cluster_id,
      cluster_name,
      cluster_princeps,
      secondary_princeps
    FROM cluster_names
  `);

  // Prepare cluster data for insertion
  const clusterDataToInsert = clusterInfo.map(row => {
    // Extract substance (from cluster_name)
    const substance = row.cluster_name || '';

    // Extract primary princeps
    const primaryPrinceps = row.cluster_princeps || '';

    // Extract secondary princeps as array
    let secondaryPrincepsList: string[] = [];
    if (row.secondary_princeps) {
      try {
        const parsed = JSON.parse(row.secondary_princeps);
        if (Array.isArray(parsed)) {
          secondaryPrincepsList = parsed.map((s: any) => String(s));
        }
      } catch (e) {
        console.warn(`⚠️  Failed to parse secondary_princeps for cluster ${row.cluster_id}:`, e);
      }
    }

    // Build search vector
    const searchVector = buildSearchVector(substance, primaryPrinceps, secondaryPrincepsList);

    // Get count of products in cluster
    const countProductsRow = db.runQuery<{ count: number }>(
      'SELECT COUNT(*) AS count FROM medicament_summary WHERE cluster_id = ?',
      [row.cluster_id]
    )[0];

    return {
      cluster_id: row.cluster_id,
      title: substance,  // Display title (Substance Clean)
      subtitle: row.cluster_princeps ?? '', // Ensure string, never null
      count_products: countProductsRow.count,
      search_vector: searchVector  // The search vector for FTS5
    };
  });

  db.insertClusterData(clusterDataToInsert);

  // 2. Populate medicament_detail table with cluster content
  const medicamentDetailData = db.runQuery<{
    cis_code: string;
    cluster_id: string;
    nom_canonique: string;
    is_princeps: number;
  }>(`
    SELECT
      cis_code,
      cluster_id,
      nom_canonique,
      is_princeps
    FROM medicament_summary
    WHERE cluster_id IS NOT NULL
  `);

  const detailDataToInsert = medicamentDetailData.map(row => ({
    cis_code: row.cis_code,
    cluster_id: row.cluster_id,
    nom_complet: row.nom_canonique,
    is_princeps: row.is_princeps === 1
  }));

  db.insertClusterMedicamentDetails(detailDataToInsert);

  console.log(`✅ Populated cluster_index with ${clusterDataToInsert.length} entries`);
  console.log(`✅ Populated medicament_detail with ${detailDataToInsert.length} entries`);

  // --- 7. Index (FTS5) ---
  console.log("📇 Populating search index...");
  db.populateSearchIndex();
  console.log("✅ Search index populated");

  // --- 8. Populate Product Scan Cache (Denormalized table for Flutter Scanner) ---
  console.log("📦 Populating product scan cache...");
  db.populateProductScanCache();
  console.log("✅ Product scan cache populated");

  // --- 9. Populate UI Materialized Views (Replace Flutter complex views) ---
  console.log("🏗️ Populating UI materialized view tables...");
  db.populateAllUiTables();
  console.log("✅ UI materialized views populated");

  // --- 10. Metadata Injection ---
  console.log("📝 Injecting build metadata...");
  const buildDate = new Date().toISOString();
  db.setMetadata('last_updated', buildDate);
  db.setMetadata('schema_version', '1.0');
  console.log(`✅ Metadata injected: last_updated=${buildDate}, schema_version=1.0`);

  // Re-enable FK constraints and validate (throws if violations found)
  db.enableForeignKeys();

  // Switch to WAL mode for better concurrent access (after all inserts are done)
  console.log("💾 Switching to WAL mode and flushing checkpoint...");
  db.db.exec("PRAGMA journal_mode = WAL;");
  db.db.exec("PRAGMA wal_checkpoint(TRUNCATE);");

  console.log("✨ Pipeline Completed Successfully!");
}

// --- Helpers ---

async function readBdpmFile(filePath: string): Promise<string[][]> {
  const content = await fs.promises.readFile(filePath);
  const decoded = iconv.decode(content, "utf-8"); // UTF-8 (converti depuis Windows-1252 au téléchargement)
  return new Promise((resolve, reject) => {
    parse(decoded, {
      delimiter: "\t",
      relax_quotes: true,
      relax_column_count: true, // Allow inconsistent column counts
      skip_empty_lines: true, // Skip empty lines
      skip_records_with_error: true // Skip records with errors
    }, (err, records) => {
      if (err) reject(err);
      else resolve(records);
    });
  });
}

// Stream version for generators
async function* streamBdpmFile(filePath: string): AsyncIterable<string[]> {
  const stream = fs.createReadStream(filePath)
    .pipe(iconv.decodeStream("utf-8"))
    .pipe(parse({
      delimiter: "\t",
      relax_quotes: true,
      relax_column_count: true, // Allow inconsistent column counts
      skip_empty_lines: true, // Skip empty lines
      skip_records_with_error: true // Skip records with errors
    }));

  for await (const row of stream) {
    // Filter out empty rows or rows with only whitespace
    if (row && row.length > 0 && row.some((cell: string) => cell && cell.trim().length > 0)) {
      yield row;
    }
  }
}

main().catch((err) => {
  console.error("❌ Pipeline Failed:", err);
  process.exit(1);
});
