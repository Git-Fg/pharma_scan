import { describe, expect, test } from "bun:test";
import { ReferenceDatabase } from "../src/db";
import {
  createManufacturerResolver,
  normalizeString,
  normalizeManufacturerName,
  parseDateToIso,
  parseGroupMetadata,
  parsePriceToCents,
  resolveComposition
} from "../src/logic";
import {
  CisIdSchema,
  GenericType,
  type Product,
  type RefComposition
} from "../src/types";

describe("1. Chemical Normalization (Sanitizer)", () => {
  test("Strips salts and forms", () => {
    expect(normalizeString("MÉMANTINE (CHLORHYDRATE DE)")).toBe("memantine");
    expect(normalizeString("ABACAVIR (SULFATE D')")).toBe("abacavir");
    expect(normalizeString("PERINDOPRIL ARGININE")).toBe("perindopril");
  });

  test("Handles 'Equivalant à'", () => {
    const raw = "ABACAVIR (SULFATE D') équivalant à ABACAVIR 300 mg";
    expect(normalizeString(raw)).toBe("abacavir");
  });

  test("Handles complex punctuation", () => {
    expect(normalizeString("PARACETAMOL - CODEINE")).toBe("codeine paracetamol");
    expect(normalizeString("PARACETAMOL/CODEINE")).toBe("codeine paracetamol");
  });
});

describe("2. Group Label Parsing (3-Tier Strategy)", () => {
  const princepsCis = CisIdSchema.parse("10000001");
  const cisNames = new Map([[princepsCis, "DOLIPRANE 1000 mg, comprimé"]]);

  test("Tier 1: Relational (Princeps Known)", () => {
    const result = parseGroupMetadata("PARACETAMOL (DCI) - TOTO", princepsCis, cisNames);
    expect(result.brand).toBe("DOLIPRANE 1000 mg, comprimé");
    expect(result.molecule).toContain("PARACETAMOL");
  });

  test("Tier 2: Simple Split", () => {
    const result = parseGroupMetadata("IBUPROFENE 400 mg - ADVIL", undefined, cisNames);
    expect(result.molecule).toBe("IBUPROFENE 400 mg");
    expect(result.brand).toBe("ADVIL");
  });
});

describe("3. Price parsing", () => {
  test("handles French formats and thousand separators", () => {
    expect(parsePriceToCents("12,50")).toBe(1250);
    expect(parsePriceToCents("  3,10 ")).toBe(310);
    expect(parsePriceToCents("1 200,50")).toBe(120050);
    expect(parsePriceToCents("1,200,50")).toBe(120050);
    expect(parsePriceToCents("1.200,50")).toBe(120050);
    expect(parsePriceToCents("50")).toBe(5000);
    expect(parsePriceToCents("")).toBeNull();
  });
});

describe("4. Generic type persistence", () => {
  test("stores generic_type and keeps princeps flag aligned", () => {
    const db = new ReferenceDatabase(":memory:");
    const product: Product = {
      cis: CisIdSchema.parse("90000001"),
      label: "TEST",
      is_princeps: false,
      generic_type: GenericType.UNKNOWN,
      group_id: null,
      form: "Forme",
      routes: "orale",
      type_procedure: "Procédure nationale",
      surveillance_renforcee: false,
      manufacturer_id: 1,
      marketing_status: "Actif",
      date_amm: "2020-01-01",
      regulatory_info: "{}",
      composition: "[]",
      composition_codes: "[]",
      composition_display: "",
      drawer_label: ""
    };

    db.insertManufacturers([{ id: 1, label: "LAB" }]);
    db.insertProducts([product]);
    db.insertClusters([
      { id: "CLS_X", label: "Test Cluster", princeps_label: "Test Cluster", substance_code: "test" }
    ]);
    db.insertGroups([{ id: "GRP_X", cluster_id: "CLS_X", label: "Group X" }]);
    db.updateProductGrouping([
      {
        cis: product.cis,
        group_id: "GRP_X",
        is_princeps: false,
        generic_type: GenericType.SUBSTITUTABLE
      }
    ]);

    const row = db
      .rawQuery<{ generic_type: number; is_princeps: number; group_id: string }>(
        "SELECT generic_type, is_princeps, group_id FROM products WHERE cis='90000001'"
      )[0];

    expect(row.generic_type).toBe(GenericType.SUBSTITUTABLE);
    expect(row.is_princeps).toBe(0);
    expect(row.group_id).toBe("GRP_X");

    db.updateProductGrouping([
      {
        cis: product.cis,
        group_id: "GRP_X",
        is_princeps: true,
        generic_type: GenericType.PRINCEPS
      }
    ]);

    const princepsRow = db
      .rawQuery<{ generic_type: number; is_princeps: number }>(
        "SELECT generic_type, is_princeps FROM products WHERE cis='90000001'"
      )[0];
    expect(princepsRow.generic_type).toBe(GenericType.PRINCEPS);
    expect(princepsRow.is_princeps).toBe(1);
  });
});

