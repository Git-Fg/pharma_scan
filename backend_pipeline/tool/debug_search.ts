import { Database } from 'bun:sqlite';
const db = new Database('./data/reference.db', { readonly: true });
console.log('total search rows:', db.query('SELECT COUNT(*) as c FROM search_index').get());
console.log('search_index schema:', db.query("SELECT name, type, sql FROM sqlite_master WHERE name='search_index'").get());
console.log('match DOLIPRANE count (MATCH):', db.query("SELECT COUNT(*) as c FROM search_index WHERE search_index MATCH 'DOLIPRANE'").get());
console.log('search_vector LIKE DOLIPRANE:', db.query("SELECT COUNT(*) as c FROM search_index WHERE search_vector LIKE '%DOLIPRANE%'").get());
console.log('search_vector LIKE doliprane:', db.query("SELECT COUNT(*) as c FROM search_index WHERE search_vector LIKE '%doliprane%'").get());
