import {
  SALT_PREFIXES,
  SALT_SUFFIXES,
  MINERAL_TOKENS,
} from "./constants";
import { normalizePrincipleOptimal, normalizeForSearchIndex } from "./sanitizer";
import type { GeneriqueGroup, GroupMember, PrincipeActif } from "./types";

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
// Port of CompositionsParser from lib/core/services/ingestion/parsers/compositions_parser.dart
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
): Promise<Map<string, string>> {
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
      denomination: normalizeSaltPrefix(cols[3]),
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

  for (const [cis, linksMap] of buffer.entries()) {
    // 1. Collecter les vainqueurs par LinkID (FT > SA)
    const rawWinners: CompositionRow[] = [];
    for (const rows of linksMap.values()) {
      const winner = selectBestComponentForLink(rows);
      if (winner) rawWinners.push(winner);
    }

    // 2. CONSOLIDATION : Fusionner les variantes d'hydratation et de sels minéraux
    // Map<NomSubstanceBase, CompositionRow>
    const consolidatedComponents = new Map<string, CompositionRow>();

    for (const comp of rawWinners) {
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

  return result;
}

// --- 2. Principes Actifs Parser (Yields PrincipesActifs Rows) ---
// Port of PrincipesActifsParser from lib/core/services/ingestion/parsers/compositions_parser.dart
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
      denomination: normalizeSaltPrefix(cols[3]),
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
      if (winner) rawWinners.push(winner);
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
// Port of GeneriquesParser from lib/core/services/ingestion/parsers/generiques_parser.dart
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

