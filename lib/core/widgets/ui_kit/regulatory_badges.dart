import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Reusable widget for displaying regulatory badges (Narcotic, List 1/2, Hospital, etc.).
///
/// Centralizes badge generation logic to eliminate duplication between ProductCard
/// and GroupExplorerView. Uses Shadcn badge variants for consistent styling.
class RegulatoryBadges extends StatelessWidget {
  const RegulatoryBadges({
    required this.isNarcotic,
    required this.isList1,
    required this.isList2,
    required this.isException,
    required this.isRestricted,
    required this.isHospitalOnly,
    required this.isDental,
    required this.isSurveillance,
    required this.isOtc,
    this.compact = false,
    super.key,
  });

  final bool isNarcotic;
  final bool isList1;
  final bool isList2;
  final bool isException;
  final bool isRestricted;
  final bool isHospitalOnly;
  final bool isDental;
  final bool isSurveillance;
  final bool isOtc;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final badges = <Widget>[];

    // DANGER / STRICT -> Destructive (Red)
    if (isNarcotic) {
      badges.add(
        ShadBadge.destructive(
          child: Text(
            Strings.badgeNarcotic,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    // LIST 1 (Toxic) -> Destructive (Red)
    if (isList1) {
      badges.add(
        ShadBadge.destructive(
          child: Text(
            Strings.badgeList1,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    // LIST 2 (Less Toxic) -> Outline (Informational, not critical)
    if (isList2) {
      badges.add(
        ShadBadge.outline(
          child: Text(
            Strings.badgeList2,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    // EXCEPTIONS -> Secondary (Distinct but not alarming)
    if (isException) {
      badges.add(
        ShadBadge.secondary(
          child: Text(
            Strings.badgeException,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    // RESTRICTED -> Outline (Information)
    if (isRestricted) {
      badges.add(
        ShadBadge.outline(
          child: Text(
            Strings.badgeRestricted,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    // HOSPITAL -> Outline (Information)
    if (isHospitalOnly) {
      badges.add(
        ShadBadge.outline(
          child: Text(
            Strings.hospitalBadge,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    // DENTAL -> Secondary (Distinct category)
    if (isDental) {
      badges.add(
        ShadBadge.secondary(
          child: Text(
            Strings.badgeDental,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    // SURVEILLANCE -> Outline (Information)
    if (isSurveillance) {
      badges.add(
        ShadBadge.outline(
          child: Text(
            Strings.badgeSurveillance,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    // OTC -> Secondary (Safe/Light)
    if (isOtc) {
      badges.add(
        ShadBadge.secondary(
          child: Text(
            Strings.badgeOtc,
            style: theme.textTheme.small,
          ),
        ),
      );
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: compact ? 2.0 : AppDimens.spacing2xs,
      runSpacing: compact ? 1.0 : AppDimens.spacing2xs / 2,
      children: badges,
    );
  }
}
