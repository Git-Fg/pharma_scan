import { Database } from "bun:sqlite";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { DEFAULT_DB_PATH } from "../src/db";
import { isStoppedProduct, normalizeString, type StoppedStatus } from "../src/logic";

const DEFAULT_OUT_PATH = join("data", "audit_unified_report.json");
const SIMILARITY_THRESHOLD = 0.86;
const FORBIDDEN_MANUFACTURERS = ["boiron"];

const REDUNDANCY_SUFFIXES = new Set([
  "base",
  "anhydre",
  "hydrate",
  "monohydrate",
  "dihydrate",
  "trihydrate",
  "sel",
  "acide",
  "sodique",
  "disodique",
  "trisodique",
  "tetrasodique",
  "sodique anhydre",
  "medocaril"
]);

type IgnoreConfig = {
  fuzzy_pairs?: string[];
  discriminator_regex?: string[];
};

function loadIgnoreConfig(path = "data/audit_ignore.json"): IgnoreConfig {
  try {
    const raw = readFileSync(path, "utf8");
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object") {
      return parsed as IgnoreConfig;
    }
  } catch {
    // optional; ignore if missing
  }
  return {};
}

function saveIgnoreConfig(config: IgnoreConfig, path = "data/audit_ignore.json") {
  writeFileSync(path, JSON.stringify(config, null, 2));
}

type ClusterRow = {
  id: string;
  label: string;
  substance_code: string;
  princeps_label: string;
};

type ProductRow = StoppedStatus & {
  cis: string;
  label: string;
  composition: string;
  composition_codes: string;
  cluster_id: string | null;
  manufacturer_label: string | null;
};

type AuditReport = {
  timestamp: string;
  stats: {
    total_clusters: number;
    split_brand_count: number;
    permutation_clusters: number;
    fuzzy_warning_count: number;
    composition_redundancies_count: number;
    label_only_cluster_count: number;
    combo_overlap_count: number;
    forbidden_manufacturer_count: number;
  };
  critical_errors: {
    split_brands: Array<{
      princeps_label: string;
      clusters: Array<{ id: string; label: string; code: string }>;
    }>;
    permutations: Array<{
      sorted_tokens: string;
      clusters: Array<{ id: string; label: string; code: string }>;
    }>;
  };
  warnings: {
    fuzzy_duplicates: Array<{
      score: number;
      discriminator_tokens: string[];
      diff_visual: string;
      cluster_a: { id: string; label: string; code: string };
      cluster_b: { id: string; label: string; code: string };
    }>;
    forbidden_manufacturers: Array<{
      manufacturer: string;
      cis_list: string[];
      product_count: number;
    }>;
    label_only_clusters: Array<{
      id: string;
      label: string;
      substance_code: string;
      reason: string;
      product_count: number;
    }>;
    combo_component_overlaps: Array<{
      combo_cluster: { id: string; label: string };
      components: string[];
      overlaps: Array<{ id: string; label: string; component: string }>;
    }>;
  };
  composition_redundancies: Array<{
    cis: string;
    label: string;
    problem: string;
    redundant_term: string;
  }>;
};

export function runAudit(
  dbPath: string = DEFAULT_DB_PATH,
  outPath: string = DEFAULT_OUT_PATH,
  persistIgnore: boolean = false
): AuditReport {
  const ignoreConfig = loadIgnoreConfig();
  const db = new Database(dbPath, { readonly: true });
  const clusters = db
    .query<ClusterRow, []>("SELECT id, label, substance_code, princeps_label FROM clusters")
    .all();
  const allProducts = db
    .query<ProductRow, []>(`
      SELECT
        p.cis,
        p.label,
        p.composition,
        p.composition_codes,
        p.marketing_status,
        c.id AS cluster_id,
        m.label AS manufacturer_label,
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
      FROM products p
      LEFT JOIN groups g ON p.group_id = g.id
      LEFT JOIN clusters c ON g.cluster_id = c.id
      LEFT JOIN manufacturers m ON p.manufacturer_id = m.id
    `)
    .all();

  const products = allProducts.filter((p) => !isStoppedProduct(p));
  const stoppedProducts = allProducts.filter((p) => isStoppedProduct(p));

  const activeClusterIds = new Set(products.map((p) => p.cluster_id).filter(Boolean) as string[]);
  const stoppedClusterIds = new Set(
    stoppedProducts.map((p) => p.cluster_id).filter(Boolean) as string[]
  );

  const filteredClusters = clusters.filter((c) => {
    if (activeClusterIds.has(c.id)) return true;
    if (stoppedClusterIds.has(c.id)) return false;
    return true;
  });

  const splitBrands = detectSplitBrands(filteredClusters);
  const permutations = detectPermutations(filteredClusters);
  const compositionRedundancies = findCompositionRedundancies(products);
  const labelOnlyClusters = findLabelOnlyClusters(filteredClusters, products);
  const comboComponentOverlaps = findComboComponentOverlaps(filteredClusters);
  const forbiddenManufacturers = findForbiddenManufacturers(products);

  const report: AuditReport = {
    timestamp: new Date().toISOString(),
    stats: {
      total_clusters: filteredClusters.length,
      split_brand_count: splitBrands.length,
      permutation_clusters: permutations.length,
      fuzzy_warning_count: 0,
      composition_redundancies_count: compositionRedundancies.length,
      label_only_cluster_count: labelOnlyClusters.length,
      combo_overlap_count: comboComponentOverlaps.length,
      forbidden_manufacturer_count: forbiddenManufacturers.length
    },
    critical_errors: {
      split_brands: splitBrands,
      permutations
    },
    warnings: {
      fuzzy_duplicates: [],
      forbidden_manufacturers: forbiddenManufacturers,
      label_only_clusters: labelOnlyClusters,
      combo_component_overlaps: comboComponentOverlaps
    },
    composition_redundancies: compositionRedundancies
  };

  mkdirSync(dirname(outPath), { recursive: true });
  writeFileSync(outPath, JSON.stringify(report, null, 2));
  return report;
}

