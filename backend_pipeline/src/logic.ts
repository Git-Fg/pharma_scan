import { hasAccents, removeAccentsEnhanced } from "@urbanzoo/remove-accents";
import { z } from "zod";
import {
  NOISE_WORDS,
  ORAL_FORM_TOKENS,
  SALT_PREFIXES,
  SALT_SUFFIXES
} from "./constants";
import type {
  CisId,
  GroupId,
  RefComposition,
  RefGenerique,
  RegulatoryInfo
} from "./types";
import type { RawCompositionSchema } from "./types";

/**
 * Advanced pharmaceutical normalization for clustering/search.
 * Ports the Dart sanitizer (normalizePrincipleOptimal/normalizeForSearchIndex).
 */
export function normalizeString(input: string): string {
  if (!input) return "";
  // Stage 1: uppercase and accent cleanup
  let normalized = input
    .toUpperCase()
    .replace(/\u00A0/g, " ")
    .replace(/–/g, "-")
    .trim();

  if (hasAccents(normalized)) {
    normalized = removeAccentsEnhanced(normalized);
  }

  // Stage 2: remove leading "ACIDE "
  normalized = normalized.replace(/^ACIDE\s+/, "");

  // Stage 2b: correct common typos before further normalization
  const typoFixes = {
    MONOSODIQIUE: "MONOSODIQUE"
  } as const satisfies Record<string, string>;
  Object.entries(typoFixes).forEach(([wrong, replacement]) => {
    const pattern = new RegExp(`\\b${wrong}\\b`, "g");
    normalized = normalized.replace(pattern, replacement);
  });

  // Stage 2c: inject form hints to avoid merging radically different routes/forms
  const formHints = [
    "CREME",
    "COLLYRE",
    "OPHTALMIQUE",
    "INJECTABLE",
    "PERFUSION",
    "POMMADE",
    "SOLUTION BUVABLE",
    "SIROP",
    "SUSPENSION",
    "COMPRIME",
    "CAPSULE"
  ];
  const appended: string[] = [];
  for (const hint of formHints) {
    if (normalized.includes(hint)) {
      appended.push(hint);
    }
  }
  if (appended.length > 0) {
    normalized = `${normalized} ${appended.join(" ")}`.trim();
  }
  // Stage 3: drop "EQUIVALENT A ..." tail (keeps base molecule)
  // Skip this truncation for combination strings that include "+"
  const hasPlus = normalized.includes("+");
  const equivMatch = normalized.search(/\bEQUIVAL[EA]NT\s+A\b/);
  if (!hasPlus && equivMatch > -1) {
    normalized = normalized.substring(0, equivMatch).trim();
  }

  // Stage 4: remove parenthetical salt hints
  normalized = normalized.replace(/\s*\([^)]*\)/g, " ");

  // Stage 5: strip known salt prefixes (single occurrence expected)
  for (const prefix of SALT_PREFIXES) {
    if (normalized.startsWith(prefix)) {
      normalized = normalized.substring(prefix.length).trim();
      break;
    }
  }

  // Stage 6: iteratively strip salt suffixes wherever they appear
  let changed = true;
  while (changed) {
    changed = false;
    for (const suffix of SALT_SUFFIXES) {
      const suffixWithSpace = ` ${suffix}`;
      if (normalized.endsWith(suffixWithSpace)) {
        normalized = normalized.slice(0, -suffixWithSpace.length).trim();
        changed = true;
      } else if (normalized.includes(` ${suffix} `)) {
        normalized = normalized.replace(` ${suffix} `, " ").trim();
        changed = true;
      }
    }
  }

  // Stage 7: remove oral solid form tokens (do not split by tablet/capsule variants)
  if (ORAL_FORM_TOKENS.length > 0) {
    const formPattern = new RegExp(
      `\\b(?:${ORAL_FORM_TOKENS.map((t) => t.replace(/\s+/g, "\\s+")).join("|")})\\b`,
      "g"
    );
    normalized = normalized.replace(formPattern, " ");
  }

  // Stage 7: remove noise markers
  for (const noise of NOISE_WORDS) {
    normalized = normalized.replace(new RegExp(noise, "g"), " ").trim();
  }

  // Stage 8: final punctuation/whitespace collapse
  // Strip common dosage markers to align clustering on molecule (e.g., "300 mg")
  normalized = normalized.replace(
    /\b\d+(?:[.,]\d+)?\s*(?:MG|G|UG|µG|MCG|ML|UI|MICROGRAMME(?:S)?|MILLIGRAMME(?:S)?|GRAMME(?:S)?|POUR\s*CENT|%|MICROLITRE(?:S)?|U\.I\.?)\b/g,
    " "
  );

  // Strip standalone percentage strengths (e.g., "2 %")
  normalized = normalized.replace(/\b\d+(?:[.,]\d+)?\s*%/g, " ");

  // Strip residual administration tokens that trail unit forms (e.g., " /DOSE")
  normalized = normalized.replace(/\/?(?:DOSE|DOSES|PUFF|APPLICATION)\b/gi, " ");

  // Stage 9: drop any remaining standalone numeric tokens (strength remnants like "100")
  normalized = normalized.replace(/\b\d+(?:[.,]\d+)?\b/g, " ");

  // Stage 10: drop standalone unit tokens and plus signs that keep dose variants apart
  normalized = normalized.replace(/\b(?:ML|L|G|MG|MCG|UG|µG|UI|MUI|IU|M)\b/gi, " ");
  normalized = normalized.replace(/\s*\+\s*/g, " ");

  // Stage 9: collapse repeated consecutive tokens (e.g., "bisoprolol bisoprolol")
  normalized = collapseDuplicateTokens(normalized);

  normalized = normalized
    .replace(/[-'",:./]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();

  // Stage 10: normalize token order for combination products (A+B vs B+A)
  normalized = normalizeTokenOrder(normalized);

  // Final pass: remove any remaining consecutive duplicate tokens after punctuation cleanup
  normalized = collapseDuplicateTokens(normalized);

  return normalized.replace(/\s+/g, " ").trim();
}

/**
 * Parses a French decimal string "12,50" -> 1250 (cents).
 */
export function parsePriceToCents(raw: string): number | null {
  if (!raw) return null;
  // Remove all whitespace (including non-breaking) and legacy dot thousand separators.
  const sanitized = raw.replace(/[\s\u00A0]/g, "").replace(/\./g, "");
  if (!sanitized) return null;

  const parts = sanitized.split(",");
  let normalized = sanitized;

  if (parts.length > 1) {
    const integerPart = parts.slice(0, -1).join("");
    const decimalPart = parts[parts.length - 1];
    normalized = `${integerPart}.${decimalPart}`;
  }

  const val = Number.parseFloat(normalized);
  if (!Number.isFinite(val) || Number.isNaN(val)) return null;

  return Math.round(val * 100);
}

/**
 * The "3-Tier" Parsing Strategy for Group Labels.
 * Port of: parseGeneriquesImpl in bdpm_file_parser.dart
 */
export function parseGroupMetadata(
  rawLabel: string,
  princepsCis: CisId | undefined,
  cisToName: Map<CisId, string>
): { molecule: string; brand: string; textBrand: string | null } {
  const split = simpleSplit(rawLabel);

  // Tier 1: Relational (If we know the princeps CIS name)
  if (princepsCis && cisToName.has(princepsCis)) {
    const princepsName = cisToName.get(princepsCis)!;
    return {
      molecule: split.molecule,
      brand: princepsName,
      textBrand: split.brand !== "Unknown" ? split.brand : null
    };
  }

  // Tier 2: Simple Split ("MOLECULE - MARQUE")
  return {
    molecule: split.molecule,
    brand: split.brand,
    textBrand: split.brand !== "Unknown" ? split.brand : null
  };
}

function simpleSplit(label: string): { molecule: string; brand: string } {
  const normalized = label.replace(/\u00A0/g, " ").replace(/[–—]/g, "-");

  // 1) Prefer " - " (space-dash-space) to avoid cutting intra-token hyphens (e.g., "L-CARNITINE").
  const primaryParts = normalized.split(/\s+-\s+/);
  if (primaryParts.length > 1) {
    const molecule = primaryParts.shift()!.trim();
    const brand = primaryParts.length > 0 ? primaryParts[primaryParts.length - 1].trim() : "Unknown";
    return { molecule, brand };
  }

  // 2) Glued or malformed dash (e.g., "AMOX-CLAMOXYL", "AMOX -CLAMOXYL", "AMOX- CLAMOXYL").
  const gluedParts = normalized.split(/(?<=\S)\s*[-–]\s*(?=[A-ZÀ-ÿ0-9])/);
  if (gluedParts.length > 1) {
    const molecule = gluedParts.shift()!.trim();
    const brand = gluedParts.length > 0 ? gluedParts[gluedParts.length - 1].trim() : "Unknown";
    return { molecule, brand };
  }

  // 3) Last fallback: any dash separation (still tolerant to glued).
  const fallbackParts = normalized.split(/\s*[-–]\s*/);
  if (fallbackParts.length > 1) {
    const molecule = fallbackParts.shift()!.trim();
    const brand = fallbackParts.length > 0 ? fallbackParts[fallbackParts.length - 1].trim() : "Unknown";
    return { molecule, brand };
  }

  return { molecule: normalized, brand: "Unknown" };
}

/**
 * Parse regulatory flags (List I/II, Narcotic, Hospital-only) from conditions text.
 */
export function parseRegulatoryInfo(conditions: string): RegulatoryInfo {
  if (!conditions) {
    return { list1: false, list2: false, narcotic: false, hospital: false };
  }

  const haystack = conditions.toLowerCase();
  const list1 = /\bliste\s*i\b/.test(haystack);
  const list2 = /\bliste\s*ii\b/.test(haystack);
  const narcotic = /stup[ée]fiant/.test(haystack);
  const hospital = /usage\s+(?:hospitalier|h[oô]pital)/.test(haystack);

  return { list1, list2, narcotic, hospital };
}

/**
 * Parse DD/MM/YYYY to ISO YYYY-MM-DD; returns null if invalid.
 */
export function parseDateToIso(date: string): string | null {
  if (!date) return null;
  const match = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(date.trim());
  if (!match) return null;
  const [, dd, mm, yyyy] = match;
  return `${yyyy}-${mm}-${dd}`;
}

type CompositionRow = z.infer<typeof RawCompositionSchema>;

export type CompositionData = {
  names: string[];
  codes: string[];
};

export type CompositionEntry = {
  element: string;
  substances: Array<{ name: string; dosage: string }>;
};

/**
 * Aggregates raw composition rows into active ingredient names and substance codes.
 * Implements the "FT overrides SA" rule.
 */
export function buildComposition(rows: CompositionRow[]): CompositionData {
  const substances = new Map<
    string,
    { name: string; nature: string; code: string }
  >();
  const uniqueCodes = new Set<string>();

  for (const row of rows) {
    const [, , code, name, , , nature] = row;
    if (nature !== "SA" && nature !== "FT") continue;

    const trimmedCode = code.trim();
    if (trimmedCode && trimmedCode !== "0") {
      uniqueCodes.add(trimmedCode);
    }

    const existing = substances.get(code);
    if (!existing) {
      substances.set(code, { name, nature, code: trimmedCode });
    } else if (nature === "FT" && existing.nature === "SA") {
      substances.set(code, { name, nature, code: trimmedCode });
    }
  }

  const names = Array.from(substances.values())
    .map((s) => normalizeIngredientName(s.name))
    .sort();

  return {
    names,
    codes: Array.from(uniqueCodes).sort()
  };
}

/**
 * Builds a deterministic composition signature using BDPM composition rows.
 * Rules:
 * - Prefer FT rows; if none exist, fallback to SA rows.
 * - Ignore dosage/posology; rely on substance codes when present, else normalized names.
 * - Deterministic ordering (sorted tokens) for stable cluster IDs.
 */
export function computeCompositionSignature(rows: RefComposition[] | undefined): {
  signature: string;
  tokens: string[];
  nature: "FT" | "SA" | null;
} {
  if (!rows || rows.length === 0) {
    return { signature: "", tokens: [], nature: null };
  }

  const hasFt = rows.some((r) => r.nature === "FT");
  const targetNature: "FT" | "SA" = hasFt ? "FT" : "SA";
  const tokens = new Set<string>();

  for (const row of rows) {
    if (row.nature !== targetNature) continue;
    const code = row.codeSubstance.trim();
    if (code && code !== "0") {
      tokens.add(`C:${code}`);
      continue;
    }
    const normalizedName = normalizeString(row.substanceName);
    if (normalizedName) {
      tokens.add(`N:${normalizedName}`);
    }
  }

  const ordered = Array.from(tokens).sort((a, b) => a.localeCompare(b));
  return {
    signature: ordered.join("|"),
    tokens: ordered,
    nature: targetNature
  };
}

/**
 * Returns displayable composition by preferring BDPM join data (CIS_COMPO).
 * Falls back to regex-based extraction on the original label for dirty rows.
 */
export function resolveComposition(
  cis: CisId,
  originalLabel: string,
  compoMap: Map<CisId, RefComposition[]>
): { display: string; structured: CompositionEntry[] } {
  const structured = buildStructuredComposition(compoMap.get(cis));
  if (structured.length > 0) {
    return { display: formatCompositionDisplay(structured), structured };
  }

  const fallback = extractCompositionFromLabel(originalLabel);
  return {
    display: fallback,
    structured:
      fallback.trim().length === 0
        ? []
        : [
            {
              element: "composition",
              substances: [{ name: fallback, dosage: "" }]
            }
          ]
  };
}

/**
 * Resolves the drawer label by preferring the group princeps (type 0) brand.
 * Falls back to normalized original label when no princeps is linked.
 */
export function resolveDrawerLabel(
  cis: CisId,
  originalLabel: string,
  genericsMap: Map<CisId, RefGenerique>,
  groupMasterMap: Map<GroupId, { label: string }>
): string {
  const genericInfo = genericsMap.get(cis);
  if (genericInfo) {
    const master = groupMasterMap.get(genericInfo.groupId);
    if (master?.label) {
      return normalizeDrawerText(master.label);
    }
  }
  return normalizeDrawerText(originalLabel);
}

function extractCompositionFromLabel(originalLabel: string): string {
  if (!originalLabel) return "";
  const sanitized = originalLabel.replace(/\u00A0/g, " ").trim();
  if (!sanitized) return "";
  const upper = sanitized.toUpperCase();
  const pattern =
    /([A-ZÀ-ÖØ-öø-ÿ0-9'’\-./\s]+?)\s+(\d+(?:[.,]\d+)?\s*(?:MG|G|UG|µG|MCG|ML|UI|U\.I\.?|%))/g;
  const parts: string[] = [];
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(upper)) !== null) {
    const name = match[1].replace(/[-,/]/g, " ").trim();
    const dose = match[2].replace(/\s+/g, " ").trim();
    if (name && dose) {
      parts.push(`${name} ${dose}`);
    }
  }
  if (parts.length > 0) return parts.join(" + ");
  return upper;
}

function normalizeDrawerText(label: string): string {
  const normalized = normalizeString(label);
  return normalized || label.trim();
}

function buildStructuredComposition(rows: RefComposition[] | undefined): CompositionEntry[] {
  if (!rows || rows.length === 0) return [];

  // Group by element label (col 2)
  const byElement = new Map<string, RefComposition[]>();
  for (const row of rows) {
    const element = row.elementLabel?.trim() || "composition";
    if (!byElement.has(element)) byElement.set(element, []);
    byElement.get(element)!.push(row);
  }

  const result: CompositionEntry[] = [];

  for (const [element, groupRows] of byElement) {
    // Within element, group by linkId (col 8). If missing, fallback to codeSubstance.
    const byLink = new Map<string, RefComposition[]>();
    for (const row of groupRows) {
      const linkKey = (row.linkId?.trim() || row.codeSubstance?.trim() || row.substanceName).trim();
      if (!byLink.has(linkKey)) byLink.set(linkKey, []);
      byLink.get(linkKey)!.push(row);
    }

    const substances: Array<{ name: string; dosage: string }> = [];

    for (const rowsForLink of byLink.values()) {
      const chosen =
        rowsForLink.find((r) => r.nature === "FT") ??
        rowsForLink.find((r) => r.nature === "SA") ??
        rowsForLink[0];

      const name = chosen.substanceName.trim();
      const dosage = chosen.dosage.trim();
      const isZeroish = /^0+(?:[.,]0+)?(?:\s*\D.*)?$/u.test(dosage);
      if (!name || !dosage || isZeroish) continue;

      substances.push({ name, dosage });
    }

    if (substances.length > 0) {
      result.push({ element, substances });
    }
  }

  return result;
}

function formatCompositionDisplay(entries: CompositionEntry[]): string {
  if (entries.length === 0) return "";
  const allElementsSame =
    entries.length > 0 &&
    entries.every((entry) => entry.element === entries[0].element);

  const renderEntry = (entry: CompositionEntry) => {
    const parts = entry.substances.map((s) =>
      s.dosage ? `${s.name} ${s.dosage}` : s.name
    );
    const joined = parts.join(" + ");
    return allElementsSame ? joined : `${entry.element}: ${joined}`;
  };

  return entries.map(renderEntry).join(" | ");
}

/**
 * Cleans up ingredient names for display.
 * e.g. "MÉMANTINE (CHLORHYDRATE DE)" -> "MÉMANTINE"
 */
function normalizeIngredientName(name: string): string {
  let clean = name.trim();
  const suffixMatch = /^(.*)\s\([A-ZÉÈÊÎÔÂÄËÏÖÜÀÂÊÎÔÛÇ]+\s+(?:DE|D')\)$/u.exec(clean);
  if (suffixMatch) {
    clean = suffixMatch[1];
  }
  return clean.charAt(0).toUpperCase() + clean.slice(1).toLowerCase();
}

function collapseDuplicateTokens(text: string): string {
  const tokens = text.split(/\s+/).filter(Boolean);
  if (tokens.length < 2) return text.trim();
  const deduped: string[] = [];
  for (const token of tokens) {
    if (deduped.length === 0 || deduped[deduped.length - 1] !== token) {
      deduped.push(token);
    }
  }
  return deduped.join(" ");
}

function normalizeTokenOrder(text: string): string {
  const stopTokens = new Set(["+", "mg", "g", "ug", "µg", "mcg", "ml", "ui"]);
  const tokens = text
    .split(/\s+/)
    .filter(Boolean)
    .filter((t) => !stopTokens.has(t));
  if (tokens.length < 2) return text.trim();
  tokens.sort((a, b) => a.localeCompare(b));
  return tokens.join(" ");
}

/**
 * Generates a deterministic Cluster ID.
 * Logic: Merges groups if they share a Normalized Molecule Key OR Princeps CIS.
 */
export function generateClusterId(
  normalizedMolecule: string,
  princepsCis?: GroupId | CisId
): string {
  if (normalizedMolecule) {
    return `CLS_MOL_${normalizedMolecule.replace(/\s/g, "_")}`;
  }
  if (princepsCis) return `CLS_CIS_${princepsCis}`;
  return "CLS_UNKNOWN";
}

// --- Manufacturer normalization & clustering ---

const MANUFACTURER_STOP_WORDS = new Set([
  "LABORATOIRES",
  "LABORATOIRE",
  "PHARMA",
  "PHARMACEUTICALS",
  "HEALTHCARE",
  "GROUP",
  "FRANCE",
  "EUROPE",
  "INTERNATIONAL",
  "DEUTSCHLAND",
  "GMBH",
  "SAS",
  "SA",
  "LTD",
  "AB",
  "OY",
  "S.P.A",
  "SPA",
  "INC",
  "NV",
  "BV",
  "LIMITED",
  "THERAPEUTICS",
  "SCIENCES",
  "HOLDING",
  "HOLDINGS"
]);

export function normalizeManufacturerName(raw: string): string {
  if (!raw) return "";
  let clean = raw.replace(/\s*\(.*?\)\s*/g, " ").trim();
  clean = clean.toUpperCase().replace(/\u00A0/g, " ");

  if (hasAccents(clean)) {
    clean = removeAccentsEnhanced(clean);
  }

  clean = clean.replace(/[^A-Z0-9\s]/g, " ");
  const tokens = clean
    .split(/\s+/)
    .filter(Boolean)
    .filter((t) => t.length > 1 && !MANUFACTURER_STOP_WORDS.has(t));

  tokens.sort((a, b) => a.localeCompare(b));
  return tokens.join(" ").trim();
}

function levenshteinDistance(a: string, b: string): number {
  if (a === b) return 0;
  const m = a.length;
  const n = b.length;
  if (m === 0) return n;
  if (n === 0) return m;
  const dp = Array.from({ length: m + 1 }, () => new Array<number>(n + 1).fill(0));
  for (let i = 0; i <= m; i++) dp[i][0] = i;
  for (let j = 0; j <= n; j++) dp[0][j] = j;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + cost
      );
    }
  }
  return dp[m][n];
}

