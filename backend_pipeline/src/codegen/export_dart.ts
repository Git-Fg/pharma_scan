/**
 * Unified Export Orchestrator
 *
 * Consolidates schema export and Dart code generation.
 * Replaces scripts/dump_schema.sh with TypeScript implementation.
 */

import { execSync } from 'child_process';
import { promises as fs } from 'fs';
import path from 'path';
import { runSchemaExport } from '../pipeline/07_export_schema.js';
import { generateDartTypes, generateDartQueries } from './dart_generator.js';
import { generateDaoReferences } from './dao_generator.js';
import type { ExportOptions } from './utils.js';

/**
 * Main export function - orchestrates all generation steps
 */
export async function runDartExport(options: ExportOptions): Promise<void> {
  console.log('🎯 Starting unified Dart export...\n');

  // Validate prerequisites
  await validatePrerequisites(options);

  // Step 1: Export JSON contracts (Phase 7)
  console.log('📋 Step 1: Exporting JSON contracts...');
  const schemaResult = await runSchemaExport(
    options.dbPath,
    options.outputDir
  );
  console.log('');

  // Step 2: Generate Dart types
  console.log('📋 Step 2: Generating Dart type constants...');
  const dartOutputDir = path.join(
    options.flutterProjectRoot,
    'lib/core/database/generated'
  );
  await fs.mkdir(dartOutputDir, { recursive: true });

  await generateDartTypes(schemaResult.types, {
    outputDir: dartOutputDir,
    packageName: 'pharma_scan.core.database.generated',
  });
  console.log('');

  // Step 3: Generate query contracts
  console.log('📋 Step 3: Generating query contracts...');
  await generateDartQueries(schemaResult.queries, {
    outputDir: dartOutputDir,
    packageName: 'pharma_scan.core.database.generated',
  });
  console.log('');

  // Step 4: Generate DAO reference implementations
  console.log('📋 Step 4: Generating DAO references...');
  await generateDaoReferences(schemaResult.queries, {
    outputDir: dartOutputDir,
    packageName: 'pharma_scan.core.database.generated',
  });
  console.log('');

  // Step 5: Sync database artifacts (from dump_schema.sh)
  console.log('📋 Step 5: Syncing database artifacts...');
  await syncDatabaseArtifacts(options);
  console.log('');

  // Step 6: Generate/update Drift schema file
  console.log('📋 Step 6: Updating Drift schema file...');
  await updateDriftSchema(options);
  console.log('');

  console.log('✅ Unified export complete!');
  console.log(`   JSON contracts: ${options.outputDir}`);
  console.log(`   Generated files: ${dartOutputDir}`);
}

/**
 * Validate that prerequisites are met
 */
async function validatePrerequisites(options: ExportOptions): Promise<void> {
  // Check database exists
  try {
    await fs.access(options.dbPath);
  } catch {
    throw new Error(`Database not found: ${options.dbPath}\nRun 'bun run build' first to generate the database.`);
  }

  // Check output directory
  await fs.mkdir(options.outputDir, { recursive: true });

  // Check Flutter project root
  try {
    await fs.access(options.flutterProjectRoot);
    const pubspecPath = path.join(options.flutterProjectRoot, 'pubspec.yaml');
    await fs.access(pubspecPath);
  } catch {
    throw new Error(`Flutter project not found: ${options.flutterProjectRoot}`);
  }
}

/**
 * Sync database artifacts (consolidates dump_schema.sh functionality)
 */
