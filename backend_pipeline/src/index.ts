import fs from "node:fs";
import { parse } from "csv-parse";
import iconv from "iconv-lite";
import { z } from "zod";
import { ReferenceDatabase } from "./db";
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
  type Cluster,
  type GroupId,
  type GroupRow,
  type GenericInfo,
  type ProductGroupingUpdate,
  type Presentation,
  type Product,
  type RawAvailability,
  type RawComposition,
  type RawConditions,
  type RawGroup,
  type RawPresentation,
  type RawSpecialite
} from "./types";
import {
  buildComposition,
  computeCompositionSignature,
  createManufacturerResolver,
  generateClusterId,
  normalizeString,
  parseDateToIso,
  parseGroupMetadata,
  parsePriceToCents,
  parseRegulatoryInfo,
  resolveComposition,
  resolveDrawerLabel
} from "./logic";

const BDPM_BASE_URL = "https://base-donnees-publique.medicaments.gouv.fr/download/file/";
const DATA_DIR = "data";

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
  shortageMap: Map<string, { status: string; link: string | null }>;
  groupsData: RawGroup[];
}> {
  const dependencyMaps: DependencyMaps = {
    conditions: new Map(),
    compositions: new Map(),
    presentations: new Map(),
    generics: new Map(),
    atc: new Map()
  };

  const shortageMap = new Map<string, { status: string; link: string | null }>();
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
        const [groupId, label, , type] = row;
        return { groupId, label, type };
      },
      label: "generics"
    }),
    loadMap<RawAvailability, string, { status: string; link: string | null }>({
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
        const [, , , status, , , link] = row;
        return { status, link: link ?? null };
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

// --- Main Pipeline ---
async function main() {
  // Clean previous DB to ensure schema refresh
  fs.rmSync("reference.db", { force: true });
  const db = new ReferenceDatabase("reference.db");

  // 1. Download Files
  const cisPath = await download("CIS_bdpm.txt");
  const cipPath = await download("CIS_CIP_bdpm.txt");
  const groupsPath = await download("CIS_GENER_bdpm.txt");
  const cpdPath = await download("CIS_CPD_bdpm.txt");
  const dispoPath = await download("CIS_CIP_Dispo_Spec.txt");
  const compoPath = await download("CIS_COMPO_bdpm.txt");
  const mitmPath = await download("CIS_MITM.txt");

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
        const parsedType = Number.parseInt(type, 10);
        const numericType = Number.isFinite(parsedType) ? parsedType : GenericType.UNKNOWN;
        genericsMap.set(cis, { groupId, label, cis, type: numericType });
        if (numericType === GenericType.PRINCEPS && !groupMasterMap.has(groupId)) {
          groupMasterMap.set(groupId, { label });
        }
      }
    })
  ]);

  const cisNames = new Map<CisId, string>();
  const manufacturerResolver = createManufacturerResolver();
  const products: Product[] = [];

  // Metadata cache for clustering decisions
  const productMeta = new Map<
    CisId,
    {
      label: string;
      codes: string[];
      signature: string;
      isPrinceps: boolean;
      groupId: string | null;
      genericType: GenericType;
    }
  >();

  // 2. Process Specialties (Products)
  console.log("📦 Processing Products...");
  await processStream<RawSpecialite>(cisPath, RawSpecialiteSchema, (batch) => {
    const transformed: Product[] = batch.map((row) => {
      const cis = row[0];
      const conditions = dependencyMaps.conditions.get(cis) ?? [];
      const compositionRows = dependencyMaps.compositions.get(cis) ?? [];
      const compositionSignature = computeCompositionSignature(compoMap.get(cis));
      const composition = buildComposition(compositionRows);
      const compositionResolved = resolveComposition(cis, row[1], compoMap);
      const drawerLabel = resolveDrawerLabel(cis, row[1], genericsMap, groupMasterMap);
      const surveillance = row[11].trim().toLowerCase() === "oui";
      const manufacturerId = manufacturerResolver.resolve(row[10]).id;
      const genericInfo = dependencyMaps.generics.get(cis);
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

      cisNames.set(cis, row[1]);
      productMeta.set(cis, {
        label: row[1],
        codes: composition.codes,
        signature: compositionSignature.signature,
        isPrinceps,
        groupId: null,
        genericType
      });

      return {
        cis,
        label: row[1],
        form: row[2],
        routes: row[3],
        type_procedure: row[5],
        surveillance_renforcee: surveillance,
        marketing_status: row[4],
        manufacturer_id: manufacturerId,
        is_princeps: isPrinceps,
        generic_type: genericType,
        group_id: null,
        date_amm: parseDateToIso(row[7]),
        regulatory_info: JSON.stringify(parseRegulatoryInfo(conditions.join(", "))),
        composition: JSON.stringify(compositionResolved.structured),
        composition_codes: JSON.stringify(composition.codes),
        composition_display: compositionResolved.display,
        drawer_label: drawerLabel
      };
    });

    products.push(...transformed);
  });

  const manufacturers = manufacturerResolver.toRows();
  if (manufacturers.length > 0) {
    db.insertManufacturers(manufacturers);
  }
  if (products.length > 0) {
    db.insertProducts(products);
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

  // 3. Process Groups & Clusters
  console.log("🔗 Processing Groups & Clusters...");
  const groupInfos: Array<{
    groupId: string;
    rawLabel: string;
    princepsCis: CisId;
    molecule: string;
    brand: string;
    textBrand: string | null;
    normalized: string;
    genericType: GenericType;
    isPrinceps: boolean;
    hasProduct: boolean;
  }> = [];
  const missingGroupCis = new Set<CisId>();
  const groupStats = {
    total: 0,
    linkedViaCis: 0,
    rescuedViaText: 0,
    failed: 0
  };

  const clusters = new Map<string, Cluster>();
  const groupRows: GroupRow[] = [];
  const productGroupUpdates: ProductGroupingUpdate[] = [];
  const cisToCluster = new Map<CisId, string>();

  for (const row of groupsData) {
    groupStats.total++;
    const [groupId, rawLabel, cis, type] = row;
    const parsedType = Number.parseInt(type, 10);
    const genericType = Number.isFinite(parsedType) &&
      [
        GenericType.PRINCEPS,
        GenericType.GENERIC,
        GenericType.COMPLEMENTARY,
        GenericType.SUBSTITUTABLE,
        GenericType.AUTO_SUBSTITUTABLE
      ].includes(parsedType as GenericType)
      ? (parsedType as GenericType)
      : GenericType.UNKNOWN;
    const isPrinceps = genericType === GenericType.PRINCEPS;

    const meta = productMeta.get(cis);
    let molecule: string;
    let brand: string;
    let textBrand: string | null;

    let pendingUpdate: ProductGroupingUpdate | null = null;

    if (meta) {
      const parsed = parseGroupMetadata(rawLabel, cis, cisNames);
      molecule = parsed.molecule;
      brand = parsed.brand;
      textBrand = parsed.textBrand;
      meta.groupId = groupId;
      meta.genericType = genericType;
      if (isPrinceps) meta.isPrinceps = true;

      pendingUpdate = {
        cis,
        group_id: groupId,
        is_princeps: isPrinceps,
        generic_type: genericType
      };
      groupStats.linkedViaCis++;
    } else {
      const parsed = parseGroupMetadata(rawLabel, undefined, cisNames);
      molecule = parsed.molecule;
      brand = parsed.brand !== "Unknown" ? parsed.brand : "Référence (Retirée)";
      textBrand = parsed.textBrand;
      missingGroupCis.add(cis);
      groupStats.rescuedViaText++;
    }

    const normalized = normalizeString(molecule);
    if (!normalized) {
      groupStats.failed++;
      continue;
    }

    if (pendingUpdate) {
      productGroupUpdates.push(pendingUpdate);
    }

    groupInfos.push({
      groupId,
      rawLabel,
      princepsCis: cis,
      molecule,
      brand,
      textBrand,
      normalized,
      genericType,
      isPrinceps,
      hasProduct: !!meta
    });
  }

  // Signature-first clustering (composition-driven)
  const ensureCluster = (
    clusterId: string,
    label: string,
    princepsLabel: string,
    substanceCode: string,
    textBrandLabel: string | null = null
  ) => {
    if (!clusters.has(clusterId)) {
      clusters.set(clusterId, {
        id: clusterId,
        label,
        princeps_label: princepsLabel,
        substance_code: substanceCode,
        text_brand_label: textBrandLabel ?? undefined
      });
    }
  };

  const signatureBuckets = new Map<string, CisId[]>();
  for (const [cis, meta] of productMeta) {
    if (!meta.signature) continue;
    if (!signatureBuckets.has(meta.signature)) signatureBuckets.set(meta.signature, []);
    signatureBuckets.get(meta.signature)!.push(cis);
  }

  const buildClusterIdFromSignature = (signature: string): string => {
    const safe = signature.replace(/[^A-Z0-9|:_-]/gi, "_");
    return `CLS_SIG_${safe || "UNKNOWN"}`;
  };

  for (const [signatureKey, cisList] of signatureBuckets) {
    const metas = cisList
      .map((cis) => ({ cis, meta: productMeta.get(cis) }))
      .filter((entry) => entry.meta !== undefined) as Array<{
      cis: CisId;
      meta: {
        label: string;
        signature: string;
        isPrinceps: boolean;
        groupId: string | null;
        genericType: GenericType;
      };
    }>;

    if (metas.length === 0) continue;

    let representative = metas.find((m) => m.meta.isPrinceps);
    if (!representative) {
      representative = metas.reduce((shortest, current) =>
        current.meta.label.length < shortest.meta.label.length ? current : shortest
      );
    }

    const clusterId = buildClusterIdFromSignature(signatureKey);
    const princepsLabel =
      metas.find((m) => m.meta.isPrinceps)?.meta.label ?? representative.meta.label;
    ensureCluster(
      clusterId,
      representative.meta.label,
      princepsLabel,
      metas[0]?.meta.signature || "unknown"
    );

    for (const { cis } of metas) {
      cisToCluster.set(cis, clusterId);
    }
  }

  // Fallback for products without signatures: cluster by normalized label
  for (const [cis, meta] of productMeta) {
    if (meta.signature) continue;
    const normalized = normalizeString(meta.label);
    const clusterId = generateClusterId(normalized, meta.isPrinceps ? cis : undefined);
    ensureCluster(clusterId, meta.label, meta.label, normalized || "unknown");
    cisToCluster.set(cis, clusterId);
  }

  // Map generics group -> cluster from any member (prefer signature-based entries)
  const groupClusterMap = new Map<string, string>();
  for (const [cis, clusterId] of cisToCluster) {
    const genericInfo = dependencyMaps.generics.get(cis);
    if (!genericInfo) continue;
    if (!groupClusterMap.has(genericInfo.groupId)) {
      groupClusterMap.set(genericInfo.groupId, clusterId);
    }
  }

  // Build group rows with computed cluster ids (including rescued groups)
  for (const info of groupInfos) {
    let clusterId = cisToCluster.get(info.princepsCis);

    if (!clusterId) {
      const genericInfo = dependencyMaps.generics.get(info.princepsCis);
      const inferredCluster = genericInfo ? groupClusterMap.get(genericInfo.groupId) : undefined;
      if (inferredCluster) {
        clusterId = inferredCluster;
      }
    }

    if (!clusterId) {
      clusterId = generateClusterId(info.normalized);
      if (!clusters.has(clusterId)) {
        ensureCluster(
          clusterId,
          info.molecule,
          info.brand,
          info.normalized || "unknown",
          info.textBrand ?? null
        );
      }
    }

    groupRows.push({ id: info.groupId, cluster_id: clusterId, label: info.rawLabel });
  }

  db.insertClusters(Array.from(clusters.values()));
  db.insertGroups(groupRows);
  db.updateProductGrouping(productGroupUpdates);

  if (missingGroupCis.size > 0) {
    console.warn(
      `⚠️ Rescued ${missingGroupCis.size} groups with missing CIS via label parsing (total: ${groupStats.total}, linked via CIS: ${groupStats.linkedViaCis}, rescued via text: ${groupStats.rescuedViaText}, failed: ${groupStats.failed})`
    );
  }

  // 4. Process Presentations (CIPs) from pre-materialized map
  console.log("🏷️ Processing Presentations...");
  const presentationRows: Presentation[] = [];
  for (const [cis, rows] of dependencyMaps.presentations) {
    if (!cisNames.has(cis)) continue;
    for (const row of rows) {
      const shortage = shortageMap.get(row[6]) || shortageMap.get(row[0]);
      presentationRows.push({
        cis: row[0],
        cip13: row[6],
        reimbursement_rate: row[8],
        price_cents: parsePriceToCents(row[9]),
        availability_status: shortage?.status ?? null,
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

  console.log("✅ Pipeline Complete: reference.db generated");
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
