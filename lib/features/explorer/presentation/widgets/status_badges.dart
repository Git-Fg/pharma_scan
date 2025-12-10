import 'package:flutter/widgets.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/medication_status_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

List<Widget> buildStatusBadges(
  BuildContext context,
  Set<MedicationStatusFlag> flags, {
  String? availabilityStatus,
}) {
  final theme = context.shadTheme;
  final badges = <Widget>[];

  if (flags.contains(MedicationStatusFlag.revoked)) {
    badges.add(
      ShadBadge.destructive(
        child: Text(Strings.revokedStatusTitle, style: theme.textTheme.small),
      ),
    );
  }

  if (flags.contains(MedicationStatusFlag.notMarketed)) {
    badges.add(
      ShadBadge.secondary(
        child: Text(Strings.nonCommercialise, style: theme.textTheme.small),
      ),
    );
  }

  if (flags.contains(MedicationStatusFlag.shortage)) {
    final label = availabilityStatus?.trim();
    badges.add(
      ShadBadge.destructive(
        child: Text(
          Strings.stockAlert(label ?? Strings.unknown),
          style: theme.textTheme.small,
        ),
      ),
    );
  }

  if (flags.contains(MedicationStatusFlag.expired)) {
    badges.add(
      ShadBadge.destructive(
        child: Text(Strings.expiredProductTitle, style: theme.textTheme.small),
      ),
    );
  }

  return badges;
}