async function syncDatabaseArtifacts(options: ExportOptions): Promise<void> {
  const srcDb = options.dbPath;
  const testDest = path.join(options.flutterProjectRoot, 'assets/test/reference.db');
  const appDest = path.join(options.flutterProjectRoot, 'assets/database/reference.db.gz');

  // Create destination directories
  await fs.mkdir(path.dirname(testDest), { recursive: true });
  await fs.mkdir(path.dirname(appDest), { recursive: true });

  // Copy to test assets
  console.log(`   -> Copying to test assets: ${path.relative(options.flutterProjectRoot, testDest)}`);
  await fs.copyFile(srcDb, testDest);

  // Compress to app assets
  console.log(`   -> Compressing to app assets: ${path.relative(options.flutterProjectRoot, appDest)}`);

  // Use gzip via child process for better compression
  try {
    const gzipCommand = `gzip -c "${srcDb}" > "${appDest}"`;
    execSync(gzipCommand, { stdio: 'pipe' });
  } catch (error) {
    throw new Error(`Failed to compress database: ${error}`);
  }

  console.log('   ✅ Database artifacts synced');
}

/**
 * Update Drift schema file using sqlite3 CLI
 */
async function updateDriftSchema(options: ExportOptions): Promise<void> {
  const dbPath = options.dbPath;
  const outputPath = path.join(
    options.flutterProjectRoot,
    'lib/core/database/reference_schema.drift'
  );

  console.log(`   -> Extracting schema from database`);
  console.log(`   -> Writing to: ${path.relative(options.flutterProjectRoot, outputPath)}`);

  try {
    // Extract tables
    const tablesSql = execSync(
      `sqlite3 "${dbPath}" ".mode list" ".headers off" "SELECT sql || ';' FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND sql IS NOT NULL ORDER BY name;"`,
      { encoding: 'utf-8' }
    );

    // Extract virtual tables (FTS5)
    const virtualTablesSql = execSync(
      `sqlite3 "${dbPath}" ".mode list" ".headers off" "SELECT sql || ';' FROM sqlite_master WHERE type = 'table' AND name LIKE 'search_index%' AND sql IS NOT NULL ORDER BY name;"`,
      { encoding: 'utf-8' }
    );

    // Extract indexes
    const indexesSql = execSync(
      `sqlite3 "${dbPath}" ".mode list" ".headers off" "SELECT sql || ';' FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%' AND sql IS NOT NULL ORDER BY tbl_name, name;"`,
      { encoding: 'utf-8' }
    );

    // Build output
    const lines: string[] = [];
    lines.push('-- REFERENCE SCHEMA - Tables de référence générées par le backend TypeScript');
    lines.push('-- Ces tables sont importées depuis la base de données reference.db');
    lines.push('-- Généré automatiquement par src/codegen/export_dart.ts');
    lines.push('-- Ne pas éditer manuellement - Régénérer avec: cd backend_pipeline && bun run export');
    lines.push('');
    lines.push('-- Tables:');
    lines.push(tablesSql.trim());
    lines.push('');
    lines.push('-- Virtual Tables (FTS5):');
    lines.push(virtualTablesSql.trim());
    lines.push('');
    lines.push('-- Indexes:');
    lines.push(indexesSql.trim());
    lines.push('');

    // Write to file
    await fs.writeFile(outputPath, lines.join('\n'), 'utf-8');

    // Clean up legacy files
    const legacyFiles = [
      path.join(options.flutterProjectRoot, 'lib/core/database/generated_tables.drift'),
      path.join(options.flutterProjectRoot, 'lib/core/database/backend_tables.drift'),
    ];

    for (const file of legacyFiles) {
      try {
        await fs.unlink(file);
      } catch {
        // File doesn't exist, ignore
      }
    }

    console.log('   ✅ Drift schema updated');
  } catch (error) {
    throw new Error(`Failed to update Drift schema: ${error}`);
  }
}

/**
 * Main entry point when run directly
 */
async function main(): Promise<void> {
  // Use the directory containing this script as the base
  const scriptDir = path.dirname(new URL(import.meta.url).pathname);
  const backendDir = path.resolve(scriptDir, '../..');

  const dbPath = path.join(backendDir, 'output/reference.db');
  const outputDir = path.join(backendDir, 'output');
  const flutterProjectRoot = path.join(backendDir, '..');

  await runDartExport({
    dbPath,
    outputDir,
    flutterProjectRoot,
  });
}

// Run main when executed directly
main().catch((error) => {
  console.error('Export failed:', error);
  process.exit(1);
});

