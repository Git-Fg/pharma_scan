import 'package:pharma_scan/core/database/reference_schema.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

/// Extension type wrapping [ClusterIndexData] to provide zero-cost abstraction
/// for cluster search results.
///
/// This entity represents a conceptual cluster (group of related medications)
/// that users can search for and explore.
extension type ClusterEntity(ClusterIndexData _data) {
  /// Creates a [ClusterEntity] from a [ClusterIndexData] instance.
  ClusterEntity.fromData(ClusterIndexData data) : this(data);

  /// The unique identifier for this cluster.
  ClusterId get id => ClusterId.validated(_data.clusterId);

  /// The main title displayed to users (e.g., "Ibuprofène 400mg").
  String get title => _data.title;

  /// Optional subtitle providing context (e.g., "Réf: Advil").
  String get subtitle => _data.subtitle ?? '';

  /// Number of products in this cluster.
  int get productCount => _data.countProducts ?? 0;

  /// Display text with product count for UI components.
  String get displayText => productCount > 0 ? '$title ($productCount)' : title;

  /// The search vector used for FTS5 (internal use only).
  String? get searchVector => _data.searchVector;

  /// Read-only access to the underlying Drift data.
  ClusterIndexData get dbData => _data;
}

/// Extension type wrapping [MedicamentSummaryData] to provide zero-cost abstraction
/// for individual products within a cluster.
///
/// This entity represents a specific medication that belongs to a cluster,
/// displayed in the medication drawer when users explore cluster contents.
extension type ClusterProductEntity(MedicamentSummaryData _data) {
  /// Creates a [ClusterProductEntity] from a [MedicamentSummaryData] instance.
  ClusterProductEntity.fromData(MedicamentSummaryData data) : this(data);

  /// The CIS code identifying this specific medication.
  CisCode get cisCode => CisCode.validated(_data.cisCode);

  /// The representative CIP code for this medication.
  String? get cipCode => _data.representativeCip;

  /// The complete name of the medication as displayed to users.
  String get name => _data.nomCanonique;

  /// True if this is a princeps (original brand) medication.
  bool get isPrinceps => _data.isPrinceps == 1;

  /// The cluster this product belongs to (nullable for edge cases).
  ClusterId? get clusterId =>
      _data.clusterId != null ? ClusterId.validated(_data.clusterId!) : null;

  /// Read-only access to the underlying Drift data.
  MedicamentSummaryData get dbData => _data;
}
