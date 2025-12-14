import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/core/domain/types/commercialization_status.dart';

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

    // Use the Extension Type for parsing commercialization status
    final status = CommercializationStatus.fromDatabase(
        commercializationStatus ?? dbData.status);

    // Set flags based on the parsed status
    if (status.isRevoked) {
      flags.add(MedicationStatusFlag.revoked);
    }
    if (status.isNotMarketed) {
      flags.add(MedicationStatusFlag.notMarketed);
    }

    // Check for shortage (availability status is not null and not empty)
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
  Set<MedicationStatusFlag> statusFlags(
      {String? commercializationStatus, String? availabilityStatus}) {
    final flags = <MedicationStatusFlag>{};

    // Use the Extension Type for parsing commercialization status
    final status =
        CommercializationStatus.fromDatabase(commercializationStatus);

    // Set flags based on the parsed status
    if (status.isRevoked) {
      flags.add(MedicationStatusFlag.revoked);
    }
    if (status.isNotMarketed) {
      flags.add(MedicationStatusFlag.notMarketed);
    }

    // Check for shortage (availability status is not null and not empty)
    if (availabilityStatus != null && availabilityStatus.trim().isNotEmpty) {
      flags.add(MedicationStatusFlag.shortage);
    }

    return flags;
  }
}
