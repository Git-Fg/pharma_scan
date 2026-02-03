/**
 * DAO Reference Generator - Generates reference implementations from query contracts
 */

import { promises as fs } from 'fs';
import path from 'path';
import type { QueriesExport } from '../pipeline/07_export_schema.js';
import type { GeneratorOptions } from './utils.js';
import { buildDartHeader, formatSqlForDart, toPascalCase, toCamelCase } from './utils.js';

/**
 * Generate lib/core/database/generated/dao_references.dart
 *
 * This generates reference implementations that can be copied to manual DAOs.
 * The code is fully functional but intended as a starting point.
 */
export async function generateDaoReferences(
  queries: QueriesExport,
  options: GeneratorOptions
): Promise<void> {
  const lines: string[] = [];

  // Header
  lines.push(buildDartHeader(options.packageName, 'from backend/queries.json'));
  lines.push('');
  lines.push('/// ============================================');
  lines.push('/// REFERENCE-ONLY CODE - NOT MEANT TO COMPILE');
  lines.push('/// ============================================');
  lines.push('///');
  lines.push('/// This file contains reference implementations that can be copied');
  lines.push('/// to your manual DAO classes. These are starting points - you will');
  lines.push('/// need to customize the business logic and fix imports.');
  lines.push('///');
  lines.push('/// This file intentionally does not compile because:');
  lines.push('/// - It references methods like customSelect that only exist in DAOs');
  lines.push('/// - It may reference entity types that need to be created');
  lines.push('/// - It includes placeholder helpers like _mapClusterRow');
  lines.push('///');
  lines.push('/// Usage:');
  lines.push('///   1. Find the method you need below');
  lines.push('///   2. Copy the implementation to your DAO class');
  lines.push('///   3. Fix any imports and customize the business logic');
  lines.push('///');
  lines.push('/// To regenerate: cd backend_pipeline && bun run export');
  lines.push('');

  // Imports
  lines.push("import 'package:drift/drift.dart';");
  lines.push("import 'package:pharma_scan/core/database/database.dart';");

  // Import entity types
  const entityImports = new Set<string>([
    'package:pharma_scan/core/domain/entities/cluster_entity.dart',
    'package:pharma_scan/core/domain/entities/group_detail_entity.dart',
  ]);
  for (const imp of entityImports) {
    lines.push(`import '${imp}';`);
  }
  lines.push('');

  // Generate each category
  generateCategoryReferences(lines, 'Explorer', 'explorer', queries.explorer);
  generateCategoryReferences(lines, 'Catalog', 'catalog', queries.catalog);
  generateCategoryReferences(lines, 'Restock', 'restock', queries.restock);

  const content = lines.join('\n');
  const outputPath = path.join(options.outputDir, 'dao_references.dart');
  await fs.writeFile(outputPath, content, 'utf-8');
  console.log(`   ✅ dao_references.dart (${(content.length / 1024).toFixed(1)} KB)`);
}

/**
 * Generate DAO reference implementations for a category
 */
function generateCategoryReferences(
  lines: string[],
  label: string,
  daoName: string,
  contracts: import('../pipeline/07_export_schema.js').QueryContract[]
): void {
  if (contracts.length === 0) {
    lines.push(`/// No ${label.toLowerCase()} queries defined`);
    lines.push('');
    return;
  }

  lines.push(`// ========================================`);
  lines.push(`// ${label} DAO Reference Implementations`);
  lines.push(`// DAO Class: ${toPascalCase(daoName)}Dao`);
  lines.push(`// ========================================`);
  lines.push('');

  for (const contract of contracts) {
    generateMethodReference(lines, contract);
    lines.push('');
  }
}

/**
 * Generate a single method reference
 */
function generateMethodReference(
  lines: string[],
  contract: import('../pipeline/07_export_schema.js').QueryContract
): void {
  const methodName = contract.name;

  lines.push(`/// ${contract.description}`);
  lines.push('///');
  lines.push('/// Generated from backend query contract');
  lines.push('///');
  lines.push('/// Contract: See kExplorerQueryContracts in generated_queries.dart');
  lines.push(`/// Returns: ${contract.returnType}`);

  // Parse return type to determine if it's a Stream or Future
  const isStream = contract.returnType.startsWith('Stream');
  let returnType = isStream
    ? extractStreamType(contract.returnType)
    : extractFutureType(contract.returnType);

  // Replace non-existent entity types with dynamic
  if (returnType === 'ClusterProductEntity') {
    returnType = 'dynamic';
  }

  // Method signature
  const params = contract.parameters
    .map((p) => `${toDartType(p.type)} ${toCamelCase(p.name)}`)
    .join(', ');

  lines.push(`${isStream ? 'Stream' : 'Future'}<${returnType}> ${methodName}(${params}) {`);

  // Method body
  if (contract.parameters.length === 0) {
    // No parameters - simple query
    lines.push(`  return customSelect(`);
  } else if (contract.parameters.some(p => p.name === 'query' && p.type === 'string')) {
    // Query string with conditional logic
    const queryParam = contract.parameters.find(p => p.name === 'query');
    if (queryParam) {
      const queryVar = toCamelCase(queryParam.name);
      lines.push(`  if (${queryVar}.isEmpty) {`);
      lines.push(`    return customSelect(`);
      lines.push(`      '${getEmptyQuerySql(contract.sql)}',`);
      lines.push(`      readsFrom: {clusterIndex},`);
      lines.push(`    ).watch().map((rows) => rows.map((row) => _mapClusterRow(row)).toList());`);
      lines.push(`  }`);
      lines.push(`  return customSelect(`);
    }
  } else {
    lines.push(`  return customSelect(`);
  }

  // SQL query
  lines.push(`    '''`);
  lines.push(`${formatSqlForDart(contract.sql)}`);
  lines.push(`    ''',`);

  // Parameters
  if (contract.parameters.length > 0) {
    lines.push(`    variables: [`);
    for (const param of contract.parameters) {
      const varName = toCamelCase(param.name);
      lines.push(`      ${varName},`);
    }
    lines.push(`    ],`);
  }

  lines.push(`  );`);

  // Close method
  lines.push(`}`);

  lines.push('');
}

/**
 * Extract Stream<T> type
 */
function extractStreamType(returnType: string): string {
  const match = returnType.match(/Stream<(.+)>/);
  return match ? match[1] : 'dynamic';
}

/**
 * Extract Future<T> type
 */
function extractFutureType(returnType: string): string {
  const match = returnType.match(/Future<(.+)>/);
  return match ? match[1] : 'dynamic';
}

/**
 * Get the "empty query" SQL from a contract that has conditional logic
 */
function getEmptyQuerySql(sql: string): string {
  // Look for the comment pattern "-- When query is empty"
  const lines = sql.split('\n');
  let inEmptySection = false;
  const emptyLines: string[] = [];

  for (const line of lines) {
    if (line.includes('-- When query is empty')) {
      inEmptySection = true;
      continue;
    }
    if (line.includes('-- When query has value')) {
      break;
    }
    if (inEmptySection && line.trim() && !line.startsWith('--')) {
      emptyLines.push(line.trim());
    }
  }

  return emptyLines.join(' ') || 'SELECT * FROM cluster_index ORDER BY title ASC LIMIT 100';
}

/**
 * Map SQL/JSON type to Dart type
 */
function toDartType(type: string): string {
  const t = type.toLowerCase();
  if (t === 'string') return 'String';
  if (t === 'number' || t === 'int') return 'int';
  if (t === 'boolean') return 'bool';
  if (t === 'array') return 'List';
  if (t === 'object') return 'Map';
  return 'dynamic';
}
