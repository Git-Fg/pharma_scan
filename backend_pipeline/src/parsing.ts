import * as cheerio from 'cheerio';
import {
  SALT_PREFIXES,
  SALT_SUFFIXES,
  MINERAL_TOKENS,
} from "./constants";
import { normalizePrincipleOptimal, normalizeForSearchIndex } from "./sanitizer";
import type { GeneriqueGroup, GroupMember, PrincipeActif, MedicamentAvailability, SafetyAlert, Specialite } from "./types";

// --- 0. Core Parsing Generators/Interfaces ---

// Mots-clés d'hydratation à supprimer pour la déduplication
const HYDRATION_TERMS = [
  'ANHYDRE',
  'HEMIPENTAHYDRATE', 'HEMIPENTAHYDRAT', 'HÉMIPENTAHYDRATÉ',
  'MONOHYDRATE', 'MONOHYDRATÉ',
  'DIHYDRATE', 'DIHYDRATÉ',
  'TRIHYDRATE', 'TRIHYDRATÉ',
  'PENTAHYDRATE', 'PENTAHYDRATÉ',
  'SESQUIHYDRATE', 'SESQUIHYDRATÉ',
  'HEXAHYDRATE', 'HEXAHYDRATÉ',
  'HEMIHYDRATE', 'HÉMIHYDRATÉ'
];

// Mots-clés de sels à supprimer pour la déduplication (variantes minérales)
const SALT_MINERAL_TERMS = [
  'POTASSIQUE',
  'SODIQUE',
  'MONOSODIQUE',
  'DISODIQUE',
  'DE SODIUM',
  'DE POTASSIUM',
  'DE CALCIUM',
  'DE MAGNESIUM',
  'MAGNESIQUE',
  'CALCIQUE',
  'ACIDE',
  'HEMIHYDRATE',
  'DICHLORHYDRATE DE'
];

/**
 * Nettoie le nom de la substance pour obtenir la "Base" stricte (pour comparaison).
 * Supprime les états d'hydratation ET les variantes de sels minéraux (potassique, sodique, etc.).
 * Retourne en majuscules pour la comparaison de clés.
 */
function normalizeToBaseSubstance(label: string): string {
  if (!label) return label;

  let clean = label.toUpperCase();

  // 1. Suppression des suffixes d'hydratation
  for (const term of HYDRATION_TERMS) {
    // Regex pour remplacer "TERME" en fin de mot ou suivi d'espace
    const regex = new RegExp(`\\b${term}\\b`, 'gi');
    clean = clean.replace(regex, '');
  }

  // 2. Suppression des variantes de sels minéraux
  for (const term of SALT_MINERAL_TERMS) {
    // Regex pour remplacer "TERME" en fin de mot ou suivi d'espace
    const regex = new RegExp(`\\b${term}\\b`, 'gi');
    clean = clean.replace(regex, '');
  }

  // 3. Nettoyage final des espaces multiples et trim
  return clean.replace(/\s+/g, ' ').trim();
}

/**
 * Supprime les termes d'hydratation et de sels minéraux d'un label tout en préservant la casse originale.
 * Utilisé pour générer le nom final après consolidation.
 */
function removeHydrationAndSaltTermsPreservingCase(label: string): string {
  if (!label) return label;

  let clean = label;

  // 1. Suppression des suffixes d'hydratation (insensible à la casse)
  for (const term of HYDRATION_TERMS) {
    // Regex insensible à la casse pour préserver la casse originale
    const regex = new RegExp(`\\b${term}\\b`, 'gi');
    clean = clean.replace(regex, '');
  }

  // 2. Suppression des variantes de sels minéraux (insensible à la casse)
  for (const term of SALT_MINERAL_TERMS) {
    // Regex insensible à la casse pour préserver la casse originale
    const regex = new RegExp(`\\b${term}\\b`, 'gi');
    clean = clean.replace(regex, '');
  }

  // 3. Nettoyage final des espaces multiples et trim
  return clean.replace(/\s+/g, ' ').trim();
}

/**
 * Remove salt suffixes from molecule names.
 * Port of _removeSaltSuffixes from parser_utils.dart
 */
function removeSaltSuffixes(label: string): string {
  if (!label) return label;

  let cleaned = normalizeSaltPrefix(label);

  for (const suffix of SALT_SUFFIXES) {
    const suffixEscaped = suffix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const suffixPattern = new RegExp(`\\s+${suffixEscaped}(?:\\s|$)`, 'i');
    cleaned = cleaned.replace(suffixPattern, ' ').trim();
  }

  return cleaned.replace(/\s+/g, ' ').trim();
}

/**
 * Smart split for BDPM labels.
 * Port of _smartSplitLabel from parser_utils.dart
 */
