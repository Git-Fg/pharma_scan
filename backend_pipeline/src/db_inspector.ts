import { Database } from 'bun:sqlite';
import * as path from 'path';

const DB_PATH = './output/reference.db';
const db = new Database(DB_PATH);

const tables = ['specialites', 'medicament_summary', 'generique_groups', 'group_members', 'medicaments'];

console.log('📊 Database Inspection:');
for (const table of tables) {
    try {
        const count = db.query(`SELECT COUNT(*) as count FROM ${table}`).get() as { count: number };
        console.log(`- ${table}: ${count.count} rows`);
    } catch (e) {
        console.log(`- ${table}: ERROR (Table might not exist)`);
    }
}