describe("5. Regulatory fields persistence", () => {
  test("persists surveillance flag as integer and handles complementary generics", () => {
    const db = new ReferenceDatabase(":memory:");
    const product: Product = {
      cis: CisIdSchema.parse("91000001"),
      label: "TEST SURV",
      is_princeps: false,
      generic_type: GenericType.UNKNOWN,
      group_id: null,
      form: "Forme",
      routes: "orale",
      type_procedure: "Procédure centrale",
      surveillance_renforcee: true,
      manufacturer_id: 1,
      marketing_status: "Actif",
      date_amm: "2020-01-01",
      regulatory_info: "{}",
      composition: "[]",
      composition_codes: "[]",
      composition_display: "",
      drawer_label: ""
    };

    db.insertManufacturers([{ id: 1, label: "LAB" }]);
    db.insertProducts([product]);
    db.insertClusters([
      {
        id: "CLS_SURV",
        label: "Cluster Surv",
        princeps_label: "Cluster Surv",
        substance_code: "surv"
      }
    ]);
    db.insertGroups([{ id: "GRP_SURV", cluster_id: "CLS_SURV", label: "Group Surv" }]);
    db.updateProductGrouping([
      {
        cis: product.cis,
        group_id: "GRP_SURV",
        is_princeps: false,
        generic_type: GenericType.COMPLEMENTARY
      }
    ]);

    const row = db.rawQuery<{
      surveillance_renforcee: number;
      generic_type: number;
      type_procedure: string;
    }>("SELECT surveillance_renforcee, generic_type, type_procedure FROM products WHERE cis='91000001'")[0];

    expect(row.surveillance_renforcee).toBe(1);
    expect(row.generic_type).toBe(GenericType.COMPLEMENTARY);
    expect(row.type_procedure).toBe("Procédure centrale");
  });
});

describe("6. Date parsing", () => {
  test("parses BDPM date to ISO", () => {
    expect(parseDateToIso("15/01/2023")).toBe("2023-01-15");
    expect(parseDateToIso("")).toBeNull();
  });
});

describe("7. Manufacturer normalization and commercialization date persistence", () => {
  test("reuses manufacturer ids and stores commercialization date", () => {
    const db = new ReferenceDatabase(":memory:");
    db.insertManufacturers([{ id: 1, label: "SANOFI" }]);

    const baseProduct = {
      label: "TEST",
      generic_type: GenericType.UNKNOWN,
      group_id: null,
      form: "Forme",
      routes: "orale",
      type_procedure: "Procédure nationale",
      marketing_status: "Actif",
      date_amm: "2020-01-01",
      regulatory_info: "{}",
      composition: "[]",
      composition_codes: "[]",
      composition_display: "",
      drawer_label: ""
    };

    const productA: Product = {
      ...baseProduct,
      cis: CisIdSchema.parse("92000001"),
      is_princeps: false,
      surveillance_renforcee: false,
      manufacturer_id: 1
    };

    const productB: Product = {
      ...baseProduct,
      cis: CisIdSchema.parse("92000002"),
      is_princeps: false,
      surveillance_renforcee: true,
      manufacturer_id: 1
    };

    db.insertProducts([productA, productB]);
    db.insertPresentations([
      {
        cis: productA.cis,
        cip13: "1234567890123",
        price_cents: null,
        reimbursement_rate: null,
        availability_status: null,
        ansm_link: null,
        date_commercialisation: "2023-01-15"
      }
    ]);

    const manufacturerRows = db.rawQuery<{ cnt: number }>(
      "SELECT COUNT(*) as cnt FROM manufacturers WHERE label='SANOFI'"
    );
    expect(manufacturerRows[0]?.cnt).toBe(1);

    const manufacturerIds = db.rawQuery<{ manufacturer_id: number }>(
      "SELECT manufacturer_id FROM products"
    );
    expect(new Set(manufacturerIds.map((row) => row.manufacturer_id)).size).toBe(1);

    const presentationRows = db.rawQuery<{ date_commercialisation: string | null }>(
      "SELECT date_commercialisation FROM presentations WHERE cip13='1234567890123'"
    );
    expect(presentationRows[0]?.date_commercialisation).toBe("2023-01-15");
  });
});

