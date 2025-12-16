import { normalizePrincipleOptimal, generateGroupingKey, applyPharmacologicalMask, normalizeCommonPrincipes, computeCanonicalSubstance } from "./sanitizer";
import crypto from "crypto";
import { ClusterData } from "./types";
import { COMMON_WORDS } from "./constants";

export interface ClusteringInput {
  groupId: string;
  cisCode: string;           // Code CIS du produit
  productName: string;       // Nom du produit (pour affichage)
  genericType: number;       // 0, 1, 2, 4
  genericSortIndex: number;  // Le numéro de tri
  cisExists: boolean;        // Est-ce que ce produit est dans CIS_BDPM ?
  substanceCodes: string[];  // Official IDs from ANSM
  commonPrincipes: string;   // "P1 + P2" or "P1, P2"
}

/**
 * Build search vector for FTS5 indexing - THE ONLY place for search keyword generation
 * Concatenates substance, primary princeps, secondary princeps, AND active principles
 * then applies heavy normalization for fuzzy matching
 * 
 * This enables DUAL search:
 * - Brand search: "CLAMOXYL", "DOLIPRANE"
 * - Substance search: "amoxicilline", "paracetamol"
 */
export function buildSearchVector(
  substance: string,
  primaryPrinceps: string,
  secondaryPrincepsList: string[],
  principesActifs?: string  // NEW: Active substance composition (e.g., "Amoxicilline 500 mg + Acide clavulanique 125 mg")
): string {
  // 1. Collect (Set for deduplication)
  const keywords = new Set<string>();

  keywords.add(substance);
  keywords.add(primaryPrinceps);
  secondaryPrincepsList.forEach(p => keywords.add(p));

  // 2. NEW: Extract individual substance names from composition
  if (principesActifs && principesActifs.trim()) {
    // Split by '+' or ',' to get individual substances
    const substances = principesActifs.split(/[+,]/).map(s => s.trim());
    substances.forEach(s => {
      if (s) {
        // Extract just the substance name (before any dosage)
        // e.g., "Amoxicilline 500 mg" -> "Amoxicilline"
        const substanceName = s.split(/\s+\d/)[0].trim();
        if (substanceName) {
          keywords.add(substanceName);
        }
      }
    });
  }

  // 3. Concatenation
  let vector = Array.from(keywords).join(' ');

  // 4. "Kärcher" cleaning (Normalisation lourde)
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
 * Cette fonction travaille mot par mot (plus sûr que caractère par caractère)
 */
export function findCommonWordPrefix(strings: string[]): string {
  if (strings.length === 0) return "";
  if (strings.length === 1) return strings[0];

  // 1. Standard Word-Based LCP
  const arrays = strings.map(s => s.trim().split(/\s+/));
  const firstArr = arrays[0];
  const commonWords: string[] = [];

  for (let i = 0; i < firstArr.length; i++) {
    const word = firstArr[i];
    const isCommon = arrays.every(arr =>
      arr.length > i && arr[i].toUpperCase() === word.toUpperCase()
    );
    if (isCommon) {
      commonWords.push(word);
    } else {
      break;
    }
  }

  const wordBasedResult = commonWords.join(" ");

  // 2. Exception Handling: Condensed Fallback
  // If the word-based match is too weak (< 3 chars), try to match by ignoring spaces/dashes.
  // This handles cases like "BI PROFENID" vs "BIPROFENID" -> "BIPROFENID"
  if (wordBasedResult.length < 3) {
    const normalize = (s: string) => s.replace(/[\s-]/g, "").toUpperCase();
    const condensedList = strings.map(normalize);

    // Find CP on condensed strings
    const firstCondensed = condensedList[0];
    let condensedLcp = "";

    for (let i = 0; i < firstCondensed.length; i++) {
      const char = firstCondensed[i];
      if (condensedList.every(s => s[i] === char)) {
        condensedLcp += char;
      } else {
        break;
      }
    }

    // Only accept if significant match found
    if (condensedLcp.length >= 3) {
      // Heuristic: If one of the original inputs exactly matches the condensed LCP (ignoring case),
      // return that original input to preserve casing/formatting if possible.
      // Otherwise, just return the condensed upper-case version (it's better than nothing).
      const exactMatch = strings.find(s => normalize(s) === condensedLcp);
      return exactMatch || condensedLcp;
    }
  }

  return wordBasedResult;
}

/**
 * Deterministic hash for cluster ID generation.
 * Ensures consistent IDs across pipeline runs if data is stable.
 */
export function generateClusterId(key: string): string {
  return "CLS_" + crypto.createHash("md5").update(key).digest("hex").substring(0, 8).toUpperCase();
}

export interface ClusterMetadata {
  clusterId: string;
  substanceCode: string;
  princepsLabel: string;
  secondaryPrinceps: string[]; // Noms de princeps secondaires (co-marketing, rachats)
}

/**
 * Union-Find (Disjoint Set) Data Structure
 * Used to efficiently merge groups into clusters.
 */
class DisjointSet {
  private parent: Map<string, string>;

  constructor() {
    this.parent = new Map<string, string>();
  }

  // Find the representative of the set containing element x (with path compression)
  find(x: string): string {
    if (!this.parent.has(x)) {
      this.parent.set(x, x);
      return x;
    }

    let p = this.parent.get(x)!;
    if (p !== x) {
      p = this.find(p); // Recursive path compression
      this.parent.set(x, p);
    }
    return p;
  }

  // Union the sets containing x and y
  union(x: string, y: string): void {
    const rootX = this.find(x);
    const rootY = this.find(y);

    if (rootX !== rootY) {
      this.parent.set(rootX, rootY); // Arbitrary link
    }
  }
}

/**
 * Graph-Based Clustering Strategy
 * Merges groups based on shared Princeps (Hard Link) and shared Dosage-Agnostic Substance (Soft Link).
 * Uses Union-Find to resolve connected components.
 */
export function computeClusters(items: ClusteringInput[]): Map<string, ClusterMetadata> {
  // Map<GroupId, ClusterMetadata>
  const groupToCluster = new Map<string, ClusterMetadata>();
  if (items.length === 0) return groupToCluster;

  const uf = new DisjointSet();

  // 1. Initialize UF for all items
  for (const item of items) {
    uf.find(item.groupId);
  }

  // 2. Build Maps for Linking
  const cisToGroups = new Map<string, string[]>();
  const substanceToGroups = new Map<string, string[]>();
  const codeToGroups = new Map<string, string[]>();      // Code-based (Hard Link) <--- NEW

  for (const item of items) {
    // A. Map by Princeps CIS (Hard Link) - DOES NOT APPLY DIRECTLY TO PRODUCT LEVEL INPUTS AS BEFORE
    // But we can still map by "CIS Code of the Type 0 in the same Group" if we had that info.
    // However, the new logic relies heavily on SubstanceCodes and GroupID.
    // Let's rely on GroupID unioning implicitly handled by UF init?
    // UF.find(item.groupId) links all items with same GroupID.

    // Actually, in Product Level clustering:
    // item.groupId IS the group ID from the file. So all CIS sharing groupId are UNIFIED by default
    // because we did `uf.find(item.groupId)`.
    // Wait, `uf.find(item.groupId)` acts on the groupId string key.
    // If multiple items have same groupId, they map to same UF root?
    // YES, `uf.find` creates an entry. But we need to UNION them or they are just separate entries?
    // No, existing logic: 
    // `const root = uf.find(item.groupId);`
    // If item A and Item B have same groupId "G1", `uf.find("G1")` returns same root. 
    // They are grouped in `clusters` map by root.
    // So grouping by GroupID is implicit/automatic.

    // We only need explicit maps if we want to merge DIFFERENT GroupIDs together.
    // e.g. Group G1 (Paracétamol) and Group G2 (Paracétamol orphans) -> Merge by Substance Code.

    // RE-VERIFY: item.princepsCisCode was used to merge groups that shared a princeps.
    // In strict ANSM logic, groups are defined by ANSM. We mostly want to merge via SubstanceCode now.
    // So I will remove Step 2.A (Princeps CIS) unless we pass it.
    // To match `ClusteringInput` changes, I'll remove `princepsCisCode` usage since it's removed from interface.

    // Logic 2.A Removed. The GroupID is the primary grouping. SubstanceCode is the super-grouping.

    // B. Map by Dosage-Agnostic AND Salt-Agnostic Substance (Soft Link)
    // We use computeCanonicalSubstance to strip salts (e.g. "Morphine Sulfate" -> "Morphine")
    // allowing variants to merge into the same conceptual cluster.
    if (item.commonPrincipes) {
      // normalizeCommonPrincipes splits '+' and normalizes separators.
      // We then apply computeCanonicalSubstance to each part?
      // Actually computeCanonicalSubstance works on a single substance string.
      // normalizeCommonPrincipes returns a '+' separated string of normalized principles.
      // We should map each principle through computeCanonicalSubstance.

      const parts = item.commonPrincipes.split(/[+,]+/).map(p => p.trim());
      const canonicalParts = parts.map(p => {
        // 1. Strip Dosage (e.g. "1%", "500 mg")
        const noDosage = generateGroupingKey(p);
        // 2. Strip Salt (e.g. "Olamine", "Sulfate")
        return computeCanonicalSubstance(noDosage);
      }).sort();
      const substanceKey = canonicalParts.join(" + ");


      // Only link if the key is meaningful (length > 2) to avoid merging "A" or "MG"
      if (substanceKey && substanceKey.length > 2) {
        if (!substanceToGroups.has(substanceKey)) {
          substanceToGroups.set(substanceKey, []);
        }
        substanceToGroups.get(substanceKey)!.push(item.groupId);
      }
    }

    // C. Official Code Substance Link (NEW - The "Golden" Link)
    // If two groups share the exact same set of substance IDs, they are chemically identical
    if (item.substanceCodes && item.substanceCodes.length > 0) {
      // Sort and join to create a deterministic key (e.g. "0045|0123")
      // This handles combination products correctly (A+B matches B+A)
      const codeKey = item.substanceCodes.sort().join('|');

      if (!codeToGroups.has(codeKey)) {
        codeToGroups.set(codeKey, []);
      }
      codeToGroups.get(codeKey)!.push(item.groupId);
    }
  }

  // 3. Perform Unions
  // A. Link by Princeps CIS -> Removed as `princepsCisCode` removed from input.
  // The primary grouping is already done by existing Group ID.
  // The "Hard Link" for merging DIFFERENT groups is now SubstanceCode.

  // B. Union groups sharing the same Substance Key
  for (const groups of substanceToGroups.values()) {
    if (groups.length > 1) {
      const first = groups[0];
      for (let i = 1; i < groups.length; i++) {
        uf.union(first, groups[i]);
      }
    }
  }

  // C. Union groups sharing the same Official Substance Codes
  for (const groups of codeToGroups.values()) {
    if (groups.length > 1) {
      const first = groups[0];
      for (let i = 1; i < groups.length; i++) {
        uf.union(first, groups[i]);
      }
    }
  }

  // 4. Resolve Clusters
  // Map<RootGroupId, ClusteringInput[]>
  const clusters = new Map<string, ClusteringInput[]>();

  for (const item of items) {
    const root = uf.find(item.groupId);
    if (!clusters.has(root)) {
      clusters.set(root, []);
    }
    clusters.get(root)!.push(item);
  }

  // 5. Generate Metadata for each Cluster
  for (const [root, clusterItems] of clusters.entries()) {
    // A. Determine Substance Code (Consensus)
    // We pick the most frequent substance key in the cluster
    const substVotes = new Map<string, number>();
    for (const item of clusterItems) {
      if (item.commonPrincipes) {
        const key = normalizeCommonPrincipes(item.commonPrincipes);
        substVotes.set(key, (substVotes.get(key) || 0) + 1);
      }
    }

    // Sort votes
    const sortedSubst = Array.from(substVotes.entries()).sort((a, b) => b[1] - a[1]);
    let substanceCode = sortedSubst.length > 0 ? sortedSubst[0][0] : "";

    // Fallback: if substanceCode still has dosage (because we used full commonPrincipes for consensus),
    // we might want to clean it for display or just keep it. 
    // Usually for display in the app, we want the "Clean" substance.
    // Let's use the Dosage-Agnostic version for the Cluster Substance Code.
    if (substanceCode) {
      const clean = generateGroupingKey(substanceCode);
      if (clean && clean.length > 2) substanceCode = clean;
    }


    // B. Naming Strategy (Golden Source: Princeps > SortIndex)
    const princepsLabel = determineClusterName(clusterItems);

    // We can still try to collect secondary princeps for metadata (all type 0 that are not the winner)
    const secondaryPrinceps = clusterItems
      .filter(i => i.genericType === 0 && i.cisExists && cleanProductName(i.productName) !== princepsLabel)
      .map(i => cleanProductName(i.productName));
    // Deduplicate
    const uniqueSecondaries = Array.from(new Set(secondaryPrinceps));

    // C. Generate ID
    // Stable ID based on sorted list of Group IDs in the cluster
    const clusterKey = clusterItems.map(i => i.groupId).sort().join("|");
    const clusterId = generateClusterId(clusterKey);

    // D. Assign to all
    const metadata: ClusterMetadata = {
      clusterId,
      substanceCode,
      princepsLabel,
      secondaryPrinceps: uniqueSecondaries
    };

    for (const item of clusterItems) {
      groupToCluster.set(item.groupId, metadata);
    }
  }

  return groupToCluster;
}

// --- Golden Source Naming Helpers ---

/**
 * Determine the "Golden" Cluster Name based on strict hierarchy:
 * 1. Active Princeps (Type 0 + cisExists) sorted by SortIndex ASC
 * 2. Inactive Princeps (Type 0 only) sorted by SortIndex ASC
 * 3. Fallback: Common Name (e.g. Molecule Name)
 */
function determineClusterName(members: ClusteringInput[]): string {

  // 1. FILTRE PRINCEPS STRICT
  // On cherche les produits qui sont officiellement des Princeps (Type 0)
  // ET qui existent réellement dans la base (cisExists = true)
  const validPrinceps = members.filter(m => m.genericType === 0 && m.cisExists);

  if (validPrinceps.length > 0) {
    // 2. TRI HIERARCHIQUE
    // On trie par le numéro de colonne 5 (sortIndex) croissant (1, puis 2, puis 3...)
    // En cas d'égalité, on peut utiliser le CIS pour être déterministe
    validPrinceps.sort((a, b) => {
      const diff = a.genericSortIndex - b.genericSortIndex;
      if (diff !== 0) return diff;
      return a.cisCode.localeCompare(b.cisCode);
    });

    // Le vainqueur est le premier de la liste
    return cleanProductName(validPrinceps[0].productName);
  }

  // --- CAS DE REPLI (FALLBACK) ---

  // Cas A : Princeps référencé mais retiré du marché (cisExists = false) ?
  const ghostPrinceps = members.filter(m => m.genericType === 0);
  if (ghostPrinceps.length > 0) {
    ghostPrinceps.sort((a, b) => a.genericSortIndex - b.genericSortIndex);
    return cleanProductName(ghostPrinceps[0].productName);
  }

  // Cas B : Aucun princeps (ex: vieux groupe générique).
  // On prend le nom du groupe (si disponible via le groupId qui était souvent le nom de la molécule)
  // Ou on essaye de trouver un préfixe commun sur les noms des produits
  // Pour l'instant, on retourne le nom du premier produit ou "Groupe Générique"
  if (members.length > 0) {
    // Tentative de trouver un nom commun
    const names = members.map(m => cleanProductName(m.productName));
    const common = findCommonWordPrefix(names);
    if (common && common.length > 3) return common;

    // Sinon le nom du produit le plus court (souvent le plus simple)
    names.sort((a, b) => a.length - b.length);
    return names[0];
  }

  return "Cluster Inconnu";
}

function cleanProductName(name: string): string {
  if (!name) return "";
  // On enlève "comprimé", dosage, etc.
  // Stratégie simple : On prend la première partie avant la virgule
  // Ex: "DOLIPRANE 1000 mg, comprimé" -> "DOLIPRANE 1000 mg"
  // Mais souvent on veut juste "DOLIPRANE".
  // Utilisons une logique un peu plus poussée si nécessaire, ou celle demandée.

  // 1. Split on comma usually separates Name+Dosage from Form
  let part1 = name.split(',')[0].trim();

  // 2. Remove Dosage ? Typically "Doliprane 1000 mg" -> "Doliprane".
  // But sometimes checking if the name ends with dosage is tricky without regex.
  // Let's use a regex like parseGeneriques does implicitly via smart split.

  // Remove trailing dosage info (digits + common units)
  // Matches " 1000 mg", " 500 UI", " 1 g" at end of string
  part1 = part1.replace(/\s+\d+(?:[.,]\d+)?\s*(?:mg|g|ml|ui|u\.i\.|cp|µg|mcg)(?:\s+|$)/gi, '').trim();

  return part1;
}