// lib/features/explorer/models/search_candidate_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

part 'search_candidate_model.freezed.dart';

@freezed
abstract class SearchCandidate with _$SearchCandidate {
  const factory SearchCandidate({
    required String cisCode,
    required String nomCanonique,
    required bool isPrinceps,
    String? groupId,
    required List<String> commonPrinciples,
    required String princepsDeReference,
    String? formePharmaceutique,
    String? procedureType,
    required Medicament medicament,
  }) = _SearchCandidate;
}
