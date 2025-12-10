import { Database } from "bun:sqlite";
import { mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";

import type { RegulatoryInfo } from "../src/types";
import { GenericType } from "../src/types";

type ExplorerView = {
  clusters: {
    [id: string]: {
      label: string;
      princeps_label: string;
      substance_code: string;
      stats: {
        product_count: number;
        group_count: number;
        princeps_count: number;
        has_princeps: boolean;
        generic_types: GenericType[];
      };
      princeps_products: { cis: string; label: string }[];
      princeps_cis: string[];
      groups: {
        [id: string]: {
          label: string;
          princeps_cis: string | null;
          products: {
            cis: string;
            label: string;
            is_princeps: boolean;
            generic_type: GenericType;
            type_procedure: string;
            surveillance_renforcee: boolean;
            price: string;
            manufacturer: string | null;
            date_commercialisation: string | null;
            badges: string[];
            composition: string[];
          }[];
        };
      };
    };
  };
  meta: {
    generated_at: string;
    total_clusters: number;
    total_products: number;
    clusters_without_princeps: number;
  };
};

type Row = {
  cluster_id: string;
  cluster_label: string;
  cluster_subtitle: string;
  substance_code: string;
  group_id: string;
  group_label: string;
  cis: string;
  product_label: string;
  is_princeps: number;
  generic_type: number;
  type_procedure: string;
  surveillance_renforcee: number;
  price_cents: number | null;
  regulatory_info: string | null;
  composition: string;
  manufacturer: string | null;
  date_commercialisation: string | null;
};

function main() {
  const dbPath = "reference.db";
  const outPath = join("data", "explorer_view.json");

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
      p.generic_type,
      p.type_procedure,
      p.surveillance_renforcee,
      (
        SELECT MIN(price_cents)
        FROM presentations pr
        WHERE pr.cis = p.cis
      ) AS price_cents,
      (
        SELECT MIN(date_commercialisation)
        FROM presentations pr
        WHERE pr.cis = p.cis
      ) AS date_commercialisation,
      p.regulatory_info,
      p.composition,
      m.label AS manufacturer
    FROM products p
    JOIN groups g ON p.group_id = g.id
    JOIN clusters c ON g.cluster_id = c.id
    LEFT JOIN manufacturers m ON p.manufacturer_id = m.id
    ORDER BY c.label ASC, p.is_princeps DESC, p.label ASC
  `);

  console.log("?? Aggregating data...");

  const result: ExplorerView = {
    clusters: {},
    meta: {
      generated_at: new Date().toISOString(),
      total_clusters: 0,
      total_products: 0,
      clusters_without_princeps: 0
    }
  };

  const rows = query.all();

  for (const row of rows) {
    if (!result.clusters[row.cluster_id]) {
      result.clusters[row.cluster_id] = {
        label: row.cluster_label,
        princeps_label: row.cluster_subtitle,
        substance_code: row.substance_code,
        stats: {
          product_count: 0,
          group_count: 0,
          princeps_count: 0,
          has_princeps: false,
          generic_types: []
        },
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
        princeps_cis: null,
        products: []
      };
      cluster.stats.group_count++;
    }

    if (row.is_princeps) {
      cluster.princeps_products.push({ cis: row.cis, label: row.product_label });
      cluster.princeps_cis.push(row.cis);
      cluster.groups[row.group_id].princeps_cis = row.cis;
    }

    const badges: string[] = [];
    const genericType = normalizeGenericType(row.generic_type);
    if (genericType !== GenericType.PRINCEPS && genericType !== GenericType.UNKNOWN) {
      badges.push(describeGenericType(genericType));
    }
    if (row.regulatory_info) {
      const reg = safeRegulatoryInfo(row.regulatory_info);
      if (reg?.narcotic) badges.push("Stupefiant");
      if (reg?.list1) badges.push("Liste I");
      if (reg?.list2) badges.push("Liste II");
      if (reg?.hospital) badges.push("Hopital");
    }

    cluster.groups[row.group_id].products.push({
      cis: row.cis,
      label: row.product_label,
      is_princeps: Boolean(row.is_princeps),
      generic_type: genericType,
      type_procedure: row.type_procedure,
      surveillance_renforcee: Boolean(row.surveillance_renforcee),
      price: row.price_cents != null ? `${(row.price_cents / 100).toFixed(2)}€` : "N/A",
      manufacturer: row.manufacturer ?? null,
      date_commercialisation: row.date_commercialisation,
      badges,
      composition: safeComposition(row.composition)
    });

    cluster.stats.product_count++;
    cluster.stats.generic_types.push(genericType);

    result.meta.total_products++;
  }

  // Normalize princeps metadata from collected products
  for (const cluster of Object.values(result.clusters)) {
    if (cluster.princeps_products.length > 0) {
      const unique = new Map<string, { cis: string; label: string }>();
      for (const p of cluster.princeps_products) {
        if (!unique.has(p.cis)) unique.set(p.cis, p);
      }
      cluster.princeps_products = Array.from(unique.values());
      cluster.princeps_cis = Array.from(unique.keys());
      // Align princeps_label to the first actual princeps product encountered
      cluster.princeps_label = cluster.princeps_products[0].label;
    }

    const uniqueGenericTypes = new Set(cluster.stats.generic_types);
    cluster.stats.generic_types = Array.from(uniqueGenericTypes);
    cluster.stats.princeps_count = cluster.princeps_products.length;
    cluster.stats.has_princeps = cluster.stats.princeps_count > 0;
    if (!cluster.stats.has_princeps) {
      result.meta.clusters_without_princeps++;
    }
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

function safeComposition(raw: string | null): string[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) {
      // Structured shape { element, substances: [{name,dosage}] }
      if (parsed.every((v) => v && typeof v === "object" && "substances" in v)) {
        const entries = parsed as Array<{
          element: string;
          substances: Array<{ name: string; dosage: string }>;
        }>;
        const allSameElement =
          entries.length > 0 && entries.every((e) => e.element === entries[0].element);
        return entries.map((entry) => {
          const parts = (entry.substances ?? []).map((s) =>
            s.dosage ? `${s.name} ${s.dosage}` : s.name
          );
          const joined = parts.join(" + ");
          return allSameElement ? joined : `${entry.element}: ${joined}`;
        });
      }
      return parsed.map((v) => String(v));
    }
  } catch {
    return [];
  }
  return [];
}

function safeRegulatoryInfo(raw: string): Partial<RegulatoryInfo> | null {
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object") {
      return parsed as Partial<RegulatoryInfo>;
    }
  } catch {
    return null;
  }
  return null;
}

function normalizeGenericType(value: number | null | undefined): GenericType {
  switch (value) {
    case GenericType.PRINCEPS:
    case GenericType.GENERIC:
    case GenericType.COMPLEMENTARY:
    case GenericType.SUBSTITUTABLE:
    case GenericType.AUTO_SUBSTITUTABLE:
      return value;
    default:
      return GenericType.UNKNOWN;
  }
}

function describeGenericType(value: GenericType): string {
  switch (value) {
    case GenericType.GENERIC:
      return "Générique";
    case GenericType.COMPLEMENTARY:
      return "Complémentarité posologique";
    case GenericType.SUBSTITUTABLE:
      return "Générique substitutable";
    case GenericType.AUTO_SUBSTITUTABLE:
      return "Auto-substitutable";
    default:
      return "Statut générique inconnu";
  }
}

function normalizeLabel(cluster: ExplorerView["clusters"][string]): string {
  return (cluster.princeps_label || cluster.label || "").trim();
}

main();
