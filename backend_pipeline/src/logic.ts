import { hasAccents, removeAccentsEnhanced } from "@urbanzoo/remove-accents";
import { z } from "zod";
import {
  MANUFACTURER_STOP_WORDS,
  NOISE_WORDS,
  ORAL_FORM_TOKENS,
  PREFIX_STOP_WORDS,
  TARGET_POPULATION_TOKENS,
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
/**
 * Detects if a product is homeopathic based on its label, dosage, or manufacturer.
 * Consolidates all heuristics (build + tooling) into a single source of truth.
 */
export function isHomeopathic(label: string, dosage: string = "", manufacturer: string = ""): boolean {
  const combinedText = `${label} ${dosage} ${manufacturer}`.toUpperCase();

  // 1. Laboratory-based detection (highest priority)
  if (
    combinedText.includes("LEHNING") ||
    combinedText.includes("BOIRON") ||
    combinedText.includes("HEEL") ||
    combinedText.includes("WELEDA") ||
    combinedText.includes("RECKEWEG") ||
    combinedText.includes("UNDA") ||
    combinedText.includes("LABORATOIRES HOMEOPATHIQU") ||
    combinedText.includes("LABORATOIRES HOMEOPATHES")
  ) {
    return true;
  }

  // 2. Explicit homeopathic terms and common label hints
  if (
    combinedText.includes("HOMÉOPATHIQU") ||
    combinedText.includes("HOMEOPATH") ||
    combinedText.includes("POUR PRÉPARATIONS") ||
    combinedText.includes("GRANULES") ||
    combinedText.includes("GLOBULES") ||
    combinedText.includes("TRITURATION") ||
    combinedText.includes("MOTHER TINCTURE") ||
    combinedText.includes("TEINTURE MÈRE")
  ) {
    return true;
  }

  // 3. Specific labelling codes (L-codes, COMPLEXE) used by Boiron/Lehning ranges
  const hasLCode = /\bL\s?\d{2,3}\b/.test(combinedText) && combinedText.includes("SOLUTION BUVABLE");
  const hasComplexe = /COMPLEXE\s*N[°O]?\s*\d*/.test(combinedText);
  if (hasLCode || hasComplexe) {
    return true;
  }

  // 4. Dilution pattern detection (most specific)
  const dilutionPatterns = [
    /\d+(?:CH|DH|K)\s*(?:À|A|ET)\s*\d+(?:CH|DH|K)/i, // Range: "2CH à 30CH"
    /\d+(?:CH|DH|K)\s*(?:À|A|ET)\s*\d+(?:CH|DH|K)\s*(?:ET|OU)\s*\d+(?:CH|DH|K)/i, // Complex range
    /\d+(?:CH|DH|K)(?:\s*[,;]\s*\d+(?:CH|DH|K))*/i, // Multiple dilutions
    /\b(?:CH|DH|K)\s*\d+\b/i, // Reverse pattern
    /\b\d+LM\b/i,
    /\b\d+M\b(?![GL])/i, // M followed by non-G/L to avoid MG
    /\b\d+X\b/i,
    /\b\d+CK\b/i,
    /\b\d+Q\b/i
  ];

  for (const pattern of dilutionPatterns) {
    if (pattern.test(combinedText)) {
      return true;
    }
  }

  // 5. Single dilution (with strict context checks to avoid false positives)
  const singleDilutionPattern = /\b\d+(?:CH|DH|K|LM|CK|Q|X)\b/i; // Removed M to avoid MG conflicts
  if (singleDilutionPattern.test(combinedText)) {
    if (
      combinedText.includes("DEGRÉ DE DILUTION") ||
      combinedText.includes("DILUTION COMPRISE ENTRE") ||
      combinedText.includes("POUR PRÉPARATIONS") ||
      combinedText.includes("HOMÉOPATHIQU") ||
      combinedText.includes("HOMEOPATH") ||
      (combinedText.includes("SOLUTION BUVABLE") && combinedText.includes("GOUTTES")) ||
      (combinedText.includes("GOUTTES") && combinedText.length > 80)
    ) {
      return true;
    }
  }

  return false;
}

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

  // Strip lone percent signs early to avoid leaving "%" tokens in cluster ids
  normalized = normalized.replace(/%/g, " ");

  // Brand aliasing to unify princeps/generics that differ only by market name
  const brandAliases: Record<string, string> = {
    ARLUNIS: "BIPRETERAX",
    CONEBILOX: "TEMERITDUO"
  };
  for (const [from, to] of Object.entries(brandAliases)) {
    const pattern = new RegExp(`\\b${from}\\b`, "g");
    normalized = normalized.replace(pattern, to);
  }

  // Remove leading prefix stop words (segment markers) and their duplicates mid-string
  if (PREFIX_STOP_WORDS.length > 0) {
    const prefixPattern = new RegExp(
      `^(?:${PREFIX_STOP_WORDS.map((t) => t.replace(/\s+/g, "\\s+")).join("|")})\\s+`,
      "g"
    );
    normalized = normalized.replace(prefixPattern, " ");
    const midPrefixPattern = new RegExp(
      `\\s+(?:${PREFIX_STOP_WORDS.map((t) => t.replace(/\s+/g, "\\s+")).join("|")})\\b`,
      "g"
    );
    normalized = normalized.replace(midPrefixPattern, " ");
  }

  // Strip population markers early to avoid label pollution
  if (TARGET_POPULATION_TOKENS.length > 0) {
    const populationPattern = new RegExp(
      `\\b(?:${TARGET_POPULATION_TOKENS.map((t) => t.replace(/\s+/g, "\\s+")).join("|")})\\b`,
      "g"
    );
    normalized = normalized.replace(populationPattern, " ");
  }

  // Early removal of noise words (common marketing add-ons)
  for (const noise of NOISE_WORDS) {
    const noisePattern = new RegExp(`\\b${noise}\\b`, "gi");
    normalized = normalized.replace(noisePattern, " ");
  }
  normalized = normalized.replace(/\bSANS\s+CONSERVATEUR\b/gi, " ");

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

  // Stage 2.5: remove chemical prefixes (N-ACETYL, DL-, D-, L-, ALPHA-, BETA-, GAMMA-)
  const chemicalPrefixes = [
    /^N-ACETYL\s+/,
    /^DL-\s*/,
    /^D-\s*/,
    /^L-\s*/,
    /^ALPHA-\s*/,
    /^BETA-\s*/,
    /^GAMMA-\s*/i
  ];

  for (const prefix of chemicalPrefixes) {
    if (prefix.test(normalized)) {
      normalized = normalized.replace(prefix, "");
      break;
    }
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

  // Stage 6.5: remove target population markers that should not split clusters
  if (TARGET_POPULATION_TOKENS.length > 0) {
    const populationPattern = new RegExp(
      `\\b(?:${TARGET_POPULATION_TOKENS.map((t) => t.replace(/\s+/g, "\\s+")).join("|")})\\b`,
      "g"
    );
    normalized = normalized.replace(populationPattern, " ");
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

  // Stage 7.5: explicitly strip percentage phrases before unit collapse
  normalized = normalized.replace(/\bPOUR\s+CENT\b/gi, " ");
  normalized = normalized.replace(/\bPOUR\s+MILLE\b/gi, " ");

  // Stage 8: final punctuation/whitespace collapse
  // Strip common dosage markers to align clustering on molecule (e.g., "300 mg")
  const compoundUnitPattern =
    /\b\d+(?:[.,]\d+)?\s*(?:MG|G|UG|µG|MCG|ML|UI|MICROGRAMME(?:S)?|MILLIGRAMME(?:S)?|GRAMME(?:S)?|POUR\s*CENT|%|MICROLITRE(?:S)?|U\.I\.?)(?:\s*\/[\s\d.,]*(?:MG|G|UG|µG|MCG|ML|L|UI|IU|U\.I\.?|MICROLITRE(?:S)?))?\b/g;
  normalized = normalized.replace(compoundUnitPattern, " ");

  // Strip standalone percentage strengths (e.g., "2 %")
  normalized = normalized.replace(/\b\d+(?:[.,]\d+)?\s*%/g, " ");

  // Strip residual administration tokens that trail unit forms (e.g., " /DOSE")
  normalized = normalized.replace(/\/?(?:DOSE|DOSES|PUFF|APPLICATION)\b/gi, " ");
  normalized = normalized.replace(/\s*\/[\s\d.,]*(?:MG|G|UG|µG|MCG|ML|L|UI|IU|U\.I\.?)\b/gi, " ");

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

  // Stage 11: collapse redundant manufacturer qualifiers that pollute molecule keys
  // Focus on short tokens that only add lab brand noise and trigger fuzzy duplicates.
  const manufacturerTokens = [
    ...MANUFACTURER_STOP_WORDS,
    "LAB",
    "ARROW",
    "EG",
    "VIATRIS",
    "ZENTIVA",
    "UPSA",
    "TEVA",
    "BIOGARAN",
    "SANDOZ",
    "MYLAN",
    "CRISTERS",
    "ARROW LAB",
    "MEDIPHA",
    "BOUCHARA",
    "RECORDATI"
  ];
  const manufacturerPattern = buildStopWordPattern(manufacturerTokens);
  normalized = normalized.replace(manufacturerPattern, " ").replace(/\s+/g, " ").trim();

  // Stage 12: clean dangling unit suffixes left by aggressive splits
  normalized = normalized.replace(/\b(?:ml|mg|g)\b$/i, "").replace(/\b[a-z]\b$/i, "").trim();

  // Final pass: remove any remaining consecutive duplicate tokens after punctuation cleanup
  normalized = collapseDuplicateTokens(normalized);

  return normalized.replace(/\s+/g, " ").trim();
}

/**
 * Cleans a raw product label by removing dosage and form hints.
 * Example: "CLAMOXYL 1 g, poudre pour solution..." -> "CLAMOXYL"
 */
export function cleanProductLabel(label: string): string {
  if (!label) return "";
  let working = label.replace(/\u00A0/g, " ").trim();
  if (!working) return "";

  // Drop stray percent symbols
  working = working.replace(/%/g, " ");

  // Remove percent words without numeric strength
  working = working.replace(/\bPOUR\s+CENT\b/gi, " ");
  working = working.replace(/\bPOURCENT\b/gi, " ");

  working = removeAccentsEnhanced(working.toUpperCase());

  // Drop everything after the first comma (usually holds form/route details)
  const commaIdx = working.indexOf(",");
  if (commaIdx !== -1) {
    working = working.slice(0, commaIdx);
  }

  // Remove explicit dosage patterns
  const dosagePattern =
    /\b\d+(?:[.,]\d+)?\s*(?:MG|G|UG|µG|MCG|ML|UI|MUI|IU|%|MICROGRAMME(?:S)?|MILLIGRAMME(?:S)?|GRAMME(?:S)?|MICROLITRE(?:S)?|U\.I\.?)(?:\s*\/[\s\d.,]*(?:MG|G|UG|µG|MCG|ML|L|UI|IU|U\.I\.?|MICROLITRE(?:S)?))?\b/gi;
  working = working.replace(dosagePattern, " ");
  working = working.replace(/\s*\/[\s\d.,]*(?:MG|G|UG|µG|MCG|ML|L|UI|IU|U\.I\.?)\b/gi, " ");

  // Remove standalone numeric fragments that may linger (e.g., "1000")
  working = working.replace(/\b\d+(?:[.,]\d+)?\b/g, " ");

  // Remove population markers that shouldn't alter brand names
  if (TARGET_POPULATION_TOKENS.length > 0) {
    const populationPattern = new RegExp(
      `\\b(?:${TARGET_POPULATION_TOKENS.map((t) => t.replace(/\s+/g, "\\s+")).join("|")})\\b`,
      "gi"
    );
    working = working.replace(populationPattern, " ");
  }

  // Strip common form keywords
  const formWords = [
    "COMPRIME",
    "COMPRIMES",
    "GELULE",
    "GELULES",
    "CAPSULE",
    "CAPSULES",
    "SOLUTION",
    "POMMADE",
    "CREME",
    "PELLICULE",
    "PELLICULEE",
    "PELLICULES",
    "COLLYRE",
    "SIROP",
    "SUSPENSION",
    "POUDRE",
    "INJECTABLE",
    "PERFUSION",
    "EMULSION",
    "SPRAY",
    "AEROSOL",
    "PATCH",
    "FILM",
    "SACHET",
    "LYOPHILISAT",
    "GRANULES",
    "OVULE",
    "SUPPOSITOIRE",
    "PULVERISATION",
    "GOUTTES"
  ];
  const formRegex = new RegExp(`\\b(?:${formWords.join("|")})\\b`, "gi");
  working = working.replace(formRegex, " ");

  // Strip marketing and excipient noise words that fragment brands
  for (const noise of NOISE_WORDS) {
    const pattern = new RegExp(`\\b${noise.replace(/\s+/g, "\\s+")}\\b`, "gi");
    working = working.replace(pattern, " ");
  }
  working = working.replace(/\bSANS\s+CONSERVATEUR\b/gi, " ");
  working = working.replace(/\bADRENALINEE\b/gi, " ");

  // Normalize to canonical uppercase (accent stripped by normalizeString if needed)
  const cleaned = working.replace(/[-'/]/g, " ").replace(/\s+/g, " ").trim();
  return cleaned ? cleaned.toUpperCase() : "";
}

/**
 * Parses a group label (CIS_GENER col 2) into molecule and reference (princeps) parts.
 * Splits on the last " - " occurrence to avoid cutting intra-token hyphens.
 */
export function parseGroupLabel(groupLabel: string): { molecule: string; reference: string } {
  const { left, right } = splitGroupLabelLoose(groupLabel);
  return { molecule: left, reference: right ?? "" };
}

/**
 * Detects if a label likely describes a combination therapy (A + B)
 * even when composition data is incomplete.
 */
export function detectComboMolecules(label: string): boolean {
  if (!label) return false;
  const upper = label.toUpperCase().replace(/\u00A0/g, " ");
  const parts = upper.split(/[+/]/);
  if (parts.length < 2) return false;

  const stripUnits = (text: string) =>
    text
      .replace(
        /\b\d+(?:[.,]\d+)?\s*(?:MG|G|UG|µG|MCG|ML|UI|MUI|IU|%|MICROGRAMME(?:S)?|GRAMME(?:S)?|MILLIGRAMME(?:S)?|POUR\s*CENT)\b/gi,
        " "
      )
      .replace(/\s+/g, " ")
      .trim();

  let meaningful = 0;
  for (const raw of parts) {
    const cleaned = stripUnits(raw);
    if (!cleaned || cleaned.length < 3) continue;
    if (/^(MG|ML|G|UG|MCG|UI|MUI|IU|POUR CENT)$/i.test(cleaned)) continue;
    if (/^\d+$/.test(cleaned)) continue;
    meaningful++;
  }

  return meaningful >= 2;
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
 * Splits a group label using the last dash, tolerating missing spaces/em-dash.
 * Example: "AMOXICILLINE 500MG - CLAMOXYL" -> ["AMOXICILLINE 500MG", "CLAMOXYL"]
 * Example: "AMOXICILLINE-CLAMOXYL" -> ["AMOXICILLINE", "CLAMOXYL"]
 */
export function splitGroupLabelLoose(label: string): { left: string; right: string | null } {
  if (!label) return { left: "", right: null };
  const normalized = label.replace(/\u00A0/g, " ").replace(/[–—]/g, "-");
  const spacedIdx = normalized.lastIndexOf(" - ");
  const idx = spacedIdx !== -1 ? spacedIdx : normalized.lastIndexOf("-");
  if (idx === -1) return { left: normalized.trim(), right: null };
  const left = normalized.slice(0, idx).trim();
  const right = normalized.slice(idx + (spacedIdx !== -1 ? 3 : 1)).trim();
  return { left, right: right || null };
}

/**
 * Splits a group label using the first dash to extract the generic (left) part.
 */
export function splitGroupLabelFirst(label: string): { left: string; right: string | null } {
  if (!label) return { left: "", right: null };
  const normalized = label.replace(/\u00A0/g, " ").replace(/[–—]/g, "-");
  const spacedIdx = normalized.indexOf(" - ");
  const idx = spacedIdx !== -1 ? spacedIdx : normalized.indexOf("-");
  if (idx === -1) return { left: normalized.trim(), right: null };
  const left = normalized.slice(0, idx).trim();
  const right = normalized.slice(idx + (spacedIdx !== -1 ? 3 : 1)).trim();
  return { left, right: right || null };
}

/**
 * Cleans a princeps candidate by removing dosage and form hints.
 * Keeps brand tokens intact for canonical naming.
 */
export function cleanPrincepsCandidate(label: string): string {
  if (!label) return "";
  let working = label.replace(/\u00A0/g, " ").trim();
  if (!working) return "";

  // Remove stray percent signs early
  working = working.replace(/%/g, " ");

  const commaIdx = working.indexOf(",");
  if (commaIdx !== -1) {
    working = working.slice(0, commaIdx);
  }

  const dosagePattern =
    /\b\d+(?:[.,]\d+)?\s*(?:MG|G|UG|µG|MCG|ML|UI|MUI|IU|%|MICROGRAMME(?:S)?|MILLIGRAMME(?:S)?|GRAMME(?:S)?|MICROLITRE(?:S)?|U\.I\.?)\b/gi;
  working = working.replace(dosagePattern, " ");
  working = working.replace(/\b\d+(?:[.,]\d+)?\b/g, " ");

  // Remove population tokens and percentage words that pollute brand names
  if (TARGET_POPULATION_TOKENS.length > 0) {
    const populationPattern = new RegExp(
      `\\b(?:${TARGET_POPULATION_TOKENS.map((t) => t.replace(/\s+/g, "\\s+")).join("|")})\\b`,
      "gi"
    );
    working = working.replace(populationPattern, " ");
  }
  working = working.replace(/\bPOUR\s+(CENT|MILLE)\b/gi, " ");
  working = working.replace(/\bPOUR\b/gi, " ");
  working = working.replace(/\bCENT\b/gi, " ");
  working = working.replace(/\bMILLE\b/gi, " ");

  const formWords = [
    "COMPRIME",
    "COMPRIMES",
    "GELULE",
    "GELULES",
    "CAPSULE",
    "CAPSULES",
    "SOLUTION",
    "POMMADE",
    "CREME",
    "PELLICULE",
    "PELLICULEE",
    "PELLICULES",
    "COLLYRE",
    "SIROP",
    "SUSPENSION",
    "POUDRE",
    "INJECTABLE",
    "PERFUSION",
    "EMULSION",
    "SPRAY",
    "AEROSOL",
    "PATCH",
    "FILM",
    "SACHET",
    "LYOPHILISAT",
    "GRANULES",
    "OVULE",
    "SUPPOSITOIRE",
    "PULVERISATION",
    "GOUTTES"
  ];
  const formRegex = new RegExp(`\\b(?:${formWords.join("|")})\\b`, "gi");
  working = working.replace(formRegex, " ");

  const cleaned = working
    .replace(/[-'/]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .toUpperCase();

  // Guard against leading residual numbers (e.g., "1 G ZINNAT" -> "ZINNAT")
  return cleaned.replace(/^\d+\s+G\s+/, "").trim();
}

/**
 * Removes the official form and trailing text from the CIS label
 * to keep a brand + dosage surface (for princeps).
 */
export function stripFormFromCisLabel(label: string, form: string): string {
  if (!label) return "";
  let working = label.replace(/\u00A0/g, " ").trim();
  if (!working) return "";
  working = removeAccentsEnhanced(working.toUpperCase());

  const commaIdx = working.indexOf(",");
  if (commaIdx !== -1) {
    working = working.slice(0, commaIdx);
  }

  const normalizedForm = removeAccentsEnhanced((form || "").toUpperCase());
  if (normalizedForm) {
    const tokens = normalizedForm
      .replace(/[^A-Z0-9\s]/g, " ")
      .split(/\s+/)
      .filter((t) => t.length > 2);
    for (const token of tokens) {
      const re = new RegExp(`\\b${token}\\b`, "gi");
      working = working.replace(re, " ");
    }
  }

  working = working.replace(/\s+/g, " ").trim();
  return working ? working.toUpperCase() : "";
}

/**
 * Normalizes route strings into atomic tokens (lowercase) for comparison.
 */
export function normalizeRoutes(route: string): string[] {
  if (!route) return [];
  const split = route
    .replace(/\u00A0/g, " ")
    .split(/[;/,+]|et|ou/gi)
    .map((t) => t.replace(/\s+/g, " ").trim().toLowerCase())
    .filter(Boolean);
  return Array.from(new Set(split));
}

/**
 * Parse regulatory flags (List I/II, Narcotic, Hospital-only) from conditions text.
 */
export function parseRegulatoryInfo(conditions: string): RegulatoryInfo {
  if (!conditions) {
    return { list1: false, list2: false, narcotic: false, hospital: false, dental: false };
  }

  const haystack = conditions.toLowerCase();
  const list1 = /\bliste\s*i\b/.test(haystack);
  const list2 = /\bliste\s*ii\b/.test(haystack);
  const narcotic = /stup[ée]fiant/.test(haystack);
  const hospital = /usage\s+(?:hospitalier|h[oô]pital)/.test(haystack);
  const dental = /dentaire/.test(haystack);

  return { list1, list2, narcotic, hospital, dental };
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

/**
 * Validates substance codes according to strict rules.
 * Rejects dummy/placeholder codes and enforces proper format.
 */
function isValidCode(code: string): boolean {
  if (!code || typeof code !== 'string') return false;

  const trimmed = code.trim();

  // Reject empty or zero codes
  if (!trimmed || trimmed === '0' || trimmed === '00' || trimmed === '000') {
    return false;
  }

  // Reject common dummy/placeholder codes
  if (trimmed === '9999' || trimmed === '999' || trimmed === '99') {
    return false;
  }

  // Check length constraints (2-8 characters for valid BDPM codes)
  if (trimmed.length < 2 || trimmed.length > 8) {
    return false;
  }

  // Reject codes with only repeated digits (e.g., "111", "7777")
  if (/^(\d)\1+$/.test(trimmed)) {
    return false;
  }

  // Accept only alphanumeric format (letters and numbers)
  if (!/^[A-Z0-9]+$/i.test(trimmed)) {
    return false;
  }

  return true;
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
 * - Ignore dosage/posology; rely on substance codes when present and valid, else normalized names.
 * - Deterministic ordering (sorted tokens) for stable cluster IDs.
 * - Strict validation of substance codes to prevent fragmentation by dummy codes.
 */
export function computeCompositionSignature(rows: RefComposition[] | undefined): {
  signature: string;
  tokens: string[];
  bases: string[];
  nature: "FT" | "SA" | null;
} {
  if (!rows || rows.length === 0) {
    return { signature: "", tokens: [], bases: [], nature: null };
  }

  /**
   * We keep one entry per normalized base substance (salt-insensitive),
   * preferring FT over SA for the same base and choosing a single canonical
   * token (best code when present, else normalized name). This prevents
   * signatures like "Base|Base Chlorhydrate" from fragmenting clusters.
   */
  const byBase = new Map<
    string,
    { token: string; nature: "FT" | "SA"; hasFt: boolean }
  >();
  const baseAlias = new Map<string, string>();
  const nameToToken = new Map<string, string>(); // enforce consistent token per normalized name within a signature

  const tokenPriority = (token: string) => {
    if (token.startsWith("N:")) return 2;
    if (token.startsWith("C:")) return 1;
    return 0;
  };

  const compareCodeTokens = (a: string, b: string) => {
    const strip = (t: string) => t.replace(/^C:/, "");
    const na = Number.parseInt(strip(a), 10);
    const nb = Number.parseInt(strip(b), 10);
    if (Number.isFinite(na) && Number.isFinite(nb)) return na - nb;
    return strip(a).localeCompare(strip(b));
  };

  for (const row of rows) {
    if (row.nature !== "FT" && row.nature !== "SA") continue;

    const code = row.codeSubstance.trim();
    // Use the salt-insensitive normalized name as the primary clustering key.
    const nameToken = normalizeString(row.substanceName);
    const isFt = row.nature === "FT";

    const codeToken = code && isValidCode(code) ? `C:${code}` : null;
    const nameKey = nameToken || null;
    const aliasKeys = [nameKey, codeToken].filter(Boolean) as string[];

    // If this normalized name already has a chosen token, reuse it to avoid code-based splits
    if (nameKey && nameToToken.has(nameKey)) {
      const reused = nameToToken.get(nameKey)!;
      const baseKey = baseAlias.get(nameKey) ?? nameKey;
      const existing = byBase.get(baseKey);
      if (!existing) {
        byBase.set(baseKey, {
          token: reused,
          nature: row.nature,
          hasFt: isFt
        });
      } else {
        existing.hasFt = existing.hasFt || isFt;
        if (isFt && existing.nature === "SA") {
          existing.nature = "FT";
        }
      }
      continue;
    }

    let baseKey: string | null = null;
    for (const alias of aliasKeys) {
      const canonical = baseAlias.get(alias);
      if (canonical) {
        baseKey = canonical;
        break;
      }
    }

    if (!baseKey) {
      baseKey = nameKey ?? codeToken;
    }

    if (!baseKey) continue;

    for (const alias of aliasKeys) {
      baseAlias.set(alias, baseKey);
    }

    // Always prefer the normalized substance name as the token; use code only as a fallback.
    const candidateToken = nameKey ? `N:${nameKey}` : codeToken;
    if (!candidateToken) continue;

    // Record mapping for this name to the chosen token for later rows in the same signature
    if (nameKey && !nameToToken.has(nameKey)) {
      nameToToken.set(nameKey, candidateToken);
    }

    const existing = byBase.get(baseKey);
    if (!existing) {
      byBase.set(baseKey, { token: candidateToken, nature: row.nature, hasFt: isFt });
      continue;
    }

    // Decide if the candidate should replace the existing token
    const existingNatureScore = existing.hasFt ? 1 : existing.nature === "FT" ? 1 : 0;
    const candidateNatureScore = isFt ? 1 : 0;

    const existingTokenScore = tokenPriority(existing.token);
    const candidateTokenScore = tokenPriority(candidateToken);

    let shouldReplace = false;
    if (candidateNatureScore > existingNatureScore) {
      shouldReplace = true;
    } else if (candidateNatureScore === existingNatureScore) {
      if (candidateTokenScore > existingTokenScore) {
        shouldReplace = true;
      } else if (candidateTokenScore === existingTokenScore) {
        // Both codes or both names: pick the smallest/lexicographic for determinism
        const cmp = candidateTokenScore === 1
          ? compareCodeTokens(candidateToken, existing.token)
          : candidateToken.localeCompare(existing.token);
        if (cmp < 0) {
          shouldReplace = true;
        }
      }
    }

    if (shouldReplace) {
      existing.token = candidateToken;
      existing.nature = isFt ? "FT" : existing.nature;
    }
    existing.hasFt = existing.hasFt || isFt;
  }

  if (byBase.size === 0) {
    return { signature: "", tokens: [], bases: [], nature: null };
  }

  const tokens = Array.from(byBase.values())
    .map((entry) => entry.token)
    .sort((a, b) => a.localeCompare(b));

  const nature: "FT" | "SA" =
    Array.from(byBase.values()).some((entry) => entry.hasFt) ? "FT" : "SA";

  const bases = Array.from(byBase.keys()).sort((a, b) => a.localeCompare(b));

  return {
    signature: tokens.join("|"),
    tokens,
    bases,
    nature
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

export function formatCompositionDisplay(entries: CompositionEntry[]): string {
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
function buildStopWordPattern(words: Iterable<string>): RegExp {
  const escaped = Array.from(words)
    .map((w) => w?.trim())
    .filter(Boolean)
    .map((w) => escapeForRegex(w!).replace(/\s+/g, "\\s+"));
  if (escaped.length === 0) return /$a/;
  return new RegExp(`\\b(?:${escaped.join("|")})\\b`, "gi");
}

function escapeForRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

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
export function generateClusterId(label: string): string {
  const normalized = normalizeString(label);
  const safe = (normalized || label || "UNKNOWN").toUpperCase().replace(/[^A-Z0-9]/g, "_");
  return `CLS_${safe || "UNKNOWN"}`;
}

// --- Manufacturer normalization & clustering ---

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

export function levenshteinDistance(a: string, b: string): number {
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

// --- Shared helpers (tools + tests) ---

export type StoppedStatus = {
  marketing_status?: string | null;
  stopped_presentations: number;
  active_presentations: number;
};

export function isStoppedProduct(row: StoppedStatus): boolean {
  const status = (row.marketing_status ?? "").toLowerCase();
  const hasCisStop =
    status.includes("non commercialisée") ||
    status.includes("non commercialise") ||
    status.includes("arrêt") ||
    status.includes("arret");
  const allStopped = row.active_presentations === 0 && row.stopped_presentations > 0;
  return hasCisStop || allStopped;
}

export function extractBrand(label: string): string {
  if (!label) return "";
  const cleaned = label.replace(/\u00A0/g, " ");
  const head = cleaned.split(",")[0] ?? cleaned;

  const withoutRatios = head
    .replace(/\((?:[^)]*\d+(?:[.,]\d+)?\s*(?:mg|g|ml|µg|mcg|iu|u\.i\.|mui|%)\s*[^)]*)\)/gi, " ")
    .replace(
      /\b\d+(?:[.,]\d+)?\s*(?:mg|g|ug|µg|mcg|ml|m?l|l|cl|iu|ui|u\.i\.|mui|%)(?:\s*\/\s*\d+(?:[.,]\d+)?\s*(?:ml|l|g|mg|µg|mcg|iu|ui|u\.i\.?)?)?\b/gi,
      " "
    )
    .replace(/\b\d+(?:[.,]\d+)?\s*\/\s*\d+(?:[.,]\d+)?\b/gi, " ");

  const withoutDose = withoutRatios
    .replace(/\b\d+(?:[.,]\d+)?\b/gi, " ")
    .replace(
      /\b(?:mg|g|ug|µg|mcg|ml|m?l|l|cl|iu|ui|u\.i\.|mui|%|milligrammes?|grammes?|microgrammes?)\b/gi,
      " "
    )
    .replace(/\bmillions?\s*ui\b/gi, " ")
    .replace(/\s*\+\s*/g, " ");

  const formWords = [
    "COMPRIME",
    "GELULE",
    "CAPSULE",
    "SOLUTION",
    "POMMADE",
    "CREME",
    "% CREME",
    "COLLYRE",
    "SIROP",
    "SUSPENSION",
    "POUDRE",
    "INJECTABLE",
    "PERFUSION",
    "EMULSION",
    "SPRAY",
    "AEROSOL",
    "PATCH",
    "FILM",
    "SACHE",
    "SACHET",
    "LYOPHILISAT",
    "GRANULES",
    "OVULE",
    "SUPPOSITOIRE",
    "PULVERISATION",
    "GOUTTES"
  ];
  const formRegex = new RegExp(`\\b(?:${formWords.join("|")})\\b`, "gi");
  const stripped = withoutDose.replace(formRegex, " ").replace(/[-'/]/g, " ");
  const normalized = stripped.replace(/\s+/g, " ").trim();
  return normalized || head.trim();
}
