// Backend-to-Frontend Schema Contract
// Compile-time type safety for database schema using extension types
// Zero runtime cost - types compile away completely

/// Schema version tracking - matches backend schema_metadata table
const int kSchemaVersion = 1;
const String kSchemaVersionTable = 'schema_metadata';

/// Compile-time safe table names
/// These must match backend_pipeline/src/db.ts exactly
extension type SchemaTable(String _) {
  // Core medication tables
  static const String medicamentSummary = 'medicament_summary';
  static const String productScanCache = 'product_scan_cache';
  static const String medicaments = 'medicaments';
  static const String medicamentDetail = 'medicament_detail';
  static const String principesActifs = 'principes_actifs';
  static const String specialites = 'specialites';

  // Clustering and grouping tables
  static const String clusterIndex = 'cluster_index';
  static const String clusterNames = 'cluster_names';
  static const String generiqueGroups = 'generique_groups';
  static const String groupMembers = 'group_members';

  // UI optimized materialized views
  static const String uiExplorerList = 'ui_explorer_list';
  static const String uiGroupDetails = 'ui_group_details';

  // Search and metadata
  static const String searchIndex = 'search_index';
  static const String laboratories = 'laboratories';
}

/// Compile-time safe column names for boolean fields (INTEGER 0/1)
/// Backend creates these as: INTEGER NOT NULL DEFAULT 0 CHECK(col IN (0, 1))
extension type BooleanColumn(String _) {
  // Medicament summary flags
  static const String isPrinceps = 'is_princeps';
  static const String isFormInferred = 'is_form_inferred';
  static const String isSurveillance = 'is_surveillance';

  // Regulatory flags
  static const String isHospital = 'is_hospital';
  static const String isDental = 'is_dental';
  static const String isList1 = 'is_list1';
  static const String isList2 = 'is_list2';
  static const String isNarcotic = 'is_narcotic';
  static const String isException = 'is_exception';
  static const String isRestricted = 'is_restricted';
  static const String isOtc = 'is_otc';
  static const String hasSafetyAlert = 'has_safety_alert';
}

/// Compile-time safe column names for display/UI fields
extension type DisplayColumn(String _) {
  // Primary display fields
  static const String nomCanonique = 'nom_canonique';
  static const String princepsDeReference = 'princeps_de_reference';
  static const String princepsBrandName = 'princeps_brand_name';
  static const String formePharmaceutique = 'forme_pharmaceutique';

  // Pricing and metadata
  static const String prixPublic = 'prix_public';
  static const String prixMin = 'price_min';
  static const String prixMax = 'price_max';
  static const String labName = 'lab_name';
  static const String titulaireId = 'titulaire_id';

  // Identification
  static const String cisCode = 'cis_code';
  static const String cipCode = 'cip_code';
  static const String cip7 = 'cip7';
  static const String clusterId = 'cluster_id';
  static const String groupId = 'group_id';

  // Substances and dosage
  static const String principesActifsCommuns = 'principes_actifs_communs';
  static const String formattedDosage = 'formatted_dosage';
  static const String principe = 'principe';
  static const String dosage = 'dosage';

  // Search and indexing
  static const String searchVector = 'search_vector';
  static const String title = 'title';
  static const String subtitle = 'subtitle';

  // Status and administration
  static const String status = 'status';
  static const String voiesAdministration = 'voies_administration';
  static const String commercialisationStatut = 'commercialisation_statut';
  static const String tauxRemboursement = 'taux_remboursement';
}

/// Required foreign key relationships
/// Ensures referential integrity between tables
const Map<String, Map<String, String>> kForeignKeys = {
  SchemaTable.medicamentSummary: {
    DisplayColumn.titulaireId: '${SchemaTable.laboratories}.id',
    DisplayColumn.clusterId: '${SchemaTable.clusterNames}.cluster_id',
  },
  SchemaTable.medicaments: {
    DisplayColumn.cisCode:
        '${SchemaTable.medicamentSummary}.${DisplayColumn.cisCode}',
  },
  SchemaTable.principesActifs: {
    DisplayColumn.cipCode:
        '${SchemaTable.medicaments}.${DisplayColumn.cipCode}',
  },
  SchemaTable.groupMembers: {
    DisplayColumn.cipCode:
        '${SchemaTable.medicaments}.${DisplayColumn.cipCode}',
    DisplayColumn.groupId: '${SchemaTable.generiqueGroups}.group_id',
  },
  SchemaTable.medicamentDetail: {
    DisplayColumn.clusterId: '${SchemaTable.clusterIndex}.cluster_id',
  },
};

