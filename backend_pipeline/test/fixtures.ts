import { ReferenceDatabase } from "../src/db";
import { generateClusterId, normalizeString } from "../src/logic";
import { CisIdSchema, GroupIdSchema, GenericType } from "../src/types";
import type { CisId, Cluster, GroupId, Product, ProductGroupingUpdate } from "../src/types";

export class TestDbBuilder {
  db: ReferenceDatabase;
  cisNames = new Map<CisId, string>();
  private products: Product[] = [];
  private groups: Array<{ id: GroupId; label: string; princepsCis?: CisId }> = [];
  private manufacturers = new Map<string, number>();
  private nextManufacturerId = 1;

  constructor() {
    this.db = new ReferenceDatabase(":memory:");
  }

  addSpecialty(
    cis: string | CisId,
    label: string,
    isPrinceps = false,
    compositionCodes: string[] = [],
    manufacturerLabel = "LAB"
  ) {
    const cisId = typeof cis === "string" ? CisIdSchema.parse(cis) : cis;
    this.cisNames.set(cisId, label);
    const manufacturerId =
      this.manufacturers.get(manufacturerLabel) ??
      (() => {
        const id = this.nextManufacturerId++;
        this.manufacturers.set(manufacturerLabel, id);
        return id;
      })();
    const product: Product = {
      cis: cisId,
      label,
      is_princeps: isPrinceps,
      generic_type: isPrinceps ? GenericType.PRINCEPS : GenericType.UNKNOWN,
      group_id: null,
      form: "Comprimé",
      routes: "orale",
      manufacturer_id: manufacturerId,
      marketing_status: "Actif",
      date_amm: "2020-01-01",
      regulatory_info: "{}",
      composition: "[]",
      composition_codes: JSON.stringify(compositionCodes),
      composition_display: "",
      drawer_label: normalizeString(label) || label
    };
    this.products.push(product);
    return this;
  }

  addGroup(groupId: string | GroupId, rawLabel: string, princepsCis?: string | CisId) {
    const groupIdValue = typeof groupId === "string" ? GroupIdSchema.parse(groupId) : groupId;
    const princepsCisValue =
      typeof princepsCis === "string" ? CisIdSchema.parse(princepsCis) : princepsCis;

    this.groups.push({ id: groupIdValue, label: rawLabel, princepsCis: princepsCisValue });
    return this;
  }

  finalize() {
    if (this.manufacturers.size > 0) {
      this.db.insertManufacturers(
        Array.from(this.manufacturers.entries()).map(([label, id]) => ({ id, label }))
      );
    }
    // Insert products first
    this.db.insertProducts(this.products);

    // Prepare meta map
    const productMeta = new Map<
      CisId,
      {
        label: string;
        codes: string[];
        signature: string;
        isPrinceps: boolean;
        groupId: GroupId | null;
        genericType: GenericType;
      }
    >();
    for (const product of this.products) {
      const codes = JSON.parse(product.composition_codes) as string[];
      const signature =
        codes.length > 0
          ? codes
              .map((c) => `C:${c}`)
              .sort((a, b) => a.localeCompare(b))
              .join("|")
          : "";
      productMeta.set(product.cis, {
        label: product.label,
        codes,
        signature,
        isPrinceps: false,
        groupId: null,
        genericType: product.generic_type
      });
    }

    const productGroupUpdates: ProductGroupingUpdate[] = [];

    // Mark princeps/group linkage
    for (const { id, princepsCis } of this.groups) {
      if (princepsCis) {
        const meta = productMeta.get(princepsCis);
        if (meta) {
          meta.isPrinceps = true;
          meta.groupId = id;
          meta.genericType = GenericType.PRINCEPS;
        }
        productGroupUpdates.push({
          cis: princepsCis,
          group_id: id,
          is_princeps: true,
          generic_type: GenericType.PRINCEPS
        });
      }
    }

    // Signature-first clustering (mirrors src/index.ts)
    const clusters = new Map<string, Cluster>();
    const cisToCluster = new Map<CisId, string>();

    const ensureCluster = (
      clusterId: string,
      label: string,
      princepsLabel: string,
      substanceCode: string
    ) => {
      if (!clusters.has(clusterId)) {
        clusters.set(clusterId, {
          id: clusterId,
          label,
          princeps_label: princepsLabel,
          substance_code: substanceCode
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

    for (const [signature, cisList] of signatureBuckets) {
      const metas = cisList
        .map((cis) => ({ cis, meta: productMeta.get(cis)! }))
        .filter((entry) => entry.meta !== undefined);
      if (metas.length === 0) continue;

      let representative = metas.find((m) => m.meta.isPrinceps);
      if (!representative) {
        representative = metas.reduce((shortest, current) =>
          current.meta.label.length < shortest.meta.label.length ? current : shortest
        );
      }

      const clusterId = buildClusterIdFromSignature(signature);
      const princepsLabel =
        metas.find((m) => m.meta.isPrinceps)?.meta.label ?? representative.meta.label;

      ensureCluster(clusterId, representative.meta.label, princepsLabel, signature || "unknown");
      for (const { cis } of metas) {
        cisToCluster.set(cis, clusterId);
      }
    }

    // Fallback: products without signatures
    for (const [cis, meta] of productMeta) {
      if (meta.signature) continue;
      const normalized = normalizeString(meta.label);
      const clusterId = generateClusterId(normalized, meta.isPrinceps ? cis : undefined);
      ensureCluster(clusterId, meta.label, meta.label, normalized || "unknown");
      cisToCluster.set(cis, clusterId);
    }

    // Build group rows
    const groupRows: Array<{ id: GroupId; cluster_id: string; label: string }> = [];
    for (const { id, label, princepsCis } of this.groups) {
      const clusterId =
        (princepsCis && cisToCluster.get(princepsCis)) ||
        generateClusterId(normalizeString(label), princepsCis);
      groupRows.push({ id, cluster_id: clusterId, label });
    }

    this.db.insertClusters(Array.from(clusters.values()));
    this.db.insertGroups(groupRows);
    if (productGroupUpdates.length > 0) {
      this.db.updateProductGrouping(productGroupUpdates);
    }
    return this;
  }
}
