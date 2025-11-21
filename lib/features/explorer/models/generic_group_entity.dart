import 'package:freezed_annotation/freezed_annotation.dart';

part 'generic_group_entity.freezed.dart';

@freezed
abstract class GenericGroupEntity with _$GenericGroupEntity {
  const factory GenericGroupEntity({
    required String groupId,
    required String commonPrincipes,
    required String princepsReferenceName,
  }) = _GenericGroupEntity;
}
