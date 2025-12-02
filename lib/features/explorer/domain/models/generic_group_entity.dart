import 'package:dart_mappable/dart_mappable.dart';

part 'generic_group_entity.mapper.dart';

@MappableClass()
class GenericGroupEntity with GenericGroupEntityMappable {
  const GenericGroupEntity({
    required this.groupId,
    required this.commonPrincipes,
    required this.princepsReferenceName,
    this.princepsCisCode,
  });

  final String groupId;
  final String commonPrincipes;
  final String princepsReferenceName;
  final String? princepsCisCode;
}
