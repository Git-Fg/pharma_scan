import { Database } from "bun:sqlite";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const DEFAULT_DB_PATH = "reference.db";
const DEFAULT_OUT_PATH = join("data", "audit_unified_report.json");
const SIMILARITY_THRESHOLD = 0.82;

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

const NOISE_WORDS = new Set([
  "le",
  "la",
  "de",
  "du",
  "des",
  "par",
  "pour",
  "et",
  "au"
]);

const VALID_SPLIT_TOKENS = new Set([
  "enfants",
  "adultes",
  "nourrissons",
  "injectable",
  "creme",
  "pommade",
  "sirop",
  "gouttes",
  "fort",
  "faible",
  "vitaminique",
  "sugar-free",
  "sans",
  "sucre"
]);

type ClusterRow = {
  id: string;
  label: string;
  substance_code: string;
  princeps_label: string;
};

type ProductRow = {
  cis: string;
  label: string;
  composition: string;
};

type AuditReport = {
  timestamp: string;
  stats: {
    total_clusters: number;
    split_brand_count: number;
    permutation_clusters: number;
    fuzzy_warning_count: number;
    composition_redundancies_count: number;
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
  outPath: string = DEFAULT_OUT_PATH
): AuditReport {
  const db = new Database(dbPath, { readonly: true });
  const clusters = db
    .query<ClusterRow, []>("SELECT id, label, substance_code, princeps_label FROM clusters")
    .all();
  const products = db
    .query<ProductRow, []>("SELECT cis, label, composition FROM products")
    .all();

  const splitBrands = detectSplitBrands(clusters);
  const permutations = detectPermutations(clusters);
  const fuzzyDuplicates = detectFuzzyDuplicates(clusters);
  const compositionRedundancies = findCompositionRedundancies(products);

  const report: AuditReport = {
    timestamp: new Date().toISOString(),
    stats: {
      total_clusters: clusters.length,
      split_brand_count: splitBrands.length,
      permutation_clusters: permutations.length,
      fuzzy_warning_count: fuzzyDuplicates.length,
      composition_redundancies_count: compositionRedundancies.length
    },
    critical_errors: {
      split_brands: splitBrands,
      permutations
    },
    warnings: {
      fuzzy_duplicates: fuzzyDuplicates
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

function detectFuzzyDuplicates(clusters: ClusterRow[]) {
  const invertedIndex = new Map<string, ClusterRow[]>();
  const processedPairs = new Set<string>();

  for (const c of clusters) {
    const tokens = tokenize(c.substance_code);
    for (const t of tokens) {
      if (!invertedIndex.has(t)) invertedIndex.set(t, []);
      invertedIndex.get(t)!.push(c);
    }
  }

  const warnings: AuditReport["warnings"]["fuzzy_duplicates"] = [];

  for (const [, group] of invertedIndex) {
    if (group.length < 2) continue;
    if (group.length > 50) continue;

    for (let i = 0; i < group.length; i++) {
      for (let j = i + 1; j < group.length; j++) {
        const a = group[i];
        const b = group[j];

        const pairId = [a.id, b.id].sort().join("::");
        if (processedPairs.has(pairId)) continue;
        processedPairs.add(pairId);

        const score = levenshteinSimilarity(a.substance_code.toLowerCase(), b.substance_code.toLowerCase());
        if (score < SIMILARITY_THRESHOLD) continue;

        const { diffA, diffB, discriminators } = diffTokens(a.substance_code, b.substance_code);

        if (discriminators.length > 0 && discriminators.every((t) => NOISE_WORDS.has(t))) {
          continue;
        }
        if (discriminators.some((t) => VALID_SPLIT_TOKENS.has(t))) {
          continue;
        }

        warnings.push({
          score: Number(score.toFixed(3)),
          discriminator_tokens: discriminators,
          diff_visual: `[${diffA.join(" ")}] <---> [${diffB.join(" ")}]`,
          cluster_a: { id: a.id, label: a.label, code: a.substance_code },
          cluster_b: { id: b.id, label: b.label, code: b.substance_code }
        });
      }
    }
  }

  warnings.sort((a, b) => b.score - a.score);
  return warnings;
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

function tokenize(code: string): string[] {
  return code
    .toLowerCase()
    .split(/\s+/)
    .map((t) => t.trim())
    .filter((t) => t.length > 0);
}

function diffTokens(a: string, b: string) {
  const setA = new Set(tokenize(a));
  const setB = new Set(tokenize(b));
  const diffA = [...setA].filter((x) => !setB.has(x));
  const diffB = [...setB].filter((x) => !setA.has(x));
  const discriminators = [...new Set([...diffA, ...diffB])];
  return { diffA, diffB, discriminators };
}

function levenshteinSimilarity(s1: string, s2: string): number {
  if (s1 === s2) return 1;
  if (s1.length === 0 || s2.length === 0) return 0;

  const track = Array.from({ length: s2.length + 1 }, () => Array<number>(s1.length + 1).fill(0));
  for (let i = 0; i <= s1.length; i++) track[0][i] = i;
  for (let j = 0; j <= s2.length; j++) track[j][0] = j;

  for (let j = 1; j <= s2.length; j++) {
    for (let i = 1; i <= s1.length; i++) {
      const cost = s1[i - 1] === s2[j - 1] ? 0 : 1;
      track[j][i] = Math.min(
        track[j][i - 1] + 1,
        track[j - 1][i] + 1,
        track[j - 1][i - 1] + cost
      );
    }
  }
  const distance = track[s2.length][s1.length];
  const maxLength = Math.max(s1.length, s2.length);
  return 1 - distance / maxLength;
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
  console.log(`   - Clusters with multiple princeps: ${report.stats.merged_molecule_clusters}`);
  console.log(`   - Ingredient permutations: ${report.stats.permutation_clusters}`);
  console.log(`   - Fuzzy warnings: ${report.stats.fuzzy_warning_count}`);
  console.log(`   - Composition redundancies: ${report.stats.composition_redundancies_count}`);
  console.log(`   - Report saved to ${outPath}`);
}
