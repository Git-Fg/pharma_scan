
import { ReferenceDatabase } from "../src/db";
import { parseGenericsMetadata, parseGeneriques } from "../src/parsing";
import { streamBdpmFile } from "../src/parsing"; // Wait, streamBdpmFile is not exported from parsing.ts? It's likely in utils or internal.
// Checking imports in index.ts:
// import { parse } from "csv-parse";
// import fs from "fs";
// ...
// Actually index.ts has definitions or imports.
// streamBdpmFile is not exported from parsing.ts in current file view.
// It is used in index.ts but likely defined in index.ts or imported. 
// Let's check index.ts imports again.
// Line 1-24 imports.
// streamBdpmFile is likely a helper in index.ts or imported from somewhere. 
// Ah, looking at Step 6 view of index.ts:
// It uses `streamBdpmFile(generPath)`.
// It is NOT in the imports list shown in Step 6 (lines 1-20).
// Wait, Step 6 lines 1-20:
/*
import {
  parseCompositions,
  ...
} from "./parsing";
*/
// It must be defined in `index.ts` itself or I missed it.

// Let's assume I can copy `streamBdpmFile` logic or use fs.
import fs from 'fs';
import path from 'path';
import { parse } from 'csv-parse';
import iconv from 'iconv-lite';

async function streamBdpmFile(filePath: string) {
    const parser = fs
        .createReadStream(filePath)
        .pipe(iconv.decodeStream('win1252')) // BDPM is Windows-1252
        .pipe(
            parse({
                delimiter: '\t',
                relax_quotes: true,
                relax_column_count: true,
                trim: true,
                from_line: 1, // Skip header? No BDPM usually has no header or we handle row 0 logic.
                // Actually BDPM text files often have no header.
            })
        );
    return parser;
}

const DB_PATH = "./data/reference.db";
const GENER_PATH = "./data/CIS_GENER_bdpm.txt";

async function main() {
    console.log("Debugging Doliprane (60234100)...");
    const db = new ReferenceDatabase(DB_PATH);

    // 1. Check DB presence
    const ms = db.runQuery("SELECT cis_code, group_id, nom_canonique FROM medicament_summary WHERE cis_code = '60234100'");
    console.log("DB Medicament Summary:", ms);

    // 2. Check Generics Metadata Parsing
    if (fs.existsSync(GENER_PATH)) {
        const validCisSet = new Set(['60234100']);
        const meta = await parseGenericsMetadata(streamBdpmFile(GENER_PATH), validCisSet);
        console.log("Generics Metadata for 60234100:", meta.get('60234100'));

        // Check raw lines for Doliprane
        const stream = await streamBdpmFile(GENER_PATH);
        for await (const row of stream) {
            if (row[2] === '60234100') {
                console.log("Raw Row for 60234100:", row);
            }
        }
    } else {
        console.log("Generics file not found at", GENER_PATH);
    }
}

main();
