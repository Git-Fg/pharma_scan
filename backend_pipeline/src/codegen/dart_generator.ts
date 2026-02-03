/**
 * Dart Code Generator - Generates type constants and query contracts from JSON exports
 */

import { promises as fs } from 'fs';
import path from 'path';
import type { TypeExport, QueriesExport } from '../pipeline/07_export_schema.js';
import type { GeneratorOptions } from './utils.js';
import { buildDartHeader, formatSqlForDart, toCamelCase } from './utils.js';

/**
 * Generate lib/core/database/generated/generated_types.dart
 */
export async function generateDartTypes(
  types: TypeExport,
  options: GeneratorOptions
): Promise<void> {
  const lines: string[] = [];

  // Header
  lines.push(buildDartHeader(options.packageName, 'from backend/types.json'));
  lines.push('');

  // TypeDefinition class
  lines.push('/// Type definition metadata');
  lines.push('class TypeDefinition {');
  lines.push('  final String name;');
  lines.push('  final String type;');
  lines.push('  final int? length;');
  lines.push('  final bool nullable;');
  lines.push('  final String? description;');
  lines.push('');
  lines.push('  const TypeDefinition({');
  lines.push('    required this.name,');
  lines.push('    required this.type,');
  lines.push('    this.length,');
  lines.push('    required this.nullable,');
  lines.push('    this.description,');
  lines.push('  });');
  lines.push('}');
  lines.push('');

  // Branded types constants
  lines.push('/// Branded type definitions from backend');
  lines.push('const Map<String, TypeDefinition> kBrandedTypes = {');
  for (const [name, def] of Object.entries(types.zodSchemas)) {
    lines.push(`  '${name}': TypeDefinition(`);
    lines.push(`    name: '${name}',`);
    lines.push(`    type: '${def.type}',`);
    if (def.length) lines.push(`    length: ${def.length},`);
    lines.push(`    nullable: ${def.nullable},`);
    if (def.description) lines.push(`    description: '${def.description}',`);
    lines.push('  ),');
  }
  lines.push('};');
  lines.push('');

  // Column to extension type mapping
  const extensionTypeMap = new Map<string, string>();
  for (const [name, def] of Object.entries(types.brandedTypes)) {
    const columnMap = getColumnNameForType(name);
    if (columnMap) {
      extensionTypeMap.set(columnMap, name);
    }
  }

  lines.push('/// Column name to extension type mapping');
  lines.push('const Map<String, String> kColumnExtensionTypes = {');
  for (const [column, typeName] of extensionTypeMap.entries()) {
    lines.push(`  '${column}': '${typeName}',`);
  }
  lines.push('};');
  lines.push('');

  // Table to entity mapping
  lines.push('/// Table name to entity class mapping');
  lines.push('const Map<String, String> kTableToEntityMap = {');
  const tableEntityMap: [string, string][] = [
    ['cluster_index', 'ClusterIndexData'],
    ['medicament_summary', 'MedicamentSummary'],
    ['ui_group_details', 'GroupDetailEntity'],
    ['ui_explorer_list', 'ClusterEntity'],
    ['generique_groups', 'GenericGroup'],
    ['medicaments', 'Medicament'],
    ['specialites', 'Specialite'],
  ];
  for (const [table, entity] of tableEntityMap) {
    lines.push(`  '${table}': '${entity}',`);
  }
  lines.push('};');
  lines.push('');

  // Entity classes
  lines.push('/// Entity class definitions');
  for (const [name, def] of Object.entries(types.entities)) {
    lines.push(`/// ${def.description ?? name}`);
    lines.push(`class ${name} {`);
    lines.push(`  const ${name}();`);
    lines.push('}');
    lines.push('');
  }

  const content = lines.join('\n');
  const outputPath = path.join(options.outputDir, 'generated_types.dart');
  await fs.writeFile(outputPath, content, 'utf-8');
  console.log(`   ✅ generated_types.dart (${(content.length / 1024).toFixed(1)} KB)`);
}

/**
 * Generate lib/core/database/generated/generated_queries.dart
 */
export async function generateDartQueries(
  queries: QueriesExport,
  options: GeneratorOptions
): Promise<void> {
  const lines: string[] = [];

  // Header
  lines.push(buildDartHeader(options.packageName, 'from backend/queries.json'));
  lines.push('');

  // QueryContract class
  lines.push('/// Query contract definition');
  lines.push('class QueryContract {');
  lines.push('  final String name;');
  lines.push('  final String description;');
  lines.push('  final List<QueryParameter> parameters;');
  lines.push('  final String returnType;');
  lines.push('  final String sql;');
  lines.push('');
  lines.push('  const QueryContract({');
  lines.push('    required this.name,');
  lines.push('    required this.description,');
  lines.push('    required this.parameters,');
  lines.push('    required this.returnType,');
  lines.push('    required this.sql,');
  lines.push('  });');
  lines.push('}');
  lines.push('');

  // QueryParameter class
  lines.push('/// Query parameter definition');
  lines.push('class QueryParameter {');
  lines.push('  final String name;');
  lines.push('  final String type;');
  lines.push('  final String? description;');
  lines.push('');
  lines.push('  const QueryParameter({');
  lines.push('    required this.name,');
  lines.push('    required this.type,');
  lines.push('    this.description,');
  lines.push('  });');
  lines.push('}');
  lines.push('');

  // Generate query contracts by category
  generateQueryContracts(lines, 'Explorer', 'explorer', queries.explorer);
  generateQueryContracts(lines, 'Catalog', 'catalog', queries.catalog);
  generateQueryContracts(lines, 'Restock', 'restock', queries.restock);

  const content = lines.join('\n');
  const outputPath = path.join(options.outputDir, 'generated_queries.dart');
  await fs.writeFile(outputPath, content, 'utf-8');
  console.log(`   ✅ generated_queries.dart (${(content.length / 1024).toFixed(1)} KB)`);
}

/**
 * Generate query contracts for a category
 */
function generateQueryContracts(
  lines: string[],
  label: string,
  category: string,
  contracts: import('../pipeline/07_export_schema.js').QueryContract[]
): void {
  const constName = `k${label}QueryContracts`;

  lines.push(`/// ${label} query contracts`);
  lines.push(`const List<QueryContract> ${constName} = [`);

  for (const contract of contracts) {
    lines.push('  QueryContract(');
    lines.push(`    name: '${contract.name}',`);
    lines.push(`    description: '${contract.description}',`);
    lines.push(`    parameters: const [`);

    for (const param of contract.parameters) {
      lines.push(`      QueryParameter(`);
      lines.push(`        name: '${param.name}',`);
      lines.push(`        type: '${param.type}',`);
      if (param.description) {
        lines.push(`        description: '${param.description}',`);
      }
      lines.push('      ),');
    }

    lines.push('    ],');
    lines.push(`    returnType: '${contract.returnType}',`);
    lines.push(`    sql: '''`);
    lines.push(`${formatSqlForDart(contract.sql)}`);
    lines.push(`    ''',`);
    lines.push('  ),');
  }

  lines.push('];');
  lines.push('');
}

/**
 * Map branded type name to column name
 */
function getColumnNameForType(typeName: string): string | null {
  const map: Record<string, string> = {
    CisId: 'cis_code',
    Cip13: 'cip_code',
    GroupId: 'group_id',
    ClusterId: 'cluster_id',
  };
  return map[typeName] ?? null;
}
