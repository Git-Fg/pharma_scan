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
  // Échantillonnage aléatoire limité à 500 clusters pour revue
  // Order clusters by `cluster_princeps` alphabetically (case-insensitive)
  const clustersQuery = db.query(`
    SELECT * FROM v_clusters_audit
    -- Fallback to unified_name when cluster_princeps is NULL
    ORDER BY COALESCE(cluster_princeps, unified_name) COLLATE NOCASE ASC
    LIMIT 500
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
  // Échantillonnage aléatoire limité à 500 groupes pour revue
  const groupsQuery = db.query(`
    SELECT * FROM v_groups_audit
    ORDER BY RANDOM()
    LIMIT 500
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
  // PARTIE 3 : Échantillonnage Aléatoire (200 Exemples)
  // ---------------------------------------------------------
  console.log("🧪 Sélection de 200 exemples aléatoires...");

  // Échantillonnage aléatoire simple de 200 médicaments
  const qSamples = db.query(`
    SELECT * FROM v_samples_audit 
    ORDER BY RANDOM() 
    LIMIT 100
  `);
  const samples = qSamples.all();

  // Parser principes_actifs_communs_json si présent (déjà validé dans la vue)
  // Les nouveaux champs (smr_niveau, url_notice, has_safety_alert) sont déjà inclus via ms.*
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

    // Normaliser les nouveaux champs pour l'audit
    // smr_niveau, url_notice, has_safety_alert sont déjà présents via ms.*
    // Convertir has_safety_alert en boolean si c'est un nombre (SQLite retourne 0/1)
    if (typeof row.has_safety_alert === 'number') {
      row.has_safety_alert = Boolean(row.has_safety_alert);
    }

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