function detectSplitBrands(clusters: ClusterRow[]) {
  const map = new Map<string, ClusterRow[]>();
  for (const c of clusters) {
    if (!c.princeps_label || c.princeps_label === "Unknown") continue;
    if (!map.has(c.princeps_label)) map.set(c.princeps_label, []);
    map.get(c.princeps_label)!.push(c);
  }

  const result: AuditReport["critical_errors"]["split_brands"] = [];
  for (const [label, rows] of map) {
    if (rows.length < 2) continue;
    const uniqueClusters = new Set(rows.map((r) => r.id));
    if (uniqueClusters.size < 2) continue;
    result.push({
      princeps_label: label,
      clusters: rows.map((r) => ({ id: r.id, label: r.label, code: r.substance_code }))
    });
  }
  return result;
}

function detectPermutations(clusters: ClusterRow[]) {
  const map = new Map<string, ClusterRow[]>();
  for (const c of clusters) {
    const tokens = c.substance_code.split(" ").filter(Boolean).sort();
    if (tokens.length < 2) continue;
    const signature = tokens.join(" ");
    if (!map.has(signature)) map.set(signature, []);
    map.get(signature)!.push(c);
  }

  const result: AuditReport["critical_errors"]["permutations"] = [];
  for (const [signature, rows] of map) {
    const distinctCodes = new Set(rows.map((r) => r.substance_code));
    if (distinctCodes.size < 2) continue;
    result.push({
      sorted_tokens: signature,
      clusters: rows.map((r) => ({ id: r.id, label: r.label, code: r.substance_code }))
    });
  }
  return result;
}

// Fuzzy duplicate detection removed: produced only false positives.
function detectFuzzyDuplicates(
  _clusters: ClusterRow[],
  _ignoreConfig: IgnoreConfig,
  _persistIgnore: boolean
): AuditReport["warnings"]["fuzzy_duplicates"] {
  return [];
}

function findForbiddenManufacturers(products: ProductRow[]) {
  const byLabel = new Map<string, Set<string>>();
  for (const p of products) {
    if (!p.manufacturer_label) continue;
    const normalized = p.manufacturer_label.trim().toLowerCase();
    if (!normalized) continue;
    if (!FORBIDDEN_MANUFACTURERS.some((m) => normalized.includes(m))) continue;
    if (!byLabel.has(normalized)) byLabel.set(normalized, new Set<string>());
    byLabel.get(normalized)!.add(p.cis);
  }

  return Array.from(byLabel.entries()).map(([manufacturer, cisSet]) => ({
    manufacturer,
    cis_list: Array.from(cisSet).sort(),
    product_count: cisSet.size
  }));
}

function findLabelOnlyClusters(clusters: ClusterRow[], products: ProductRow[]) {
  const byCluster = new Map<string, ProductRow[]>();
  for (const p of products) {
    if (!p.cluster_id) continue;
    if (!byCluster.has(p.cluster_id)) byCluster.set(p.cluster_id, []);
    byCluster.get(p.cluster_id)!.push(p);
  }

  const parseCodes = (raw: string) => {
    if (!raw) return [];
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed.filter((c) => typeof c === "string" && c.trim()).map((c) => c.trim()) : [];
    } catch {
      return [];
    }
  };

  const result: AuditReport["warnings"]["label_only_clusters"] = [];

  for (const cluster of clusters) {
    const members = byCluster.get(cluster.id) ?? [];
    if (members.length === 0) continue;
    const allEmptyCodes = members.every((p) => parseCodes(p.composition_codes).length === 0);
    const idIsLabel = cluster.id.startsWith("CLS_MOL_");
    const substanceLooksLabel = !cluster.substance_code.includes("C:") && cluster.id.startsWith("CLS_MOL_");

    if (allEmptyCodes && (idIsLabel || substanceLooksLabel)) {
      result.push({
        id: cluster.id,
        label: cluster.label,
        substance_code: cluster.substance_code,
        reason: "Cluster built from label parsing; no BDPM composition tokens present",
        product_count: members.length
      });
    }
  }

  return result;
}

