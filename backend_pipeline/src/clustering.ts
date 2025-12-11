import {
  cleanPrincepsCandidate,
  cleanProductLabel,
  generateClusterId,
  normalizeString,
  normalizeRoutes,
  parseGroupLabel,
  parseRegulatoryInfo,
  splitGroupLabelFirst,
  stripFormFromCisLabel
} from "./logic";
import type {
  CisId,
  Cluster,
  DependencyMaps,
  GroupRow,
  ProductGroupingUpdate,
  RawGroup
} from "./types";
import { GenericType, type NamingSource } from "./types";

export type ProductMetaEntry = {
  label: string;
  codes: string[];
  signature: string;
  bases: string[];
  isPrinceps: boolean;
  groupId: string | null;
  genericType: GenericType;
};

type GroupStats = {
  total: number;
  linkedViaCis: number;
  rescuedViaText: number;
  failed: number;
};

export type GroupNaming = {
  canonical: string;
  reference: string | null;
  namingSource: NamingSource;
  historicalPrincepsRaw: string | null;
  genericLabelClean: string | null;
  princepsAliases: string[];
};

type ClusteringContext = {
  dependencyMaps: DependencyMaps;
  groupsData: RawGroup[];
  excludedCis: Set<CisId>;
  productMeta: Map<CisId, ProductMetaEntry>;
  cisNames: Map<CisId, string>;
  cisDetails: Map<CisId, { label: string; form: string; route: string }>;
  groupCompositionCanonical: Map<string, { tokens: string[]; substances: Array<{ name: string; dosage: string; nature: "FT" | "SA" | null }> }>;
};

export type ClusteringResult = {
  clusters: Cluster[];
  groupRows: GroupRow[];
  productGroupUpdates: ProductGroupingUpdate[];
  cisToCluster: Map<CisId, string>;
  missingGroupCis: Set<CisId>;
  groupStats: GroupStats;
  groupNaming: Map<string, GroupNaming>;
  groupRoutes: Map<string, Set<string>>;
};

export class ClusteringEngine {
  private readonly dependencyMaps;
  private readonly groupsData;
  private readonly excludedCis;
  private readonly productMeta;
  private readonly cisNames;
  private readonly cisDetails;
  private readonly groupCompositionCanonical;

  constructor(context: ClusteringContext) {
    this.dependencyMaps = context.dependencyMaps;
    this.groupsData = context.groupsData;
    this.excludedCis = context.excludedCis;
    this.productMeta = context.productMeta;
    this.cisNames = context.cisNames;
    this.cisDetails = context.cisDetails;
    this.groupCompositionCanonical = context.groupCompositionCanonical;
  }

