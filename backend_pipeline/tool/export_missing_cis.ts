import fs from "node:fs";
import path from "node:path";
import { Database } from "bun:sqlite";

const DATA_DIR = path.join(process.cwd(), "data");
const SOURCE_FILE = path.join(DATA_DIR, "CIS_InfoImportante.txt");
const OUT_FILE = path.join(DATA_DIR, "missing_cis_examples.json");

function readLines(file: string): string[] {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, "utf8").split(/\r?\n/).filter(Boolean);
}

function extractCisFromLine(line: string): string | null {
  // The source file uses CIS code as the first token on each line
  const m = line.trim().match(/^([^\s\t]+)\s+/);
  return m ? m[1] : null;
}

async function main() {
  console.log("🔎 Scanning source alerts for CIS codes...");

  const lines = readLines(SOURCE_FILE);
  if (lines.length === 0) {
    console.error(`Source file not found or empty: ${SOURCE_FILE}`);
    process.exit(1);
  }

  const fileCisSet = new Set<string>();
  for (const line of lines) {
    const cis = extractCisFromLine(line);
    if (cis) fileCisSet.add(cis);
  }

  console.log(`Found ${fileCisSet.size} unique CIS in source alerts`);

  const dbPath = path.join(process.cwd(), "data", "reference.db");
  if (!fs.existsSync(dbPath)) {
    console.error(`Database not found at: ${dbPath}`);
    process.exit(1);
  }

  const db = new Database(dbPath);
  const rows = db.query<{ cis_code: string }, []>("SELECT cis_code FROM specialites").all();
  const knownCis = new Set(rows.map(r => r.cis_code));
  console.log(`Database contains ${knownCis.size} specialites`);

  const missing = Array.from(fileCisSet).filter(c => !knownCis.has(c));
  console.log(`Missing CIS count: ${missing.length}`);

  const sample = missing.slice(0, 100);

  const payload = {
    generated_at: new Date().toISOString(),
    total_missing: missing.length,
    sample_count: sample.length,
    sample
  };

  fs.writeFileSync(OUT_FILE, JSON.stringify(payload, null, 2), "utf8");
  console.log(`✅ Wrote ${OUT_FILE} with ${sample.length} examples`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