function smartSplitLabel(rawLabel: string): { title: string; subtitle: string; method: string } {
  let clean = rawLabel.replace(/\u00a0/g, ' ');

  // Normalize various dash types
  const dashTypes = ['–', '—', '−', '‑', '‒', '―', '–'];
  for (const dash of dashTypes) {
    clean = clean.replace(new RegExp(dash, 'g'), '-');
  }

  // Pre-process dashes: space-dash-space pattern before capital letters
  clean = clean.replace(/(?<=[a-zA-Z0-9%)])\s*-\s*(?=[A-Z])/g, ' - ');
  clean = clean.replace(/\s+-(?=[A-Z])/g, ' - ');
  clean = clean.replace(/\s{2,}/g, ' ').trim();

  if (clean.includes(' - ')) {
    const parts = clean.split(' - ');
    const subtitle = parts[parts.length - 1]?.trim() || '';
    const title = parts.slice(0, -1).join(' - ').trim();
    return {
      title: title,
      subtitle: subtitle || 'Référence inconnue',
      method: 'text_smart_split'
    };
  }

  return {
    title: clean,
    subtitle: 'Référence inconnue',
    method: 'fallback'
  };
}

/**
 * Extrait proprement la valeur et l'unité de la colonne 5 (Dosage).
 * Gère le format français (1,5 mg) et les unités complexes.
 * 
 * Stratégie "L'Héritage du Vainqueur" : Cette fonction est appelée uniquement
 * sur le dosage du composant gagnant (FT > SA), garantissant la cohérence
 * entre le nom de la substance et son dosage.
 * 
 * Exemples :
 * - "5 mg" -> { value: 5, unit: "mg" }
 * - "1,5 mg" -> { value: 1.5, unit: "mg" }
 * - "100 mg/5ml" -> { value: 100, unit: "mg/5ml" }
 */
export function parseDosage(dosageStr: string): { value: number | null; unit: string | null } {
  if (!dosageStr) return { value: null, unit: null };

  const cleanStr = dosageStr.trim();

  // Regex pour capturer le nombre (y compris décimales à virgule) au début
  // ^(\d+(?:[.,]\d+)?) -> Capture "100", "1,5", "0.5", "6.94"
  // \s*(.*)$           -> Capture tout le reste comme unité ("mg", "mg/5ml", "%")
  const match = /^(\d+(?:[.,]\d+)?)\s*(.*)$/.exec(cleanStr);

  if (!match) {
    // Cas où il n'y a pas de chiffre (rare dans dosage, possible bruit)
    return { value: null, unit: cleanStr || null };
  }

  const rawValue = match[1].replace(',', '.'); // Normalisation JS (virgule -> point)
  const unit = match[2].trim();

  const value = parseFloat(rawValue);

  return {
    value: Number.isFinite(value) ? value : null,
    unit: unit || null
  };
}

// --- 1. Compositions Parser (Yields Flattened Composition Strings) ---
// Compositions parsing logic (derived from earlier implementation);
// Improved version using linkId to group related components (SA/FT pairs)

interface CompositionRow {
  cis: string;
  substanceCode: string;
  denomination: string;
  dosage: string;
  nature: string;
  linkId: string; // <-- CRUCIAL : Colonne 8 (Lien)
}

function cellAsString(value: unknown): string {
  if (value == null) return '';
  if (typeof value === 'string') return value.trim();
  return String(value).trim();
}

/**
 * Normalizes salt prefix from molecule names.
 * Port of _normalizeSaltPrefix from parser_utils.dart
 */
function normalizeSaltPrefix(label: string): string {
  if (!label) return label;

  // Regex pattern matching Dart: r'^((?:CHLORHYDRATE|SULFATE|...)\s+(?:DE\s+|D[\u0027\u2019]))(.+)$'
  const saltPattern = /^((?:CHLORHYDRATE|SULFATE|MALEATE|MALÉATE|TARTRATE|BESILATE|BÉSILATE|MESILATE|MÉSILATE|SUCCINATE|FUMARATE|OXALATE|CITRATE|ACETATE|ACÉTATE|LACTATE|VALERATE|VALÉRATE|PROPIONATE|BUTYRATE|PHOSPHATE|NITRATE|BROMHYDRATE)\s+(?:DE\s+|D['']))(.+)$/i;
  const match = saltPattern.exec(label);
  if (match) {
    const molecule = match[2]?.trim() || '';
    // Recursively normalize in case of multiple prefixes
    return normalizeSaltPrefix(molecule);
  }

  return label;
}

/**
 * Helper to select the best component within a single LinkID group.
 * 
 * Règle de priorité : FT (Fraction Thérapeutique) > SA (Substance Active)
 * 
 * IMPORTANT - Garantie Atomique :
 * Le composant retourné par cette fonction détermine TOUT :
 * - Le nom de la substance (denomination)
 * - Le dosage (dosage)
 * - L'unité (via parseDosage)
 * 
 * Cette fonction est le "Juge de Paix" qui évite les incohérences :
 * - ❌ Mauvais : Nom FT "Amlodipine" + Dosage SA "6.94 mg"
 * - ✅ Correct : Nom FT "Amlodipine" + Dosage FT "5 mg"
 * 
 * Le dosage est atomiquement lié au composant gagnant.
 */
function selectBestComponentForLink(rows: CompositionRow[]): CompositionRow | null {
  if (rows.length === 0) return null;

  // 1. Priorité absolue au FT (Fraction Thérapeutique)
  // Le FT représente la forme thérapeutique active, c'est la référence clinique
  const ft = rows.find(r => r.nature.toUpperCase() === 'FT');
  if (ft) return ft;

  // 2. Sinon SA (Substance Active)
  // Si pas de FT, on utilise la SA comme fallback
  const sa = rows.find(r => r.nature.toUpperCase() === 'SA');
  if (sa) return sa;

  // 3. Fallback (ex: solvant, autre)
  // Cas rare où ni FT ni SA ne sont présents
  return rows[0];
}