  run(): ClusteringResult {
    console.log("Processing Groups & Clusters (Tiroir strategy)...");

    const groupNaming = this.buildGroupNaming();
    const groupRoutes = new Map<string, Set<string>>();
    const groupSafety = new Map<
      string,
      { list1: boolean; list2: boolean; narcotic: boolean; hospital: boolean; dental: boolean }
    >();
    const emptySafety = () => ({
      list1: false,
      list2: false,
      narcotic: false,
      hospital: false,
      dental: false
    });
    for (const row of this.groupsData) {
      const [groupId, , cis] = row;
      if (this.excludedCis.has(cis)) continue;
      const route = this.cisDetails.get(cis)?.route?.trim();
      if (route) {
        const tokens = normalizeRoutes(route);
        if (!groupRoutes.has(groupId)) groupRoutes.set(groupId, new Set<string>());
        for (const t of tokens) {
          groupRoutes.get(groupId)!.add(t);
        }
      }
      const conditions = this.dependencyMaps.conditions.get(cis) ?? [];
      if (!groupSafety.has(groupId)) {
        groupSafety.set(groupId, emptySafety());
      }
      const agg = groupSafety.get(groupId)!;
      for (const cond of conditions) {
        const parsed = parseRegulatoryInfo(cond);
        agg.list1 = agg.list1 || parsed.list1;
        agg.list2 = agg.list2 || parsed.list2;
        agg.narcotic = agg.narcotic || parsed.narcotic;
        agg.hospital = agg.hospital || parsed.hospital;
        agg.dental = agg.dental || parsed.dental;
      }
    }

    const groupStats: GroupStats = {
      total: 0,
      linkedViaCis: 0,
      rescuedViaText: 0,
      failed: 0
    };
    const missingGroupCis = new Set<CisId>();
    const groupRows: GroupRow[] = [];
    const productGroupUpdates: ProductGroupingUpdate[] = [];
    const cisToCluster = new Map<CisId, string>();

    const groupProducts = this.buildGroupProducts();
    const clustersBySignature = new Map<string, Cluster>(); // signature -> cluster (primary key)
    const clustersByNormalized = new Map<string, Cluster>(); // normalized name -> cluster (fallback)
    const groupIdToClusterKey = new Map<string, string>(); // groupId -> signature or normalized
    const aliasClusterMap = new Map<string, string>(); // normalized alias -> cluster id
    const signatureToClusterId = new Map<string, string>(); // signature -> cluster id
    const signatureMeta = new Map<
      string,
      { canonical: string; sourcePriority: number; productCount: number }
    >(); // best canonical per signature

    for (const row of this.groupsData) {
      const [groupId, rawLabel, cis, type] = row;
      if (this.excludedCis.has(cis)) continue;
      groupStats.total++;

      const products = groupProducts.get(groupId) ?? [];
      if (this.productMeta.has(cis)) {
        groupStats.linkedViaCis++;
      } else {
        missingGroupCis.add(cis);
        groupStats.rescuedViaText++;
      }

      const naming = groupNaming.get(groupId);
      const { molecule: parsedMolecule, reference: parsedReference } = parseGroupLabel(rawLabel);
      let canonicalName =
        naming?.canonical ||
        cleanPrincepsCandidate(parsedReference || "") ||
        cleanPrincepsCandidate(parsedMolecule) ||
        rawLabel.toUpperCase();
      // Clean canonical name to remove common suffixes that shouldn't be in cluster labels
      canonicalName = cleanProductLabel(canonicalName) || canonicalName;
      canonicalName = canonicalName.replace(/\s+(ML|LP|VELOTAB|CONSTA|PEDEA|MAINTENA|CONSTA\s+L\.P\.)$/i, "").trim() || canonicalName;
      const reference = naming?.reference ?? parsedReference;

      if (!canonicalName) {
        groupStats.failed++;
        continue;
      }

      const normalized = normalizeString(canonicalName) || canonicalName.toLowerCase();
      const aliases = [
        canonicalName,
        ...(naming?.princepsAliases ?? []),
        naming?.historicalPrincepsRaw ?? "",
        naming?.reference ?? ""
      ].filter(Boolean);
      const normalizedAliases = Array.from(
        new Set(
          aliases
            .map((a) => normalizeString(cleanProductLabel(a)) || normalizeString(a) || a.toLowerCase())
            .filter(Boolean)
        )
      );

      // Primary clustering key: composition signature
      const composition = this.groupCompositionCanonical.get(groupId);
      const signature = composition?.tokens.join("|") || "";
      const hasSignature = signature.length > 0;

      let clusterId: string | undefined;
      let clusterKey: string;
      const sourcePriority =
        naming?.namingSource === "GOLDEN_PRINCEPS"
          ? 2
          : naming?.namingSource === "TYPE_0_LINK"
            ? 1
            : 0;
      const productCountForGroup = products.length;

      if (hasSignature) {
        // Use signature as primary clustering key
        clusterKey = signature;
        
        // Check if a cluster already exists for this signature
        if (signatureToClusterId.has(signature)) {
          clusterId = signatureToClusterId.get(signature)!;
          const meta = signatureMeta.get(signature);
          const better =
            !meta ||
            sourcePriority > meta.sourcePriority ||
            (sourcePriority === meta.sourcePriority && productCountForGroup > meta.productCount);
          if (better) {
            const existingCluster = clustersBySignature.get(signature);
            if (existingCluster) {
              existingCluster.label = canonicalName;
              existingCluster.princeps_label = canonicalName;
              signatureMeta.set(signature, { canonical: canonicalName, sourcePriority, productCount: productCountForGroup });
            }
          }
        } else {
          // Check alias map first (for split-brain resolution)
          for (const a of normalizedAliases) {
            const hit = aliasClusterMap.get(a);
            if (hit) {
              clusterId = hit;
              signatureToClusterId.set(signature, clusterId);
              break;
            }
          }
          
          if (!clusterId) {
            const bestCanonical = canonicalName;
            clusterId = generateClusterId(bestCanonical);
            signatureToClusterId.set(signature, clusterId);
            signatureMeta.set(signature, { canonical: bestCanonical, sourcePriority, productCount: productCountForGroup });
          }
          
          // Create or update cluster by signature
          if (!clustersBySignature.has(signature)) {
            const bestCanonical = signatureMeta.get(signature)?.canonical ?? canonicalName;
            clustersBySignature.set(signature, {
              id: clusterId,
              label: bestCanonical,
              princeps_label: bestCanonical,
              substance_code: normalized || "unknown",
              text_brand_label:
                naming?.genericLabelClean ?? reference ?? naming?.historicalPrincepsRaw ?? undefined
            });
          } else {
            const existing = clustersBySignature.get(signature)!;
            const meta = signatureMeta.get(signature);
            if (meta && meta.canonical !== existing.princeps_label) {
              existing.label = meta.canonical;
              existing.princeps_label = meta.canonical;
            }
            if (!existing.text_brand_label && (reference || naming?.genericLabelClean)) {
              existing.text_brand_label = reference ?? naming?.genericLabelClean ?? undefined;
            }
            clusterId = existing.id;
            signatureToClusterId.set(signature, clusterId);
          }
        }
      } else {
        // Fallback to normalized name clustering (no composition signature available)
        clusterKey = normalized;
        
        // Reuse cluster id if any alias already mapped
        for (const a of normalizedAliases) {
          const hit = aliasClusterMap.get(a);
          if (hit) {
            clusterId = hit;
            break;
          }
        }
        if (!clusterId) {
          clusterId = generateClusterId(canonicalName);
        }

        if (!clustersByNormalized.has(normalized)) {
          clustersByNormalized.set(normalized, {
            id: clusterId,
            label: canonicalName,
            princeps_label: canonicalName,
            substance_code: normalized || "unknown",
            text_brand_label:
              naming?.genericLabelClean ?? reference ?? naming?.historicalPrincepsRaw ?? undefined
          });
        } else {
          const existing = clustersByNormalized.get(normalized)!;
          if (!existing.text_brand_label && (reference || naming?.genericLabelClean)) {
            existing.text_brand_label = reference ?? naming?.genericLabelClean ?? undefined;
          }
          clusterId = existing.id;
        }
      }

      // Map all aliases to chosen cluster id
      for (const a of normalizedAliases) {
        if (!aliasClusterMap.has(a)) {
          aliasClusterMap.set(a, clusterId);
        }
      }

      groupIdToClusterKey.set(groupId, clusterKey);
      const targetClusterId = clusterId;
      groupRows.push({
        id: groupId,
        cluster_id: targetClusterId,
        label: rawLabel,
        canonical_name: canonicalName,
        historical_princeps_raw: naming?.historicalPrincepsRaw ?? null,
        generic_label_clean: naming?.genericLabelClean ?? null,
        naming_source: naming?.namingSource ?? "GENER_PARSING",
        princeps_aliases: JSON.stringify(naming?.princepsAliases ?? []),
        safety_flags: JSON.stringify(groupSafety.get(groupId) ?? emptySafety()),
        routes: JSON.stringify(Array.from(groupRoutes.get(groupId) ?? []))
      });

      const parsedType = Number.parseInt(type, 10);
      const validTypes = [
        GenericType.PRINCEPS,
        GenericType.GENERIC,
        GenericType.COMPLEMENTARY,
        GenericType.SUBSTITUTABLE,
        GenericType.AUTO_SUBSTITUTABLE
      ];
      const genericType =
        Number.isFinite(parsedType) && validTypes.includes(parsedType as GenericType)
          ? (parsedType as GenericType)
          : GenericType.UNKNOWN;
      const isPrinceps = genericType === GenericType.PRINCEPS;
      if (this.productMeta.has(cis)) {
        productGroupUpdates.push({
          cis,
          group_id: groupId,
          is_princeps: isPrinceps,
          generic_type: genericType
        });
      }
    }

    // Assign clustered products (grouped)
    for (const [groupId, products] of groupProducts) {
      const clusterKey = groupIdToClusterKey.get(groupId);
      if (!clusterKey) continue;
      
      let cluster: Cluster | undefined;
      const composition = this.groupCompositionCanonical.get(groupId);
      const signature = composition?.tokens.join("|") || "";
      
      if (signature.length > 0) {
        cluster = clustersBySignature.get(signature);
      } else {
        cluster = clustersByNormalized.get(clusterKey);
      }
      
      if (!cluster) continue;

      for (const product of products) {
        cisToCluster.set(product.cis, cluster.id);
        // Keep cluster.princeps_label stable (canonical); do not override with per-product labels to avoid split-brain.
      }
    }

    // Handle standalone products (no group)
    for (const [cis, meta] of this.productMeta) {
      const genericInfo = this.dependencyMaps.generics.get(cis);
      if (genericInfo) continue; // already assigned through group
      const baseLabel = cleanProductLabel(meta.label) || meta.label;
      const normalized = normalizeString(baseLabel) || baseLabel.toLowerCase();
      // First, try to reuse any cluster already mapped via aliases (built from grouped princeps)
      const aliasHit = aliasClusterMap.get(normalized);
      if (aliasHit) {
        cisToCluster.set(cis, aliasHit);
        continue;
      }

      const existingCluster = clustersByNormalized.get(normalized);
      const clusterId = existingCluster ? existingCluster.id : generateClusterId(baseLabel);
      if (!existingCluster) {
        clustersByNormalized.set(normalized, {
          id: clusterId,
          label: baseLabel,
          princeps_label: baseLabel,
          substance_code: normalized || "unknown"
        });
      }
      cisToCluster.set(cis, clusterId);
    }

    // Merge clusters: signature-based clusters take precedence, then normalized-name clusters
    const finalClusters = new Map<string, Cluster>();
    
    // First, add all signature-based clusters
    for (const [signature, cluster] of clustersBySignature) {
      finalClusters.set(cluster.id, cluster);
    }
    
    // Then, add normalized-name clusters that don't conflict
    for (const [normalized, cluster] of clustersByNormalized) {
      if (!finalClusters.has(cluster.id)) {
        finalClusters.set(cluster.id, cluster);
      }
    }

    return {
      clusters: Array.from(finalClusters.values()),
      groupRows,
      productGroupUpdates,
      cisToCluster,
      missingGroupCis,
      groupStats,
      groupNaming,
      groupRoutes
    };
  }

