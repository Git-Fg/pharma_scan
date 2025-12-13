import 'package:pharma_scan/core/database/restock_views.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/utils/strings.dart';

/// Extension type wrapping [ViewRestockItem] for zero-cost abstraction.
extension type RestockItemEntity(ViewRestockItem _data) {
  // Factory expecting the exact Drift row type
  factory RestockItemEntity.fromData(ViewRestockItem data) =>
      RestockItemEntity(data);

  // Directly validated getters
  Cip13 get cip => Cip13.validated(_data.cipCode);

  // Logic mapped from DAO
  String get label => _data.nomCanonique ?? Strings.unknown;

  int get quantity => _data.stockCount;

  bool get isChecked => _data.notes?.contains('"checked":true') ?? false;

  // Handle nullable boolean from Drift view
  bool get isPrinceps => _data.isPrinceps ?? false;

  String? get form => _data.formePharmaceutique;

  String? get princepsLabel => _data.princepsDeReference;

  /// Sorting key used by higher layers when applying smart sorting.
  String get sortingKey => (princepsLabel ?? label).trim();
}
