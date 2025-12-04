import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

part 'restock_item_entity.mapper.dart';

@MappableClass()
class RestockItemEntity with RestockItemEntityMappable {
  const RestockItemEntity({
    required this.cip,
    required this.label,
    required this.quantity,
    required this.isChecked,
    required this.isPrinceps,
    this.princepsLabel,
  });

  final Cip13 cip;
  final String label;
  final String? princepsLabel;
  final int quantity;
  final bool isChecked;
  final bool isPrinceps;

  /// Sorting key used by higher layers when applying smart sorting.
  ///
  /// Repository/provider can decide whether to interpret this as
  /// princeps-based or product-based sorting depending on user preference.
  String get sortingKey => (princepsLabel ?? label).trim();
}