/**
 * Parses CIS_COMPO_bdpm.txt to produce a map of CIS -> Flattened Composition String
 * Improved logic: Groups components by LinkID, then selects best (FT > SA) per link group
 */
export async function parseCompositions(
  rows: Iterable<string[]> | AsyncIterable<string[]>
): Promise<{ flattened: Map<string, string>; codes: Map<string, string[]> }> { // <--- Changed return type
  // Structure: Map<CIS, Map<LinkID, List<Rows>>>
  const buffer = new Map<string, Map<string, CompositionRow[]>>();

  for await (const row of rows) {
    const cols = row.map(cellAsString);
    // Expected columns: [CIS, ElementLabel, CodeSubstance, Denomination, Dosage, Ref, Nature, Link]
    if (cols.length < 8) continue;

    const cis = cols[0];
    const nature = cols[6]?.toUpperCase().trim(); // Index 6 = Nature (SA/FT)
    const linkId = cols[7]?.trim() || '0';        // Index 7 = Lien (1, 2...)

    if (!cis || !nature) continue;

    const compoRow: CompositionRow = {
      cis,
      substanceCode: cols[2],
      denomination: cols[3], // Raw label (Optimization: sanitize later)
      dosage: cols[4],
      nature,
      linkId
    };

    if (!buffer.has(cis)) {
      buffer.set(cis, new Map());
    }
    const cisLinks = buffer.get(cis)!;

    if (!cisLinks.has(linkId)) {
      cisLinks.set(linkId, []);
    }
    cisLinks.get(linkId)!.push(compoRow);
  }

  // Flatten logic
  const result = new Map<string, string>();
  const cisToCodes = new Map<string, string[]>(); // <--- New Map

  for (const [cis, linksMap] of buffer.entries()) {
    // 1. Collecter les vainqueurs par LinkID (FT > SA)
    const rawWinners: CompositionRow[] = [];
    for (const rows of linksMap.values()) {
      const winner = selectBestComponentForLink(rows);
      if (winner) {
        // Optimization: Normalize only the winner
        rawWinners.push({
          ...winner,
          denomination: normalizeSaltPrefix(winner.denomination)
        });
      }
    }

    // 2. CONSOLIDATION : Fusionner les variantes d'hydratation et de sels minéraux
    // Map<NomSubstanceBase, CompositionRow>
    const consolidatedComponents = new Map<string, CompositionRow>();
    const uniqueCodes = new Set<string>(); // <--- New Set for codes

    for (const comp of rawWinners) {
      // Collect the official substance code (Column 3 in BDPM)
      if (comp.substanceCode && comp.substanceCode.trim()) {
        uniqueCodes.add(comp.substanceCode.trim());
      }

      // On nettoie le nom pour la comparaison (ex: "AMOXICILLINE ANHYDRE" -> "AMOXICILLINE", 
      // "X POTASSIQUE" -> "X", "X SODIQUE" -> "X")
      const baseNameKey = normalizeToBaseSubstance(comp.denomination);

      if (!consolidatedComponents.has(baseNameKey)) {
        // Nouveau composant unique
        // On nettoie le nom pour qu'il soit "propre" (sans anhydre) en préservant la casse
        const cleanedName = removeHydrationAndSaltTermsPreservingCase(comp.denomination);
        consolidatedComponents.set(baseNameKey, {
          ...comp,
          denomination: cleanedName
        });
      } else {
        // Doublon détecté (ex: on a déjà Amox et on reçoit Amox Anhydre)
        // Stratégie de fusion : On garde celui qui a un dosage défini, 
        // ou on garde le premier (souvent le FT est déjà passé).

        const existing = consolidatedComponents.get(baseNameKey)!;

        // Si l'existant n'a pas de dosage mais le nouveau oui, on remplace
        // (C'est rare avec la logique FT > SA, mais prudent)
        if ((!existing.dosage || existing.dosage.trim() === '') && (comp.dosage && comp.dosage.trim() !== '')) {
          const cleanedName = removeHydrationAndSaltTermsPreservingCase(comp.denomination);
          consolidatedComponents.set(baseNameKey, {
            ...comp,
            denomination: cleanedName
          });
        }
      }
    }

    // Store the codes for this CIS
    if (uniqueCodes.size > 0) {
      cisToCodes.set(cis, Array.from(uniqueCodes).sort());
    }

    // 3. Conversion en liste
    const finalComponents = Array.from(consolidatedComponents.values());

    // 4. Tri par LinkID (pour stabilité)
    finalComponents.sort((a, b) => {
      const linkA = parseInt(a.linkId);
      const linkB = parseInt(b.linkId);
      if (!isNaN(linkA) && !isNaN(linkB)) return linkA - linkB;
      return a.denomination.localeCompare(b.denomination);
    });

    // 5. Formatage final
    const parts = finalComponents.map(r => {
      // GARANTIE ATOMIQUE : Le dosage utilisé est strictement celui du vainqueur (FT > SA)
      // Si FT a gagné, on utilise le dosage du FT. Si SA a gagné, on utilise le dosage du SA.
      // Aucun mélange entre nom FT et dosage SA (évite "Amlodipine 6.94 mg" au lieu de "Amlodipine 5 mg")
      const dosage = r.dosage ? ` ${r.dosage.trim()}` : '';
      return `${r.denomination}${dosage}`.trim();
    });

    result.set(cis, parts.join(' + '));
  }

  return { flattened: result, codes: cisToCodes };
}

