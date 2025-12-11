import { Database } from "bun:sqlite";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { DEFAULT_DB_PATH } from "../src/db";
import {
  extractBrand,
  isStoppedProduct,
  parseGroupLabel,
  cleanProductLabel,
  type StoppedStatus
} from "../src/logic";

type ExplorerView = {
  clusters: {
    [id: string]: {
      label: string;
      princeps_label: string;
      dosage: string | null;
      has_shortage: boolean;
      princeps_brand: string | null;
      secondary_princeps_brands: string[];
      substance_code: string;
      groups: {
        [id: string]: {
          label: string;
          products: Array<{ cis: string; label: string; is_princeps: boolean }>;
        };
      };
      princeps_products: { cis: string; label: string }[];
      princeps_cis: string[];
    };
  };
  meta: {
    generated_at: string;
    total_clusters: number;
    total_products: number;
  };
};

type Row = StoppedStatus & {
  cluster_id: string;
  cluster_label: string;
  cluster_subtitle: string;
  substance_code: string;
  group_id: string;
  group_label: string;
  cis: string;
  product_label: string;
  is_princeps: number;
};

function main() {
  const dbPath = DEFAULT_DB_PATH;
  const outPath = join("data", "explorer_view.json");

  if (!existsSync(dbPath)) {
    throw new Error(
      `Missing reference database at ${dbPath}. Generate it first (e.g., bun run build:db).`
    );
  }

  // Ensure previous preview is removed to avoid stale data
  mkdirSync(join("data"), { recursive: true });
  rmSync(outPath, { force: true });

  console.log(`?? Opening ${dbPath}...`);
  const db = new Database(dbPath, { readonly: true });

  const query = db.query<Row, []>(`
    SELECT
      c.id AS cluster_id,
      c.label AS cluster_label,
      c.princeps_label AS cluster_subtitle,
      c.substance_code,
      g.id AS group_id,
      g.label AS group_label,
      p.cis,
      p.label AS product_label,
      p.is_princeps,
      p.marketing_status,
      (
        SELECT COUNT(1)
        FROM presentations pr
        WHERE pr.cis = p.cis
          AND (
            lower(COALESCE(pr.availability_status, '')) LIKE '%arr%'
            OR lower(COALESCE(pr.market_status, '')) LIKE '%arr%'
          )
      ) AS stopped_presentations,
      (
        SELECT COUNT(1)
        FROM presentations pr
        WHERE pr.cis = p.cis
          AND (
            lower(COALESCE(pr.availability_status, '')) NOT LIKE '%arr%'
            AND lower(COALESCE(pr.market_status, '')) NOT LIKE '%arr%'
          )
      ) AS active_presentations
    FROM clusters c
    JOIN groups g ON g.cluster_id = c.id
    JOIN products p ON p.group_id = g.id
    WHERE p.cis IS NOT NULL
  `);

  console.log("?? Aggregating data...");

  const result: ExplorerView = {
    clusters: {},
    meta: {
      generated_at: new Date().toISOString(),
      total_clusters: 0,
      total_products: 0
    }
  };

  const rows = query.all();

  const hasShortageByCluster = new Map<string, boolean>();
  const referencesByCluster = new Map<string, Set<string>>();

  for (const row of rows) {
    const isStopped = isStoppedProduct(row);
    if (isStopped) {
      continue;
    }

    if (!result.clusters[row.cluster_id]) {
      const cleanClusterLabel = cleanProductLabel(row.cluster_label) || row.cluster_label;
      const cleanPrincepsLabel = cleanProductLabel(row.cluster_subtitle) || cleanClusterLabel;
      result.clusters[row.cluster_id] = {
        label: cleanClusterLabel,
        princeps_label: cleanPrincepsLabel,
        dosage: extractDosage(row.cluster_label) ?? extractDosage(row.cluster_subtitle),
        has_shortage: false,
        princeps_brand: null,
        secondary_princeps_brands: [],
        substance_code: row.substance_code,
        princeps_products: [],
        princeps_cis: [],
        groups: {}
      };
      result.meta.total_clusters++;
    }

    const cluster = result.clusters[row.cluster_id];
    if (!cluster.groups[row.group_id]) {
      cluster.groups[row.group_id] = {
        label: row.group_label,
        products: []
      };
    }

    if (row.is_princeps) {
      cluster.princeps_products.push({ cis: row.cis, label: row.product_label });
      cluster.princeps_cis.push(row.cis);
    }

    const parsed = parseGroupLabel(row.group_label);
    const reference = parsed.reference?.trim();
    if (reference) {
      if (!referencesByCluster.has(row.cluster_id)) {
        referencesByCluster.set(row.cluster_id, new Set<string>());
      }
      referencesByCluster.get(row.cluster_id)!.add(reference);
    }

    const hasShortage = row.stopped_presentations > 0;
    if (hasShortage) {
      hasShortageByCluster.set(row.cluster_id, true);
      cluster.has_shortage = true;
    }

    cluster.groups[row.group_id].products.push({
      cis: row.cis,
      label: row.product_label,
      is_princeps: Boolean(row.is_princeps)
    });

    result.meta.total_products++;
  }

  // Normalize princeps metadata from collected products
  for (const [clusterId, cluster] of Object.entries(result.clusters)) {
    cluster.has_shortage = cluster.has_shortage || Boolean(hasShortageByCluster.get(clusterId));
    if (cluster.princeps_products.length > 0) {
      const unique = new Map<string, { cis: string; label: string }>();
      for (const p of cluster.princeps_products) {
        if (!unique.has(p.cis)) unique.set(p.cis, p);
      }
      cluster.princeps_products = Array.from(unique.values());
      cluster.princeps_cis = Array.from(unique.keys());
      // Align princeps_label to the first actual princeps product encountered
      cluster.princeps_label = cleanProductLabel(cluster.princeps_products[0].label) || cluster.princeps_products[0].label;
    }

    const primaryCandidate =
      cluster.princeps_products[0]?.label || cluster.princeps_label || cluster.label;
    const cleanedPrimary = cleanProductLabel(primaryCandidate) || primaryCandidate;
    const brandPrimary = extractBrand(cleanedPrimary);
    const brandSecondary = cluster.princeps_products
      .slice(1)
      .map((p) => extractBrand(cleanProductLabel(p.label) || p.label))
      .filter(Boolean)
      .filter((b) => b !== brandPrimary);
    const referenceBrands = Array.from(referencesByCluster.get(clusterId) ?? [])
      .map((ref) => {
        const cleaned = cleanProductLabel(ref) || ref;
        return extractBrand(cleaned) || cleaned;
      })
      .filter(Boolean)
      .filter((b) => b !== brandPrimary);
    const uniqSecondary = Array.from(new Set([...brandSecondary, ...referenceBrands]));
    cluster.princeps_brand = brandPrimary || null;
    cluster.secondary_princeps_brands = uniqSecondary;
  }

  // Order clusters by princeps label (fallback to cluster label)
  const orderedClusters: ExplorerView["clusters"] = {};
  const sortedEntries = Object.entries(result.clusters).sort((a, b) => {
    const labelA = normalizeLabel(a[1]);
    const labelB = normalizeLabel(b[1]);
    return labelA.localeCompare(labelB, "fr", { sensitivity: "base" });
  });
  for (const [id, cluster] of sortedEntries) {
    orderedClusters[id] = cluster;
  }
  result.clusters = orderedClusters;

  console.log(`?? Writing to ${outPath}...`);
  mkdirSync(join("data"), { recursive: true });
  Bun.write(outPath, JSON.stringify(result, null, 2));

  console.log(
    `? Success! Exported ${result.meta.total_clusters} clusters containing ${result.meta.total_products} products.`
  );
}

function normalizeLabel(cluster: ExplorerView["clusters"][string]): string {
  const candidate = cluster.princeps_label || cluster.label || "";
  return (cleanProductLabel(candidate) || candidate).trim();
}

function extractDosage(label: string | null | undefined): string | null {
  if (!label) return null;
  const match = label.match(/\b\d+(?:[.,]\d+)?\s*(?:mg|g|µg|ug|mcg|ml|ui|mui|iu|%)/i);
  return match ? match[0].trim() : null;
}

if (import.meta.main) {
  main();
}
