import fs from "fs";
import { parse } from "csv-parse";
import iconv from "iconv-lite";

/**
 * Streams a BDPM file (TSV, Latin1) row by row.
 * Essential for large files (CIS_bdpm.txt) to keep memory usage low.
 */
export async function* streamBdpmFile(filePath: string): AsyncIterable<string[]> {
    const stream = fs.createReadStream(filePath)
        .pipe(iconv.decodeStream("latin1")) // Stream decoding
        .pipe(parse({
            delimiter: "\t",
            relax_quotes: true,
            relax_column_count: true,
            skip_empty_lines: true,
            skip_records_with_error: true,
            quote: null
        }));

    for await (const row of stream) {
        // Basic filter for empty rows
        if (row && row.length > 0 && row.some((cell: string) => cell && cell.trim().length > 0)) {
            yield row;
        }
    }
}

/**
 * Build search vector for FTS5 indexing (trigram tokenizer).
 * Concatenates substance, primary princeps, secondary princeps, active principles,
 * and optionally raw names for better fuzzy matching coverage.
 */
export function buildSearchVector(
    substance: string,
    primaryPrinceps: string,
    secondaryPrincepsList: string[],
    principesActifs?: string,
    rawNames?: string[]
): string {
    const keywords = new Set<string>();

    if (substance) keywords.add(substance);
    if (primaryPrinceps) keywords.add(primaryPrinceps);
    if (secondaryPrincepsList) secondaryPrincepsList.forEach(p => keywords.add(p));

    if (principesActifs && principesActifs.trim()) {
        const substances = principesActifs.split(/[+,]/).map(s => s.trim());
        substances.forEach(s => {
            if (s) {
                const substanceName = s.split(/\s+\d/)[0].trim();
                if (substanceName) {
                    keywords.add(substanceName);
                }
            }
        });
    }

    if (rawNames && rawNames.length > 0) {
        rawNames.forEach(name => {
            if (name && name.trim()) {
                const normalized = name.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase();
                keywords.add(normalized);
            }
        });
    }

    let vector = Array.from(keywords).join(' ');

    return vector
        .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
        .toUpperCase()
        .replace(/\b(COMPRIME|GELULE|SIROP|SACHET|DOSE|FLACON|MG|ML|BASE|ANHYDRE)\b/g, " ")
        .replace(/[^A-Z0-9]/g, " ")
        .replace(/\s+/g, " ")
        .trim();
}

/**
 * Trouve le préfixe commun (mot par mot) d'une liste de chaînes.
 */
export function findCommonWordPrefix(strings: string[]): string {
    if (strings.length === 0) return "";
    if (strings.length === 1) return strings[0];

    // 1. Standard Word-Based LCP
    const arrays = strings.map(s => s.trim().split(/\s+/));
    const firstArr = arrays[0];
    const commonWords: string[] = [];

    for (let i = 0; i < firstArr.length; i++) {
        const word = firstArr[i];
        const isCommon = arrays.every(arr =>
            arr.length > i && arr[i].toUpperCase() === word.toUpperCase()
        );
        if (isCommon) {
            commonWords.push(word);
        } else {
            break;
        }
    }

    const wordBasedResult = commonWords.join(" ");

    // 2. Exception Handling: Condensed Fallback
    if (wordBasedResult.length < 3) {
        const normalize = (s: string) => s.replace(/[\s-]/g, "").toUpperCase();
        const condensedList = strings.map(normalize);

        const firstCondensed = condensedList[0];
        let condensedLcp = "";

        for (let i = 0; i < firstCondensed.length; i++) {
            const char = firstCondensed[i];
            if (condensedList.every(s => s[i] === char)) {
                condensedLcp += char;
            } else {
                break;
            }
        }

        if (condensedLcp.length >= 3) {
            const exactMatch = strings.find(s => normalize(s) === condensedLcp);
            return exactMatch || condensedLcp;
        }
    }

    return wordBasedResult;
}