  private buildGroupProducts(): Map<
    string,
    Array<{ cis: CisId; meta: ProductMetaEntry; genericType: GenericType }>
  > {
    const result = new Map<string, Array<{ cis: CisId; meta: ProductMetaEntry; genericType: GenericType }>>();
    for (const [cis, meta] of this.productMeta) {
      const genericInfo = this.dependencyMaps.generics.get(cis);
      if (!genericInfo) continue;
      const groupId = genericInfo.groupId;
      const parsedType = Number.parseInt(genericInfo.type, 10);
      const validTypes = [
        GenericType.PRINCEPS,
        GenericType.GENERIC,
        GenericType.COMPLEMENTARY,
        GenericType.SUBSTITUTABLE,
        GenericType.AUTO_SUBSTITUTABLE
      ];
      const genericType =
        Number.isFinite(parsedType) && validTypes.includes(parsedType as GenericType)
          ? (parsedType as GenericType)
          : meta.genericType ?? GenericType.UNKNOWN;
      meta.groupId = groupId;
      meta.genericType = genericType;
      if (genericType === GenericType.PRINCEPS) {
        meta.isPrinceps = true;
      }
      if (!result.has(groupId)) result.set(groupId, []);
      result.get(groupId)!.push({ cis, meta, genericType });
    }
    return result;
  }

