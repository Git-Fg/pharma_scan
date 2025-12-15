import { normalizePrincipleOptimal, generateGroupingKey, applyPharmacologicalMask, normalizeCommonPrincipes } from "./sanitizer";
import crypto from "crypto";
import { ClusterData } from "./types";

export interface ClusteringInput {
  groupId: string;
  princepsCisCode: string | null;
  princepsReferenceName: string;
  princepsForm: string | null; // Forme pharmaceutique du princeps (pour masque galénique)
  commonPrincipes: string; // "P1 + P2" or "P1, P2"
  isPrincepsGroup: boolean; // Indique si le groupe contient un Type 0 (vrai princeps)
}

/**
 * Build search vector for FTS5 indexing - THE ONLY place for search keyword generation
 * Concatenates substance, primary princeps, and secondary princeps
 * then applies heavy normalization for fuzzy matching
 */
export function buildSearchVector(
  substance: string,
  primaryPrinceps: string,
  secondaryPrincepsList: string[]
): string {
  // 1. Collect (Set for deduplication)
  const keywords = new Set<string>();

  keywords.add(substance);
  keywords.add(primaryPrinceps);
  secondaryPrincepsList.forEach(p => keywords.add(p));

  // 2. Concatenation
  let vector = Array.from(keywords).join(' ');

  // 3. "Kärcher" cleaning (Normalisation lourde)
  return vector
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "") // Sans accents
    .toUpperCase()
    // Retrait du bruit médical inutile pour la recherche conceptuelle
    .replace(/\b(COMPRIME|GELULE|SIROP|SACHET|DOSE|FLACON|MG|ML|BASE|ANHYDRE)\b/g, " ")
    .replace(/[^A-Z0-9]/g, " ") // Garde uniquement Alphanumérique
    .replace(/\s+/g, " ")       // Trim espaces
    .trim();
}

/**
 * Trouve le préfixe commun (mot par mot) d'une liste de chaînes.
 * Ex: ["CLAMOXYL 125", "CLAMOXYL 500"] -> "CLAMOXYL"
 * Ex: ["DOLIPRANE 1000", "DOLIPRANE 500"] -> "DOLIPRANE"
 * Ex: ["SPASFON", "SPASFON LYOC"] -> "SPASFON"
 *
 * Cette fonction travaille mot par mot (plus sûr que caractère par caractère)
 * pour éviter de couper un mot en deux et garantir un préfixe sémantiquement cohérent.
 */
export function findCommonWordPrefix(strings: string[]): string {
  if (strings.length === 0) return "";
  if (strings.length === 1) return strings[0];

  // 1. On découpe tout en mots (split sur espace)
  const arrays = strings.map(s => s.trim().split(/\s+/));

  // 2. On prend le premier tableau comme référence
  const firstArr = arrays[0];
  const commonWords: string[] = [];

  // 3. On itère mot par mot
  for (let i = 0; i < firstArr.length; i++) {
    const word = firstArr[i];

    // Vérifie si ce mot existe au même index dans TOUTES les autres chaînes
    const isCommon = arrays.every(arr =>
      arr.length > i && arr[i].toUpperCase() === word.toUpperCase()
    );

    if (isCommon) {
      commonWords.push(word);
    } else {
      break; // Dès qu'un mot diffère, on arrête (c'est un préfixe)
    }
  }

  return commonWords.join(" ");
}

/**
 * Normalizes commonPrincipes for comparison using optimal normalization.
 * Port of normalizeCommonPrincipes from grouping_algorithms.dart
 */
function normalizeCommonPrinciples(commonPrincipes: string): string {
  if (!commonPrincipes) return "";

  // Associations are delimited by "+", otherwise by comma.
  const rawList = commonPrincipes.includes("+")
    ? commonPrincipes.split("+")
    : commonPrincipes.split(",");

  // Normalize principles, deduplicate, then sort for stable comparison.
  const normalizedSet = new Set<string>();
  for (const p of rawList) {
    const trimmed = p.trim();
    if (trimmed) {
      const normalized = normalizePrincipleOptimal(trimmed);
      if (normalized) {
        normalizedSet.add(normalized);
      }
    }
  }

  const normalizedList = Array.from(normalizedSet).sort();
  return normalizedList.join(", ").trim();
}

