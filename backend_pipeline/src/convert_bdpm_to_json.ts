/**
 * BDPM to JSON Converter
 *
 * Converts BDPM TSV files to JSON for easier testing and iteration.
 * This allows rapid A/B testing of different processing strategies
 * without re-running the full pipeline.
 *
 * Usage:
 *   bun run src/convert_bdpm_to_json.ts              # Convert all files
 *   bun run src/convert_bdpm_to_json.ts --sample 100   # Convert with sampling
 *   bun run src/convert_bdpm_to_json.ts --file CIS_bdpm.txt  # Convert specific file
 */

import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(__dirname, '../data');
const OUTPUT_DIR = path.join(__dirname, '../data_json');

interface ConvertOptions {
    sample?: number;      // Sample size (for quick testing)
    file?: string;        // Specific file to convert
    pretty?: boolean;     // Pretty print JSON (default: false for size)
    includeRaw?: boolean; // Include raw TSV line for debugging
}

interface BdpmFileSpec {
    filename: string;
    name: string;
    delimiter: string;
    encoding: BufferEncoding;
    columns: string[];
    skipLines?: number;
    sampleSize?: number;
}

// BDPM file specifications
const BDPM_FILES: BdpmFileSpec[] = [
    {
        filename: 'CIS_bdpm.txt',
        name: 'specialites',
        delimiter: '\t',
        encoding: 'latin1',
        columns: [
            'cis_code',
            'nom_specialite',
            'forme_pharmaceutique',
            'voies_administration',
            'statut',
            'procedure',
            'commercialisation_statut',
            'date_amm',
            'mu',
            'mu_real',
            'titulaire',
            'surveillance'
        ]
    },
    {
        filename: 'CIS_CIP_bdpm.txt',
        name: 'presentations',
        delimiter: '\t',
        encoding: 'latin1',
        columns: [
            'cis_code',
            'cip7',
            'libelle',
            'statut',
            'date_decl',
            'mu',
            'agrement',
            'cip13'
        ]
    },
    {
        filename: 'CIS_GENER_bdpm.txt',
        name: 'generiques',
        delimiter: '\t',
        encoding: 'latin1',
        columns: [
            'group_id',
            'group_label',
            'cis_code',
            'type',
            'ordre'
        ]
    },
    {
        filename: 'CIS_COMPO_bdpm.txt',
        name: 'composition',
        delimiter: '\t',
        encoding: 'latin1',
        columns: [
            'cis_code',
            'element_pharmaceutique',
            'code_substance',
            'denomination_substance',
            'dosage_substance',
            'ref_dosage',
            'lien',
            'vigueur'
        ]
    },
    {
        filename: 'CIS_CPD_bdpm.txt',
        name: 'conditions',
        delimiter: '\t',
        encoding: 'latin1',
        columns: [
            'cis_code',
            'condition_prescription',
            'condition_derogation'
        ]
    }
];

/**
 * Parse a single BDPM TSV line
 */
function parseBdmpLine(line: string, spec: BdpmFileSpec, includeRaw = false): Record<string, string> | null {
    const parts = line.split(spec.delimiter);
    if (parts.length !== spec.columns.length) {
        return null;
    }

    const record: Record<string, string> = {};
    spec.columns.forEach((col, i) => {
        record[col] = parts[i]?.trim() || '';
    });

    if (includeRaw) {
        record._raw = line;
    }

    return record;
}

/**
 * Convert a BDPM file to JSON
 */
function convertBdmpFile(spec: BdpmFileSpec, options: ConvertOptions): { records: Record<string, string>[]; stats: any } {
    const inputPath = path.join(DATA_DIR, spec.filename);
    const outputPath = path.join(OUTPUT_DIR, `${spec.name}.json`);

    if (!fs.existsSync(inputPath)) {
        throw new Error(`File not found: ${inputPath}`);
    }

    console.log(`Converting ${spec.filename}...`);

    const content = fs.readFileSync(inputPath, { encoding: spec.encoding });
    const lines = content.split(/\r?\n/).filter(l => l.trim());

    const stats = {
        totalLines: lines.length,
        successful: 0,
        failed: 0,
        sampled: options.sample ? Math.min(lines.length, options.sample) : lines.length
    };

    const records: Record<string, string>[] = [];
    const limit = options.sample ? options.sample : lines.length;

    for (let i = 0; i < Math.min(lines.length, limit); i++) {
        const record = parseBdmpLine(lines[i], spec, options.includeRaw);
        if (record) {
            records.push(record);
            stats.successful++;
        } else {
            stats.failed++;
        }
    }

    // Write JSON output
    const jsonOutput = options.pretty
        ? JSON.stringify(records, null, 2)
        : JSON.stringify(records);

    fs.writeFileSync(outputPath, jsonOutput, 'utf8');

    console.log(`  → ${stats.successful} records written to ${spec.name}.json`);
    if (stats.failed > 0) {
        console.log(`  → ${stats.failed} records failed to parse`);
    }

    return { records, stats };
}

/**
 * Create a combined test dataset with key medications
 */
