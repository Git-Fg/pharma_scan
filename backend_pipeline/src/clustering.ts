import { normalizePrincipleOptimal, generateGroupingKey, applyPharmacologicalMask } from "./sanitizer";
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
 * Build search vector for FTS5 indexing
 * Concatenates substance, primary princeps, and secondary princeps
 * then applies heavy normalization for fuzzy matching
 */
export function buildSearchVector(
  substance: string,
  primaryPrinceps: string,
  secondaryPrincepsList: string[]
): string {
  // 1. Collect (Set to deduplicate)
  const keywords = new Set<string>();

  keywords.add(substance);
  keywords.add(primaryPrinceps);
  secondaryPrincepsList.forEach(p => keywords.add(p));

  // 2. Concatenation
  let vector = Array.from(keywords).join(' ');

  // 3. Heavy "Kärcher" cleaning (Heavy normalization)
  return vector
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "") // Remove accents
    .toUpperCase()
    // Remove medical noise not useful for conceptual search
    .replace(/\b(COMPRIME|GELULE|SIROP|SACHET|DOSE|FLACON|MG|ML|BASE|ANHYDRE)\b/g, " ")
    .replace(/[^A-Z0-9]/g, " ") // Keep only alphanumeric
    .replace(/\s+/g, " ")       // Trim spaces
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
function normalizeCommonPrincipes(commonPrincipes: string): string {
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
 * Port of groupByCommonPrincipes from grouping_algorithms.dart
 * Implements the "Hybrid Clustering Strategy":
 * 1. Hard Link (via Princeps CIS)
 * 2. Soft Link (via Normalized Common Principles)
 * 3. Suspicious Cluster Detection (prefix/substring checks)
 * 
 * Returns a map from groupId to cluster metadata (clusterId, substanceCode, princepsLabel)
 */
export function computeClusters(items: ClusteringInput[]): Map<string, ClusterMetadata> {
  // Map<GroupId, ClusterMetadata>
  const groupToCluster = new Map<string, ClusterMetadata>();

  if (items.length === 0) return groupToCluster;

  // ===== PHASE 0: BUILD CIS-TO-PRINCIPLE MAP (Hard Link) =====
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

  // ===== PHASE 1: GROUPING =====
  const commonPrincipesCounts = new Map<string, number>();
  const commonPrincipesToGroupIds = new Map<string, Set<string>>();

  for (const item of items) {
    let groupingKey: string | null = null;
    
    // 1. Hard Link via Princeps CIS
    if (item.princepsCisCode && cisToPrincipleMap.has(item.princepsCisCode)) {
      groupingKey = cisToPrincipleMap.get(item.princepsCisCode)!;
    }
    // 2. Soft Link via Common Principles
    else if (item.commonPrincipes) {
      groupingKey = normalizeCommonPrincipes(item.commonPrincipes);
    }

    if (groupingKey && groupingKey.length > 2) {
      commonPrincipesCounts.set(groupingKey, (commonPrincipesCounts.get(groupingKey) || 0) + 1);
      if (!commonPrincipesToGroupIds.has(groupingKey)) {
        commonPrincipesToGroupIds.set(groupingKey, new Set());
      }
      commonPrincipesToGroupIds.get(groupingKey)!.add(item.groupId);
    }
  }

  const suspiciousPrincipes = new Set<string>();

  for (const [key, groupIds] of commonPrincipesToGroupIds.entries()) {
    if (groupIds.size > 1) {
      const isSinglePrinciple = !key.includes(",");
      if (isSinglePrinciple && key.length >= 4) {
        continue;
      }

      // Re-fetch items for this key to analyze names
      const clusterItems = items.filter(item => {
        let k;
        if (item.princepsCisCode && cisToPrincipleMap.has(item.princepsCisCode)) {
          k = cisToPrincipleMap.get(item.princepsCisCode)!;
        } else if (item.commonPrincipes) {
          k = normalizeCommonPrincipes(item.commonPrincipes);
        }
        return k === key;
      });

      const normalizedPrinceps = clusterItems.map(i =>
        normalizePrincipleOptimal(i.princepsReferenceName)
      );

      if (groupIds.size > 2) {
        const uniquePrinceps = Array.from(new Set(normalizedPrinceps));

        let allShareCommonPrefix = false;
        if (uniquePrinceps.length > 1) {
          const first = uniquePrinceps[0];
          let commonPrefixLength = 0;
          if (first.length >= 4) {
            for (let len = 4; len <= first.length; len++) {
              const prefix = first.substring(0, len);
              if (uniquePrinceps.every(name => name.length >= len && name.substring(0, len) === prefix)) {
                commonPrefixLength = len;
              } else {
                break;
              }
            }
          }
          allShareCommonPrefix = commonPrefixLength >= 4;
        } else {
          // If only 1 unique princeps name, effectively sharing prefix
          allShareCommonPrefix = true;
        }

        if (uniquePrinceps.length > 3 && !allShareCommonPrefix) {
          suspiciousPrincipes.add(key);
        } else if (!allShareCommonPrefix) {
          let hasVeryDifferentNames = false;
          for (let i = 0; i < normalizedPrinceps.length; i++) {
            for (let j = i + 1; j < normalizedPrinceps.length; j++) {
              const name1 = normalizedPrinceps[i];
              const name2 = normalizedPrinceps[j];

              const minLen = Math.min(name1.length, name2.length);

              if (minLen >= 4) {
                const prefix1 = name1.substring(0, 4);
                const prefix2 = name2.substring(0, 4);
                if (
                  prefix1 !== prefix2 &&
                  !name1.includes(prefix2) &&
                  !name2.includes(prefix1)
                ) {
                  hasVeryDifferentNames = true;
                  break;
                }
              } else {
                if (
                  name1 !== name2 &&
                  !name1.includes(name2) &&
                  !name2.includes(name1)
                ) {
                  hasVeryDifferentNames = true;
                  break;
                }
              }
            }
            if (hasVeryDifferentNames) break;
          }

          if (hasVeryDifferentNames) {
            suspiciousPrincipes.add(key);
          }
        }
      }
    }
  }

  // ===== PHASE 2: CONSTRUCTION =====
  const groupedByPrincipes = new Map<string, ClusteringInput[]>();

  for (const item of items) {
    let groupingKey: string;
    
    // 1. Hard Link via Princeps CIS
    if (item.princepsCisCode && cisToPrincipleMap.has(item.princepsCisCode)) {
      groupingKey = cisToPrincipleMap.get(item.princepsCisCode)!;
    }
    // 2. Soft Link via Common Principles
    else if (item.commonPrincipes) {
      groupingKey = normalizeCommonPrincipes(item.commonPrincipes);
    }
    // 3. Fallback: Unique key
    else {
      groupingKey = `UNIQUE_${item.groupId}`;
    }

    // Mark as unique if suspicious or too short
    if (groupingKey.length <= 2 || suspiciousPrincipes.has(groupingKey)) {
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
