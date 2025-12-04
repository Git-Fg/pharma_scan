import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/regulatory_badges.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Card widget for scanner result bubbles.
///
/// Displays scan results with dismissal, animation, and action buttons.
/// Replaces the generic ProductCard for scanner-specific use cases.
class ScannerResultCard extends StatelessWidget {
  const ScannerResultCard({
    required this.summary,
    required this.cip,
    required this.badges,
    required this.subtitle,
    required this.onClose,
    this.onExplore,
    this.price,
    this.refundRate,
    this.boxStatus,
    this.availabilityStatus,
    this.isHospitalOnly = false,
    this.exactMatchLabel,
    super.key,
  });

  final MedicamentEntity summary;
  final Cip13 cip;
  final List<Widget> badges;
  final List<String> subtitle;
  final VoidCallback onClose;
  final VoidCallback? onExplore;
  final double? price;
  final String? refundRate;
  final String? boxStatus;
  final String? availabilityStatus;
  final bool isHospitalOnly;
  final String? exactMatchLabel;

  @override
  Widget build(BuildContext context) {
    final isGenericWithPrinceps =
        !summary.isPrinceps &&
        summary.groupId != null &&
        summary.princepsDeReference.isNotEmpty &&
        summary.princepsDeReference != 'Inconnu';

    final displayTitle = isGenericWithPrinceps
        ? extractPrincepsLabel(summary.princepsDeReference)
        : getDisplayTitle(summary);

    final availabilityAlert = _buildAvailabilityAlert(context);
    final statusIcons = _buildStatusIcons(context);
    final exactMatchBanner = _buildExactMatchBanner(context);
    final hasRegulatoryBadges =
        summary.isNarcotic ||
        summary.isList1 ||
        summary.isList2 ||
        summary.isException ||
        summary.isRestricted ||
        summary.isHospitalOnly ||
        summary.isDental ||
        summary.isSurveillance ||
        summary.isOtc;
    final regulatoryBadgesWidget = RegulatoryBadges(
      isNarcotic: summary.isNarcotic,
      isList1: summary.isList1,
      isList2: summary.isList2,
      isException: summary.isException,
      isRestricted: summary.isRestricted,
      isHospitalOnly: summary.isHospitalOnly,
      isDental: summary.isDental,
      isSurveillance: summary.isSurveillance,
      isOtc: summary.isOtc,
      compact: true,
    );

    final card = ShadCard(
      title: ProductCardHeader(
        displayTitle: displayTitle,
        badges: badges,
        statusIcons: statusIcons,
        isFocusPrinceps: isGenericWithPrinceps,
        compact: true,
      ),
      description: subtitle.isNotEmpty ? _buildDescription(context) : null,
      footer: _buildActions(context),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing2xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exactMatchBanner != null) ...[
              exactMatchBanner,
              const Gap(2),
            ],
            if (availabilityAlert != null) ...[
              availabilityAlert,
              const Gap(2),
            ],
            if (hasRegulatoryBadges) ...[
              const Gap(AppDimens.spacingXs),
              regulatoryBadgesWidget,
            ],
          ],
        ),
      ),
    );

    return Semantics(
      label: _buildSemanticsLabel(),
      hint: Strings.tapToViewDetails,
      child: card,
    );
  }

  Widget _buildDescription(BuildContext context) {
    final theme = context.shadTheme;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimens.spacing2xs,
        right: AppDimens.spacing2xs,
        top: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: subtitle
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  line,
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onExplore != null)
          Semantics(
            button: true,
            label: Strings.exploreGroupLabel,
            hint: Strings.exploreGroupHint,
            child: ShadButton.outline(
              onPressed: onExplore,
              leading: const Icon(LucideIcons.search, size: 12),
              child: Text(
                Strings.exploreGroup,
                style: context.shadTextTheme.small,
              ),
            ),
          ),
        if (onExplore != null) const Gap(4),
        Semantics(
          button: true,
          label: Strings.closeCardLabel,
          hint: Strings.closeCardHint,
          child: ShadButton.ghost(
            onPressed: onClose,
            child: Text(
              Strings.close,
              style: context.shadTextTheme.small,
            ),
          ),
        ),
      ],
    );
  }

  String _buildSemanticsLabel() {
    final buffer = StringBuffer(
      '${Strings.medication} ${summary.nomCanonique}',
    )..write(', ${Strings.cip} $cip');
    if (summary.titulaire != null && summary.titulaire!.isNotEmpty) {
      buffer.write(', ${Strings.holder} ${summary.titulaire}');
    }
    if (summary.principesActifsCommuns.isNotEmpty) {
      buffer.write(
        ', ${Strings.activePrinciples} ${summary.principesActifsCommuns.take(3).join(', ')}',
      );
    }
    if (summary.conditionsPrescription != null &&
        summary.conditionsPrescription!.isNotEmpty) {
      buffer.write(', ${Strings.condition} ${summary.conditionsPrescription}');
    }
    return buffer.toString();
  }

  Widget? _buildAvailabilityAlert(BuildContext context) {
    if (availabilityStatus == null || availabilityStatus!.isEmpty) {
      return null;
    }
    final theme = context.shadTheme;
    return ShadAlert.destructive(
      title: Text(
        Strings.stockAlert(availabilityStatus!.trim()),
        style: theme.textTheme.small,
      ),
    );
  }

  Widget _buildStatusIcons(BuildContext context) {
    final theme = context.shadTheme;
    final primaryColor = theme.colorScheme.primary;
    final destructiveColor = theme.colorScheme.destructive;
    final icons = <Widget>[];

    Widget buildTooltip(String message, Icon icon) {
      return ShadTooltip(
        builder: (BuildContext tooltipContext) =>
            Text(message, style: theme.textTheme.small),
        child: icon,
      );
    }

    if (isHospitalOnly) {
      icons.add(
        buildTooltip(
          Strings.hospitalTooltip,
          Icon(LucideIcons.building2, size: 16, color: primaryColor),
        ),
      );
    }

    if (availabilityStatus != null && availabilityStatus!.isNotEmpty) {
      icons.add(
        buildTooltip(
          availabilityStatus!,
          Icon(LucideIcons.triangleAlert, size: 16, color: destructiveColor),
        ),
      );
    }

    if (boxStatus != null && boxStatus!.isNotEmpty) {
      final normalized = _normalizeStatusValue(boxStatus!);
      final isStopped =
          normalized.contains('arret') || normalized.contains('abroge');
      if (isStopped) {
        icons.add(
          buildTooltip(
            Strings.stoppedTooltip,
            Icon(LucideIcons.ban, size: 16, color: destructiveColor),
          ),
        );
      }
    }

    if (icons.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: icons
          .map(
            (icon) => Padding(
              padding: const EdgeInsets.only(right: AppDimens.spacingXs),
              child: icon,
            ),
          )
          .toList(),
    );
  }

  String _normalizeStatusValue(String value) {
    return removeDiacritics(value).toLowerCase();
  }

  Widget? _buildExactMatchBanner(BuildContext context) {
    if (exactMatchLabel == null || exactMatchLabel!.isEmpty) {
      return null;
    }
    final theme = context.shadTheme;
    final mutedColor = theme.colorScheme.muted;
    final mutedForeground = theme.colorScheme.mutedForeground;
    final smallRadius = theme.radius.topLeft.x;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: mutedColor,
        borderRadius: BorderRadius.circular(smallRadius),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.scanBarcode,
            size: AppDimens.iconXs,
            color: mutedForeground,
          ),
          const Gap(4),
          Expanded(
            child: Text(
              exactMatchLabel!,
              style: theme.textTheme.small.copyWith(color: mutedForeground),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
