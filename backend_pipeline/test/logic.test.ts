import { describe, expect, test } from "bun:test";
import {
  createManufacturerResolver,
  extractBrand,
  isStoppedProduct,
  normalizeString,
  normalizeManufacturerName,
  parseDateToIso,
  parseGroupMetadata,
  parsePriceToCents
} from "../src/logic";
import { CisIdSchema } from "../src/types";

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

describe("5. Princeps brand extraction (abilify drops)", () => {
  test("drops mg/mL parsed to abilify without ml suffix", () => {
    const label = "ABILIFY 1 mg/mL, solution buvable";
    expect(extractBrand(label)).toBe("ABILIFY");
  });
});

describe("6. Date parsing", () => {
  test("parses BDPM date to ISO", () => {
    expect(parseDateToIso("15/01/2023")).toBe("2023-01-15");
    expect(parseDateToIso("")).toBeNull();
  });
});

describe("9. Stopped product detection for export", () => {
  test("flags CIS non commercialisée regardless of presentation counts", () => {
    const stopped = isStoppedProduct({
      cluster_id: "CLS",
      cluster_label: "Label",
      cluster_subtitle: "Subtitle",
      substance_code: "code",
      group_id: "GRP",
      group_label: "Group",
      cis: "10000001",
      product_label: "Prod",
      is_princeps: 0,
      marketing_status: "Non commercialisée",
      stopped_presentations: 0,
      active_presentations: 2
    });

    expect(stopped).toBe(true);
  });

  test("requires all presentations stopped when CIS is active", () => {
    const stopped = isStoppedProduct({
      cluster_id: "CLS",
      cluster_label: "Label",
      cluster_subtitle: "Subtitle",
      substance_code: "code",
      group_id: "GRP",
      group_label: "Group",
      cis: "10000002",
      product_label: "Prod",
      is_princeps: 0,
      marketing_status: "Commercialisée",
      stopped_presentations: 2,
      active_presentations: 0
    });

    expect(stopped).toBe(true);
  });

  test("keeps products with mixed availability as visible", () => {
    const stopped = isStoppedProduct({
      cluster_id: "CLS",
      cluster_label: "Label",
      cluster_subtitle: "Subtitle",
      substance_code: "code",
      group_id: "GRP",
      group_label: "Group",
      cis: "10000003",
      product_label: "Prod",
      is_princeps: 0,
      marketing_status: "Commercialisée",
      stopped_presentations: 1,
      active_presentations: 1
    });

    expect(stopped).toBe(false);
  });
});