// --- 2. Principes Actifs Parser (Yields PrincipesActifs Rows) ---
// Principes actifs parsing logic (derived from earlier implementation)
// Improved version using linkId to group related components (SA/FT pairs)

/**
 * Parses CIS_COMPO_bdpm.txt to produce normalized Principes Actifs rows
 * Logic: Groups by LinkID, then selects best (FT > SA) per link group
 */
export async function parsePrincipesActifs(
  rows: Iterable<string[]> | AsyncIterable<string[]>,
  cisToCip13: Map<string, string[]>
): Promise<PrincipeActif[]> {
  const principes: PrincipeActif[] = [];
  // Structure: Map<CIS, Map<LinkID, List<Rows>>>
  const buffer = new Map<string, Map<string, CompositionRow[]>>();

  // 1. Accumulate ALL rows by (CIS + LinkID)
  for await (const row of rows) {
    const cols = row.map(cellAsString);
    if (cols.length < 8) continue;

    const cis = cols[0];
    if (!cisToCip13.has(cis)) continue;

    const nature = cols[6]?.toUpperCase().trim();
    const linkId = cols[7]?.trim() || '0';

    const compoRow: CompositionRow = {
      cis,
      substanceCode: cols[2],
      denomination: cols[3], // Raw label (Optimization: sanitize later)
      dosage: cols[4],
      nature,
      linkId
    };

    if (!buffer.has(cis)) {
      buffer.set(cis, new Map());
    }
    const cisLinks = buffer.get(cis)!;
    if (!cisLinks.has(linkId)) {
      cisLinks.set(linkId, []);
    }
    cisLinks.get(linkId)!.push(compoRow);
  }

  function stripBaseSuffix(value: string): string {
    return value.replace(/\s+BASE$/i, '').trim();
  }

  // 2. Process winners per LinkID with consolidation
  for (const [cis, linksMap] of buffer.entries()) {
    const cip13s = cisToCip13.get(cis);
    if (!cip13s) continue;

    // 2.1. Collecter les vainqueurs par LinkID (FT > SA)
    const rawWinners: CompositionRow[] = [];
    for (const rows of linksMap.values()) {
      const winner = selectBestComponentForLink(rows);
      if (winner) {
        // Optimization: Normalize only the winner
        rawWinners.push({
          ...winner,
          denomination: normalizeSaltPrefix(winner.denomination)
        });
      }
    }

    // 2.2. CONSOLIDATION : Fusionner les variantes d'hydratation et de sels minéraux
    // Map<NomSubstanceBase, CompositionRow>
    const consolidatedComponents = new Map<string, CompositionRow>();

    for (const comp of rawWinners) {
      // On nettoie le nom pour la comparaison (ex: "AMOXICILLINE ANHYDRE" -> "AMOXICILLINE", 
      // "X POTASSIQUE" -> "X", "X SODIQUE" -> "X")
      const baseNameKey = normalizeToBaseSubstance(comp.denomination);

      if (!consolidatedComponents.has(baseNameKey)) {
        // Nouveau composant unique
        // On nettoie le nom pour qu'il soit "propre" (sans anhydre/sels) en préservant la casse
        const cleanedName = removeHydrationAndSaltTermsPreservingCase(comp.denomination);
        consolidatedComponents.set(baseNameKey, {
          ...comp,
          denomination: cleanedName
        });
      } else {
        // Doublon détecté (ex: on a déjà Amox et on reçoit Amox Anhydre)
        // Stratégie de fusion : On garde celui qui a un dosage défini, 
        // ou on garde le premier (souvent le FT est déjà passé).

        const existing = consolidatedComponents.get(baseNameKey)!;

        // Si l'existant n'a pas de dosage mais le nouveau oui, on remplace
        // (C'est rare avec la logique FT > SA, mais prudent)
        if ((!existing.dosage || existing.dosage.trim() === '') && (comp.dosage && comp.dosage.trim() !== '')) {
          const cleanedName = removeHydrationAndSaltTermsPreservingCase(comp.denomination);
          consolidatedComponents.set(baseNameKey, {
            ...comp,
            denomination: cleanedName
          });
        }
      }
    }

    // 2.3. Générer les entrées PrincipeActif à partir des composants consolidés
    for (const winner of Array.from(consolidatedComponents.values())) {
      // GARANTIE ATOMIQUE : Le dosage est strictement celui du vainqueur
      // Si FT a gagné, on utilise le dosage du FT. Si SA a gagné, on utilise le dosage du SA.
      // Cela évite les incohérences comme "Amlodipine 6.94 mg" (nom FT + dosage SA)
      // au lieu de "Amlodipine 5 mg" (nom FT + dosage FT).
      const { value: dosageVal, unit: dosageUnit } = parseDosage(winner.dosage);

      // Nettoyage final du nom (suppression suffixe BASE si présent dans FT)
      const principle = stripBaseSuffix(winner.denomination);
      const normalizedPrinciple = principle
        ? normalizePrincipleOptimal(principle)
        : undefined;
      const dosageText = dosageVal?.toString();

      for (const cip13 of cip13s) {
        principes.push({
          codeCip: cip13,
          principe: principle,
          principeNormalized: normalizedPrinciple,
          dosage: dosageText,
          dosageUnit: dosageUnit ?? undefined
        });
      }
    }
  }

  return principes;
}

