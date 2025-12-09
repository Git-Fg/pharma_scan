import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MedicationUiMapper {
  MedicationUiMapper._();

  static List<Widget> buildStatusBadges({
    required BuildContext context,
    required MedicamentEntity medicament,
    String? boxStatus,
    String? availabilityStatus,
    bool isExpired = false,
    DateTime? expDate,
  }) {
    final theme = context.shadTheme;
    final commercializationStatus = boxStatus ?? medicament.data.status;
    final normalizedCommercialization = commercializationStatus
        ?.toLowerCase()
        .trim();
    final isRevoked =
        medicament.isRevoked ||
        (normalizedCommercialization?.contains('abrog') ?? false);
    final isNotMarketed =
        medicament.isNotMarketed ||
        (normalizedCommercialization?.contains('non commercialis') ?? false);
    final isShortage =
        availabilityStatus != null && availabilityStatus.trim().isNotEmpty;
    final hasExpired =
        isExpired || (expDate != null && expDate.isBefore(DateTime.now()));

    final badges = <Widget>[];

    if (isRevoked) {
      badges.add(
        ShadBadge.destructive(
          child: Text(
            Strings.revokedStatusTitle,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    if (isNotMarketed) {
      badges.add(
        ShadBadge.secondary(
          child: Text(
            Strings.nonCommercialise,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    if (isShortage) {
      badges.add(
        ShadBadge.destructive(
          child: Text(
            Strings.stockAlert(availabilityStatus.trim()),
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    if (hasExpired) {
      badges.add(
        ShadBadge.destructive(
          child: Text(
            Strings.expiredProductTitle,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    return badges;
  }

  static List<Widget> buildStatusBadgesForGroup({
    required BuildContext context,
    required GroupDetailEntity medicament,
    String? availabilityStatus,
  }) {
    final theme = context.shadTheme;
    final normalizedCommercialization = medicament.status?.toLowerCase().trim();
    final isRevoked =
        medicament.isRevoked ||
        (normalizedCommercialization?.contains('abrog') ?? false);
    final isNotMarketed =
        medicament.isNotMarketed ||
        (normalizedCommercialization?.contains('non commercialis') ?? false);
    final isShortage =
        availabilityStatus != null && availabilityStatus.trim().isNotEmpty;

    final badges = <Widget>[];

    if (isRevoked) {
      badges.add(
        ShadBadge.destructive(
          child: Text(
            Strings.revokedStatusTitle,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    if (isNotMarketed) {
      badges.add(
        ShadBadge.secondary(
          child: Text(
            Strings.nonCommercialise,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    if (isShortage) {
      badges.add(
        ShadBadge.destructive(
          child: Text(
            Strings.stockAlert(availabilityStatus.trim()),
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    return badges;
  }

  static Color getStatusColor(
    BuildContext context,
    MedicamentEntity medicament, {
    String? availabilityStatus,
  }) {
    final colors = context.shadColors;
    if (medicament.isRevoked) return colors.destructive;
    if (availabilityStatus != null && availabilityStatus.isNotEmpty) {
      return colors.destructive;
    }
    if (medicament.isNotMarketed) return colors.mutedForeground;
    return colors.muted;
  }
}
