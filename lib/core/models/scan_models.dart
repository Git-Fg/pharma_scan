import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/domain/entities/medicament_entity.dart';

typedef ScanResult = ({
  MedicamentEntity summary,
  Cip13 cip,
  double? price,
  String? refundRate,
  String? boxStatus,
  String? availabilityStatus,
  bool isHospitalOnly,
  String? libellePresentation,
  DateTime? expDate,
});

extension ScanResultX on ScanResult {
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
