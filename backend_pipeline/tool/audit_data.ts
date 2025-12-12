import { Database } from "bun:sqlite";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DEFAULT_DB_PATH } from "../src/db";

// Configuration
const OUT_DIR = join("data", "audit");
const DB_PATH = DEFAULT_DB_PATH;

function main() {
  console.log("🕵️  Démarrage de l'audit de données...");

  // 1. Setup
  mkdirSync(OUT_DIR, { recursive: true });
  
  if (!existsSync(DB_PATH)) {
    console.error(`❌ Base de données introuvable : ${DB_PATH}`);
    console.error("   Veuillez d'abord exécuter 'bun run build:db' pour générer la base de données.");
    process.exit(1);
  }

  const db = new Database(DB_PATH, { readonly: true });

  // ---------------------------------------------------------
  // PARTIE 1 : Catalogue des Clusters (Concepts Thérapeutiques)
  // ---------------------------------------------------------
  console.log("📊 Génération du catalogue des clusters...");

  // Utiliser directement la vue SQL qui fait tout le travail
  const clustersQuery = db.query(`
    SELECT * FROM v_clusters_audit
    ORDER BY cis_count DESC
  `);

  // Les données sont déjà formatées dans la vue (JSON arrays, substance_label formaté)
  // Il suffit de parser les JSON arrays en objets JavaScript
  const clusters = clustersQuery.all().map((row: any) => {
    const cleaned: any = { ...row };
    
    // Convertir les chaînes séparées par '|' en tableaux JavaScript
    const parsePipeSeparated = (str: string | null): string[] => {
      if (!str) return [];
      return str.split('|').filter(s => s.length > 0);
    };
    
    cleaned.dosages_available = parsePipeSeparated(cleaned.dosages_available);
    cleaned.all_princeps_names = parsePipeSeparated(cleaned.all_princeps_names);
    cleaned.all_brand_names = parsePipeSeparated(cleaned.all_brand_names);
    
    // Parser substance_label depuis JSON array
    if (cleaned.substance_label_json) {
      try {
        const substances = JSON.parse(cleaned.substance_label_json);
        cleaned.substance_label = Array.isArray(substances) ? substances.join(", ") : cleaned.substance_label_json;
      } catch {
        cleaned.substance_label = cleaned.substance_label_json;
      }
    }
    delete cleaned.substance_label_json;
    
    // Parser secondary_princeps depuis JSON array
    if (cleaned.secondary_princeps) {
      try {
        const secondaries = JSON.parse(cleaned.secondary_princeps);
        cleaned.secondary_princeps = Array.isArray(secondaries) ? secondaries : [];
      } catch {
        cleaned.secondary_princeps = [];
      }
    } else {
      cleaned.secondary_princeps = [];
    }
    
    // Renommer unified_name en cluster_name pour cohérence avec l'ancien format
    // et remplacer cluster_princeps par le nom unifié
    cleaned.cluster_name = cleaned.unified_name || cleaned.cluster_name;
    delete cleaned.unified_name;
    
    return cleaned;
  });
  
  writeFileSync(
    join(OUT_DIR, "1_clusters_catalog.json"), 
    JSON.stringify(clusters, null, 2)
  );
  console.log(`✅ ${clusters.length} clusters exportés dans '1_clusters_catalog.json'`);

  // ---------------------------------------------------------
  // PARTIE 2 : Catalogue des Groupes Génériques
  // ---------------------------------------------------------
  console.log("📋 Génération du catalogue des groupes génériques...");

  // Utiliser directement la vue SQL qui fait tout le travail
  const groupsQuery = db.query(`
    SELECT * FROM v_groups_audit
    ORDER BY member_count DESC, princeps_label
  `);

  // Les données sont déjà formatées dans la vue (JSON arrays)
  const groups = groupsQuery.all().map((row: any) => {
    const cleaned: any = { ...row };
    
    // Convertir les chaînes séparées par '|' en tableaux JavaScript
    const parsePipeSeparated = (str: string | null): string[] => {
      if (!str) return [];
      return str.split('|').filter(s => s.length > 0);
    };
    
    cleaned.forms_available = parsePipeSeparated(cleaned.forms_available);
    
    // Parser principes_actifs_communs si c'est une string JSON
    if (typeof cleaned.principes_actifs_communs === 'string') {
      try {
        const parsed = JSON.parse(cleaned.principes_actifs_communs);
        cleaned.principes_actifs_communs = Array.isArray(parsed) ? Array.from(new Set(parsed)) : parsed;
      } catch {
        // Garder la valeur originale si parsing échoue
      }
    }
    
    return cleaned;
  });
  
  writeFileSync(
    join(OUT_DIR, "2_group_catalog.json"), 
    JSON.stringify(groups, null, 2)
  );
  console.log(`✅ ${groups.length} groupes exportés dans '2_group_catalog.json'`);

  // ---------------------------------------------------------
  // PARTIE 3 : Échantillonnage Stratifié (200 Exemples)
  // ---------------------------------------------------------
  console.log("🧪 Sélection des 200 exemples stratifiés...");

  // On veut 4 catégories de 50 items pour être sûr de tout voir
  const samples: any[] = [];

  // A. Les "Vrais" Princeps (Pour vérifier qu'ils commandent bien le nom du cluster)
  const qPrinceps = db.query(`SELECT * FROM v_samples_audit WHERE is_princeps = 1 LIMIT 50`);
  samples.push(...qPrinceps.all().map((r: any) => ({ ...r, _audit_tag: "STRATE_PRINCEPS" })));

  // B. Les Génériques purs (Pour vérifier qu'ils sont bien attachés au bon cluster)
  const qGenerics = db.query(`SELECT * FROM v_samples_audit WHERE is_princeps = 0 AND group_id IS NOT NULL LIMIT 50`);
  samples.push(...qGenerics.all().map((r: any) => ({ ...r, _audit_tag: "STRATE_GENERIQUE" })));

  // C. Les Cas Complexes (Poly-médication ou noms longs)
  // On cherche des noms avec "/" (souvent des associations)
  const qComplex = db.query(`SELECT * FROM v_samples_audit WHERE nom_canonique LIKE '%/%' LIMIT 50`);
  samples.push(...qComplex.all().map((r: any) => ({ ...r, _audit_tag: "STRATE_COMPLEXE" })));

  // D. Les "Orphelins" (Sans groupe officiel, clusterisés par substance uniquement)
  const qOrphans = db.query(`SELECT * FROM v_samples_audit WHERE group_id IS NULL LIMIT 50`);
  samples.push(...qOrphans.all().map((r: any) => ({ ...r, _audit_tag: "STRATE_ORPHELIN" })));

  // Parser principes_actifs_communs_json si présent (déjà validé dans la vue)
  const cleanSamples = samples.map((row: any) => {
    if (row.principes_actifs_communs_json) {
      try {
        row.principes_actifs_communs = JSON.parse(row.principes_actifs_communs_json);
      } catch {
        // Ignore parsing errors
      }
    }
    // Supprimer la colonne temporaire
    delete row.principes_actifs_communs_json;
    return row;
  });

  writeFileSync(
    join(OUT_DIR, "3_samples_detailed.json"), 
    JSON.stringify(cleanSamples, null, 2)
  );

  console.log(`✅ ${cleanSamples.length} exemples exportés dans '3_samples_detailed.json'`);
  console.log(`📂 Fichiers disponibles dans : ${OUT_DIR}`);

  // Fermeture de la base de données
  db.close();
}

main();
