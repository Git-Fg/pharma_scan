import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';

typedef ScanMetadata = ({
  double? price,
  String? refundRate,
  String? boxStatus,
  String? availabilityStatus,
  bool isHospitalOnly,
  String? libellePresentation,
  DateTime? expDate,
});

const ScanMetadata _emptyScanMetadata = (
  price: null,
  refundRate: null,
  boxStatus: null,
  availabilityStatus: null,
  isHospitalOnly: false,
  libellePresentation: null,
  expDate: null,
);

/// WHY: Dedicated data structure for scanner results.
/// Removed @MappableClass to avoid issues with Extension Type serialization.
class ScanResult {
  const ScanResult({
    required this.summary,
    required this.cip,
    this.metadata = _emptyScanMetadata,
  });

  final MedicamentEntity summary;
  final Cip13 cip;
  final ScanMetadata metadata;

  double? get price => metadata.price;
  String? get refundRate => metadata.refundRate;
  String? get boxStatus => metadata.boxStatus;
  String? get availabilityStatus => metadata.availabilityStatus;
  bool get isHospitalOnly => metadata.isHospitalOnly;
  String? get libellePresentation => metadata.libellePresentation;
  DateTime? get expDate => metadata.expDate;

  /// Returns true when the expiration date is strictly before today 00:00.
  bool get isExpired {
    if (metadata.expDate == null) return false;
    final today = DateTime.now();
    final todayFloor = DateTime(today.year, today.month, today.day);
    final expiryLocal = metadata.expDate!.toLocal();
    final expiryFloor = DateTime(
      expiryLocal.year,
      expiryLocal.month,
      expiryLocal.day,
    );
    return expiryFloor.isBefore(todayFloor);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScanResult &&
        other.summary == summary &&
        other.cip == cip &&
        other.metadata == metadata;
  }

  @override
  int get hashCode => Object.hash(summary, cip, metadata);
}
