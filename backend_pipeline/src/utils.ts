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