/// UI Display mapping - backend column to Flutter widget location
/// Format: table.column -> Screen.Widget.Property
const Map<String, String> kUiDisplayMapping = {
  // Scanner Result Screen
  '${SchemaTable.productScanCache}.${DisplayColumn.nomCanonique}':
      'ScannerResult.title',
  '${SchemaTable.productScanCache}.${DisplayColumn.princepsDeReference}':
      'ScannerResult.subtitle',
  '${SchemaTable.productScanCache}.${BooleanColumn.isPrinceps}':
      'ScannerResult.badge_type',
  '${SchemaTable.productScanCache}.${BooleanColumn.isNarcotic}':
      'ScannerResult.warning_narcotic',
  '${SchemaTable.productScanCache}.${DisplayColumn.formePharmaceutique}':
      'ScannerResult.form_display',
  '${SchemaTable.productScanCache}.${DisplayColumn.prixPublic}':
      'ScannerResult.price',
  '${SchemaTable.productScanCache}.${DisplayColumn.labName}':
      'ScannerResult.laboratory',

  // Explorer/Search Screen
  '${SchemaTable.clusterIndex}.${DisplayColumn.title}':
      'ExplorerList.item_title',
  '${SchemaTable.clusterIndex}.${DisplayColumn.subtitle}':
      'ExplorerList.item_subtitle',
  '${SchemaTable.clusterIndex}.count_products': 'ExplorerList.badge_count',
  '${SchemaTable.searchIndex}.${DisplayColumn.searchVector}':
      'SearchScreen.fts5_target',

  // Group Detail Screen
  '${SchemaTable.uiGroupDetails}.${DisplayColumn.nomCanonique}':
      'GroupDetailList.item_title',
  '${SchemaTable.uiGroupDetails}.${BooleanColumn.isPrinceps}':
      'GroupDetailList.badge',
  '${SchemaTable.uiGroupDetails}.${DisplayColumn.princepsBrandName}':
      'GroupDetailList.brand_label',
  '${SchemaTable.uiGroupDetails}.${DisplayColumn.prixPublic}':
      'GroupDetailList.price',
  '${SchemaTable.uiGroupDetails}.${DisplayColumn.formePharmaceutique}':
      'GroupDetailList.form',
};

/// Schema validation utilities
class SchemaContract {
  SchemaContract._();

  /// Verify a table exists in schema
  static bool hasTable(String tableName) {
    return const [
      SchemaTable.medicamentSummary,
      SchemaTable.productScanCache,
      SchemaTable.clusterIndex,
      SchemaTable.uiExplorerList,
      SchemaTable.uiGroupDetails,
      SchemaTable.medicaments,
      SchemaTable.groupMembers,
      SchemaTable.generiqueGroups,
      SchemaTable.laboratories,
      SchemaTable.searchIndex,
      SchemaTable.specialites,
      SchemaTable.principesActifs,
      SchemaTable.medicamentDetail,
      SchemaTable.clusterNames,
    ].contains(tableName);
  }

  /// Check if a column should be boolean (INTEGER 0/1)
  static bool isBooleanColumn(String columnName) {
    return const [
      BooleanColumn.isPrinceps,
      BooleanColumn.isNarcotic,
      BooleanColumn.isSurveillance,
      BooleanColumn.isHospital,
      BooleanColumn.isDental,
      BooleanColumn.isList1,
      BooleanColumn.isList2,
      BooleanColumn.isException,
      BooleanColumn.isRestricted,
      BooleanColumn.isOtc,
      BooleanColumn.hasSafetyAlert,
      BooleanColumn.isFormInferred,
    ].contains(columnName);
  }

  /// Get UI display location for a column
  static String? getUiDisplay(String tableName, String columnName) {
    return kUiDisplayMapping['$tableName.$columnName'];
  }

  /// Get foreign key constraint for a column
  static String? getForeignKey(String tableName, String columnName) {
    return kForeignKeys[tableName]?[columnName];
  }
}
