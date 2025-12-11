import fs from "node:fs";
import { parse } from "csv-parse";
import iconv from "iconv-lite";
import { z } from "zod";
import { DEFAULT_DB_PATH, ReferenceDatabase } from "./db";
import {
  RawAvailabilitySchema,
  RawCompositionSchema,
  RawConditionsSchema,
  RawGroupSchema,
  RawMitmSchema,
  RawPresentationSchema,
  RawSpecialiteSchema,
  RefComposition,
  RefGenerique,
  type DependencyMaps,
  GenericType,
  type CisId,
  type GroupId,
  type GenericInfo,
  type Presentation,
  type Product,
  type RawAvailability,
  type RawComposition,
  type RawConditions,
  type RawGroup,
  type RawPresentation,
  type RawSpecialite,
  RawMitm
} from "./types";
import {
  buildComposition,
  computeCompositionSignature,
  createManufacturerResolver,
  detectComboMolecules,
  formatCompositionDisplay,
  isHomeopathic,
  levenshteinDistance,
  normalizeString,
  parseDateToIso,
  parsePriceToCents,
  parseRegulatoryInfo,
  resolveComposition,
  resolveDrawerLabel
} from "./logic";
import { ClusteringEngine, type ClusteringResult, type ProductMetaEntry } from "./clustering";

const BDPM_BASE_URL = "https://base-donnees-publique.medicaments.gouv.fr/download/file/";
const DATA_DIR = "data";

const isBoironManufacturer = (name: string): boolean => {
  const normalized = name?.toLowerCase().replace(/\s+/g, " ").trim();
  if (!normalized) return false;
  return normalized.includes("boiron");
};


const buildComboFallbackSignature = (
  label: string,
  baseTokens: string[]
): { signature: string; tokens: string[] } => {
  const codeTokens = Array.from(new Set(baseTokens.filter((t) => t.startsWith("C:"))));
  if (codeTokens.length >= 2) {
    return { signature: codeTokens.join("|"), tokens: codeTokens };
  }
  if (codeTokens.length === 1) {
    return { signature: codeTokens[0], tokens: codeTokens };
  }

  const normalizedLabel = label?.replace(/\u00A0/g, " ") ?? "";
  if (!normalizedLabel) return { signature: "", tokens: [] };

  const stripUnits = (text: string) =>
    text
      .replace(
        /\b\d+(?:[.,]\d+)?\s*(?:MG|G|UG|µG|MCG|ML|UI|MUI|IU|%|MICROGRAMME(?:S)?|GRAMME(?:S)?|MILLIGRAMME(?:S)?|POUR\s*CENT)\b/gi,
        " "
      )
      .replace(/\s+/g, " ")
      .trim();

  const parts = normalizedLabel
    .split(/[+/]/)
    .map(stripUnits)
    .map((p) => p.replace(/\s+/g, " ").trim().toLowerCase())
    .filter((p) => p && p.length >= 3);

  const unique = Array.from(new Set(parts));
  if (unique.length < 2) return { signature: "", tokens: [] };

  const tokens = unique.map((token) => `COMBO:${token}`);
  return { signature: tokens.join("|"), tokens };
};


// --- Helper: Download ---
async function download(filename: string): Promise<string> {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const url = `${BDPM_BASE_URL}${filename}`;
  console.log(`⬇️ Downloading ${url}...`);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`HTTP ${response.status} for ${url}`);

  const path = `${DATA_DIR}/${filename}`;
  await Bun.write(path, await response.arrayBuffer());
  return path;
}

