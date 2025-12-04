import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';

/// WHY: Dedicated data structure for scanner results enables us to
/// transport CIP-level metadata (price, refund) alongside the summary.
class ScanResult {
  const ScanResult({
    required this.summary,
    required this.cip,
    this.price,
    this.refundRate,
    this.boxStatus,
    this.availabilityStatus,
    this.isHospitalOnly = false,
    this.libellePresentation,
  });

  final MedicamentEntity summary;
  final Cip13 cip;
  final double? price;
  final String? refundRate;
  final String? boxStatus;
  final String? availabilityStatus;
  final bool isHospitalOnly;
  final String? libellePresentation;
}
