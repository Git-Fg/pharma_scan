import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:dart_mappable/dart_mappable.dart';

enum MedicationStatusFlag { revoked, notMarketed, shortage, expired }

@MappableEnum()
extension MedicamentStatusFlags on MedicamentEntity {
  Set<MedicationStatusFlag> statusFlags({
    String? commercializationStatus,
    String? availabilityStatus,
    bool isExpired = false,
    DateTime? expDate,
  }) {
    final flags = <MedicationStatusFlag>{};
    final normalizedStatus =
        (commercializationStatus ?? data.status)?.toLowerCase().trim();

    if (isRevoked || (normalizedStatus?.contains('abrog') ?? false)) {
      flags.add(MedicationStatusFlag.revoked);
    }
    if (isNotMarketed ||
        (normalizedStatus?.contains('non commercialis') ?? false)) {
      flags.add(MedicationStatusFlag.notMarketed);
    }
    if (availabilityStatus != null && availabilityStatus.trim().isNotEmpty) {
      flags.add(MedicationStatusFlag.shortage);
    }

    final expired =
        isExpired || (expDate != null && expDate.isBefore(DateTime.now()));
    if (expired) {
      flags.add(MedicationStatusFlag.expired);
    }

    return flags;
  }
}

extension GroupDetailStatusFlags on GroupDetailEntity {
  Set<MedicationStatusFlag> statusFlags({String? availabilityStatus}) {
    final flags = <MedicationStatusFlag>{};
    final normalizedStatus = status?.toLowerCase().trim();

    if (isRevoked || (normalizedStatus?.contains('abrog') ?? false)) {
      flags.add(MedicationStatusFlag.revoked);
    }
    if (isNotMarketed ||
        (normalizedStatus?.contains('non commercialis') ?? false)) {
      flags.add(MedicationStatusFlag.notMarketed);
    }
    if (availabilityStatus != null && availabilityStatus.trim().isNotEmpty) {
      flags.add(MedicationStatusFlag.shortage);
    }

    return flags;
  }
}
