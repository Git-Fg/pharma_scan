import 'package:pharma_scan/core/database/restock_views.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/utils/strings.dart';

/// Extension type wrapping [ViewRestockItem] for zero-cost abstraction.
extension type RestockItemEntity(ViewRestockItem data) {
  // Factory expecting the exact Drift row type
  factory RestockItemEntity.fromData(ViewRestockItem data) =>
      RestockItemEntity(data);

  // Directly validated getters
  Cip13 get cip => Cip13.validated(data.cipCode);

  // Logic mapped from DAO
  String get label => data.nomCanonique ?? Strings.unknown;

  int get quantity => data.stockCount;

  bool get isChecked => data.notes?.contains('"checked":true') ?? false;

  // Handle potentially non-boolean representation from Drift view
  bool get isPrinceps => _convertToBool(data.isPrinceps);

  // Helper to convert potentially string/int values to boolean
  // Handles various database representations: 1/0, '1'/'0', 'true'/'false', 't'/'f', etc.
  static bool _convertToBool(dynamic value) {
    if (value == null) return false;

    if (value is bool) return value;

    if (value is int) return value != 0;

    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == '1' || lower == 'true' || lower == 't' || lower == 'yes' || lower == 'y') {
        return true;
      } else if (lower == '0' || lower == 'false' || lower == 'f' || lower == 'no' || lower == 'n') {
        return false;
      }
    }

    // If conversion isn't straightforward, treat non-empty as true
    return value.toString().isNotEmpty && value.toString() != '0';
  }

  String? get form => data.formePharmaceutique;

  String? get princepsLabel => data.princepsDeReference;

  /// Sorting key used by higher layers when applying smart sorting.
  String get sortingKey => (princepsLabel ?? label).trim();
}
