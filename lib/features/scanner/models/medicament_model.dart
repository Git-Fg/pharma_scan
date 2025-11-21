// lib/features/scanner/models/medicament_model.dart
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'medicament_model.freezed.dart';

@freezed
abstract class Medicament with _$Medicament {
  const factory Medicament({
    required String nom,
    required String codeCip,
    @Default([]) List<String> principesActifs,
    @Default('') String titulaire,
    @Default('') String formePharmaceutique,
    Decimal? dosage,
    @Default('') String dosageUnit,
    @Default('') String groupId,
    @Default(0) int groupMemberType,
    @Default('') String conditionsPrescription,
  }) = _Medicament;
}