// --- 3. Generiques Parser (Yields Groups and Members) ---
// Generique group parsing logic (derived from earlier implementation)
// Logic: 3-Tier parsing (relational > text_split > smart_split)

interface GroupAccumulator {
  rawLabel: string;
  members: Array<{ cis: string; type: number }>;
}

export interface GeneriquesParseResult {
  groups: GeneriqueGroup[];
  members: GroupMember[];
}

/**
 * Parses CIS_GENER_bdpm.txt to produce groups with 3-Tier logic:
 * 1. Relational (if princeps CIS has composition and specialite name)
 * 2. Text Split (if label contains " - ")
 * 3. Smart Split (fallback)
 */
export async function parseGeneriques(
  rows: Iterable<string[]> | AsyncIterable<string[]>,
  cisToCip13: Map<string, string[]>,
  medicamentCips: Set<string>,
  compositionMap: Map<string, string>, // Map<CIS, FlattenedComposition>
  specialitesMap: Map<string, string>  // Map<CIS, SpecialiteName>
): Promise<GeneriquesParseResult> {
  const generiqueGroups: GeneriqueGroup[] = [];
  const groupMembers: GroupMember[] = [];
  const seenGroups = new Set<string>();
  const groupMeta = new Map<string, GroupAccumulator>();

  // 1. Accumulate Members (same as Dart)
  for await (const row of rows) {
    if (row.length < 4) continue;
    const parts = row.map(cellAsString);
    // Expected: [GroupId, Label, CIS, Type, Sort]
    const groupId = parts[0];
    const libelle = parts[1];
    const cis = parts[2];
    const typeRaw = parts[3];
    const sortRaw = parts[4] || '0'; // Colonne 5 : ordre de tri (défaut 0 si absente)

    const type = parseInt(typeRaw, 10);
    const sortOrder = parseInt(sortRaw, 10) || 0; // Parsing sécurisé avec fallback à 0
    const cip13s = cisToCip13.get(cis);
    const isPrinceps = type === 0;
    const isRecognizedGeneric = type === 1 || type === 2 || type === 3 || type === 4;

    if (cip13s && (isPrinceps || isRecognizedGeneric) && !isNaN(type)) {
      const accumulator = groupMeta.get(groupId) || { rawLabel: libelle, members: [] };
      if (!groupMeta.has(groupId)) {
        groupMeta.set(groupId, accumulator);
      }
      accumulator.members.push({ cis, type });

      // Update rawLabel on first sight (Dart: seenGroups.add returns true if newly added)
      if (!seenGroups.has(groupId)) {
        seenGroups.add(groupId);
        accumulator.rawLabel = libelle;
      }

      for (const cip13 of cip13s) {
        if (medicamentCips.has(cip13)) {
          groupMembers.push({
            codeCip: cip13,
            groupId,
            type,
            sortOrder // Ajouté pour départager les princeps au sein d'un même groupe
          });
        }
      }
    }
  }

  // 2. Process Groups (3-Tiers: relational > text_split > smart_split)
  for (const [groupId, acc] of groupMeta.entries()) {
    const rawLabel = acc.rawLabel.trim();

    // Find princeps member (type 0)
    let princepsMember: { cis: string; type: number } | undefined;
    for (const member of acc.members) {
      if (member.type === 0) {
        princepsMember = member;
        break;
      }
    }
    const princepsCis = princepsMember?.cis;

    const relationalMolecule = princepsCis ? compositionMap.get(princepsCis) : undefined;
    const relationalPrinceps = princepsCis ? specialitesMap.get(princepsCis) : undefined;

    let parsingMethod: string;
    let moleculeLabel: string;
    let princepsLabel: string;

    // Tier 1: Relational (if both composition and specialite name exist)
    if (relationalMolecule != null && relationalPrinceps != null) {
      parsingMethod = 'relational';
      moleculeLabel = relationalMolecule;
      princepsLabel = relationalPrinceps;
    }
    // Tier 2: Text Split (if label contains " - ")
    else if (rawLabel.includes(' - ')) {
      parsingMethod = 'text_split';
      const segments = rawLabel.split(' - ');
      const firstSegment = segments[0]?.trim() || '';
      const lastSegmentRaw = segments.length > 1 ? segments[segments.length - 1]?.trim() : '';
      // Extract princeps name: remove trailing period and dosage if present
      // Example: "CLAMOXYL 1g" -> "CLAMOXYL"
      princepsLabel = lastSegmentRaw.replace(/\.$/, '').trim();
      // Remove dosage pattern (e.g., "1g", "500mg", "1000 UI") from the end
      princepsLabel = princepsLabel.replace(/\s+\d+.*$/, '').trim();
      moleculeLabel = normalizeSaltPrefix(removeSaltSuffixes(firstSegment).trim());
    }
    // Tier 3: Smart Split (fallback)
    else {
      const splitResult = smartSplitLabel(rawLabel);
      parsingMethod = splitResult.method;
      moleculeLabel = splitResult.title;
      princepsLabel = splitResult.subtitle;
    }

    if (!princepsLabel) {
      princepsLabel = 'Référence inconnue';
    }

    const cleanedMoleculeLabel = moleculeLabel.replace(/\s*\([^)]+\)\s*$/, '').trim();

    generiqueGroups.push({
      groupId,
      libelle: moleculeLabel,
      princepsLabel,
      moleculeLabel: cleanedMoleculeLabel,
      rawLabel,
      parsingMethod
    });
  }

  return { groups: generiqueGroups, members: groupMembers };
}

