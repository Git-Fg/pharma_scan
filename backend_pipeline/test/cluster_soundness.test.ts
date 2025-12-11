import { describe, expect, test } from "bun:test";
import { ClusteringEngine } from "../src/clustering";
import { cleanProductLabel, generateClusterId, parseGroupLabel } from "../src/logic";
import type { DependencyMaps, RawGroup } from "../src/types";
import { GenericType } from "../src/types";

const emptyDeps = (): DependencyMaps => ({
  conditions: new Map(),
  compositions: new Map(),
  presentations: new Map(),
  generics: new Map(),
  atc: new Map()
});

const makeProductMeta = (
  label: string,
  genericType: GenericType = GenericType.UNKNOWN
) => ({
  label,
  codes: [],
  signature: "",
  bases: [],
  isPrinceps: genericType === GenericType.PRINCEPS,
  groupId: null,
  genericType
});

describe("Cluster soundness (Tiroir)", () => {
  test("parsers clean labels and split group references", () => {
    expect(cleanProductLabel("CLAMOXYL 1 g, poudre pour solution")).toBe("CLAMOXYL");
    expect(cleanProductLabel("Doliprane 500 mg comprimé pelliculé")).toBe("DOLIPRANE");
    expect(parseGroupLabel("AMOXICILLINE - CLAMOXYL")).toEqual({
      molecule: "AMOXICILLINE",
      reference: "CLAMOXYL"
    });
    expect(generateClusterId("Clamoxyl")).toBe("CLS_CLAMOXYL");
  });

  test("merges drawers by brand across dosages and assigns standalones", () => {
    const dependencyMaps = emptyDeps();
    dependencyMaps.generics.set("00000001", { groupId: "GCLAM", label: "AMOX", type: "0" });
    dependencyMaps.generics.set("00000002", { groupId: "GCLAMGEN", label: "AMOX", type: "1" });
    dependencyMaps.generics.set("00000003", { groupId: "GDOLI500", label: "PARA", type: "0" });
    dependencyMaps.generics.set("00000004", { groupId: "GDOLI1000", label: "PARA", type: "1" });

    const groupsData: RawGroup[] = [
      ["GCLAM", "AMOXICILLINE - CLAMOXYL", "00000001", "0"],
      ["GCLAMGEN", "AMOXICILLINE - CLAMOXYL", "00000002", "1"],
      ["GDOLI500", "PARACETAMOL - DOLIPRANE", "00000003", "0"],
      ["GDOLI1000", "PARACETAMOL - DOLIPRANE", "00000004", "1"]
    ];

    const productMeta = new Map([
      ["00000001", makeProductMeta("CLAMOXYL 1 g, poudre pour solution", GenericType.PRINCEPS)],
      ["00000002", makeProductMeta("AMOXICILLINE BIOGARAN 500 mg comprimé", GenericType.GENERIC)],
      ["00000003", makeProductMeta("DOLIPRANE 500 mg comprimé", GenericType.PRINCEPS)],
      ["00000004", makeProductMeta("DOLIPRANE 1000 mg comprimé", GenericType.GENERIC)],
      ["00000005", makeProductMeta("DOLIPRANE 200 mg suppositoire", GenericType.UNKNOWN)]
    ]);

    const cisDetails = new Map([
      [
        "00000001",
        { label: "CLAMOXYL 1 g, poudre pour solution", form: "poudre pour solution", route: "orale" }
      ],
      ["00000002", { label: "AMOXICILLINE BIOGARAN 500 mg comprimé", form: "comprimé", route: "orale" }],
      ["00000003", { label: "DOLIPRANE 500 mg comprimé", form: "comprimé", route: "orale" }],
      ["00000004", { label: "DOLIPRANE 1000 mg comprimé", form: "comprimé", route: "orale" }],
      ["00000005", { label: "DOLIPRANE 200 mg suppositoire", form: "suppositoire", route: "rectale" }]
    ]);

    const engine = new ClusteringEngine({
      dependencyMaps,
      groupsData,
      excludedCis: new Set(),
      productMeta,
      cisNames: new Map(),
      cisDetails,
      groupCompositionCanonical: new Map()
    });

    const result = engine.run();
    const clusterByCis = result.cisToCluster;

    const clamoxylCluster = clusterByCis.get("00000001");
    expect(clamoxylCluster).toBe(clusterByCis.get("00000002"));
    const clamoxyl = result.clusters.find((c) => c.id === clamoxylCluster);
    expect(clamoxyl?.label).toBe("CLAMOXYL");

    const dolipraneCluster = clusterByCis.get("00000003");
    expect(dolipraneCluster).toBe(clusterByCis.get("00000004"));
    expect(dolipraneCluster).toBe(clusterByCis.get("00000005"));
    const doliprane = result.clusters.find((c) => c.id === dolipraneCluster);
    expect(doliprane?.label).toBe("DOLIPRANE");

    expect(result.clusters.length).toBe(2);

    const clamoxylGroup = result.groupRows.find((g) => g.id === "GCLAM");
    expect(clamoxylGroup?.canonical_name).toBe("CLAMOXYL");
    expect(clamoxylGroup?.naming_source).toBe("TYPE_0_LINK");
    expect(clamoxylGroup?.routes).toBe('["orale"]');
  });
});
