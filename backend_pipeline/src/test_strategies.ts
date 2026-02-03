/**
 * Strategy Testing Framework
 *
 * Allows rapid A/B testing of different processing strategies
 * without re-running the full pipeline.
 *
 * Usage:
 *   bun run src/test_strategies.ts                     # Test all strategies
 *   bun run src/test_strategies.ts --strategy masking   # Test specific strategy
 *   bun run src/test_strategies.ts --compare           # Compare strategies
 */

import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_JSON_DIR = path.join(__dirname, '../data_json');
const OUTPUT_DIR = path.join(__dirname, '../test_results');

interface ProcessingStrategy {
    name: string;
    description: string;
    process: (record: Record<string, string>) => {
        cleanBrand: string;
        cleanGeneric: string;
        form: string;
        confidence: number;
    };
}

interface TestResult {
    strategy: string;
    total: number;
    success: number;
    failed: number;
    avgConfidence: number;
    samples: any[];
}

/**
 * Load JSON data
 */
function loadData(filename: string): Record<string, string>[] {
    const filePath = path.join(DATA_JSON_DIR, filename);
    if (!fs.existsSync(filePath)) {
        throw new Error(`File not found: ${filePath}`);
    }
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

/**
 * Strategy 1: Comma Split (Current Approach)
 */
const commaSplitStrategy: ProcessingStrategy = {
    name: 'comma_split',
    description: 'Split on first comma (current pipeline approach)',
    process: (record) => {
        const nom = record.nom_specialite || '';
        const commaIndex = nom.indexOf(', ');
        const cleanBrand = commaIndex !== -1 ? nom.substring(0, commaIndex).trim() : nom;
        const form = commaIndex !== -1 ? nom.substring(commaIndex + 2).trim() : record.forme_pharmaceutique || '';

        return {
            cleanBrand,
            cleanGeneric: cleanBrand, // No generic extraction
            form,
            confidence: commaIndex !== -1 ? 0.8 : 0.5
        };
    }
};

/**
 * Strategy 2: Form Subtraction (Current Approach)
 */
const formSubtractionStrategy: ProcessingStrategy = {
    name: 'form_subtraction',
    description: 'Subtract form from end of name (current pipeline approach)',
    process: (record) => {
        const nom = (record.nom_specialite || '').toUpperCase();
        const forme = (record.forme_pharmaceutique || '').toUpperCase();

        // Simple subtraction
        let cleanBrand = nom;
        if (forme && nom.includes(forme)) {
            cleanBrand = nom.substring(0, nom.lastIndexOf(forme)).trim();
        }
        cleanBrand = cleanBrand.replace(/[,.;:\-\/]+$/, '').trim();

        return {
            cleanBrand,
            cleanGeneric: cleanBrand,
            form: forme,
            confidence: forme && nom.includes(forme) ? 0.7 : 0.4
        };
    }
};

/**
 * Strategy 3: Brand Extraction (Regex-based)
 */
const brandExtractionStrategy: ProcessingStrategy = {
    name: 'brand_extraction',
    description: 'Extract brand using regex patterns (new approach)',
    process: (record) => {
        const nom = record.nom_specialite || '';
        const forme = record.forme_pharmaceutique || '';

        // Pattern: BRAND DOSAGE form
        // e.g., "CLAMOXYL 500 mg, gélule" → "CLAMOXYL"
        const brandPattern = /^([A-Z][A-Z0-9\s]+?)\s+\d+(\.\d+)?\s*(mg|g|ml|UI|%)/i;
        const match = nom.match(brandPattern);

        let cleanBrand = match ? match[1].trim() : nom.split(',')[0].trim();
        cleanBrand = cleanBrand.replace(/[,.\s]+$/, '').trim();

        // Extract generic from composition if available
        const generic = extractGenericFromComposition(record);

        return {
            cleanBrand,
            cleanGeneric: generic || cleanBrand,
            form: forme,
            confidence: match ? 0.9 : 0.6
        };
    }
};

/**
 * Strategy 4: Composition-Based Lookup (Ideal Approach)
 */
const compositionLookupStrategy: ProcessingStrategy = {
    name: 'composition_lookup',
    description: 'Use CIS_COMPO data for generic name (ideal approach)',
    process: (record) => {
        const nom = record.nom_specialite || '';
        const forme = record.forme_pharmaceutique || '';

        // Extract brand (same as brand extraction)
        const brandPattern = /^([A-Z][A-Z0-9\s]+?)\s+\d+(\.\d+)?\s*(mg|g|ml|UI|%)/i;
        const match = nom.match(brandPattern);
        let cleanBrand = match ? match[1].trim() : nom.split(',')[0].trim();
        cleanBrand = cleanBrand.replace(/[,.\s]+$/, '').trim();

        // Use composition data for generic
        const generic = extractGenericFromComposition(record);

        return {
            cleanBrand,
            cleanGeneric: generic || cleanBrand,
            form: forme,
            confidence: generic ? 0.95 : 0.5
        };
    }
};

/**
 * Helper: Extract generic from composition record
 */
function extractGenericFromComposition(_record: Record<string, string>): string | null {
    // This would need composition data joined
    // For now, return null (would be implemented with full data)
    return null;
}

/**
 * Test a strategy on sample data
 */
function testStrategy(
    strategy: ProcessingStrategy,
    samples: Record<string, string>[],
    limit = 1000
): TestResult {
    const testSamples = samples.slice(0, limit);
    const results: any[] = [];
    let totalConfidence = 0;

    for (const sample of testSamples) {
        try {
            const result = strategy.process(sample);
            results.push({
                cis_code: sample.cis_code,
                original: sample.nom_specialite,
                ...result
            });
            totalConfidence += result.confidence;
        } catch (error) {
            // Failed processing
        }
    }

    return {
        strategy: strategy.name,
        total: testSamples.length,
        success: results.length,
        failed: testSamples.length - results.length,
        avgConfidence: results.length > 0 ? totalConfidence / results.length : 0,
        samples: results.slice(0, 10) // First 10 for inspection
    };
}

/**
 * Compare strategies side-by-side
 */
function compareStrategies(
    samples: Record<string, string>[],
    strategies: ProcessingStrategy[]
): void {
    console.log('\n=== Strategy Comparison ===\n');

    const results: TestResult[] = [];

    for (const strategy of strategies) {
        const result = testStrategy(strategy, samples, 500);
        results.push(result);

        console.log(`${strategy.name}:`);
        console.log(`  Description: ${strategy.description}`);
        console.log(`  Success Rate: ${(result.success / result.total * 100).toFixed(1)}%`);
        console.log(`  Avg Confidence: ${result.avgConfidence.toFixed(2)}`);
        console.log();
    }

    // Find best strategy
    results.sort((a, b) => b.avgConfidence - a.avgConfidence);
    console.log(`Best strategy: ${results[0].strategy} (confidence: ${results[0].avgConfidence.toFixed(2)})`);

    // Save comparison results
    const outputPath = path.join(OUTPUT_DIR, 'strategy_comparison.json');
    fs.writeFileSync(outputPath, JSON.stringify(results, null, 2), 'utf8');
    console.log(`\nResults saved to: ${outputPath}`);
}

/**
 * Analyze specific edge cases
 */
function analyzeEdgeCases(samples: Record<string, string>[]): void {
    console.log('\n=== Edge Case Analysis ===\n');

    const edgeCases = [
        { pattern: 'CLAMOXYL', description: 'Well-known brand' },
        { pattern: 'DOLIPRANE', description: 'Well-known brand with generics' },
        { pattern: 'VITAMINE', description: 'Combined products' },
        { pattern: '/', description: 'Complex names' },
        { pattern: 'LYOC', description: 'Lyophilisat forms' }
    ];

    for (const testCase of edgeCases) {
        const matches = samples.filter(s =>
            (s.nom_specialite || '').includes(testCase.pattern)
        ).slice(0, 5);

        console.log(`${testCase.description} (${testCase.pattern}):`);
        console.log(`  Found ${matches.length} samples`);

        for (const match of matches) {
            console.log(`  - ${match.nom_specialite}`);
        }
        console.log();
    }
}

/**
 * Main testing function
 */
function main() {
    const args = process.argv.slice(2);

    // Create output directory
    if (!fs.existsSync(OUTPUT_DIR)) {
        fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    // Load data
    console.log('Loading BDPM data...\n');
    const specialites = loadData('specialites.json');

    // Parse options
    const testSpecific = args.indexOf('--strategy');
    const compareMode = args.indexOf('--compare');

    if (compareMode !== -1) {
        // Compare all strategies
        compareStrategies(specialites, [
            commaSplitStrategy,
            formSubtractionStrategy,
            brandExtractionStrategy,
            compositionLookupStrategy
        ]);
    } else if (testSpecific !== -1) {
        // Test specific strategy
        const strategyName = args[testSpecific + 1];
        const strategies: ProcessingStrategy[] = [
            commaSplitStrategy,
            formSubtractionStrategy,
            brandExtractionStrategy,
            compositionLookupStrategy
        ];

        const strategy = strategies.find(s => s.name === strategyName);
        if (strategy) {
            const result = testStrategy(strategy, specialites);
            console.log(`\n${strategy.name}: ${result.success}/${result.total} successful`);
            console.log(`Avg confidence: ${result.avgConfidence.toFixed(2)}\n`);

            // Save results
            const outputPath = path.join(OUTPUT_DIR, `${strategy.name}_results.json`);
            fs.writeFileSync(outputPath, JSON.stringify(result, null, 2), 'utf8');
            console.log(`Results saved to: ${outputPath}`);
        } else {
            console.error(`Unknown strategy: ${strategyName}`);
            console.log(`Available: ${strategies.map(s => s.name).join(', ')}`);
        }
    } else {
        // Analyze edge cases
        analyzeEdgeCases(specialites);
    }
}

main();
