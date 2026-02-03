/**
 * Shared utilities for Dart code generation
 */


export interface GeneratorOptions {
  outputDir: string;
  packageName: string;
}

export interface ExportOptions {
  dbPath: string;
  outputDir: string;
  flutterProjectRoot: string;
}

export interface EnrichedColumnExport {
  name: string;
  type: string;
  nullable: boolean;
  primaryKey: boolean;
  autoIncrement: boolean;
  defaultValue: string | null;
  dartType: string;
  extensionTypeName?: string;
}

export interface EnrichedTableExport {
  name: string;
  columns: EnrichedColumnExport[];
  indexes: import('../pipeline/07_export_schema.js').IndexExport[];
  foreignKeys: import('../pipeline/07_export_schema.js').ForeignKeyExport[];
  entityName?: string;
}

/**
 * Column name to extension type mapping
 */
const COLUMN_TYPE_MAP: Record<string, { dartType: string; extensionType?: string }> = {
  cis_code: { dartType: 'String', extensionType: 'CisCode' },
  cip_code: { dartType: 'String', extensionType: 'Cip13' },
  group_id: { dartType: 'String', extensionType: 'GroupId' },
  cluster_id: { dartType: 'String', extensionType: 'ClusterId' },
  princeps_de_reference: { dartType: 'String' },
  nom_complet: { dartType: 'String' },
  nom_canonique: { dartType: 'String' },
  principes_actifs_communs: { dartType: 'String' }, // JSON stored as TEXT
};

/**
 * Table name to entity class mapping
 */
const TABLE_ENTITY_MAP: Record<string, string> = {
  cluster_index: 'ClusterIndexData',
  medicament_summary: 'MedicamentSummary',
  ui_group_details: 'GroupDetailEntity',
  ui_explorer_list: 'ClusterEntity',
  generique_groups: 'GenericGroup',
  medicaments: 'Medicament',
  specialites: 'Specialite',
  principes_actifs: 'PrincipeActif',
  laboratories: 'Laboratory',
  cluster_names: 'ClusterName',
  group_members: 'GroupMember',
  product_scan_cache: 'ProductScanCache',
  restock_items: 'RestockItem',
  scanned_boxes: 'ScannedBox',
};

/**
 * Convert SQLite type to Dart type
 */
export function sqlTypeToDart(sqlType: string): string {
  const type = sqlType.toUpperCase();
  if (type.includes('INT')) return 'int';
  if (type.includes('REAL') || type.includes('FLOAT') || type.includes('DOUBLE')) return 'double';
  if (type.includes('TEXT') || type.includes('CHAR') || type.includes('CLOB')) return 'String';
  if (type.includes('BLOB')) return 'Uint8List';
  return 'dynamic'; // JSON columns, etc.
}

/**
 * Get Dart type and optional extension type for a column
 */
export function getColumnDartType(columnName: string, sqlType: string): {
  dartType: string;
  extensionTypeName?: string;
} {
  const mapping = COLUMN_TYPE_MAP[columnName.toLowerCase()];
  if (mapping) {
    return {
      dartType: mapping.dartType,
      extensionTypeName: mapping.extensionType,
    };
  }
  return { dartType: sqlTypeToDart(sqlType) };
}

/**
 * Get entity class name for a table
 */
export function getTableEntityName(tableName: string): string {
  return TABLE_ENTITY_MAP[tableName] ?? toPascalCase(tableName);
}

/**
 * Convert snake_case to PascalCase
 */
export function toPascalCase(str: string): string {
  return str
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join('');
}

/**
 * Convert snake_case to camelCase
 */
export function toCamelCase(str: string): string {
  const pascal = toPascalCase(str);
  return pascal.charAt(0).toLowerCase() + pascal.slice(1);
}

/**
 * Build Dart file header
 */
export function buildDartHeader(_packageName: string, description: string): string {
  return `/// Auto-generated ${description}
/// DO NOT EDIT - Regenerate with: cd backend_pipeline && bun run export
library;

`;
}

/**
 * Format SQL query for Dart multiline string
 * Returns a properly formatted multiline string for Dart
 */
export function formatSqlForDart(sql: string): string {
  const trimmed = sql.trim();
  // Remove leading/trailing whitespace
  // Keep line structure but remove extra indentation
  const lines = trimmed.split('\n').map(line => line.trimEnd());
  return lines.join('\n');
}
