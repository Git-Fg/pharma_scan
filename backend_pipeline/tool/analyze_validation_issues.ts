#!/usr/bin/env bun
import { ReferenceDatabase, DEFAULT_DB_PATH } from "../src/db";
import { createReadStream } from "node:fs";
import { parse } from "csv-parse";
import iconv from "iconv-lite";
import {
  RawCompositionSchema,
  RawGroupSchema,
  type DependencyMaps
} from "../src/types";
import { normalizeString } from "../src/logic";

const DATA_DIR = "data";

async function loadDependencyMaps(): Promise<DependencyMaps> {
  const dependencyMaps: DependencyMaps = {
    conditions: new Map(),
    compositions: new Map(),
    presentations: new Map(),
    generics: new Map(),
    atc: new Map()
  };

  // Load compositions
  const compoPath = `${DATA_DIR}/CIS_COMPO_bdpm.txt`;
  const compoStream = createReadStream(compoPath)
    .pipe(iconv.decodeStream("win1252"))
    .pipe(parse({ delimiter: "\t", relax_quotes: true, from_line: 1, skip_empty_lines: true }));

  for await (const record of compoStream) {
    const result = RawCompositionSchema.safeParse(record);
    if (result.success) {
      const row = result.data;
      const cis = row[0];
      if (!dependencyMaps.compositions.has(cis)) {
        dependencyMaps.compositions.set(cis, []);
      }
      dependencyMaps.compositions.get(cis)!.push(row);
    }
  }

  // Load generics
  const genericsPath = `${DATA_DIR}/CIS_GENER_bdpm.txt`;
  const genericsStream = createReadStream(genericsPath)
    .pipe(iconv.decodeStream("win1252"))
    .pipe(parse({ delimiter: "\t", relax_quotes: true, from_line: 1, skip_empty_lines: true }));

  for await (const record of genericsStream) {
    const result = RawGroupSchema.safeParse(record);
    if (result.success) {
      const row = result.data;
      const cis = row[2];
      dependencyMaps.generics.set(cis, {
        groupId: row[0],
        label: row[1],
        type: row[3]
      });
    }
  }

  return dependencyMaps;
}

async function main() {
  const dbPath = DEFAULT_DB_PATH;
  const db = new ReferenceDatabase(dbPath);

  console.log("📊 Loading dependency maps...");
  const dependencyMaps = await loadDependencyMaps();

  // Build groupCompositionCanonical
  const groupCompositionCanonical = new Map<
    string,
    { tokens: string[]; substances: Array<{ name: string; dosage: string; nature: "FT" | "SA" | null }> }
  >();

  const builder = new Map<
    string,
    {
      tokens: Set<string>;
      substances: Map<string, { name: string; dosage: string; nature: "FT" | "SA" | null }>;
    }
  >();

  for (const [cis, rows] of dependencyMaps.compositions) {
    const genericInfo = dependencyMaps.generics.get(cis);
    if (!genericInfo) continue;
    const groupId = genericInfo.groupId;
    if (!builder.has(groupId)) {
      builder.set(groupId, { tokens: new Set(), substances: new Map() });
    }
    const current = builder.get(groupId)!;

    for (const row of rows) {
      if (row.nature !== "FT" && row.nature !== "SA") continue;
      const code = row.codeSubstance.trim();
      const normalizedName = normalizeString(row.substanceName);
      const key = code && code !== "0" ? `C:${code}` : normalizedName ? `N:${normalizedName}` : null;
      if (!key) continue;

      current.tokens.add(key);
      const dosage = row.dosage?.trim() ?? "";
      const existing = current.substances.get(key);
      const shouldReplace =
        !existing ||
        (existing.nature === "SA" && row.nature === "FT") ||
        (!existing.dosage && !!dosage);
      if (shouldReplace) {
        current.substances.set(key, {
          name: row.substanceName.trim() || existing?.name || "",
          dosage,
          nature: row.nature
        });
      }
    }
  }

  for (const [groupId, { tokens, substances }] of builder) {
    groupCompositionCanonical.set(groupId, {
      tokens: Array.from(tokens).sort((a, b) => a.localeCompare(b)),
      substances: Array.from(substances.values())
    });
  }

  // Get clustering result from database
  const groups = db.rawQuery<{ id: string; cluster_id: string }>("SELECT id, cluster_id FROM groups");
  const groupClusterMap = new Map<string, string>();
  groups.forEach(g => {
    groupClusterMap.set(g.id, g.cluster_id);
  });

  // Analyze GROUP_SPLIT issues
  const sortedGroups = Array.from(groupCompositionCanonical.entries()).sort(
    ([a], [b]) => Number.parseInt(a, 10) - Number.parseInt(b, 10)
  );

  const groupSplits: Array<{ groupId: string; nextId: string; signature: string }> = [];
  for (let i = 0; i < sortedGroups.length - 1; i++) {
    const [groupId, signature] = sortedGroups[i];
    const [nextId, nextSignature] = sortedGroups[i + 1];
    const currentNum = Number.parseInt(groupId, 10);
    const nextNum = Number.parseInt(nextId, 10);
    if (!Number.isFinite(currentNum) || !Number.isFinite(nextNum)) continue;
    if (Math.abs(currentNum - nextNum) > 1) continue;
    if (
      signature.tokens.length > 0 &&
      nextSignature.tokens.length > 0 &&
      signature.tokens.join("|") === nextSignature.tokens.join("|")
    ) {
      const clusterA = groupClusterMap.get(groupId);
      const clusterB = groupClusterMap.get(nextId);
      if (clusterA && clusterB && clusterA !== clusterB) {
        groupSplits.push({
          groupId,
          nextId,
          signature: signature.tokens.join("|")
        });
      }
    }
  }

  console.log(`\n📊 Validation Issues Analysis:`);
  console.log(`   GROUP_SPLIT issues: ${groupSplits.length}`);
  
  if (groupSplits.length > 0) {
    console.log(`\n   First 5 GROUP_SPLIT examples:`);
    groupSplits.slice(0, 5).forEach(issue => {
      const group1 = db.rawQuery<{ label: string; cluster_id: string }>(
        `SELECT label, cluster_id FROM groups WHERE id = ?`,
        [issue.groupId]
      );
      const group2 = db.rawQuery<{ label: string; cluster_id: string }>(
        `SELECT label, cluster_id FROM groups WHERE id = ?`,
        [issue.nextId]
      );
      console.log(`     Groups ${issue.groupId}/${issue.nextId}:`);
      console.log(`       Signature: ${issue.signature.substring(0, 60)}...`);
      console.log(`       Cluster1: ${group1[0]?.cluster_id} - ${group1[0]?.label.substring(0, 50)}...`);
      console.log(`       Cluster2: ${group2[0]?.cluster_id} - ${group2[0]?.label.substring(0, 50)}...`);
    });
  } else {
    console.log(`   ✅ No GROUP_SPLIT issues detected - clustering by composition is working correctly!`);
  }

  db.close();
}

main().catch(console.error);
