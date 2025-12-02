import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/core/database/database.dart';

part 'group_explorer_state.mapper.dart';

@MappableClass()
class GroupExplorerState with GroupExplorerStateMappable {
  const GroupExplorerState({
    required this.title,
    required this.princeps,
    required this.generics,
    required this.related,
    required this.commonPrincipes,
    required this.distinctDosages,
    required this.distinctForms,
    required this.aggregatedConditions,
    required this.priceLabel,
    required this.refundLabel,
    this.ansmAlertUrl,
    this.princepsCisCode,
  });

  final String title;
  final List<ViewGroupDetail> princeps;
  final List<ViewGroupDetail> generics;
  final List<ViewGroupDetail> related;
  final List<String> commonPrincipes;
  final List<String> distinctDosages;
  final List<String> distinctForms;
  final List<String> aggregatedConditions;
  final String priceLabel;
  final String refundLabel;
  final String? ansmAlertUrl;
  final String? princepsCisCode;
}