/**
 * NOUVEAU: Extraction légère des métadonnées de tri/type pour le clustering Golden Source
 */
export async function parseGenericsMetadata(
  rows: Iterable<string[]> | AsyncIterable<string[]>,
  validCisSet: Set<string>
): Promise<Map<string, { label: string; type: number; sortIndex: number; cisExists: boolean }>> {

  const cisToGroup = new Map<string, { label: string; type: number; sortIndex: number; cisExists: boolean }>();

  for await (const row of rows) {
    // Structure CIS_GENER_bdpm.txt :
    // 0: Id Grp, 1: Libellé Grp, 2: CIS, 3: Type, 4: Tri

    // Safety check for row length
    if (row.length < 5) continue;

    const cis = row[2]?.trim();
    if (!cis) continue;

    const typeRaw = row[3]?.trim() || "99";
    const sortRaw = row[4]?.trim() || "999";

    const type = parseInt(typeRaw, 10);
    const sortIndex = parseInt(sortRaw, 10);
    const label = row[1]?.trim() || "Groupe Inconnu";

    // Vérifie si ce CIS est "vivant" dans notre base principale
    const cisExists = validCisSet.has(cis);

    // On stocke simplement. Si un CIS apparaît plusieurs fois (rare mais possible dans des groupes différents?),
    // on écrase. En théorie un CIS appartient à un seul groupe générique.
    cisToGroup.set(cis, {
      label,
      type: isNaN(type) ? 99 : type,
      sortIndex: isNaN(sortIndex) ? 999 : sortIndex,
      cisExists
    });
  }

  return cisToGroup;
}

// --- 4. ATC Codes Parser (CIS_MITM.txt) ---

/**
 * Parses CIS_MITM.txt to extract ATC Codes.
 * Returns a Map<CIS, ATC_CODE>
 */
export async function parseAtcCodes(
  rows: Iterable<string[]> | AsyncIterable<string[]>
): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  for await (const row of rows) {
    if (row.length >= 2) {
      const cis = row[0]?.trim();
      const atc = row[1]?.trim(); // Code ATC (ex: J01AA02)
      if (cis && atc) {
        map.set(cis, atc);
      }
    }
  }
  return map;
}

// --- 5. Prescription Conditions Parser (CIS_CPD_bdpm.txt) ---

/**
 * Parses CIS_CPD_bdpm.txt to extract Prescription Conditions.
 * Returns a Map<CIS, FullConditionString>
 * Multiple conditions for the same CIS are joined with " | "
 */
export async function parseConditions(
  rows: Iterable<string[]> | AsyncIterable<string[]>
): Promise<Map<string, string>> {
  const map = new Map<string, string[]>();

  for await (const row of rows) {
    if (row.length >= 2) {
      const cis = row[0]?.trim();
      const condition = row[1]?.trim();
      if (cis && condition) {
        if (!map.has(cis)) map.set(cis, []);
        map.get(cis)!.push(condition);
      }
    }
  }

  // Flatten array to single string for DB storage
  const result = new Map<string, string>();
  for (const [cis, conds] of map.entries()) {
    result.set(cis, conds.join(" | "));
  }
  return result;
}

// --- 6. Availability Parser (CIS_CIP_Dispo_Spec.txt) ---

/**
 * Parses CIS_CIP_Dispo_Spec.txt for Shortages.
 * Returns availability objects.
 * Columns: [0]CIS, [1]CIP13, [2]CodeStatut, [3]Libellé, [4]DateDebut, [5]DateFin, [6]DateRetour, [7]Lien
 * 
 * IMPORTANT: If CIP13 (col 1) is empty, the alert applies to ALL CIPs of the CIS.
 * In this case, we create an entry for each CIP of that CIS.
 */