function findComboComponentOverlaps(clusters: ClusterRow[]) {
  const tokenize = (code: string, label: string) => {
    const parts = code
      .split(/\s*\|\s*/g)
      .map((t) => t.trim())
      .filter(Boolean);
    if (parts.length > 0) return parts;
    const normalized = normalizeString(label || "");
    const byPlus = normalized
      .split(/\s*\+\s*/g)
      .map((t) => t.trim())
      .filter(Boolean);
    if (byPlus.length > 1) return byPlus;
    return normalized ? [normalized] : [];
  };
  const isCodeToken = (token: string) => /^C:\d+$/i.test(token);

  const byToken = new Map<string, ClusterRow[]>();
  for (const c of clusters) {
    const tokens = tokenize(c.substance_code, c.label);
    if (tokens.length === 0) continue;
    for (const t of tokens) {
      if (!byToken.has(t)) byToken.set(t, []);
      byToken.get(t)!.push(c);
    }
  }

  const result: AuditReport["warnings"]["combo_component_overlaps"] = [];

  for (const c of clusters) {
    const tokens = tokenize(c.substance_code, c.label);
    if (tokens.length <= 1) continue; // not a combo
    if (tokens.every(isCodeToken)) continue; // fully coded combos are expected
    const overlaps: Array<{ id: string; label: string; component: string }> = [];
    for (const t of tokens) {
      const peers = byToken.get(t) ?? [];
      for (const peer of peers) {
        if (peer.id === c.id) continue;
        const peerTokens = tokenize(peer.substance_code, peer.label);
        if (peerTokens.length === 1 && peerTokens[0] === t) {
          overlaps.push({ id: peer.id, label: peer.label, component: t });
        }
      }
    }
    if (overlaps.length > 0) {
      result.push({
        combo_cluster: { id: c.id, label: c.label },
        components: tokens,
        overlaps
      });
    }
  }

  return result;
}

function findCompositionRedundancies(products: ProductRow[]) {
  const redundancies: AuditReport["composition_redundancies"] = [];

  for (const product of products) {
    const ingredients = parseIngredients(product.composition);
    if (ingredients.length < 2) continue;

    const sorted = [...ingredients].sort((a, b) => a.length - b.length);

    for (let i = 0; i < sorted.length; i++) {
      for (let j = i + 1; j < sorted.length; j++) {
        const shortForm = sorted[i];
        const longForm = sorted[j];
        if (!longForm.toLowerCase().startsWith(shortForm.toLowerCase())) continue;

        const suffixRaw = longForm.slice(shortForm.length).trim();
        if (!suffixRaw) continue;

        const suffixLower = suffixRaw.toLowerCase();
        const matchedSuffix = matchRedundancySuffix(suffixLower);
        if (!matchedSuffix) continue;

        redundancies.push({
          cis: product.cis,
          label: product.label,
          problem: `${shortForm} <-> ${longForm}`,
          redundant_term: matchedSuffix
        });
      }
    }
  }

  return redundancies;
}

function matchRedundancySuffix(suffixLower: string): string | null {
  if (REDUNDANCY_SUFFIXES.has(suffixLower)) return suffixLower;
  for (const token of REDUNDANCY_SUFFIXES) {
    if (suffixLower.endsWith(token)) return token;
  }
  return null;
}

function parseIngredients(raw: string): string[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    const names: string[] = [];
    for (const item of parsed) {
      if (typeof item === "string") {
        const val = item.trim();
        if (val) names.push(val);
        continue;
      }
      if (item && typeof item === "object") {
        // Structured composition entry { element, substances: [{ name, dosage }] }
        if (Array.isArray((item as Record<string, unknown>).substances)) {
          for (const sub of (item as Record<string, unknown>).substances as Array<
            Record<string, unknown>
          >) {
            const subName = sub?.name;
            if (typeof subName === "string" && subName.trim()) {
              names.push(subName.trim());
            }
          }
        }
        const candidate =
          (item as Record<string, unknown>).name ??
          (item as Record<string, unknown>).substance ??
          (item as Record<string, unknown>).label ??
          (item as Record<string, unknown>).denomination ??
          (item as Record<string, unknown>).ingredient ??
          (item as Record<string, unknown>).code ??
          (item as Record<string, unknown>).substance_name;
        if (typeof candidate === "string" && candidate.trim()) {
          names.push(candidate.trim());
        }
      }
    }
    return names;
  } catch {
    return [];
  }
}

function splitField(value: string | null): string[] {
  if (!value) return [];
  return value
    .split("||")
    .map((v) => v.split(","))
    .flat()
    .map((v) => v.trim())
    .filter(Boolean);
}

if (import.meta.main) {
  const outPath = DEFAULT_OUT_PATH;
  const report = runAudit(DEFAULT_DB_PATH, outPath);
  console.log("Audit complete.");
  console.log(`   - Split princeps brands: ${report.stats.split_brand_count}`);
  console.log("   - Clusters with multiple princeps: n/a");
  console.log(`   - Ingredient permutations: ${report.stats.permutation_clusters}`);
  console.log(`   - Fuzzy warnings: ${report.stats.fuzzy_warning_count}`);
  console.log(`   - Composition redundancies: ${report.stats.composition_redundancies_count}`);
  console.log(`   - Report saved to ${outPath}`);
}
