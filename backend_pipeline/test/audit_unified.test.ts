import { describe, expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { runAudit } from "../tool/audit_unified";
import { ReferenceDatabase } from "../src/db";
import { normalizeString } from "../src/logic";
import { CisIdSchema, GenericType, GroupIdSchema } from "../src/types";

const tmpPath = () => mkdtempSync(join(tmpdir(), "audit-unified-"));

describe("Unified audit (structure + fuzzy)", () => {
  test("filters noise/valid splits and flags real issues", () => {
    const dir = tmpPath();
    const dbPath = join(dir, "db.sqlite");
    const reportPath = join(dir, "report.json");
    const db = new ReferenceDatabase(dbPath);
    const grp1 = GroupIdSchema.parse("GRP1");
    const grp2 = GroupIdSchema.parse("GRP2");
    const cis1 = CisIdSchema.parse("90000001");
    const cis2 = CisIdSchema.parse("90000002");
    const cis3 = CisIdSchema.parse("90000003");
    const cis4 = CisIdSchema.parse("90000004");

    db.insertClusters([
      { id: "CLS_SPLIT_A", label: "AMOX ADULTES", princeps_label: "AMOXICILLINE", substance_code: "amoxicilline adultes" },
      { id: "CLS_SPLIT_B", label: "AMOX ADULTE", princeps_label: "AMOXICILLINE", substance_code: "amoxicilline adulte" },
      { id: "CLS_NOISE_A", label: "AMOX ADULTE PAR", princeps_label: "AMOX PAR", substance_code: "amoxicilline adulte par" },
      { id: "CLS_NOISE_B", label: "AMOX ADULTE", princeps_label: "AMOX BASE", substance_code: "amoxicilline adulte" },
      { id: "CLS_WARN_A", label: "VALSARTAN 80", princeps_label: "VALSARTAN", substance_code: "valsartan 80mg" },
      { id: "CLS_WARN_B", label: "VALSARTANE 80", princeps_label: "TELMISARTAN", substance_code: "valsartane 80mg" },
      { id: "CLS_PERM_A", label: "CODEINE PARACETAMOL", princeps_label: "CODEINE PARACETAMOL", substance_code: "codeine paracetamol" },
      { id: "CLS_PERM_B", label: "PARACETAMOL CODEINE", princeps_label: "PARACETAMOL CODEINE", substance_code: "paracetamol codeine" },
      { id: "CLS_MERGE", label: "MERGED CLUSTER", princeps_label: "MERGED", substance_code: "merge base" }
    ]);

    db.insertGroups([
      { id: grp1, cluster_id: "CLS_MERGE", label: "G1" },
      { id: grp2, cluster_id: "CLS_MERGE", label: "G2" }
    ]);

    db.insertManufacturers([
      { id: 1, label: "LAB A" },
      { id: 2, label: "LAB B" },
      { id: 3, label: "LAB C" },
      { id: 4, label: "LAB D" }
    ]);

    db.insertProducts([
      {
        cis: cis1,
        label: "Brand One",
        is_princeps: true,
        generic_type: GenericType.PRINCEPS,
        group_id: grp1,
        form: "Forme",
        routes: "orale",
        type_procedure: "Procédure nationale",
        surveillance_renforcee: false,
        manufacturer_id: 1,
        marketing_status: "Actif",
        date_amm: "2020-01-01",
        regulatory_info: "{}",
        composition: JSON.stringify([
          { element: "comprimé", substances: [{ name: "BRAND ONE", dosage: "" }] }
        ]),
        composition_codes: "[]",
        composition_display: "Brand One",
        drawer_label: normalizeString("Brand One")
      },
      {
        cis: cis2,
        label: "Brand Two",
        is_princeps: true,
        generic_type: GenericType.PRINCEPS,
        group_id: grp2,
        form: "Forme",
        routes: "orale",
        type_procedure: "Procédure nationale",
        surveillance_renforcee: false,
        manufacturer_id: 2,
        marketing_status: "Actif",
        date_amm: "2020-01-02",
        regulatory_info: "{}",
        composition: JSON.stringify([
          { element: "comprimé", substances: [{ name: "BRAND TWO", dosage: "" }] }
        ]),
        composition_codes: "[]",
        composition_display: "Brand Two",
        drawer_label: normalizeString("Brand Two")
      },
      {
        cis: cis3,
        label: "KIVEXA",
        is_princeps: true,
        generic_type: GenericType.PRINCEPS,
        group_id: null,
        form: "Forme",
        routes: "orale",
        type_procedure: "Procédure nationale",
        surveillance_renforcee: false,
        manufacturer_id: 3,
        marketing_status: "Actif",
        date_amm: "2020-01-03",
        regulatory_info: "{}",
        composition: JSON.stringify([
          {
            element: "comprimé",
            substances: [
              { name: "ABACAVIR", dosage: "" },
              { name: "ABACAVIR BASE", dosage: "" }
            ]
          }
        ]),
        composition_codes: "[]",
        composition_display: "ABACAVIR + ABACAVIR BASE",
        drawer_label: normalizeString("KIVEXA")
      },
      {
        cis: cis4,
        label: "AMOX",
        is_princeps: true,
        generic_type: GenericType.PRINCEPS,
        group_id: null,
        form: "Forme",
        routes: "orale",
        type_procedure: "Procédure nationale",
        surveillance_renforcee: false,
        manufacturer_id: 4,
        marketing_status: "Actif",
        date_amm: "2020-01-04",
        regulatory_info: "{}",
        composition: JSON.stringify([
          {
            element: "comprimé",
            substances: [
              { name: "AMOXICILLINE", dosage: "" },
              { name: "AMOXICILLINE TRIHYDRATE", dosage: "" }
            ]
          }
        ]),
        composition_codes: "[]",
        composition_display: "AMOXICILLINE + AMOXICILLINE TRIHYDRATE",
        drawer_label: normalizeString("AMOX")
      }
    ]);

    const report = runAudit(dbPath, reportPath);

    expect(report.critical_errors.split_brands.find((s) => s.princeps_label === "AMOXICILLINE")?.clusters.length).toBe(2);
    expect(report.critical_errors.permutations.find((p) => p.sorted_tokens === "codeine paracetamol")).toBeTruthy();

    const warningIds = report.warnings.fuzzy_duplicates.map((w) => [w.cluster_a.id, w.cluster_b.id].sort().join("::"));
    expect(warningIds).toContain(["CLS_WARN_A", "CLS_WARN_B"].sort().join("::"));

    expect(warningIds).not.toContain(["CLS_NOISE_A", "CLS_NOISE_B"].sort().join("::"));
    expect(warningIds).not.toContain(["CLS_SPLIT_A", "CLS_SPLIT_B"].sort().join("::"));

    const redundancyProblems = report.composition_redundancies.map((r) => r.problem);
    expect(redundancyProblems).toContain("ABACAVIR <-> ABACAVIR BASE");
    expect(redundancyProblems).toContain("AMOXICILLINE <-> AMOXICILLINE TRIHYDRATE");
    expect(redundancyProblems.find((p) => p.includes("Paracetamol"))).toBeUndefined();
  });
});
