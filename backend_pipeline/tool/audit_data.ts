import { Database } from "bun:sqlite";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { DEFAULT_DB_PATH } from "../src/db";

// Configuration
const OUT_DIR = join("output", "audit");
const DB_PATH = DEFAULT_DB_PATH;

function main() {
  console.log("🕵️  Démarrage de l'audit de données...");

  // 1. Setup
  try {
    mkdirSync(OUT_DIR, { recursive: true });
  } catch (e) {
    console.warn("⚠️ Warning creating audit dir:", e);
  }

  if (!existsSync(DB_PATH)) {
    console.error(`❌ Base de données introuvable : ${DB_PATH}`);
    console.error("   Veuillez d'abord exécuter 'bun run build:db' pour générer la base de données.");
    process.exit(1);
  }

  const db = new Database(DB_PATH, { readonly: true });

  try {
    // ---------------------------------------------------------
    // PARTIE 1 : Catalogue des Clusters (Concepts Thérapeutiques)
    // ---------------------------------------------------------
    console.log("📊 Génération du catalogue des clusters...");

    // Check if view exists
    const viewExists = db.query("SELECT name FROM sqlite_master WHERE type='view' AND name='v_clusters_audit'").get();
    if (!viewExists) {
      console.error("❌ La vue 'v_clusters_audit' n'existe pas. Assurez-vous d'avoir reconstruit la BDD.");
      process.exit(1);
    }

    const clustersQuery = db.query(`
      SELECT * FROM v_clusters_audit
      ORDER BY COALESCE(cluster_princeps, unified_name) COLLATE NOCASE ASC
      LIMIT 1000
    `);

    const clusters = clustersQuery.all().map((row: any) => {
      const cleaned: any = { ...row };

      const parsePipeSeparated = (str: string | null): string[] => {
        if (!str) return [];
        return str.split(',').filter(s => s.length > 0);
      };

      cleaned.dosages_available = parsePipeSeparated(cleaned.dosages_available);
      cleaned.all_princeps_names = parsePipeSeparated(cleaned.all_princeps_names);
      cleaned.all_brand_names = parsePipeSeparated(cleaned.all_brand_names);

      // Helper helper
      const safeJsonParse = (jsonString: string | null, defaultValue: any) => {
        if (!jsonString) return defaultValue;
        try {
          return JSON.parse(jsonString);
        } catch (e) {
          return defaultValue;
        }
      }

      // Parser substance_label depuis JSON array (si c'est du JSON)
      // Dans v_clusters_audit: json_group_array(DISTINCT substance_name) -> "['A', 'B']"
      const subs = safeJsonParse(cleaned.substance_label_json, null);
      if (Array.isArray(subs)) {
        cleaned.substance_label = subs.join(" + ");
      } else {
        cleaned.substance_label = cleaned.substance_label_json || cleaned.unified_name;
      }
      delete cleaned.substance_label_json;

      // Parser secondary_princeps
      cleaned.secondary_princeps = safeJsonParse(cleaned.secondary_princeps, []);

      // Renommer unified_name en cluster_name pour cohérence
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

    const groupsQuery = db.query(`
      SELECT * FROM v_groups_audit
      ORDER BY RANDOM()
      LIMIT 200
    `);

    const groups = groupsQuery.all().map((row: any) => {
      const cleaned: any = { ...row };
      const parsePipeSeparated = (str: string | null) => str ? str.split(',').filter(Boolean) : [];

      cleaned.forms_available = parsePipeSeparated(cleaned.forms_available);

      // Parse JSON arrays
      const safeJsonParse = (str: any) => {
        try { return JSON.parse(str); } catch { return []; }
      };

      if (typeof cleaned.principes_actifs_communs === 'string' && (cleaned.principes_actifs_communs.startsWith('[') || cleaned.principes_actifs_communs.startsWith('{'))) {
        cleaned.principes_actifs_communs = safeJsonParse(cleaned.principes_actifs_communs);
      }

      return cleaned;
    });

    writeFileSync(
      join(OUT_DIR, "2_group_catalog.json"),
      JSON.stringify(groups, null, 2)
    );
    console.log(`✅ ${groups.length} groupes exportés dans '2_group_catalog.json'`);

    // ---------------------------------------------------------
    // PARTIE 3 : Échantillonnage Aléatoire
    // ---------------------------------------------------------
    console.log("🧪 Sélection de 200 exemples aléatoires...");

    const qSamples = db.query(`
      SELECT * FROM v_samples_audit 
      ORDER BY RANDOM() 
      LIMIT 200
    `);
    const samples = qSamples.all();

    const cleanSamples = samples.map((row: any) => {
      const r = { ...row };
      if (r.principes_actifs_communs_json) {
        try {
          r.principes_actifs_communs = JSON.parse(r.principes_actifs_communs_json);
        } catch {
          // keep as is
        }
      }
      delete r.principes_actifs_communs_json;

      if (typeof r.has_safety_alert === 'number') {
        r.has_safety_alert = Boolean(r.has_safety_alert);
      }
      return r;
    });

    writeFileSync(
      join(OUT_DIR, "3_samples_detailed.json"),
      JSON.stringify(cleanSamples, null, 2)
    );

    console.log(`✅ ${cleanSamples.length} exemples exportés dans '3_samples_detailed.json'`);
    console.log(`📂 Fichiers disponibles dans : ${OUT_DIR}`);

  } catch (err) {
    console.error("❌ Erreur pendant l'audit:", err);
    process.exit(1);
  } finally {
    // Fermeture de la base de données
    db.close();
  }
}

main();
