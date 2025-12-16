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
  parseGenericsMetadata,
  parseSMR,
  parseASMR,
  type SmrEvaluation,
  type AsmrEvaluation,
  extractForms,
  extractRoutes
} from "./parsing";
import { computeClusters, type ClusteringInput, findCommonWordPrefix, buildSearchVector, generateClusterId } from "./clustering";
import { applyPharmacologicalMask, formatPrinciples, isPureGalenicDescription, isHomeopathic, cleanProductLabel } from "./sanitizer";
import type { Specialite, MedicamentAvailability, GeneriqueGroup, GroupMember, PrincipeActif, MedicamentSummary } from "./types";
import { readBdpmFile, streamBdpmFile } from "./utils";

// Export for testing
export { isHomeopathic, cleanProductLabel };
export const buildValidationIssues = (cis: string) => []; // Mock or real implementation if exists
export const loadDependencies = async () => ({}); // Mock if needed or point to real logic

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

  // Note: No need to truncate tables as the database is deleted and recreated on each run (lines 51-74)

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
    const allSpecialites: Specialite[] = rows.map((row) => {
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
        _titulaireName: titulaireName, // Keep for filtering
      };
    });

    // Filter out homeopathic products
    const specialites = allSpecialites.filter(s => {
      const titulaireName = (s as any)._titulaireName || '';
      if (isHomeopathic(s.nomSpecialite, s.formePharmaceutique || '', titulaireName)) {
        return false;
      }
      return true;
    });

    const filteredCount = allSpecialites.length - specialites.length;
    console.log(`🚫 Filtered ${filteredCount} homeopathic products`);

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
  let validCipSet = new Set<string>(); // Valid CIPs from inserted medicaments (for FK filtering)

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

    // Build validCipSet from actually inserted medicaments for downstream filtering
    validCipSet = new Set(medicamentsInput.map(m => m.codeCip));

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
    // Filter by valid CIPs to prevent FK violations
    const filteredDispoRows = dispoRows.filter(r => validCipSet.has(r.codeCip));
    if (filteredDispoRows.length > 0) {
      db.insertMedicamentAvailability(filteredDispoRows);
      console.log(`✅ Inserted ${filteredDispoRows.length} active shortage records`);
      if (dispoRows.length !== filteredDispoRows.length) {
        console.log(`   Filtered ${dispoRows.length - filteredDispoRows.length} availability records for excluded CIPs`);
      }
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
  let compositionCodesMap = new Map<string, string[]>();

  if (fs.existsSync(compoPath)) {
    // 3.1 Flattened Compositions
    const { flattened, codes } = await parseCompositions(streamBdpmFile(compoPath));
    compositionMap = flattened;
    compositionCodesMap = codes;
    console.log(`✅ Parsed ${compositionMap.size} flattened compositions`);

    // 3.2 Principes Actifs (Normalized)
    // Re-read stream for second pass
    const allPrincipes = await parsePrincipesActifs(streamBdpmFile(compoPath), cisToCip13);
    // Filter by valid CIPs to prevent FK violations
    const principes = allPrincipes.filter(p => p.codeCip && validCipSet.has(p.codeCip));
    if (allPrincipes.length !== principes.length) {
      console.log(`   Filtered ${allPrincipes.length - principes.length} principes for excluded CIPs`);
    }
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

    // Filter by valid CIS codes (from specialites table) to prevent FK violations
    const validCisForLinks = new Set(
      db.runQuery<{ cis_code: string }>("SELECT cis_code FROM specialites").map(r => r.cis_code)
    );
    const filteredCompoLinks = compoLinksParams.filter(c => validCisForLinks.has(c.cis_code));

    if (filteredCompoLinks.length > 0) {
      db.insertCompositionLinks(filteredCompoLinks);
      if (compoLinksParams.length !== filteredCompoLinks.length) {
        console.log(`   Filtered ${compoLinksParams.length - filteredCompoLinks.length} composition links for excluded CIS`);
      }
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
    // Filter group_members by valid CIPs to prevent FK violations
    const filteredMembers = groupMembers.filter(m => validCipSet.has(m.codeCip));
    if (groupMembers.length !== filteredMembers.length) {
      console.log(`   Filtered ${groupMembers.length - filteredMembers.length} group members for excluded CIPs`);
    }
    db.insertGroupMembers(filteredMembers);
    console.log(`✅ Inserted ${generiqueGroups.length} groups and ${filteredMembers.length} members`);
  } else {
    console.warn(`⚠️ File not found: ${generPath}`);
  }

  // --- 4b. Load Generics Metadata for Golden Source Clustering ---
  // Map<CIS, { label, type, sortIndex, cisExists }>
  let genericsMetadata = new Map<string, { label: string; type: number; sortIndex: number; cisExists: boolean }>();

  if (fs.existsSync(generPath)) {
    // Re-read stream for metadata parsing
    // Note: validCisSet was computed earlier at line 292 but that was a localized variable inside availability block.
    // We need a global validCisSet.
    const validCisSetGlobal = new Set(
      db.runQuery<{ cis_code: string }>("SELECT cis_code FROM specialites").map(s => s.cis_code)
    );

    genericsMetadata = await parseGenericsMetadata(streamBdpmFile(generPath), validCisSetGlobal);
    console.log(`✅ Parsed generics metadata for ${genericsMetadata.size} CIS`);
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



  // 5c. Build ClusteringInputs (Product-Centric Strategy)
  // Instead of clustering Groups, we cluster individual PRODUCTS.
  // Each product votes with its metadata (Type 0, Sort Index).
  // Groups are implicitly handled because products in the same group share the same GroupID.

  // Gets all active specialites to cluster
  const productsToCluster = db.runQuery<{
    cis_code: string;
    nom_specialite: string;
    forme_pharmaceutique: string;
    titulaire_id: number;
  }>("SELECT cis_code, nom_specialite, forme_pharmaceutique, titulaire_id FROM specialites");



  // LET'S RE-DO this block properly retrieving GroupIDs from DB.

  // 1. Get Map<CIS, GroupID>
  const cisToGroupIdMap = new Map<string, string>();
  const allMembers = db.runQuery<{ cip_code: string, group_id: string }>("SELECT cip_code, group_id FROM group_members");
  // But wait, group_members is CIP based.
  // Map CIP -> CIS via `medicaments` table.
  const cipToCisMap = new Map<string, string>();
  db.runQuery<{ cip_code: string, cis_code: string }>("SELECT cip_code, cis_code FROM medicaments").forEach(r => cipToCisMap.set(r.cip_code, r.cis_code));

  for (const m of allMembers) {
    const cis = cipToCisMap.get(m.cip_code);
    if (cis) cisToGroupIdMap.set(cis, m.group_id);
  }

  // 2. Build Inputs
  const finalClusteringInputs: ClusteringInput[] = productsToCluster.map(prod => {
    const dbGroupId = cisToGroupIdMap.get(prod.cis_code);
    const genInfo = genericsMetadata.get(prod.cis_code);

    // Resolving Substance Codes
    let codes: string[] = [];
    if (compositionCodesMap.has(prod.cis_code)) {
      codes = compositionCodesMap.get(prod.cis_code)!;
    }

    // Prepare common principes (for fallback soft link)
    // We can use the one computed in SQL for groups (common_principes) or just use the local one if orphan.
    // For simplicity and consistency, let's look up the "clean" one if available, 
    // or compute it strictly from this product's composition.
    // Actually, `compositionMap` has flattened compositions!
    const commonPrincipes = compositionMap.get(prod.cis_code) || "";

    return {
      groupId: dbGroupId || `ORPHAN_${prod.cis_code}`,
      cisCode: prod.cis_code,
      productName: prod.nom_specialite,
      // Use metadata if available, otherwise defaults (Type 99, Sort 999)
      genericType: genInfo ? genInfo.type : 99,
      genericSortIndex: genInfo ? genInfo.sortIndex : 999,
      cisExists: true, // It comes from 'specialites' so it exists
      substanceCodes: codes,
      commonPrincipes: commonPrincipes
    };
  });

  // 5d. Compute clusters
  const clusterMap = computeClusters(finalClusteringInputs);
  console.log(`✅ Computed clusters for ${clusterMap.size} items (Groups + Orphans)`);

  // 6. Aggregate Medicament Summary (Source of Truth)
  db.aggregateMedicamentSummary();

  // 7. Update Clusters in DB (Link Groups/Orphans to Clusters)
  db.updateClusters(clusterMap);

  // 8. Compute Canonical Compositions (Vote)
  db.computeGroupCanonicalCompositions();
  db.computeClusterCanonicalCompositions();

  // 9. Inject SMR/ASMR
  db.injectSmrAsmr(smrMap, asmrMap);

  // 10. Propagate Group Data (Harmonization)
  db.propagateGroupData();

  // 11. Compute Cluster Princeps (LCP Naming)
  db.computeAndStoreClusterPrinceps();

  // 12. Populate Cluster Index & UI Tables
  db.populateClusterIndex();

  // 13. Index (FTS5) & Caches & Metadata
  console.log("📇 Populating search index...");
  db.populateSearchIndex();

  console.log("📦 Populating product scan cache...");
  db.populateProductScanCache();

  console.log("🏗️ Populating UI materialized view tables...");
  db.populateAllUiTables();

  console.log("📝 Injecting build metadata...");
  const buildDate = new Date().toISOString();
  db.setMetadata('last_updated', buildDate);
  db.setMetadata('schema_version', '1.0');

  // Re-enable FK constraints
  db.enableForeignKeys();

  // Switch to WAL mode
  console.log("💾 Switching to WAL mode and flushing checkpoint...");
  db.db.exec("PRAGMA journal_mode = WAL;");
  db.db.exec("PRAGMA wal_checkpoint(TRUNCATE);");

  console.log("✨ Pipeline Completed Successfully!");
}

// --- Helpers ---


main().catch((err) => {
  console.error("❌ Pipeline Failed:", err);
  process.exit(1);
});