function createTestDataset(allRecords: Map<string, Record<string, string>[]>): void {
    // Key test CIP codes from documentation
    const TEST_CIPS = [
        '3400935955838', // DOLIPRANE 1000 mg
        '3400934809408', // DOLIPRANE 150 mg
        '3400931863014', // SPASFON LYOC 80 mg
        '3400930985830', // SPASFON Injectable
        '3400930234259', // AMOXICILLINE KRKA 1 g
        '3400949500963', // ALDARA 5%
    ];

    const testRecords: any = {
        metadata: {
            description: 'Test dataset for processing strategy validation',
            test_cips: TEST_CIPS,
            generated_at: new Date().toISOString()
        },
        specialites: [],
        presentations: [],
        generiques: [],
        composition: []
    };

    // Extract records for test CIPs
    const presentations = allRecords.get('presentations') || [];
    const specialites = allRecords.get('specialites') || [];

    for (const cip of TEST_CIPS) {
        const presentation = presentations.find(p => p.cip13 === cip);
        if (presentation) {
            testRecords.presentations.push(presentation);

            // Find corresponding specialite
            const specialite = specialites.find(s => s.cis_code === presentation.cis_code);
            if (specialite) {
                testRecords.specialites.push(specialite);
            }
        }
    }

    // Also include composition for these CIS
    const composition = allRecords.get('composition') || [];
    const testCisCodes = new Set(testRecords.specialites.map(s => s.cis_code));
    testRecords.composition = composition.filter(c => testCisCodes.has(c.cis_code));

    // Write test dataset
    const outputPath = path.join(OUTPUT_DIR, 'test_dataset.json');
    fs.writeFileSync(outputPath, JSON.stringify(testRecords, null, 2), 'utf8');
    console.log(`\n✓ Test dataset created with ${testRecords.specialites.length} specialites`);
}

/**
 * Create a pharmacy drawer forms sample
 */
function createPharmacyDrawerSample(allRecords: Map<string, Record<string, string>[]>): void {
    const PRIMARY_FORMS = ['gélule', 'comprimé', 'sirop', 'collyre', 'crème', 'pommade'];

    const specialites = allRecords.get('specialites') || [];
    const samples: Record<string, Record<string, string>[]> = {};

    for (const form of PRIMARY_FORMS) {
        const formRecords = specialites
            .filter(s => s.forme_pharmaceutique?.toLowerCase().includes(form))
            .slice(0, 100); // First 100 per form

        samples[form] = formRecords;
    }

    const outputPath = path.join(OUTPUT_DIR, 'pharmacy_drawer_samples.json');
    fs.writeFileSync(outputPath, JSON.stringify(samples, null, 2), 'utf8');

    const totalCount = Object.values(samples).reduce((sum, arr) => sum + arr.length, 0);
    console.log(`✓ Pharmacy drawer samples created: ${totalCount} records across ${PRIMARY_FORMS.length} forms`);
}

/**
 * Create analysis report
 */
function createAnalysisReport(allRecords: Map<string, Record<string, string>[]>): void {
    const specialites = allRecords.get('specialites') || [];
    const presentations = allRecords.get('presentations') || [];
    const composition = allRecords.get('composition') || [];

    const report: any = {
        summary: {
            total_specialites: specialites.length,
            total_presentations: presentations.length,
            total_composition: composition.length
        },
        forms_distribution: {},
        labs: {},
        statut_distribution: {}
    };

    // Analyze forms
    for (const s of specialites) {
        const form = (s.forme_pharmaceutique as string) || 'unknown';
        report.forms_distribution[form] = (report.forms_distribution[form] || 0) + 1;
    }

    // Analyze labs
    for (const s of specialites) {
        const lab = (s.titulaire as string) || 'unknown';
        report.labs[lab] = (report.labs[lab] || 0) + 1;
    }

    // Analyze status
    for (const s of specialites) {
        const status = (s.statut as string) || 'unknown';
        report.statut_distribution[status] = (report.statut_distribution[status] || 0) + 1;
    }

    // Sort by count
    report.forms_distribution = Object.fromEntries(
        Object.entries(report.forms_distribution).sort((a, b) => b[1] - a[1]).slice(0, 20)
    );

    const outputPath = path.join(OUTPUT_DIR, 'analysis_report.json');
    fs.writeFileSync(outputPath, JSON.stringify(report, null, 2), 'utf8');
    console.log(`✓ Analysis report created`);
}

/**
 * Main conversion function
 */
function main() {
    const args = process.argv.slice(2);
    const options: ConvertOptions = {
        sample: undefined,
        file: undefined,
        pretty: false,
        includeRaw: false
    };

    // Parse options
    for (let i = 0; i < args.length; i++) {
        if (args[i] === '--sample') {
            options.sample = parseInt(args[++i]);
        } else if (args[i] === '--file') {
            options.file = args[++i];
        } else if (args[i] === '--pretty') {
            options.pretty = true;
        } else if (args[i] === '--include-raw') {
            options.includeRaw = true;
        }
    }

    // Create output directory
    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    console.log('BDPM to JSON Converter\n');
    console.log(`Output directory: ${OUTPUT_DIR}\n`);

    const allRecords = new Map<string, Record<string, string>[]>();

    // Convert files
    for (const spec of BDPM_FILES) {
        if (options.file && spec.filename !== options.file) {
            continue;
        }

        try {
            const { records } = convertBdmpFile(spec, options);
            allRecords.set(spec.name, records);
        } catch (error) {
            console.error(`  ✗ Error: ${(error as Error).message}`);
        }
    }

    // Create derived datasets
    if (allRecords.size > 0) {
        console.log('\nCreating derived datasets...\n');
        createTestDataset(allRecords);
        createPharmacyDrawerSample(allRecords);
        createAnalysisReport(allRecords);
    }

    console.log('\n✓ Conversion complete!');
}

main();