// --- Helper: Stream Processor ---
async function processStream<T>(
  path: string,
  schema: z.ZodType<T>,
  onBatch: (batch: T[]) => void
) {
  const batchSize = 5000;
  let batch: T[] = [];
  const stream = fs
    .createReadStream(path)
    .pipe(iconv.decodeStream("win1252"))
    .pipe(
      parse({
        delimiter: "\t",
        relax_quotes: true,
        from_line: 1,
        skip_empty_lines: true,
        relax_column_count: true
      })
    );

  for await (const record of stream) {
    const result = schema.safeParse(record);
    if (result.success) {
      batch.push(result.data);
      if (batch.length >= batchSize) {
        onBatch(batch);
        batch = [];
      }
    }
  }

  if (batch.length > 0) onBatch(batch);
}

// --- Helper: Generic Map Loader ---
type LoadMapOptions<T, K, V> = {
  path: string;
  schema: z.ZodType<T>;
  targetMap: Map<K, V>;
  keyFn: (row: T) => K | null | undefined;
  accumulator: (current: V | undefined, row: T) => V;
  label?: string;
};

async function loadMap<T, K, V>({
  path,
  schema,
  targetMap,
  keyFn,
  accumulator,
  label
}: LoadMapOptions<T, K, V>) {
  let total = 0;
  let skipped = 0;

  await processStream<T>(path, schema, (batch) => {
    for (const row of batch) {
      total += 1;
      const key = keyFn(row);
      if (key === null || key === undefined) {
        skipped += 1;
        continue;
      }
      const current = targetMap.get(key as K);
      const next = accumulator(current, row);
      targetMap.set(key as K, next);
    }
  });

  if (label) {
    console.log(
      `✅ Loaded ${label}: ${targetMap.size} keys (skipped ${skipped}/${total})`
    );
  }

  return { total, skipped, keys: targetMap.size };
}

// --- Helper: Load dependency maps in parallel ---
export async function loadDependencies({
  conditionsPath,
  compositionsPath,
  presentationsPath,
  genericsPath,
  availabilityPath,
  mitmPath
}: {
  conditionsPath: string;
  compositionsPath: string;
  presentationsPath: string;
  genericsPath: string;
  availabilityPath: string;
  mitmPath?: string;
}): Promise<{
  dependencyMaps: DependencyMaps;
  shortageMap: Map<string, { statusCode: string; statusLabel: string; link: string | null }>;
  groupsData: RawGroup[];
}> {
  const dependencyMaps: DependencyMaps = {
    conditions: new Map(),
    compositions: new Map(),
    presentations: new Map(),
    generics: new Map(),
    atc: new Map()
  };

  const shortageMap = new Map<string, { statusCode: string; statusLabel: string; link: string | null }>();
  const groupsData: RawGroup[] = [];

  await Promise.all([
    loadMap<RawConditions, CisId, string[]>({
      path: conditionsPath,
      schema: RawConditionsSchema,
      targetMap: dependencyMaps.conditions,
      keyFn: (row) => row[0],
      accumulator: (current, row) => {
        const list = current ?? [];
        list.push(row[1]);
        return list;
      },
      label: "conditions"
    }),
    loadMap<RawComposition, CisId, RawComposition[]>({
      path: compositionsPath,
      schema: RawCompositionSchema,
      targetMap: dependencyMaps.compositions,
      keyFn: (row) => row[0],
      accumulator: (current, row) => {
        const list = current ?? [];
        list.push(row);
        return list;
      },
      label: "compositions"
    }),
    loadMap<RawPresentation, CisId, RawPresentation[]>({
      path: presentationsPath,
      schema: RawPresentationSchema,
      targetMap: dependencyMaps.presentations,
      keyFn: (row) => row[0],
      accumulator: (current, row) => {
        const list = current ?? [];
        list.push(row);
        return list;
      },
      label: "presentations"
    }),
    loadMap<RawGroup, CisId, GenericInfo>({
      path: genericsPath,
      schema: RawGroupSchema,
      targetMap: dependencyMaps.generics,
      keyFn: (row) => row[2],
      accumulator: (_current, row) => {
        groupsData.push(row);
        const [groupId, label, , type, sort] = row;
        return { groupId, label, type, sort };
      },
      label: "generics"
    }),
    loadMap<RawAvailability, string, { statusCode: string; statusLabel: string; link: string | null }>({
      path: availabilityPath,
      schema: RawAvailabilitySchema,
      targetMap: shortageMap,
      keyFn: (row) => {
        const [cis, cip] = row;
        if (cip && cip.length === 13) return cip;
        if (cis) return cis;
        return null;
      },
      accumulator: (_current, row) => {
        const [, , statusCode, statusLabel, , , link] = row;
        return {
          statusCode: statusCode || "",
          statusLabel: statusLabel || "",
          link: link ?? null
        };
      },
      label: "availability"
    })
  ]);

  if (mitmPath) {
    await loadMap({
      path: mitmPath,
      schema: RawMitmSchema,
      targetMap: dependencyMaps.atc,
      keyFn: (row: RawMitm) => row[0],
      accumulator: (current: RawMitm[] | undefined, row: RawMitm) => {
        const list = current ?? [];
        list.push(row);
        return list;
      },
      label: "mitm"
    });
  }

  return { dependencyMaps, shortageMap, groupsData };
}

