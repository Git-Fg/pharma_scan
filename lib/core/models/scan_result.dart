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
    this.expDate,
  });

  final MedicamentEntity summary;
  final Cip13 cip;
  final double? price;
  final String? refundRate;
  final String? boxStatus;
  final String? availabilityStatus;
  final bool isHospitalOnly;
  final String? libellePresentation;
  final DateTime? expDate;

  /// Returns true when the expiration date is strictly before today 00:00.
  bool get isExpired {
    if (expDate == null) return false;
    final today = DateTime.now();
    final todayFloor = DateTime(today.year, today.month, today.day);
    final expiryLocal = expDate!.toLocal();
    final expiryFloor = DateTime(
      expiryLocal.year,
      expiryLocal.month,
      expiryLocal.day,
    );
    return expiryFloor.isBefore(todayFloor);
  }
}