export async function parseAvailability(
  rows: Iterable<string[]> | AsyncIterable<string[]>,
  activeCips: Set<string>, // Only keep relevant CIPs
  cisToCip13: Map<string, string[]> // Map CIS -> CIP13s (for CIS-level alerts)
): Promise<MedicamentAvailability[]> {
  const results: MedicamentAvailability[] = [];

  for await (const row of rows) {
    // Columns: [0]CIS, [1]CIP13, [2]CodeStatut, [3]Libellé, [4]DateDebut, [5]DateFin, [6]DateRetour, [7]Lien
    const cis = row[0]?.trim();
    const cip = row[1]?.trim();
    const statut = row[3]?.trim() || "Inconnu";
    const dateDebut = row[4]?.trim() || undefined;
    const dateFin = row[5]?.trim() || undefined;
    const lien = row[7]?.trim() || undefined;

    if (!cis) continue;

    // Case 1: CIP13 is specified -> alert applies only to this CIP
    if (cip) {
      if (activeCips.has(cip)) {
        results.push({
          codeCip: cip,
          statut,
          dateDebut,
          dateFin,
          lien
        });
      }
    }
    // Case 2: CIP13 is empty -> alert applies to ALL CIPs of the CIS
    else {
      const cipsForCis = cisToCip13.get(cis);
      if (cipsForCis) {
        for (const cip13 of cipsForCis) {
          if (activeCips.has(cip13)) {
            results.push({
              codeCip: cip13,
              statut,
              dateDebut,
              dateFin,
              lien
            });
          }
        }
      }
    }
  }
  return results;
}

// --- 7. Safety Alerts Parser (CIS_InfoImportante.txt) ---

/**
 * Helper: Compare DD/MM/YYYY dates
 * Returns: -1 if d1 < d2, 0 if equal, 1 if d1 > d2
 */
function compareBdpmDates(d1: string, d2: string): number {
  if (!d1 || !d2) return 0;

  // Convert DD/MM/YYYY to YYYYMMDD for string comparison
  const toIso = (d: string): string => {
    if (d.includes('-')) {
      // Already YYYY-MM-DD format
      return d.replace(/-/g, '');
    }
    const parts = d.split('/');
    if (parts.length !== 3) return '';
    // Ensure 2-digit day and month
    const day = parts[0].padStart(2, '0');
    const month = parts[1].padStart(2, '0');
    const year = parts[2];
    return `${year}${month}${day}`;
  };

  const iso1 = toIso(d1);
  const iso2 = toIso(d2);
  if (!iso1 || !iso2) return 0;

  return iso1.localeCompare(iso2);
}

/**
 * Parse CIS_InfoImportante.txt
 * Format: CIS, DateDebut, DateFin, Texte
 * Only keeps alerts that are active (dateFin is empty or in the future)
 */
export async function parseSafetyAlerts(
  rows: Iterable<string[]> | AsyncIterable<string[]>
): Promise<SafetyAlert[]> {
  const alerts: SafetyAlert[] = [];
  const now = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

  for await (const row of rows) {
    if (row.length >= 4) {
      const cis = row[0]?.trim();
      const dateDebut = row[1]?.trim();
      const dateFin = row[2]?.trim();
      const texte = row[3]?.trim();

      if (cis && texte) {
        // On ne garde que les alertes en cours ou futures (pas celles périmées)
        // Si dateFin est vide, l'alerte est toujours active
        if (!dateFin || compareBdpmDates(dateFin, now) >= 0) {
          alerts.push({
            cisCode: cis,
            dateDebut: dateDebut || '',
            dateFin: dateFin || '',
            texte: texte
          });
        }
      }
    }
  }
  return alerts;
}

export interface ParsedSafetyAlert {
  cisCode: string;
  dateDebut: string;
  dateFin: string;
  url: string;
  message: string;
}

// HTML parsing is handled via Cheerio (see parseSafetyAlertsOptimized)

/**
 * Improved parser that extracts URL, cleans HTML, deduplicates alerts and
 * returns a lightweight list of links cis->alertIndex.
 */
export async function parseSafetyAlertsOptimized(
  rows: AsyncIterable<string[]>
): Promise<{ alerts: Omit<ParsedSafetyAlert, 'cisCode'>[]; links: { cis: string; alertIndex: number }[] }> {
  const uniqueAlertsMap = new Map<string, number>();
  const alerts: Omit<ParsedSafetyAlert, 'cisCode'>[] = [];
  const links: { cis: string; alertIndex: number }[] = [];

  for await (const row of rows) {
    if (row.length < 4) continue;

    const cisCode = row[0]?.trim();
    const dateDebut = row[1]?.trim() || '';
    const dateFin = row[2]?.trim() || '';
    const rawHtml = row[3] || '';

    if (!cisCode) continue;

    // Parse HTML robustly using Cheerio (fast fragment mode)
    const $ = cheerio.load(rawHtml, null, false);
    const link = $('a').first();

    // Extraction sécurisée
    let url = link.attr('href') || '';
    let message = link.text().trim(); // Cheerio décodera automatiquement les entités

    // If no <a> present, fall back to extracting text from the raw HTML fragment
    if (link.length === 0) {
      message = cheerio.load(`<div>${rawHtml}</div>`).text().trim();
      url = '';
    }

    if (!message) continue;

    const key = `${dateDebut}|${dateFin}|${url}|${message}`;

    let alertIndex = uniqueAlertsMap.get(key);
    if (alertIndex === undefined) {
      alertIndex = alerts.length;
      alerts.push({ dateDebut, dateFin, url, message });
      uniqueAlertsMap.set(key, alertIndex);
    }

    links.push({ cis: cisCode, alertIndex });
  }

  return { alerts, links };
}