export type ValidationIssue = {
  kind: string;
  groupId?: string;
  cis?: string;
  detail: string;
};

export function buildValidationIssues({
  clustering,
  dependencyMaps,
  groupCompositionCanonical,
  productStatusMap,
  shortageMap,
  cisDetails: _cisDetails
}: {
  clustering: ClusteringResult;
  dependencyMaps: DependencyMaps;
  groupCompositionCanonical: Map<string, { tokens: string[]; substances: Array<{ name: string; dosage: string; nature: "FT" | "SA" | null }> }>;
  productStatusMap: Map<CisId, string>;
  shortageMap: Map<string, { statusCode: string; statusLabel: string; link: string | null }>;
  cisDetails: Map<CisId, { label: string; form: string; route: string }>;
}): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  void _cisDetails;
  const { groupNaming, groupRoutes, cisToCluster } = clustering;

  for (const [groupId, routes] of groupRoutes) {
    if (routes.size > 1) {
      issues.push({
        kind: "ROUTE_INCOMPATIBLE",
        groupId,
        detail: `Group has multiple routes: ${Array.from(routes).join(", ")}`
      });
    }
  }

  for (const [cis, rows] of dependencyMaps.compositions) {
    const actives = rows.filter((r) => r[6] === "SA" || r[6] === "FT");
    if (actives.length === 1) {
      const substance = normalizeString(actives[0][3]);
      const genericInfo = dependencyMaps.generics.get(cis);
      const groupId = genericInfo?.groupId;
      const genericClean = groupId ? clustering.groupNaming.get(groupId)?.genericLabelClean : null;
      if (genericClean && substance && !genericClean.toLowerCase().includes(substance)) {
        issues.push({
          kind: "MONO_COMPONENT_MISMATCH",
          groupId: groupId ?? undefined,
          cis,
          detail: `Single substance ${substance} not found in generic label ${genericClean}`
        });
      }
    }
  }

  for (const [cis, atcRows] of dependencyMaps.atc) {
    if (!atcRows?.length) continue;
    const genericInfo = dependencyMaps.generics.get(cis);
    if (!genericInfo) continue;
    const naming = clustering.groupNaming.get(genericInfo.groupId);
    if (!naming?.canonical) continue;
    const atcLabel = atcRows[0][2];
    if (!atcLabel) continue;
    const distance = levenshteinDistance(naming.canonical.toLowerCase(), atcLabel.toLowerCase());
    const threshold = Math.max(naming.canonical.length, atcLabel.length) * 0.6;
    if (distance > threshold) {
      issues.push({
        kind: "ATC_NAME_DISTANCE",
        groupId: genericInfo.groupId,
        cis,
        detail: `Canonical '${naming.canonical}' far from ATC '${atcLabel}' (d=${distance})`
      });
    }
  }

  const groupClusterMap = new Map<string, string>();
  for (const row of clustering.groupRows) {
    groupClusterMap.set(row.id, row.cluster_id);
  }

  const sortedGroups = Array.from(groupCompositionCanonical.entries()).sort(
    ([a], [b]) => Number.parseInt(a, 10) - Number.parseInt(b, 10)
  );
  for (let i = 0; i < sortedGroups.length - 1; i++) {
    const [groupId, signature] = sortedGroups[i];
    const [nextId, nextSignature] = sortedGroups[i + 1];
    const currentNum = Number.parseInt(groupId, 10);
    const nextNum = Number.parseInt(nextId, 10);
    if (!Number.isFinite(currentNum) || !Number.isFinite(nextNum)) continue;
    if (Math.abs(currentNum - nextNum) > 1) continue;
    if (
      signature.tokens.length > 0 &&
      nextSignature.tokens.length > 0 &&
      signature.tokens.join("|") === nextSignature.tokens.join("|")
    ) {
      const clusterA = groupClusterMap.get(groupId);
      const clusterB = groupClusterMap.get(nextId);
      if (clusterA && clusterB && clusterA !== clusterB) {
        issues.push({
          kind: "GROUP_SPLIT",
          groupId,
          detail: `Adjacent groups ${groupId}/${nextId} share composition but different clusters`
        });
      }
    }
  }

  for (const [cis, meta] of cisToCluster) {
    const marketing = productStatusMap.get(cis) ?? "";
    const shortage = shortageMap.get(cis);
    if (marketing.toLowerCase().includes("non commercialisée") && shortage?.statusCode === "4") {
      issues.push({
        kind: "COMMERCIAL_STATUS_CONFLICT",
        cis,
        detail: "Marked non commercialised but availability shows remise (status 4)"
      });
    }
  }

  for (const [groupId, naming] of groupNaming) {
    if (naming.namingSource === "GENER_PARSING" && !naming.historicalPrincepsRaw) {
      issues.push({
        kind: "NAMING_FALLBACK",
        groupId,
        detail: `Group ${groupId} uses parsing fallback for canonical '${naming.canonical}'`
      });
    }
  }

  return issues;
}

