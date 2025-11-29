// lib/features/explorer/models/search_result_item_model.dart
import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';

part 'search_result_item_model.mapper.dart';

// WHY: Group-level result - returns GenericGroupEntity without hydrating full medication lists
// Medications are lazy-loaded when user navigates to group detail view
@MappableClass(discriminatorKey: 'type')
sealed class SearchResultItem with SearchResultItemMappable {
  const SearchResultItem();
}

@MappableClass(discriminatorValue: 'groupResult')
class GroupResult extends SearchResultItem with GroupResultMappable {
  const GroupResult({required this.group});

  final GenericGroupEntity group;
}

@MappableClass(discriminatorValue: 'princepsResult')
class PrincepsResult extends SearchResultItem with PrincepsResultMappable {
  const PrincepsResult({
    required this.princeps,
    required this.generics,
    required this.groupId,
    required this.commonPrinciples,
  });

  final MedicamentSummaryData princeps;
  final List<MedicamentSummaryData> generics;
  final String groupId;
  final String commonPrinciples;
}

@MappableClass(discriminatorValue: 'genericResult')
class GenericResult extends SearchResultItem with GenericResultMappable {
  const GenericResult({
    required this.generic,
    required this.princeps,
    required this.groupId,
    required this.commonPrinciples,
  });

  final MedicamentSummaryData generic;
  final List<MedicamentSummaryData> princeps;
  final String groupId;
  final String commonPrinciples;
}

@MappableClass(discriminatorValue: 'standaloneResult')
class StandaloneResult extends SearchResultItem with StandaloneResultMappable {
  const StandaloneResult({
    required this.cisCode,
    required this.summary,
    required this.representativeCip,
    required this.commonPrinciples,
  });

  final String cisCode;
  final MedicamentSummaryData summary;
  final String representativeCip;
  final String commonPrinciples;
}
