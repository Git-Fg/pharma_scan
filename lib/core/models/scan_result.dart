import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';

part 'scan_result.mapper.dart';

@MappableRecord()
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

/// WHY: Dedicated data structure for scanner results enables us to
/// transport CIP-level metadata (price, refund) alongside the summary.
@MappableClass()
class ScanResult with ScanResultMappable {
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
}
