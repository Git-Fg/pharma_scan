
import fs from 'fs';
import { ReferenceDatabase } from "../src/db";
import { parseGenericsMetadata, parseGeneriques } from "../src/parsing";
import { streamBdpmFile } from "../src/utils";

const DB_PATH = "./output/reference.db";
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
