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
});
