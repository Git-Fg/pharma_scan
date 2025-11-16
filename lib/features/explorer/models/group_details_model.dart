// lib/features/explorer/models/group_details_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

part 'group_details_model.freezed.dart';

@freezed
abstract class GroupDetails with _$GroupDetails {
  const factory GroupDetails({
    required List<Medicament> princeps,
    required List<Medicament> generics,
  }) = _GroupDetails;
}
