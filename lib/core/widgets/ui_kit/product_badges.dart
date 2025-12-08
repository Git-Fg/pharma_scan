import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Badge showing princeps/generic membership type.
class ProductTypeBadge extends StatelessWidget {
  const ProductTypeBadge({
    required this.memberType,
    this.compact = false,
    super.key,
  });

  /// Raw BDPM member type
  /// 0 = princeps, 1 = standard generic, 2 = complementary,
  /// 3 = substitutable (legacy type), 4 = substitutable.
  final int memberType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final warningScheme = theme.brightness == Brightness.dark
        ? const ShadOrangeColorScheme.dark()
        : const ShadOrangeColorScheme.light();
    final (badge, tooltip) = switch (memberType) {
      0 => (
        ShadBadge.secondary(
          child: Text(
            compact
                ? Strings.badgePrinceps.substring(0, 1)
                : Strings.badgePrinceps,
            style: theme.textTheme.small,
          ),
        ),
        Strings.badgePrincepsTooltip,
      ),
      2 => (
        ShadBadge(
          backgroundColor: warningScheme.primary,
          hoverBackgroundColor: warningScheme.ring,
          foregroundColor: warningScheme.primaryForeground,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact)
                Icon(
                  LucideIcons.triangleAlert,
                  size: 12,
                  color: warningScheme.primaryForeground,
                ),
              if (!compact) const SizedBox(width: 4),
              Text(
                compact ? 'G!' : Strings.badgeGenericComplementary,
                style: theme.textTheme.small.copyWith(
                  color: warningScheme.primaryForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Strings.badgeGenericComplementaryTooltip,
      ),
      1 || 3 || 4 => (
        ShadBadge.outline(
          child: Text(
            compact
                ? 'G'
                : memberType == 1
                ? Strings.badgeGeneric
                : Strings.badgeGenericSubstitutable,
            style: theme.textTheme.small,
          ),
        ),
        memberType == 1
            ? Strings.badgeGenericTooltip
            : Strings.badgeGenericSubstitutableTooltip,
      ),
      _ => (
        ShadBadge.outline(
          child: Text(
            compact
                ? Strings.genericTypeUnknown.substring(0, 1)
                : Strings.genericTypeUnknown,
            style: theme.textTheme.small,
          ),
        ),
        Strings.genericTypeUnknown,
      ),
    };

    return ShadTooltip(
      builder: (BuildContext tooltipContext) => Text(
        tooltip,
        style: theme.textTheme.small,
      ),
      child: badge,
    );
  }
}

/// Displays reimbursement rate and public price in a compact row.
class FinancialBadge extends StatelessWidget {
  const FinancialBadge({
    this.refundRate,
    this.price,
    super.key,
  });

  final String? refundRate;
  final double? price;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final items = <Widget>[];

    final normalizedRefund = refundRate?.trim();
    final hasRefund =
        normalizedRefund != null &&
        normalizedRefund.isNotEmpty &&
        normalizedRefund.toLowerCase() != 'nr';
    if (hasRefund) {
      items.add(_buildRefundBadge(theme, normalizedRefund));
    }

    final priceValue = price;
    if (priceValue != null) {
      items.add(
        Text(
          formatEuro(priceValue),
          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    final spaced = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        spaced.add(const Gap(6));
      }
      spaced.add(items[i]);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: spaced,
    );
  }

  Widget _buildRefundBadge(ShadThemeData theme, String rate) {
    final percent = _parsePercent(rate);
    final badgeChild = Text(rate, style: theme.textTheme.small);

    if (percent != null) {
      if (percent >= 100) {
        return ShadBadge(child: badgeChild);
      }
      if (percent >= 65) {
        return ShadBadge.secondary(child: badgeChild);
      }
      if (percent >= 30) {
        return ShadBadge.outline(child: badgeChild);
      }
    }

    return ShadBadge.outline(child: badgeChild);
  }

  double? _parsePercent(String value) {
    final cleaned = value.replaceAll('%', '').trim();
    return double.tryParse(cleaned);
  }
}

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