  private buildGroupNaming(): Map<string, GroupNaming> {
    const grouped = new Map<string, RawGroup[]>();
    const rawLabelByGroup = new Map<string, string>();

    for (const row of this.groupsData) {
      const [groupId, label, cis] = row;
      if (this.excludedCis.has(cis)) continue;
      if (!grouped.has(groupId)) {
        grouped.set(groupId, []);
        rawLabelByGroup.set(groupId, label);
      }
      grouped.get(groupId)!.push(row);
    }

    const result = new Map<string, GroupNaming>();

    for (const [groupId, rows] of grouped) {
      const rawLabel = rawLabelByGroup.get(groupId) ?? "";
      const parsed = parseGroupLabel(rawLabel);
      const firstSplit = splitGroupLabelFirst(rawLabel);
      const genericLabelClean = firstSplit.left ? cleanPrincepsCandidate(firstSplit.left) : null;

      const type0Rows = rows.filter((r) => Number.parseInt(r[3], 10) === GenericType.PRINCEPS);
      const goldenRows = type0Rows.filter((r) => r[4] === "1");

      const princepsAliases: string[] = [];
      if (type0Rows.length > 0) {
        for (const row of type0Rows) {
          const cis = row[2];
          const details = this.cisDetails.get(cis);
          if (!details) continue;
          const cleaned = stripFormFromCisLabel(details.label, details.form);
          if (cleaned) princepsAliases.push(cleaned);
        }
      }

      let canonical = "";
      let namingSource: NamingSource = "GENER_PARSING";
      let historicalPrincepsRaw: string | null = null;
      let reference: string | null = parsed.reference || null;

      const uniqueAliases = Array.from(new Set(princepsAliases));
      const normalizedMolecule = normalizeString(parsed.molecule || "");
      const scoredCandidates: Array<{
        label: string;
        score: number;
        source: NamingSource;
      }> = [];

      for (const row of type0Rows) {
        const cis = row[2];
        const details = this.cisDetails.get(cis);
        if (!details) continue;
        const cleaned =
          cleanProductLabel(stripFormFromCisLabel(details.label, details.form)) ||
          cleanProductLabel(details.label) ||
          details.label;
        if (!cleaned) continue;

        let score = 0;
        score += 10; // Type 0 bonus
        if (row[4] === "1") {
          score += 20; // Golden princeps
        }

        const normalizedLabel = normalizeString(cleaned);
        if (normalizedMolecule && normalizedLabel.startsWith(normalizedMolecule)) {
          score -= 50; // Penalize auto-generics that mirror molecule name
        }

        scoredCandidates.push({
          label: cleaned,
          score,
          source: row[4] === "1" ? "GOLDEN_PRINCEPS" : "TYPE_0_LINK"
        });
      }

      if (!canonical && scoredCandidates.length > 0) {
        scoredCandidates.sort((a, b) => {
          if (b.score !== a.score) return b.score - a.score;
          if (a.label.length !== b.label.length) return a.label.length - b.label.length;
          return a.label.localeCompare(b.label);
        });
        const best = scoredCandidates[0];
        canonical = best.label;
        reference = best.label;
        namingSource = best.source;
      }

      if (!canonical) {
        const cleanedRef = reference ? cleanPrincepsCandidate(reference) : "";
        canonical =
          cleanedRef ||
          cleanPrincepsCandidate(parsed.molecule) ||
          rawLabel.trim().toUpperCase() ||
          "UNKNOWN";
        historicalPrincepsRaw = reference;
        namingSource = "GENER_PARSING";
      }

      const finalAliases =
        uniqueAliases.length > 0
          ? uniqueAliases
          : canonical
              ? [canonical]
              : [];

      result.set(groupId, {
        canonical,
        reference,
        namingSource,
        historicalPrincepsRaw,
        genericLabelClean,
        princepsAliases: finalAliases
      });
    }

    return result;
  }
}
