import 'package:flutter/widgets.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/medication_status_extensions.dart';
import 'package:pharma_scan/core/ui/atoms/app_badge.dart';

List<Widget> buildStatusBadges(
  BuildContext context,
  Set<MedicationStatusFlag> flags, {
  String? availabilityStatus,
}) {
  final theme = context.shadTheme;
  final badges = <Widget>[];

  if (flags.contains(MedicationStatusFlag.revoked)) {
    badges.add(
      AppBadge(
        label: Strings.revokedStatusTitle,
        variant: BadgeVariant.destructive,
      ),
    );
  }

  if (flags.contains(MedicationStatusFlag.notMarketed)) {
    badges.add(
      AppBadge(
        label: Strings.nonCommercialise,
        variant: BadgeVariant.secondary,
      ),
    );
  }

  if (flags.contains(MedicationStatusFlag.shortage)) {
    final label = availabilityStatus?.trim();
    badges.add(
      AppBadge(
        label: Strings.stockAlert(label ?? Strings.unknown),
        variant: BadgeVariant.destructive,
      ),
    );
  }

  if (flags.contains(MedicationStatusFlag.expired)) {
    badges.add(
      AppBadge(
        label: Strings.expiredProductTitle,
        variant: BadgeVariant.destructive,
      ),
    );
  }

  return badges;
}
