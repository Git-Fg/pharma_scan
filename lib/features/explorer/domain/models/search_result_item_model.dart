import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';

part 'search_result_item_model.mapper.dart';

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

  final MedicamentEntity princeps;
  final List<MedicamentEntity> generics;
  final GroupId groupId;
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

  final MedicamentEntity generic;
  final List<MedicamentEntity> princeps;
  final GroupId groupId;
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

  final CisCode cisCode;
  final MedicamentEntity summary;
  final Cip13 representativeCip;
  final String commonPrinciples;
}

@MappableClass(discriminatorValue: 'clusterResult')
class ClusterResult extends SearchResultItem with ClusterResultMappable {
  const ClusterResult({
    required this.groups,
    required this.displayName,
    required this.commonPrincipes,
    required this.sortKey,
  });

  final List<GenericGroupEntity> groups;
  final String displayName;
  final String commonPrincipes;
  final String sortKey;
}
