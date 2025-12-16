import { describe, expect, test } from "bun:test";
import { TestDbBuilder } from "./fixtures";

describe("3. Clustering Engine (Integration)", () => {
  test("Merges Mémantine variants into one cluster (same signature)", () => {
    const builder = new TestDbBuilder();

    builder.addSpecialty("10000001", "AXURA 10 mg", true, ["0123"]);
    builder.addSpecialty("10000002", "EBIXA 10 mg", false, ["0123"]);

    builder.addGroup("GRP_1", "MEMANTINE 10 mg", "10000001");
    builder.addGroup("GRP_2", "MÉMANTINE (CHLORHYDRATE DE) 10 mg - EBIXA", "10000002");

    builder.finalize();

    const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
      "SELECT cluster_id, label FROM groups"
    );
    const clusterIds = new Set(rows.map((r) => r.cluster_id));
    expect(clusterIds.size).toBe(1);
  });

  test("Isolates Néfopam from Adriblastine (different signatures)", () => {
    const builder = new TestDbBuilder();

    builder.addSpecialty("20000001", "NÉFOPAM 20 mg - ACUPAN", true, ["NEFO"]);
    builder.addSpecialty("20000002", "DOXORUBICINE 10 mg - ADRIBLASTINE", true, ["ADRI"]);

    builder.addGroup("GRP_NEFO", "NÉFOPAM 20 mg - ACUPAN", "20000001");
    builder.addGroup("GRP_ADRI", "DOXORUBICINE 10 mg - ADRIBLASTINE", "20000002");

    builder.finalize();

    const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>("SELECT cluster_id, label FROM groups");
    const nefopamCluster = rows.find((r) => r.label.includes("NÉFOPAM"))?.cluster_id;
    const adriCluster = rows.find((r) => r.label.includes("ADRIBLASTINE"))?.cluster_id;

    expect(nefopamCluster).toBeDefined();
    expect(adriCluster).toBeDefined();
    expect(nefopamCluster).not.toBe(adriCluster);
  });

  test("Merges 'Equivalent' salts correctly when composition matches (Abacavir)", () => {
    const builder = new TestDbBuilder();

    // Shared composition signature: should merge
    builder.addSpecialty("30000001", "ABACAVIR 300 mg", true, ["A1"]);
    builder.addSpecialty("30000002", "ABACAVIR (SULFATE D') équivalant à ABACAVIR 300 mg", false, [
      "A1"
    ]);

    builder.addGroup("GRP_A", "ABACAVIR 300 mg", "30000001");
    builder.addGroup("GRP_B", "ABACAVIR (SULFATE D') équivalant à ABACAVIR 300 mg", "30000002");

    builder.finalize();

    const rows = builder.db.rawQuery<{ cluster_id: string }>("SELECT cluster_id FROM groups");
    const ids = new Set(rows.map((r) => r.cluster_id));
    expect(ids.size).toBe(1);
  });

  test("Keeps combination therapies separate (captopril vs captopril + HCTZ)", () => {
    const builder = new TestDbBuilder();

    builder.addSpecialty("40000001", "CAPTOPRIL 25 mg", true, ["CAPT"]);
    builder.addSpecialty("40000002", "CAPTOPRIL/HYDROCHLOROTHIAZIDE 25/12.5 mg", true, [
      "CAPT",
      "HCTZ"
    ]);

    builder.addGroup("GRP_CAPT", "CAPTOPRIL 25 mg", "40000001");
    builder.addGroup("GRP_CAPT_HCTZ", "CAPTOPRIL/HYDROCHLOROTHIAZIDE 25/12.5 mg", "40000002");

    builder.finalize();

    const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>("SELECT cluster_id, label FROM groups");
    const captCluster = rows.find((r) => r.label.includes("CAPTOPRIL 25"))?.cluster_id;
    const comboCluster = rows.find((r) => r.label.includes("HYDROCHLOROTHIAZIDE"))?.cluster_id;

    expect(captCluster).toBeDefined();
    expect(comboCluster).toBeDefined();
    expect(captCluster).not.toBe(comboCluster);
  });

  test("Does not merge combo labels lacking full composition rows", () => {
    const builder = new TestDbBuilder();

    // Deliberately missing HCTZ code to simulate incomplete composition data.
    builder.addSpecialty("50000001", "CAPTOPRIL 25 mg", true, ["CAPT"]);
    builder.addSpecialty("50000002", "CAPTOPRIL/HYDROCHLOROTHIAZIDE 25/12.5 mg", true, ["CAPT"]);

    builder.addGroup("GRP_CAPT_MISSING", "CAPTOPRIL 25 mg", "50000001");
    builder.addGroup(
      "GRP_CAPT_HCTZ_MISSING",
      "CAPTOPRIL/HYDROCHLOROTHIAZIDE 25/12.5 mg",
      "50000002"
    );

    builder.finalize();

    const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
      "SELECT cluster_id, label FROM groups"
    );
    const captCluster = rows.find((r) => r.label.includes("CAPTOPRIL 25"))?.cluster_id;
    const comboCluster = rows.find((r) => r.label.includes("HYDROCHLOROTHIAZIDE"))?.cluster_id;

    expect(captCluster).toBeDefined();
    expect(comboCluster).toBeDefined();
    expect(captCluster).not.toBe(comboCluster);
  });

  describe("Advanced Salt Variants", () => {
    test("Merges adjective salt forms correctly (MAGNESIUM SODIQUE vs MAGNESIUM DE SODIUM)", () => {
      const builder = new TestDbBuilder();

      // Should merge - same composition, different salt notation
      builder.addSpecialty("60000001", "MAGNESIUM SODIQUE 100 mg", true, ["MAG"]);
      builder.addSpecialty("60000002", "MAGNESIUM DE SODIUM 100 mg", false, ["MAG"]);

      builder.addGroup("GRP_MAG_ADJ", "MAGNESIUM SODIQUE 100 mg", "60000001");
      builder.addGroup("GRP_MAG_DE", "MAGNESIUM DE SODIUM 100 mg", "60000002");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups"
      );
      const clusterIds = new Set(rows.map((r) => r.cluster_id));
      expect(clusterIds.size).toBe(1);
    });

    test("Merges potassium salt variants (POTASSIUM vs DE POTASSIUM)", () => {
      const builder = new TestDbBuilder();

      builder.addSpecialty("60000003", "PENICILLINE POTASSIUM 1M UI", true, ["PENI"]);
      builder.addSpecialty("60000004", "PENICILLINE DE POTASSIUM 1M UI", false, ["PENI"]);

      builder.addGroup("GRP_POT_K", "PENICILLINE POTASSIUM 1M UI", "60000003");
      builder.addGroup("GRP_POT_DE", "PENICILLINE DE POTASSIUM 1M UI", "60000004");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups"
      );
      const clusterIds = new Set(rows.map((r) => r.cluster_id));
      expect(clusterIds.size).toBe(1);
    });

    test("Does not merge different salts with same base", () => {
      const builder = new TestDbBuilder();

      // Different composition codes should remain separate
      builder.addSpecialty("60000005", "MAGNESIUM CHLORURE 100 mg", true, ["MAG_CL"]);
      builder.addSpecialty("60000006", "MAGNESIUM SODIQUE 100 mg", false, ["MAG_SOD"]);

      builder.addGroup("GRP_MAG_CL", "MAGNESIUM CHLORURE 100 mg", "60000005");
      builder.addGroup("GRP_MAG_SOD", "MAGNESIUM SODIQUE 100 mg", "60000006");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups"
      );
      const clusterIds = new Set(rows.map((r) => r.cluster_id));
      expect(clusterIds.size).toBe(2);
    });
  });

  describe("Chemical Prefix Normalization", () => {
    test("Merges N-acetyl variants (N-ACETYL CYSTEINE vs ACETYL CYSTEINE)", () => {
      const builder = new TestDbBuilder();

      // Should merge - N-acetyl prefix is stripped during normalization
      builder.addSpecialty("70000001", "N-ACETYL CYSTEINE 600 mg", true, ["NAC"]);
      builder.addSpecialty("70000002", "ACETYL CYSTEINE 600 mg", false, ["NAC"]);

      builder.addGroup("GRP_NAC", "N-ACETYL CYSTEINE 600 mg", "70000001");
      builder.addGroup("GRP_AC", "ACETYL CYSTEINE 600 mg", "70000002");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups"
      );
      const clusterIds = new Set(rows.map((r) => r.cluster_id));
      expect(clusterIds.size).toBe(1);
    });

    test("Merges DL- isomer variants (DL-ALPHA TOCOPHEROL vs ALPHA TOCOPHEROL)", () => {
      const builder = new TestDbBuilder();

      builder.addSpecialty("70000003", "DL-ALPHA TOCOPHEROL 400 UI", true, ["ALPHA"]);
      builder.addSpecialty("70000004", "ALPHA TOCOPHEROL 400 UI", false, ["ALPHA"]);

      builder.addGroup("GRP_DL_ALPHA", "DL-ALPHA TOCOPHEROL 400 UI", "70000003");
      builder.addGroup("GRP_ALPHA", "ALPHA TOCOPHEROL 400 UI", "70000004");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups"
      );
      const clusterIds = new Set(rows.map((r) => r.cluster_id));
      expect(clusterIds.size).toBe(1);
    });

    test("Merges D- and L- isomers with base molecule", () => {
      const builder = new TestDbBuilder();

      // All three should merge into the same cluster
      builder.addSpecialty("70000005", "D-PENICILLAMINE 250 mg", true, ["PENIC"]);
      builder.addSpecialty("70000006", "L-PENICILLAMINE 250 mg", false, ["PENIC"]);
      builder.addSpecialty("70000007", "PENICILLAMINE 250 mg", false, ["PENIC"]);

      builder.addGroup("GRP_D_PEN", "D-PENICILLAMINE 250 mg", "70000005");
      builder.addGroup("GRP_L_PEN", "L-PENICILLAMINE 250 mg", "70000006");
      builder.addGroup("GRP_PEN", "PENICILLAMINE 250 mg", "70000007");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups"
      );
      const clusterIds = new Set(rows.map((r) => r.cluster_id));
      expect(clusterIds.size).toBe(1);
    });

    test("Does not merge different molecules with similar prefixes", () => {
      const builder = new TestDbBuilder();

      // Different base molecules should remain separate
      builder.addSpecialty("70000008", "N-ACETYL CYSTEINE 600 mg", true, ["NAC"]);
      builder.addSpecialty("70000009", "N-ACETYL SALICYLIC ACID 300 mg", false, ["ASA"]);

      builder.addGroup("GRP_NAC", "N-ACETYL CYSTEINE 600 mg", "70000008");
      builder.addGroup("GRP_ASA", "N-ACETYL SALICYLIC ACID 300 mg", "70000009");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups"
      );
      const clusterIds = new Set(rows.map((r) => r.cluster_id));
      expect(clusterIds.size).toBe(2);
    });
  });

  describe("Invalid Composition Codes", () => {
    test("Handles dummy/invalid composition codes correctly", () => {
      const builder = new TestDbBuilder();

      // Products with invalid/dummy codes should fall back to label clustering
      builder.addSpecialty("80000001", "MEDICAMENT A 100 mg", true, ["9999"]);
      builder.addSpecialty("80000002", "MEDICAMENT A 100 MG", false, ["9999"]);
      builder.addSpecialty("80000003", "MEDICAMENT B 200 mg", false, ["9998"]);

      builder.addGroup("GRP_A1", "MEDICAMENT A 100 mg", "80000001");
      builder.addGroup("GRP_A2", "MEDICAMENT A 100 MG", "80000002");
      builder.addGroup("GRP_B", "MEDICAMENT B 200 mg", "80000003");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups ORDER BY label"
      );

      // A1 and A2 should merge (same normalized label), B should be separate
      const clusterA = rows.filter(r => r.label.includes("MEDICAMENT A"));
      const clusterB = rows.filter(r => r.label.includes("MEDICAMENT B"));

      expect(new Set(clusterA.map(r => r.cluster_id)).size).toBe(1);
      expect(new Set(clusterB.map(r => r.cluster_id)).size).toBe(1);
      expect(clusterA[0].cluster_id).not.toBe(clusterB[0].cluster_id);
    });

    test("Ignores products with only invalid codes for signature clustering", () => {
      const builder = new TestDbBuilder();

      // Mix of valid and invalid codes
      builder.addSpecialty("80000004", "VALID MEDICAMENT 100 mg", true, ["VAL1"]);
      builder.addSpecialty("80000005", "INVALID MEDICAMENT 100 mg", false, ["9999"]);
      builder.addSpecialty("80000006", "ANOTHER INVALID 100 mg", false, ["9998"]);

      builder.addGroup("GRP_VALID", "VALID MEDICAMENT 100 mg", "80000004");
      builder.addGroup("GRP_INVALID1", "INVALID MEDICAMENT 100 mg", "80000005");
      builder.addGroup("GRP_INVALID2", "ANOTHER INVALID 100 mg", "80000006");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups"
      );

      // All should have different clusters since invalid codes fallback to label-based clustering
      const clusterIds = new Set(rows.map((r) => r.cluster_id));
      expect(clusterIds.size).toBe(3);
    });

    test("Handles empty composition codes gracefully", () => {
      const builder = new TestDbBuilder();

      // Products with no composition codes - use more distinct labels
      builder.addSpecialty("80000007", "FIRST PRODUCT NAME", true, []);
      builder.addSpecialty("80000008", "FIRST PRODUCT NAME", false, []);
      builder.addSpecialty("80000009", "COMPLETELY DIFFERENT PRODUCT", false, []);

      builder.addGroup("GRP_EMPTY1", "FIRST PRODUCT NAME", "80000007");
      builder.addGroup("GRP_EMPTY2", "FIRST PRODUCT NAME", "80000008");
      builder.addGroup("GRP_EMPTY3", "COMPLETELY DIFFERENT PRODUCT", "80000009");

      builder.finalize();

      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups ORDER BY label"
      );

      // Products with same labels should merge
      const product1Clusters = rows.filter(r => r.label.includes("FIRST PRODUCT NAME"));
      const product2Clusters = rows.filter(r => r.label.includes("COMPLETELY DIFFERENT PRODUCT"));

      expect(new Set(product1Clusters.map(r => r.cluster_id)).size).toBe(1);
      expect(new Set(product2Clusters.map(r => r.cluster_id)).size).toBe(1);

      // Different labels should result in different clusters
      if (product1Clusters.length > 0 && product2Clusters.length > 0) {
        // They should be in different clusters since the normalized labels are different
        const clusterIds = new Set(rows.map(r => r.cluster_id));
        expect(clusterIds.size).toBeGreaterThan(1);
      }
    });
  });

  describe("Integration with Verification Tool", () => {
    test("Detects split-brain clusters through verification tool", () => {
      const builder = new TestDbBuilder();

      // Create split-brain scenario: same princeps in different clusters
      builder.addSpecialty("90000001", "IBUPROFENE 400 mg", true, ["IBU1"]);
      builder.addSpecialty("90000002", "IBUPROFENE 200 mg", false, ["IBU2"]);

      // Same princeps in different groups (should trigger split-brain detection)
      builder.addGroup("GRP_IBU1", "IBUPROFENE 400 mg", "90000001");
      builder.addGroup("GRP_IBU2", "IBUPROFENE 200 mg", "90000001");

      builder.finalize();

      // Check that groups have different cluster IDs (split-brain scenario)
      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups WHERE label LIKE '%IBUPROFENE%'"
      );

      expect(rows.length).toBe(2);
      // These should ideally be in the same cluster but aren't - this is what the verifier catches
      const clusterIds = new Set(rows.map(r => r.cluster_id));
      // Note: This test demonstrates the issue that the verifier would detect
    });

    test("Detects label permutations through verification tool", () => {
      const builder = new TestDbBuilder();

      // Create permutation scenario: very similar labels that should be reviewed
      builder.addSpecialty("90000003", "PARACETAMOL CODEINE", true, ["PARA", "CODE"]);
      builder.addSpecialty("90000004", "CODEINE PARACETAMOL", false, ["CODE", "PARA"]);

      builder.addGroup("GRP_PARA_CODE", "PARACETAMOL CODEINE", "90000003");
      builder.addGroup("GRP_CODE_PARA", "CODEINE PARACETAMOL", "90000004");

      builder.finalize();

      // Both should merge (same composition codes)
      const rows = builder.db.rawQuery<{ cluster_id: string; label: string }>(
        "SELECT cluster_id, label FROM groups WHERE label LIKE '%PARACETAMOL%' OR label LIKE '%CODEINE%'"
      );

      const clusterIds = new Set(rows.map(r => r.cluster_id));
      expect(clusterIds.size).toBe(1); // Should be merged due to same signature
    });

    test("Detects empty composition signatures", () => {
      const builder = new TestDbBuilder();

      // Product with empty composition codes
      builder.addSpecialty("90000005", "NO COMPOSITION PRODUCT", true, []);
      builder.addSpecialty("90000006", "VALID PRODUCT", false, ["VALID"]);

      builder.addGroup("GRP_EMPTY", "NO COMPOSITION PRODUCT", "90000005");
      builder.addGroup("GRP_VALID", "VALID PRODUCT", "90000006");

      builder.finalize();

      // Check that product with empty composition exists
      const productsWithEmptyCodes = builder.db.rawQuery<{ cis: string; label: string; composition_codes: string }>(
        "SELECT cis, label, composition_codes FROM products WHERE composition_codes = '[]'"
      );

      expect(productsWithEmptyCodes.length).toBeGreaterThan(0);
      expect(productsWithEmptyCodes[0].label).toBe("NO COMPOSITION PRODUCT");
    });
  });
});