type ManufacturerCluster = {
  id: number;
  canonical: string;
  label: string;
};

export function createManufacturerResolver() {
  const clusters: ManufacturerCluster[] = [];
  const cache = new Map<string, number>();
  let nextId = 1;

  const resolve = (rawName: string): ManufacturerCluster => {
    const trimmed = (rawName ?? "").trim();
    if (cache.has(trimmed)) {
      const id = cache.get(trimmed)!;
      const cluster = clusters.find((c) => c.id === id)!;
      return cluster;
    }

    const normalized = normalizeManufacturerName(trimmed);
    const key = normalized || trimmed.toUpperCase() || `UNKNOWN_${nextId}`;

    for (const cluster of clusters) {
      const startsWith =
        key.startsWith(cluster.canonical) || cluster.canonical.startsWith(key);
      const distance = levenshteinDistance(key, cluster.canonical);
      const keyTokens = key.split(" ").filter(Boolean);
      const clusterTokens = cluster.canonical.split(" ").filter(Boolean);
      const tokenInclusion =
        (clusterTokens.length > 0 && clusterTokens.every((t) => keyTokens.includes(t))) ||
        (keyTokens.length > 0 && keyTokens.every((t) => clusterTokens.includes(t)));
      if (startsWith || tokenInclusion || distance < 3) {
        if (trimmed && trimmed.length < cluster.label.length) {
          cluster.label = trimmed;
        }
        if (key.length < cluster.canonical.length) {
          cluster.canonical = key;
        }
        cache.set(trimmed, cluster.id);
        return cluster;
      }
    }

    const newCluster: ManufacturerCluster = {
      id: nextId++,
      canonical: key,
      label: trimmed || key
    };
    clusters.push(newCluster);
    cache.set(trimmed, newCluster.id);
    return newCluster;
  };

  const toRows = () => clusters.map(({ id, label }) => ({ id, label }));

  return { resolve, toRows };
}