/**
 * Helper: Compare YYYYMMDD dates (format used in SMR/ASMR files)
 * Returns: -1 if d1 < d2, 0 if equal, 1 if d1 > d2
 */
function compareYyyyMmDdDates(d1: string, d2: string): number {
  if (!d1 || !d2) return 0;
  // Dates are already in YYYYMMDD format, can compare directly as strings
  if (d1 < d2) return -1;
  if (d1 > d2) return 1;
  return 0;
}

// --- 8. SMR Parser (CIS_HAS_SMR_bdpm.txt) ---

export type SmrEvaluation = {
  niveau: string;
  date: string;
};

/**
 * Parse CIS_HAS_SMR_bdpm.txt to get the latest evaluation
 * Format: CIS, CodeCT, TypeAvis, Date (YYYYMMDD), NiveauSMR, Texte
 * Returns Map<CIS, { niveau, date }> (keeping only the most recent evaluation per CIS)
 */
export async function parseSMR(
  rows: Iterable<string[]> | AsyncIterable<string[]>
): Promise<Map<string, SmrEvaluation>> {
  // Map CIS -> {date, niveau}
  // On doit garder uniquement le SMR le plus récent pour chaque CIS
  const tempMap = new Map<string, { date: string, niveau: string }>();

  for await (const row of rows) {
    // Format: CIS, CodeCT, TypeAvis, Date (YYYYMMDD), NiveauSMR, Texte
    if (row.length >= 6) {
      const cis = row[0]?.trim();
      const dateAvis = row[3]?.trim(); // Format YYYYMMDD
      const niveau = row[4]?.trim(); // NiveauSMR (ex: "Important", "Modéré", "Faible", "Insuffisant")

      if (cis && niveau) {
        if (!tempMap.has(cis)) {
          tempMap.set(cis, { date: dateAvis || '', niveau });
        } else {
          // Si cette ligne est plus récente, on remplace
          const existing = tempMap.get(cis)!;
          if (dateAvis && compareYyyyMmDdDates(dateAvis, existing.date) > 0) {
            tempMap.set(cis, { date: dateAvis, niveau });
          }
        }
      }
    }
  }

  // Return Map<CIS, { niveau, date }>
  const result = new Map<string, SmrEvaluation>();
  for (const [cis, val] of tempMap.entries()) {
    result.set(cis, { niveau: val.niveau, date: val.date });
  }
  return result;
}

// --- 9. ASMR Parser (CIS_HAS_ASMR_bdpm.txt) ---

export type AsmrEvaluation = {
  niveau: string;
  date: string;
};

/**
 * Parse CIS_HAS_ASMR_bdpm.txt to get the latest evaluation
 * Format: CIS, CodeCT, TypeAvis, Date (YYYYMMDD), NiveauASMR, Texte
 * Returns Map<CIS, { niveau, date }> (keeping only the most recent evaluation per CIS)
 */
export async function parseASMR(
  rows: Iterable<string[]> | AsyncIterable<string[]>
): Promise<Map<string, AsmrEvaluation>> {
  // Map CIS -> {date, niveau}
  // On doit garder uniquement l'ASMR le plus récent pour chaque CIS
  const tempMap = new Map<string, { date: string, niveau: string }>();

  for await (const row of rows) {
    // Format: CIS, CodeCT, TypeAvis, Date (YYYYMMDD), NiveauASMR, Texte
    if (row.length >= 6) {
      const cis = row[0]?.trim();
      const dateAvis = row[3]?.trim(); // Format YYYYMMDD
      const niveau = row[4]?.trim(); // NiveauASMR (ex: "I", "II", "III", "IV", "V")

      if (cis && niveau) {
        if (!tempMap.has(cis)) {
          tempMap.set(cis, { date: dateAvis || '', niveau });
        } else {
          // Si cette ligne est plus récente, on remplace
          const existing = tempMap.get(cis)!;
          if (dateAvis && compareYyyyMmDdDates(dateAvis, existing.date) > 0) {
            tempMap.set(cis, { date: dateAvis, niveau });
          }
        }
      }
    }
  }

  // Return Map<CIS, { niveau, date }>
  const result = new Map<string, AsmrEvaluation>();
  for (const [cis, val] of tempMap.entries()) {
    result.set(cis, { niveau: val.niveau, date: val.date });
  }
  return result;
}


// --- 10. Normalization Helpers (Moved from normalization.ts) ---

export function extractForms(specialites: Specialite[]): Set<string> {
  const forms = new Set<string>();
  for (const s of specialites) {
    if (s.formePharmaceutique && s.formePharmaceutique.trim()) {
      forms.add(s.formePharmaceutique.trim());
    }
  }
  return forms;
}

export function extractRoutes(specialites: Specialite[]): Set<string> {
  const routes = new Set<string>();
  for (const s of specialites) {
    if (s.voiesAdministration) {
      const parts = s.voiesAdministration.split(";");
      for (const part of parts) {
        const trimmed = part.trim();
        if (trimmed) {
          routes.add(trimmed);
        }
      }
    }
  }
  return routes;
}