// --- Main Pipeline ---
async function main() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const dbPath = DEFAULT_DB_PATH;

  // Clean previous DB to ensure schema refresh
  fs.rmSync(dbPath, { force: true });
  fs.rmSync(`${dbPath}-wal`, { force: true });
  fs.rmSync(`${dbPath}-shm`, { force: true });
  const db = new ReferenceDatabase(dbPath);
  const excludedCis = new Set<CisId>();

  // 1. Download Files
  const cisPath = await download("CIS_bdpm.txt");
  const cipPath = await download("CIS_CIP_bdpm.txt");
  const groupsPath = await download("CIS_GENER_bdpm.txt");
  const cpdPath = await download("CIS_CPD_bdpm.txt");
  const dispoPath = await download("CIS_CIP_Dispo_Spec.txt");
  const compoPath = await download("CIS_COMPO_bdpm.txt");
  const mitmPath = await download("CIS_MITM.txt");

  console.log("🚫 Pre-scanning Boiron products...");
  await processStream<RawSpecialite>(cisPath, RawSpecialiteSchema, (batch) => {
    for (const row of batch) {
      const cis = row[0];
      const holder = row[10];
      if (isBoironManufacturer(holder)) {
        excludedCis.add(cis);
      }
    }
  });

  console.log("🚫 Pre-scanning homeopathic products...");
  await processStream<RawSpecialite>(cisPath, RawSpecialiteSchema, (batch) => {
    for (const row of batch) {
      const cis = row[0];
      const label = row[1];
      const holder = row[10];
      if (isHomeopathic(label, "", holder)) {
        excludedCis.add(cis);
      }
    }
  });

  console.log("⚡ Pre-loading dependency maps...");
  const { dependencyMaps, shortageMap, groupsData } = await loadDependencies({
    conditionsPath: cpdPath,
    compositionsPath: compoPath,
    presentationsPath: cipPath,
    genericsPath: groupsPath,
    availabilityPath: dispoPath,
    mitmPath
  });

  const compoMap = new Map<CisId, RefComposition[]>();
  const genericsMap = new Map<CisId, RefGenerique>();
  const groupMasterMap = new Map<GroupId, { label: string }>();

  await Promise.all([
    Promise.resolve().then(() => {
      for (const [cis, rows] of dependencyMaps.compositions) {
        if (excludedCis.has(cis)) continue;
        const mapped = rows.map(
          ([
            cisId,
            elementLabel,
            codeSubstance,
            substanceName,
            dosage,
            reference,
            nature,
            linkId
          ]) =>
            ({
              cis: cisId,
              elementLabel,
              codeSubstance,
              substanceName,
              dosage,
              reference,
              nature,
              linkId
            }) satisfies RefComposition
        );
        if (mapped.length > 0) {
          compoMap.set(cis, mapped);
        }
      }
    }),
    Promise.resolve().then(() => {
      for (const row of groupsData) {
        const [groupId, label, cis, type] = row;
        if (excludedCis.has(cis)) continue;
        const parsedType = Number.parseInt(type, 10);
        const numericType = Number.isFinite(parsedType) ? parsedType : GenericType.UNKNOWN;
        genericsMap.set(cis, { groupId, label, cis, type: numericType });
        if (numericType === GenericType.PRINCEPS && !groupMasterMap.has(groupId)) {
          groupMasterMap.set(groupId, { label });
        }
      }
    })
  ]);

  const groupCompositionCanonical = new Map<
    string,
    { tokens: string[]; substances: Array<{ name: string; dosage: string; nature: "FT" | "SA" | null }> }
  >();

  {
    const builder = new Map<
      string,
      {
        tokens: Set<string>;
        substances: Map<string, { name: string; dosage: string; nature: "FT" | "SA" | null }>;
      }
    >();

    for (const [cis, rows] of compoMap) {
      const genericInfo = dependencyMaps.generics.get(cis);
      if (!genericInfo) continue;
      const groupId = genericInfo.groupId;
      if (!builder.has(groupId)) {
        builder.set(groupId, { tokens: new Set(), substances: new Map() });
      }
      const current = builder.get(groupId)!;

      for (const row of rows) {
        if (row.nature !== "FT" && row.nature !== "SA") continue;
        const code = row.codeSubstance.trim();
        const normalizedName = normalizeString(row.substanceName);
        const key = code && code !== "0" ? `C:${code}` : normalizedName ? `N:${normalizedName}` : null;
        if (!key) continue;

        current.tokens.add(key);
        const dosage = row.dosage?.trim() ?? "";
        const existing = current.substances.get(key);
        const shouldReplace =
          !existing ||
          (existing.nature === "SA" && row.nature === "FT") ||
          (!existing.dosage && !!dosage);
        if (shouldReplace) {
          current.substances.set(key, {
            name: row.substanceName.trim() || existing?.name || "",
            dosage,
            nature: row.nature
          });
        }
      }
    }

    for (const [groupId, { tokens, substances }] of builder) {
      groupCompositionCanonical.set(groupId, {
        tokens: Array.from(tokens).sort((a, b) => a.localeCompare(b)),
        substances: Array.from(substances.values())
      });
    }
  }

  const cisNames = new Map<CisId, string>();
  const manufacturerResolver = createManufacturerResolver();
  const products: Product[] = [];
  const productStatusMap = new Map<CisId, string>();
  // Metadata cache for clustering decisions
  const productMeta = new Map<CisId, ProductMetaEntry>();
  const cisDetails = new Map<CisId, { label: string; form: string; route: string }>();

  // 2. Process Specialties (Products)
  console.log("📦 Processing Products...");
  await processStream<RawSpecialite>(cisPath, RawSpecialiteSchema, (batch) => {
    const transformed: Product[] = [];
    for (const row of batch) {
      const cis = row[0];
      const holder = row[10];
      if (isBoironManufacturer(holder)) {
        excludedCis.add(cis);
        continue;
      }

      const conditions = dependencyMaps.conditions.get(cis) ?? [];
      const compositionRows = dependencyMaps.compositions.get(cis) ?? [];
      const genericInfo = dependencyMaps.generics.get(cis);
      const groupCanonical = genericInfo ? groupCompositionCanonical.get(genericInfo.groupId) : undefined;
      let compositionSignature = computeCompositionSignature(compoMap.get(cis));
      const hasComboSignal =
        compositionSignature.tokens.length <= 1 && detectComboMolecules(row[1]);
      let effectiveSignature = hasComboSignal ? "" : compositionSignature.signature;

      if (hasComboSignal) {
        const comboFallback = buildComboFallbackSignature(row[1], compositionSignature.tokens);
        if (comboFallback.signature) {
          compositionSignature = {
            signature: comboFallback.signature,
            tokens: comboFallback.tokens,
            bases: [],
            nature: null
          };
          effectiveSignature = comboFallback.signature;
        }
      }

      if (!effectiveSignature && groupCanonical && groupCanonical.tokens.length > 0) {
        compositionSignature = {
          signature: groupCanonical.tokens.join("|"),
          tokens: groupCanonical.tokens,
          bases: [],
          nature: null
        };
        effectiveSignature = compositionSignature.signature;
      }

      if (!effectiveSignature) {
        const atcRows = dependencyMaps.atc.get(cis);
        const primaryAtc = atcRows?.[0]?.[1];
        if (primaryAtc) {
          effectiveSignature = `ATC:${primaryAtc}`;
        }
      }

      const composition = buildComposition(compositionRows);
      const compositionCodes =
        composition.codes.length > 0
          ? composition.codes
          : groupCanonical
            ? groupCanonical.tokens.filter((t) => t.startsWith("C:")).map((t) => t.slice(2))
            : [];

      let compositionResolved = resolveComposition(cis, row[1], compoMap);
      if (compositionResolved.structured.length === 0 && groupCanonical?.substances.length) {
        const structured = [
          {
            element: "composition",
            substances: groupCanonical.substances.map((s) => ({
              name: s.name || "Composition inconnue",
              dosage: s.dosage ?? ""
            }))
          }
        ];
        compositionResolved = {
          display: formatCompositionDisplay(structured),
          structured
        };
      }
      const drawerLabel = resolveDrawerLabel(cis, row[1], genericsMap, groupMasterMap);
      const surveillance = row[11].trim().toLowerCase() === "oui";
      const manufacturerId = manufacturerResolver.resolve(holder).id;
      const parsedGeneric = genericInfo ? Number.parseInt(genericInfo.type, 10) : NaN;
      const genericType =
        Number.isFinite(parsedGeneric) &&
        [
          GenericType.PRINCEPS,
          GenericType.GENERIC,
          GenericType.COMPLEMENTARY,
          GenericType.SUBSTITUTABLE,
          GenericType.AUTO_SUBSTITUTABLE
        ].includes(parsedGeneric as GenericType)
          ? (parsedGeneric as GenericType)
          : GenericType.UNKNOWN;
      const isPrinceps = genericType === GenericType.PRINCEPS;
      const marketingStatus = row[6];

      cisNames.set(cis, row[1]);
      cisDetails.set(cis, { label: row[1], form: row[2], route: row[3] });
      productStatusMap.set(cis, marketingStatus);
      productMeta.set(cis, {
        label: row[1],
        codes: compositionCodes,
        signature: effectiveSignature,
        bases: compositionSignature.bases,
        isPrinceps,
        groupId: null,
        genericType
      });

      transformed.push({
        cis,
        label: row[1],
        form: row[2],
        routes: row[3],
        type_procedure: row[5],
        surveillance_renforcee: surveillance,
        marketing_status: marketingStatus,
        manufacturer_id: manufacturerId,
        is_princeps: isPrinceps,
        generic_type: genericType,
        group_id: null,
        date_amm: parseDateToIso(row[7]),
        regulatory_info: JSON.stringify(parseRegulatoryInfo(conditions.join(", "))),
        composition: JSON.stringify(compositionResolved.structured),
        composition_codes: JSON.stringify(compositionCodes),
        composition_display: compositionResolved.display,
        drawer_label: drawerLabel
      });
    }

    products.push(...transformed);
    if (products.length % 1000 === 0) {
      console.log(`📊 Processed ${products.length} products...`);
    }
  });

  const manufacturers = manufacturerResolver.toRows();
  if (manufacturers.length > 0) {
    db.insertManufacturers(manufacturers);
  }
  if (products.length > 0) {
    console.log(`💾 Inserting ${products.length} products...`);
    db.insertProducts(products);
  } else {
    console.log("⚠️ No products to insert!");
  }

  // Propagate composition signatures within the same BDPM generic group:
  // if a group has a unique non-empty signature, reuse it for members lacking rows.
  const groupSignatureMap = new Map<string, Set<string>>();
  const groupSignatureUnion = new Map<string, Set<string>>();
  for (const [cis, meta] of productMeta) {
    const genericInfo = dependencyMaps.generics.get(cis);
    if (!genericInfo) continue;
    if (!meta.signature) continue;
    if (!groupSignatureMap.has(genericInfo.groupId)) {
      groupSignatureMap.set(genericInfo.groupId, new Set<string>());
    }
    groupSignatureMap.get(genericInfo.groupId)!.add(meta.signature);

    if (!groupSignatureUnion.has(genericInfo.groupId)) {
      groupSignatureUnion.set(genericInfo.groupId, new Set<string>());
    }
    const tokens = meta.signature.split("|").filter(Boolean);
    for (const t of tokens) {
      groupSignatureUnion.get(genericInfo.groupId)!.add(t);
    }
  }

  for (const [cis, meta] of productMeta) {
    if (meta.signature) continue;
    const genericInfo = dependencyMaps.generics.get(cis);
    if (!genericInfo) continue;
    const signatures = groupSignatureMap.get(genericInfo.groupId);
    if (!signatures || signatures.size !== 1) continue;
    const inferred = signatures.values().next().value;
    meta.signature = inferred;
  }

  // Normalize group signatures: if a group has any signature tokens, align all members to the union
  for (const [cis, meta] of productMeta) {
    const genericInfo = dependencyMaps.generics.get(cis);
    if (!genericInfo) continue;
    const tokens = groupSignatureUnion.get(genericInfo.groupId);
    if (!tokens || tokens.size === 0) continue;
    const unified = Array.from(tokens).sort((a, b) => a.localeCompare(b)).join("|");
    meta.signature = unified;
  }

  // Normalize brand-level signatures: if the exact label appears with differing signatures, merge tokens
  const labelSignatureUnion = new Map<string, Set<string>>();
  for (const [cis, meta] of productMeta) {
    const label = cisNames.get(cis);
    if (!label || !meta.signature) continue;
    const key = normalizeString(label) || label.trim();
    if (!labelSignatureUnion.has(key)) {
      labelSignatureUnion.set(key, new Set<string>());
    }
    const tokens = meta.signature.split("|").filter(Boolean);
    for (const t of tokens) {
      labelSignatureUnion.get(key)!.add(t);
    }
  }
  for (const [cis, meta] of productMeta) {
    const label = cisNames.get(cis);
    if (!label) continue;
    const key = normalizeString(label) || label.trim();
    const tokens = labelSignatureUnion.get(key);
    if (!tokens || tokens.size === 0) continue;
    const unified = Array.from(tokens).sort((a, b) => a.localeCompare(b)).join("|");
    meta.signature = unified;
  }

  const clusteringEngine = new ClusteringEngine({
    dependencyMaps,
    groupsData,
    excludedCis,
    productMeta,
    cisNames,
    cisDetails,
    groupCompositionCanonical
  });

  const clusteringResult = clusteringEngine.run();
  const { clusters, groupRows, productGroupUpdates, missingGroupCis, groupStats, groupNaming, groupRoutes } =
    clusteringResult;

  db.insertClusters(clusters);
  db.insertGroups(groupRows);
  db.updateProductGrouping(productGroupUpdates);

  if (missingGroupCis.size > 0) {
    console.warn(
      `⚠️ Rescued ${missingGroupCis.size} groups with missing CIS via label parsing (total: ${groupStats.total}, linked via CIS: ${groupStats.linkedViaCis}, rescued via text: ${groupStats.rescuedViaText}, failed: ${groupStats.failed})`
    );
  }

  const validationIssues = buildValidationIssues({
    clustering: clusteringResult,
    dependencyMaps,
    groupCompositionCanonical,
    productStatusMap,
    shortageMap,
    cisDetails
  });
  if (validationIssues.length > 0) {
    console.warn(`⚠️ Validation issues detected: ${validationIssues.length}`);
  }

  // 4. Process Presentations (CIPs) from pre-materialized map
  console.log("🏷️ Processing Presentations...");
  const presentationRows: Presentation[] = [];
  for (const [cis, rows] of dependencyMaps.presentations) {
    if (!cisNames.has(cis) || excludedCis.has(cis)) continue;
    for (const row of rows) {
      const shortage = shortageMap.get(row[6]) || shortageMap.get(row[0]);
      const cisMarketingStatus = productStatusMap.get(row[0]);
      const rawMarketStatus = (row[4] || "").trim();
      const isNonCommercial = !!cisMarketingStatus && cisMarketingStatus.toLowerCase().includes("non commercialisée");
      const isRemise = shortage?.statusCode === "4";
      const marketStatus = isRemise
        ? shortage?.statusLabel || rawMarketStatus || cisMarketingStatus || null
        : isNonCommercial
          ? cisMarketingStatus
          : rawMarketStatus || cisMarketingStatus || null;
      const availabilityStatus = shortage
        ? [shortage.statusCode, shortage.statusLabel].filter(Boolean).join(":")
        : null;
      presentationRows.push({
        cis: row[0],
        cip13: row[6],
        reimbursement_rate: row[8],
        price_cents: parsePriceToCents(row[9]),
        market_status: marketStatus,
        availability_status: availabilityStatus,
        ansm_link: shortage?.link ?? null,
        date_commercialisation: parseDateToIso(row[5])
      });
    }
  }

  if (presentationRows.length > 0) {
    db.insertPresentations(presentationRows);
  }

  // 5. Finalize
  console.log("🔍 Building Search Index...");
  db.populateSearchIndex();
  db.optimize();
  db.close();

  console.log(`✅ Pipeline Complete: ${dbPath} generated`);
}

if (import.meta.main) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}

function extractFormHints(label: string): string {
  const upper = label.toUpperCase();
  const hints = [
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
    "CAPSULE",
    "GELULE",
    "SPRAY",
    "PULVERISATION",
    "NEBULISATION",
    "PATCH",
    "INHALATION",
    "NASAL",
    "BUCCAL",
    "SUBLINGUAL",
    "CUTANEE",
    "TOPIQUE"
  ];
  const hits = new Set<string>();
  for (const h of hints) {
    if (upper.includes(h)) hits.add(h);
  }
  return Array.from(hits).join(" ");
}
