// lib/features/scanner/models/medicament_model.dart
import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'medicament_model.freezed.dart';

@freezed
abstract class Medicament with _$Medicament {
  const factory Medicament({
    required String nom,
    required String codeCip,
    required List<String> principesActifs,
    String? titulaire,
    String? formePharmaceutique,
    Decimal? dosage,
    String? dosageUnit,
    String? groupId,
    int? groupMemberType,
    String? conditionsPrescription,
  }) = _Medicament;
}