/**
 * Deterministic hash for cluster ID generation.
 * Ensures consistent IDs across pipeline runs if data is stable.
 */
function generateClusterId(key: string): string {
  return "CLS_" + crypto.createHash("md5").update(key).digest("hex").substring(0, 8).toUpperCase();
}

export interface ClusterMetadata {
  clusterId: string;
  substanceCode: string;
  princepsLabel: string;
  secondaryPrinceps: string[]; // Noms de princeps secondaires (co-marketing, rachats)
}

/**
 * Simplified clustering strategy that relies on group_members relationship checks
 * and eliminates complex suspicious cluster detection logic.
 *
 * Strategy:
 * 1. Hard Link (via Princeps CIS) - highest confidence
 * 2. Soft Link (via Normalized Common Principles) - fallback
 * 3. Fallback: Unique clusters for orphans
 *
 * Returns a map from groupId to cluster metadata (clusterId, substanceCode, princepsLabel)
 */
export function computeClusters(items: ClusteringInput[]): Map<string, ClusterMetadata> {
  // Map<GroupId, ClusterMetadata>
  const groupToCluster = new Map<string, ClusterMetadata>();

  if (items.length === 0) return groupToCluster;

  // ===== PHASE 1: BUILD CIS-TO-PRINCIPLE MAP (Hard Link) =====
  // Map each princeps CIS code to a normalized principle name.
  // If multiple principles map to one CIS, prefer the shortest/cleanest one.
  const cisToPrincipleMap = new Map<string, string>();

  for (const item of items) {
    if (item.princepsCisCode && item.commonPrincipes) {
      const normalized = normalizeCommonPrincipes(item.commonPrincipes);
      if (normalized.length > 2) {
        const cisCodeString = item.princepsCisCode;
        const existing = cisToPrincipleMap.get(cisCodeString);
        if (!existing) {
          // First mapping for this CIS
          cisToPrincipleMap.set(cisCodeString, normalized);
        } else {
          // Conflict resolution: prefer shorter/cleaner principle name
          if (
            normalized.length < existing.length ||
            (normalized.length === existing.length && normalized < existing)
          ) {
            cisToPrincipleMap.set(cisCodeString, normalized);
          }
        }
      }
    }
  }

  // ===== PHASE 2: GROUPING =====
  const groupedByPrincipes = new Map<string, ClusteringInput[]>();

  for (const item of items) {
    let groupingKey: string;

    // 1. Hard Link via Princeps CIS (highest confidence)
    if (item.princepsCisCode && cisToPrincipleMap.has(item.princepsCisCode)) {
      groupingKey = cisToPrincipleMap.get(item.princepsCisCode)!;
    }
    // 2. Soft Link via Common Principles (fallback)
    else if (item.commonPrincipes) {
      groupingKey = normalizeCommonPrincipes(item.commonPrincipes);
      // Validate soft link quality - must be meaningful
      if (groupingKey.length <= 2) {
        groupingKey = `UNIQUE_${item.groupId}`;
      }
    }
    // 3. Fallback: Unique clusters for orphans
    else {
      groupingKey = `UNIQUE_${item.groupId}`;
    }

    if (!groupedByPrincipes.has(groupingKey)) {
      groupedByPrincipes.set(groupingKey, []);
    }
    groupedByPrincipes.get(groupingKey)!.push(item);
  }

  // ===== PHASE 3: Generate Cluster IDs and Metadata =====
  for (const [key, clusterItems] of groupedByPrincipes.entries()) {
    // Determine substance code (use key if not UNIQUE_)
    let substanceCode = key.startsWith("UNIQUE_") ? "" : key;

    // If forced to UNIQUE_, try to extract substance from first item
    if (!substanceCode && clusterItems.length > 0) {
      substanceCode = normalizeCommonPrincipes(clusterItems[0].commonPrincipes);
    }

    // --- STRATÉGIE DE NOMMAGE HYBRIDE (VOTE + PREFIXE COMMUN) ---
    // --- LOGIQUE MULTI-PRINCEPS (Primaires vs Secondaires) ---

    // 1. Compter les occurrences de chaque NOM de princeps (déjà cleané par le masque)
    // On ne regarde QUE les groupes qui ont un vrai princeps (isPrincepsGroup)
    const candidates = new Map<string, number>();

    for (const item of clusterItems) {
      if (item.isPrincepsGroup && item.princepsReferenceName) {
        // Application du masque galénique pour avoir le nom court "ADVIL"
        let name = item.princepsReferenceName.trim();
        if (name && name !== "Référence inconnue") {
          if (item.princepsForm) {
            name = applyPharmacologicalMask(name, item.princepsForm);
          }

          // Compter les occurrences (chaque groupe princeps = 1 vote)
          candidates.set(name, (candidates.get(name) || 0) + 1);
        }
      }
    }

    let finalLabel = "";
    let secondaries: string[] = [];

    if (candidates.size > 0) {
      // Trier par fréquence décroissante
      const sorted = Array.from(candidates.entries()).sort((a, b) => {
        const freqCompare = b[1] - a[1];
        if (freqCompare !== 0) return freqCompare;
        // En cas d'égalité, le plus court gagne (souvent le plus générique/propre)
        return a[0].length - b[0].length;
      });

      // LE VAINQUEUR (Le plus fréquent)
      const winnerName = sorted[0][0];

      // LES SECONDAIRES (Les autres)
      secondaries = sorted.slice(1).map(e => e[0]);

      // RAFFINAGE DU TITRE (LCP sur le vainqueur uniquement)
      // On récupère toutes les variations brutes qui ont mené à ce vainqueur
      // Ex: "ADVIL 200", "ADVIL 400" -> ont tous donné "ADVIL" après masque
      // Ici, comme on a déjà masqué, le winnerName EST le nom clean.
      // Si on veut être ultra-précis, on pourrait refaire un LCP sur les noms originaux correspondant au winner.
      // Mais avec le masque galénique, winnerName est déjà excellent ("ADVIL").

      finalLabel = winnerName;

    } else {
      // Fallback Orphelin (Logique existante LCP ou Vote simple)
      // Collecter les noms candidats (déjà nettoyés par le masque galénique)
      const allCandidates: string[] = [];

      for (const item of clusterItems) {
        const name = item.princepsReferenceName.trim();
        if (name && name !== "Référence inconnue") {
          // Application du masque galénique si disponible
          let cleanedName = name;
          if (item.princepsForm) {
            cleanedName = applyPharmacologicalMask(name, item.princepsForm);
          }
          allCandidates.push(cleanedName);
        }
      }

      // Tentative : Préfixe Commun (LCP - Longest Common Prefix)
      if (allCandidates.length > 1) {
        const commonPrefix = findCommonWordPrefix(allCandidates);

        // Validation : Le préfixe doit être significatif (au moins 3 lettres)
        if (commonPrefix.length >= 3) {
          finalLabel = commonPrefix;
        }
      }

      // Fallback ultime
      if (!finalLabel) {
        finalLabel = substanceCode || "Non déterminé";
      }
    }

    const princepsLabel = finalLabel;

    // Generate cluster ID from key
    const clusterId = generateClusterId(key);

    // Assign cluster metadata to all items in this group
    for (const item of clusterItems) {
      groupToCluster.set(item.groupId, {
        clusterId,
        substanceCode,
        princepsLabel,
        secondaryPrinceps: secondaries // Stockage des secondaires
      });
    }
  }

  return groupToCluster;
}