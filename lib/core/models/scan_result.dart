
import 'package:pharma_scan/core/database/database.dart';

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

  final MedicamentSummaryData summary;
  final String cip;
  final double? price;
  final String? refundRate;
  final String? boxStatus;
  final String? availabilityStatus;
  final bool isHospitalOnly;
  final String? libellePresentation;
}
