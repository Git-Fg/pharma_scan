import { describe, expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadDependencies } from "../src/index";

const writeTsv = async (path: string, rows: string[][]) => {
  const content = rows.map((r) => r.join("\t")).join("\n");
  await Bun.write(path, content);
};

describe("Dependency pre-materialization", () => {
  test("loads satellite files into maps and merges duplicates", async () => {
    const dir = mkdtempSync(join(tmpdir(), "bdpm-maps-"));
    const conditionsPath = join(dir, "conditions.tsv");
    const compositionsPath = join(dir, "compositions.tsv");
    const presentationsPath = join(dir, "presentations.tsv");
    const genericsPath = join(dir, "generics.tsv");
    const availabilityPath = join(dir, "availability.tsv");
    const mitmPath = join(dir, "mitm.tsv");

    await writeTsv(conditionsPath, [
      ["00000001", "LISTE I"],
      ["00000001", "STUPEFIANT"],
      ["00000002", "USAGE HOSPITALIER"]
    ]);

    await writeTsv(compositionsPath, [
      ["00000001", "PARACETAMOL", "1234", "PARACETAMOL", "500 mg", "REF", "SA", "1"],
      ["00000001", "EXCIPIENT", "", "EXCIPIENT", "", "REF", "FT", "2"]
    ]);

    await writeTsv(presentationsPath, [
      [
        "00000001",
        "CIP7",
        "Paracetamol 500",
        "Admin",
        "Market",
        "01/01/2024",
        "1234567890123",
        "Agreement",
        "65%",
        "1,20"
      ]
    ]);

    await writeTsv(genericsPath, [["GRP1", "GEN PARACETAMOL", "00000001", "0"]]);

    await writeTsv(availabilityPath, [
      ["", "1234567890123", "CODE", "Disponible", "", "", "https://ansm.fr/notice"],
      ["00000099", "", "CODE", "Rupture", "", "", ""]
    ]);

    await writeTsv(mitmPath, [["00000001", "J01AA02", "DOXYCYCLINE", "https://example.com"]]);

    const { dependencyMaps, shortageMap, groupsData } = await loadDependencies({
      conditionsPath,
      compositionsPath,
      presentationsPath,
      genericsPath,
      availabilityPath,
      mitmPath
    });

    expect(dependencyMaps.conditions.get("00000001")).toEqual(["LISTE I", "STUPEFIANT"]);
    expect(dependencyMaps.conditions.get("00000002")).toEqual(["USAGE HOSPITALIER"]);

    expect(dependencyMaps.compositions.get("00000001")?.length).toBe(2);
    expect(dependencyMaps.presentations.get("00000001")?.[0]?.[6]).toBe("1234567890123");

    expect(dependencyMaps.generics.get("00000001")).toEqual({
      groupId: "GRP1",
      label: "GEN PARACETAMOL",
      type: "0"
    });

    expect(dependencyMaps.atc.get("00000001")?.[0]?.[1]).toBe("J01AA02");

    expect(groupsData.length).toBe(1);

    expect(shortageMap.get("1234567890123")?.status).toBe("Disponible");
    expect(shortageMap.get("00000099")?.status).toBe("Rupture");
  });
});
