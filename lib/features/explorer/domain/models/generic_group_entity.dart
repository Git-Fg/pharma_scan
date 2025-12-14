import 'package:characters/characters.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

part 'generic_group_entity.mapper.dart';

@MappableClass()
class GenericGroupEntity with GenericGroupEntityMappable {
  GenericGroupEntity({
    required this.groupId,
    required this.commonPrincipes,
    required this.princepsReferenceName,
    this.princepsCisCode,
  });

  final GroupId groupId;
  final String commonPrincipes;
  final String princepsReferenceName;
  final CisCode? princepsCisCode;

  /// Get the sorting tag for this group (first letter of princepsReferenceName)
  String getSortTag() {
    final normalized = princepsReferenceName.trimLeft();
    if (normalized.isEmpty) {
      return '#';
    }
    final firstChar = normalized.characters.first.toUpperCase();
    final isAlpha = RegExp(r'^[A-Z]$').hasMatch(firstChar);
    return isAlpha ? firstChar : '#';
  }
}
