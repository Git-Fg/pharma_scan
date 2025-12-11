import { describe, expect, test } from "bun:test";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { mkdtempSync } from "node:fs";
import { runVerification } from "../tool/verify_clusters";
import { TestDbBuilder } from "./fixtures";

describe("Verification tool extensions", () => {
  test("detects route conflicts and safety mismatches", async () => {
    const dir = mkdtempSync(join(tmpdir(), "verify-db-"));
    const dbPath = join(dir, "ref.db");
    const outputDir = join(dir, "out");

    const builder = new TestDbBuilder(dbPath);
    builder
      .addSpecialty("91000001", "PRINCEPS ORAL", true, [], "LAB", { routes: "orale" })
      .addGroup("GROUTE", "MOLECULE - BRAND", "91000001", {
        routes: '["orale","injectable"]'
      });

    // Safety mismatch: products flagged narcotic but group safety_flags empty
    builder
      .addSpecialty(
        "91000002",
        "NARCOTIC PROD",
        true,
        [],
        "LAB",
        { regulatoryInfoJson: '{"narcotic":true,"list1":false,"list2":false,"hospital":false,"dental":false}' }
      )
      .addGroup("GSAFE", "SAFETY MOLECULE", "91000002", {
        safety_flags: "{}",
        routes: '["orale"]'
      });

    builder.finalize();

    const { issues } = await runVerification(dbPath, { outputDir });
    const types = new Set(issues.map(i => i.type));

    expect(types.has("route_conflict")).toBe(true);
    expect(types.has("safety_mismatch")).toBe(true);
  });
});
