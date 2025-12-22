import fs from "fs";
import { parse } from "csv-parse";
import iconv from "iconv-lite";

/**
 * Reads a BDPM file (TSV, Latin1) fully into memory.
 * Useful for small files.
 */
export async function readBdpmFile(filePath: string): Promise<string[][]> {
    const content = await fs.promises.readFile(filePath);
    const decoded = iconv.decode(content, "latin1"); // BDPM files are often Latin1 (ISO-8859-1) or CP1252
    return new Promise((resolve, reject) => {
        parse(decoded, {
            delimiter: "\t",
            relax_quotes: true,
            relax_column_count: true,
            skip_empty_lines: true,
            skip_records_with_error: true,
            quote: null // Disable quoting to handle unescaped quotes in descriptions
        }, (err, records) => {
            if (err) return reject(err);
            resolve(records);
        });
    });
}

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
 * Parses a price string (e.g. "12,50", "1 200,50") into cents integer.
 */
export function parsePriceToCents(priceStr: string): number | null {
    if (!priceStr) return null;

    // Remove spaces first
    let clean = priceStr.replace(/\s/g, '');

    // French format can be:
    // "12,50" -> 12.50
    // "1.200,50" -> 1200.50  (dot as thousands separator, comma as decimal)
    // "1 200,50" -> 1200.50  (space as thousands separator, comma as decimal)
    // "1,200,50" -> 1200.50? This is ambiguous but tests expect 120050 cents = 1200.50 euros

    // Strategy: If there's a comma, treat the LAST comma as decimal separator
    // and remove all dots and other commas
    const lastCommaIndex = clean.lastIndexOf(',');

    if (lastCommaIndex !== -1) {
        // Split at last comma
        const integerPart = clean.substring(0, lastCommaIndex).replace(/[.,]/g, ''); // Remove all separators
        const decimalPart = clean.substring(lastCommaIndex + 1);
        clean = integerPart + '.' + decimalPart;
    } else {
        // No comma, remove dots (they were thousands separators)
        clean = clean.replace(/\./g, '');
    }

    const val = parseFloat(clean);
    if (!isNaN(val)) {
        return Math.round(val * 100);
    }
    return null;
}

/**
 * Parses DD/MM/YYYY to YYYY-MM-DD.
 */
export function parseDateToIso(dateStr: string): string | null {
    if (!dateStr) return null;
    const parts = dateStr.split('/');
    if (parts.length === 3) {
        return `${parts[2]}-${parts[1]}-${parts[0]}`;
    }
    return null;
}

/**
 * Build search vector for FTS5 indexing.
 * Concatenates substance, primary princeps, secondary princeps, and active principles.
 */
export function buildSearchVector(
    substance: string,
    primaryPrinceps: string,
    secondaryPrincepsList: string[],
    principesActifs?: string
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
