import { Database } from "bun:sqlite";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { DEFAULT_DB_PATH } from "../src/db";

// --- Types ---

type SimpleClusterView = {
  id: string;
  substance: string | null; // Derived from common principles or cluster ID
  princeps: {
    main: string | null;
    secondaries: string[];
  };
  groups: string[]; // List of group labels
};

type DbRow = {
  cluster_id: string;
  group_id: string | null;
  group_label: string | null;
  is_princeps: number;
  princeps_brand_name: string | null;
  princeps_de_reference: string | null;
  principes_actifs_communs: string | null;
};

// --- Main ---

function main() {
  const dbPath = DEFAULT_DB_PATH;
  const outPath = join("data", "explorer_view.json");

  if (!existsSync(dbPath)) {
    throw new Error(`Missing DB at ${dbPath}. Run 'bun run build:db' first.`);
  }

  // Prep output
  mkdirSync(join("data"), { recursive: true });
  rmSync(outPath, { force: true });

  console.log(`📂 Opening ${dbPath}...`);
  const db = new Database(dbPath, { readonly: true });

  // 1. Query: Get all items with cluster linkage
  // We want to group by Cluster ID -> Groups -> Princeps Info
  console.log("🔄 Generating simplified cluster view...");

  const query = db.query<DbRow, []>(`
    SELECT
      ms.cluster_id,
      ms.group_id,
      gg.libelle AS group_label,
      ms.is_princeps,
      ms.princeps_brand_name,
      ms.princeps_de_reference,
      ms.principes_actifs_communs
    FROM medicament_summary ms
    LEFT JOIN generique_groups gg ON ms.group_id = gg.group_id
    WHERE ms.cluster_id IS NOT NULL
    ORDER BY ms.cluster_id, ms.group_id
  `);

  const clusters = new Map<string, SimpleClusterView>();
  let totalGroups = 0;

  for (const row of query.all()) {
    if (!row.cluster_id) continue;

    // Init Cluster
    if (!clusters.has(row.cluster_id)) {
      // Parse principes_actifs_communs from JSON string to array, then format as readable string
      let substanceStr: string | null = null;
      if (row.principes_actifs_communs) {
        const raw = String(row.principes_actifs_communs).trim();
        if (raw && raw !== '[]' && raw !== 'null') {
          try {
            // SQLite returns JSON as string, parse it
            const parsed = JSON.parse(raw);
            if (Array.isArray(parsed) && parsed.length > 0) {
              // Join array elements with comma and space for readability
              substanceStr = parsed.join(", ");
            } else if (typeof parsed === 'string' && parsed.length > 0) {
              substanceStr = parsed;
            }
          } catch (e) {
            // If parsing fails, try to extract values manually or use raw
            // Sometimes SQLite might return it differently
            if (raw.startsWith('[') && raw.endsWith(']')) {
              // Try to extract values from JSON-like string
              const matches = raw.match(/"([^"]+)"/g);
              if (matches && matches.length > 0) {
                substanceStr = matches.map(m => m.replace(/"/g, '')).join(", ");
              } else {
                substanceStr = raw;
              }
            } else {
              substanceStr = raw;
            }
          }
        }
      }
      
      clusters.set(row.cluster_id, {
        id: row.cluster_id,
        substance: substanceStr,
        princeps: {
          main: null,
          secondaries: [] // populate if we find multiple
        },
        groups: []
      });
    }

    const cluster = clusters.get(row.cluster_id)!;

    // Capture Princeps Name (Logic: if is_princeps, grab brand name)
    if (row.is_princeps && row.princeps_brand_name) {
      if (!cluster.princeps.main) {
        cluster.princeps.main = row.princeps_brand_name;
      } else if (!cluster.princeps.secondaries.includes(row.princeps_brand_name) && cluster.princeps.main !== row.princeps_brand_name) {
        cluster.princeps.secondaries.push(row.princeps_brand_name);
      }
    }

    // Capture Group Label
    if (row.group_label) {
      if (!cluster.groups.includes(row.group_label)) {
        cluster.groups.push(row.group_label);
        totalGroups++;
      }
    }
  }

  const resultList = Array.from(clusters.values());

  // Sort alphabetically
  resultList.sort((a, b) => {
    const aKey = a.princeps.main || a.substance || a.id;
    const bKey = b.princeps.main || b.substance || b.id;
    // Handle nulls safely
    const strA = aKey || "";
    const strB = bKey || "";
    return strA.localeCompare(strB, 'fr', { sensitivity: 'base' });
  });

  // Transform to JSON output
  const output = {
    meta: {
      generated_at: new Date().toISOString(),
      cluster_count: clusters.size,
      group_count: totalGroups
    },
    clusters: resultList
  };

  console.log(`💾 Writing ${resultList.length} simplified clusters to ${outPath}...`);
  Bun.write(outPath, JSON.stringify(output, null, 2));

  if (resultList.length > 0) {
    console.log("\n--- Sample Output (First Entry) ---");
    console.log(JSON.stringify(resultList[0], null, 2));
    console.log("-----------------------------------\n");
  }

  console.log("✅ Export complete.");
}

if (import.meta.main) {
  main();
}