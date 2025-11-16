// lib/features/scanner/models/scan_result_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

part 'scan_result_model.freezed.dart';

@freezed
sealed class ScanResult with _$ScanResult {
  const factory ScanResult.generic({
    required Medicament medicament,
    required List<Medicament> associatedPrinceps,
    required String groupId,
  }) = GenericScanResult;

  const factory ScanResult.princeps({
    required Medicament princeps,
    required String moleculeName,
    required List<String> genericLabs,
    required String groupId,
  }) = PrincepsScanResult;
}