describe("9. Composition resolution (join-first)", () => {
  const cis = CisIdSchema.parse("60004932");

  test("prefers FT over SA using link id", () => {
    const compoMap = new Map([[cis, ftSaSample(cis, "comprimé", "1")]]);
    const result = resolveComposition(cis, "METFORMINE 1000 mg", compoMap);
    expect(result.display.toUpperCase()).toContain("METFORMINE 780 MG");
    expect(result.display).not.toContain("CHLORHYDRATE");
    expect(result.structured[0]?.substances[0]?.name).toBe("METFORMINE");
  });

  test("groups by element label for multi-forme products", () => {
    const cisMulti = CisIdSchema.parse("60028495");
    const compoMap = new Map([[cisMulti, jourNuitSample()]]);
    const result = resolveComposition(cisMulti, "HUMEX RHUME", compoMap);
    expect(result.display).toContain("comprimé jour");
    expect(result.display).toContain("comprimé nuit");
    expect(result.display.toUpperCase()).toContain("PARACÉTAMOL 500 MG");
    expect(result.structured.length).toBe(2);
    expect(result.structured[0]?.substances.length).toBeGreaterThan(0);
  });
});

function ftSaSample(cis: ReturnType<typeof CisIdSchema.parse>, element: string, linkId: string): RefComposition[] {
  return [
    {
      cis,
      elementLabel: element,
      codeSubstance: "123",
      substanceName: "CHLORHYDRATE DE METFORMINE",
      dosage: "1000 mg",
      reference: "un comprimé",
      nature: "SA",
      linkId
    },
    {
      cis: cis,
      elementLabel: element,
      codeSubstance: "123",
      substanceName: "METFORMINE",
      dosage: "780 mg",
      reference: "un comprimé",
      nature: "FT",
      linkId
    }
  ];
}

function jourNuitSample(): RefComposition[] {
  return [
    {
      cis: CisIdSchema.parse("60028495"),
      elementLabel: "comprimé jour",
      codeSubstance: "111",
      substanceName: "PARACÉTAMOL",
      dosage: "500 mg",
      reference: "un comprimé",
      nature: "SA",
      linkId: "1"
    },
    {
      cis: CisIdSchema.parse("60028495"),
      elementLabel: "comprimé jour",
      codeSubstance: "112",
      substanceName: "PSEUDOÉPHÉDRINE",
      dosage: "30 mg",
      reference: "un comprimé",
      nature: "SA",
      linkId: "2"
    },
    {
      cis: CisIdSchema.parse("60028495"),
      elementLabel: "comprimé nuit",
      codeSubstance: "111",
      substanceName: "PARACÉTAMOL",
      dosage: "500 mg",
      reference: "un comprimé",
      nature: "SA",
      linkId: "1"
    },
    {
      cis: CisIdSchema.parse("60028495"),
      elementLabel: "comprimé nuit",
      codeSubstance: "113",
      substanceName: "DOXYLAMINE",
      dosage: "7,5 mg",
      reference: "un comprimé",
      nature: "SA",
      linkId: "3"
    }
  ];
}

describe("8. Manufacturer clustering heuristics", () => {
  test("clusters similar manufacturers with normalization and distance", () => {
    const resolver = createManufacturerResolver();
    const samples = [
      "ACCORD HEALTHCARE (ESPAGNE)",
      "ACCORD HEALTHCARE (ROYAUME UNI)",
      "ACCORD HEALTHCARE FRANCE",
      "SANOFI (PAYS-BAS)",
      "SANOFI AVENTIS FRANCE",
      "SANOFI PASTEUR"
    ];

    const ids = samples.map((name) => resolver.resolve(name).id);
    const accordIds = new Set(ids.slice(0, 3));
    const sanofiIds = new Set(ids.slice(3));

    expect(accordIds.size).toBe(1);
    expect(sanofiIds.size).toBe(1);
    expect(accordIds.values().next().value).not.toBe(sanofiIds.values().next().value);

    const normalizedAccord = normalizeManufacturerName("ACCORD HEALTHCARE FRANCE");
    expect(normalizedAccord).toBe("ACCORD");
  });
});
