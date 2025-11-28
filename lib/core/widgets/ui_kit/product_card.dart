// lib/core/widgets/ui_kit/product_card.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/theme/app_colors.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/widgets/ui_kit/info_label.dart';
import 'package:forui/forui.dart';

/// WHY: Universal ProductCard that handles all product display states.
/// Replaces MedicamentCard, InfoBubble variants, and StandaloneSearchResult.
/// "Trust the SQL" - displays Drift `MedicamentSummaryData` directly without transformation.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.summary,
    required this.cip,
    this.title,
    this.subtitle,
    this.badges = const [],
    this.groupLabel,
    this.onTap,
    this.onClose,
    this.onExplore,
    this.trailing,
    this.showActions = false,
    this.showDetails = true,
    this.compact = false,
    this.animation = false,
    this.price,
    this.refundRate,
    this.boxStatus,
    this.availabilityStatus,
    this.isHospitalOnly = false,
    this.exactMatchLabel,
  });

  final MedicamentSummaryData summary;
  final String cip;
  final String? title; // Override product.name if needed
  final List<String>? subtitle; // Additional info lines
  final List<Widget> badges; // Badges to display (type, condition, etc.)
  final String? groupLabel;
  final VoidCallback? onTap;
  final VoidCallback? onClose; // For scanner bubbles
  final VoidCallback? onExplore; // For scanner bubbles
  final Widget? trailing; // Trailing widget (chevron, etc.)
  final bool showActions; // Show close/explore buttons
  final bool showDetails; // Show detailed info (CIP, titulaire, etc.)
  final bool animation; // Apply enter animation
  final double? price;
  final String? refundRate;
  final String? boxStatus;
  final String? availabilityStatus;
  final bool isHospitalOnly;
  final String? exactMatchLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ?? getDisplayTitle(summary);
    final displaySubtitle = subtitle ?? _buildDefaultSubtitle();
    final availabilityAlert = _buildAvailabilityAlert(context);
    final statusIcons = _buildStatusIcons(context);
    final exactMatchBanner = _buildExactMatchBanner(context);
    final regulatoryBadges = _buildRegulatoryBadges(context);
    final computedBadges = [...badges];
    final shouldHighlightPrinceps =
        summary.groupId != null &&
        !summary.isPrinceps &&
        summary.princepsDeReference.isNotEmpty;
    final princepsReference = shouldHighlightPrinceps
        ? _buildPrincepsReference(context)
        : null;

    final card = FCard.raw(
      child: Padding(
        padding: EdgeInsets.all(
          compact ? AppDimens.spacingSm : AppDimens.spacingMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exactMatchBanner != null) ...[
              exactMatchBanner,
              Gap(compact ? AppDimens.spacing2xs : AppDimens.spacingSm),
            ],
            if (availabilityAlert != null) ...[
              availabilityAlert,
              Gap(compact ? AppDimens.spacing2xs : AppDimens.spacingSm),
            ],
            // Title row with badges and status icons
            Row(
              children: [
                if (computedBadges.isNotEmpty) ...[
                  ...computedBadges.map(
                    (badge) => Padding(
                      padding: const EdgeInsets.only(
                        right: AppDimens.spacingXs,
                      ),
                      child: badge,
                    ),
                  ),
                  const Gap(AppDimens.spacingXs),
                ],
                Expanded(
                  child: Text(
                    displayTitle,
                    style: context.theme.typography.xl2, // h4 equivalent
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                if (statusIcons is! SizedBox) ...[
                  const Gap(AppDimens.spacingXs),
                  statusIcons,
                ],
                if (trailing != null) ...[
                  const Gap(AppDimens.spacingXs),
                  trailing!,
                ],
              ],
            ),
            if (princepsReference != null) ...[
              Gap(compact ? AppDimens.spacing2xs : AppDimens.spacingXs),
              princepsReference,
            ],
            // Subtitle
            if (displaySubtitle.isNotEmpty) ...[
              Gap(compact ? AppDimens.spacing2xs : AppDimens.spacingXs),
              ...displaySubtitle.map(
                (line) => Padding(
                  padding: EdgeInsets.only(
                    bottom: compact
                        ? AppDimens.spacing2xs
                        : AppDimens.spacingXs / 2,
                  ),
                  child: Text(
                    line,
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            if (regulatoryBadges.isNotEmpty) ...[
              Gap(compact ? AppDimens.spacing2xs : AppDimens.spacingXs),
              Wrap(
                spacing: AppDimens.spacing2xs,
                runSpacing: AppDimens.spacing2xs / 2,
                children: regulatoryBadges,
              ),
            ],
            // Details section
            if (showDetails) ...[
              Gap(compact ? AppDimens.spacing2xs : AppDimens.spacingSm),
              ..._buildDetails(context),
            ],
            // Actions
            if (showActions) ...[
              Gap(compact ? AppDimens.spacing2xs : AppDimens.spacingMd),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );

    final wrappedCard = onTap != null
        ? Semantics(
            label: _buildSemanticsLabel(),
            hint: Strings.tapToViewDetails,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              child: card,
            ),
          )
        : card;

    return wrappedCard;
  }

  List<Widget> _buildDetails(BuildContext context) {
    final mutedStyle = context.theme.typography.sm.copyWith(
      color: context.theme.colors.mutedForeground,
    );
    final widgets = <Widget>[];

    if (summary.titulaire != null && summary.titulaire!.isNotEmpty) {
      widgets.add(
        InfoLabel(
          text: summary.titulaire!,
          icon: FIcons.building2,
          style: mutedStyle,
        ),
      );
      widgets.add(const Gap(AppDimens.spacingXs));
    }

    widgets.add(
      InfoLabel(
        text: '${Strings.cip} $cip',
        icon: FIcons.barcode,
        style: mutedStyle,
      ),
    );

    // WHY: Price and Refund Rate are removed from card face - they belong in detail sheets only
    // Financial details are "details", not "identity" - declutter the preview card

    if (summary.principesActifsCommuns.isNotEmpty) {
      widgets.add(const Gap(AppDimens.spacingXs));
      widgets.add(
        InfoLabel(
          text: summary.principesActifsCommuns.join(', '),
          icon: FIcons.flaskConical,
          style: mutedStyle,
        ),
      );
    }

    return widgets;
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
            child: FButton(
              style: FButtonStyle.outline(),
              onPress: onExplore,
              prefix: const Icon(FIcons.search, size: 16),
              child: const Text(Strings.exploreGroup),
            ),
          ),
        if (onExplore != null && onClose != null)
          const Gap(AppDimens.spacingXs),
        if (onClose != null)
          Semantics(
            button: true,
            label: Strings.closeCardLabel,
            hint: Strings.closeCardHint,
            child: FButton(
              style: FButtonStyle.ghost(),
              onPress: onClose,
              child: const Text(Strings.close),
            ),
          ),
      ],
    );
  }

  List<String> _buildDefaultSubtitle() {
    final lines = <String>[];
    final sanitizedPrinciples = summary.principesActifsCommuns
        .map(sanitizeActivePrinciple)
        .toList();
    final formattedDosage = summary.formattedDosage?.trim();

    if (formattedDosage != null && formattedDosage.isNotEmpty) {
      final form = summary.formePharmaceutique;
      if (form != null && form.isNotEmpty) {
        lines.add('$form • $formattedDosage');
      } else {
        lines.add(formattedDosage);
      }
    } else {
      final description = _buildDescriptionText(sanitizedPrinciples);
      if (description != null && description.isNotEmpty) {
        lines.add(description);
      }
    }

    return lines;
  }

  String? _buildDescriptionText(List<String> sanitizedPrinciples) {
    final form = summary.formePharmaceutique;
    final hasForm = form != null && form.isNotEmpty;
    final hasPrinciples = sanitizedPrinciples.isNotEmpty;

    if (hasForm && hasPrinciples) {
      return '$form - ${sanitizedPrinciples.join(' + ')}';
    }
    if (hasForm) return form;
    if (hasPrinciples) return sanitizedPrinciples.join(' + ');
    return null;
  }

  String _buildSemanticsLabel() {
    final buffer = StringBuffer(
      '${Strings.medication} ${summary.nomCanonique}',
    );
    buffer.write(', ${Strings.cip} $cip');
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
    return FAlert(
      style: context.theme.alertStyles.destructive.call,
      title: Text(
        Strings.stockAlert(availabilityStatus!.trim()),
        style: context.theme.typography.sm,
      ),
    );
  }

  // WHY: Build status icons with tooltips instead of text badges to save vertical space
  // Icons are more compact and provide the same information via tooltips
  Widget _buildStatusIcons(BuildContext context) {
    final primaryColor = context.theme.colors.primary;
    final destructiveColor = context.theme.colors.destructive;
    final icons = <Widget>[];

    Widget buildTooltip(String message, Icon icon) {
      return FTooltip(
        hover: true,
        longPress: true,
        tipBuilder: (context, controller) =>
            Text(message, style: context.theme.typography.sm),
        child: icon,
      );
    }

    // Hospital icon
    if (isHospitalOnly) {
      icons.add(
        buildTooltip(
          Strings.hospitalTooltip,
          Icon(FIcons.building2, size: 16, color: primaryColor),
        ),
      );
    }

    // Shortage/Tension icon
    if (availabilityStatus != null && availabilityStatus!.isNotEmpty) {
      icons.add(
        buildTooltip(
          availabilityStatus!,
          Icon(FIcons.triangleAlert, size: 16, color: destructiveColor),
        ),
      );
    }

    // Commercialisation stopped icon
    if (boxStatus != null && boxStatus!.isNotEmpty) {
      final normalized = _normalizeStatusValue(boxStatus!);
      final isStopped =
          normalized.contains('arret') || normalized.contains('abroge');
      if (isStopped) {
        icons.add(
          buildTooltip(
            Strings.stoppedTooltip,
            Icon(FIcons.ban, size: 16, color: destructiveColor),
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
    return value
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('�', 'e');
  }

  Widget _buildPrincepsReference(BuildContext context) {
    final mutedColor = context.theme.colors.muted;
    final princepsColor = context.theme.colors.secondaryForeground;
    final radiusSm = 8.0; // Standard small radius
    return Container(
      padding: EdgeInsets.all(
        compact ? AppDimens.spacingXs : AppDimens.spacingSm,
      ),
      decoration: BoxDecoration(
        color: mutedColor,
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(
            FIcons.arrowRightLeft,
            size: AppDimens.iconSm,
            color: princepsColor,
          ),
          const Gap(AppDimens.spacingXs),
          Expanded(
            child: Text(
              '${Strings.equivalentTo}${extractPrincepsLabel(summary.princepsDeReference)}',
              style:
                  (compact
                          ? context.theme.typography.sm
                          : context.theme.typography.base)
                      .copyWith(color: princepsColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildExactMatchBanner(BuildContext context) {
    if (exactMatchLabel == null || exactMatchLabel!.isEmpty) {
      return null;
    }
    final mutedColor = context.theme.colors.muted;
    final mutedForeground = context.theme.colors.mutedForeground;
    final radiusSm = 8.0; // Standard small radius
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingSm,
        vertical: AppDimens.spacingXs,
      ),
      decoration: BoxDecoration(
        color: mutedColor,
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(
            FIcons.scanBarcode,
            size: AppDimens.iconSm,
            color: mutedForeground,
          ),
          const Gap(AppDimens.spacingXs),
          Expanded(
            child: Text(
              exactMatchLabel!,
              style: context.theme.typography.sm.copyWith(
                color: mutedForeground,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRegulatoryBadges(BuildContext context) {
    final badges = <Widget>[];
    void addBadge(Widget badge) => badges.add(badge);

    if (summary.isNarcotic) {
      addBadge(
        FBadge(
          style: FBadgeStyle.destructive(),
          child: Text(
            Strings.badgeNarcotic,
            style: context.theme.typography.sm,
          ),
        ),
      );
    }

    if (summary.isList1) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.regulatoryRed),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeList1,
            style: context.theme.typography.sm.copyWith(
              color: AppColors.regulatoryRed,
            ),
          ),
        ),
      );
    }

    if (summary.isList2) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.regulatoryGreen),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeList2,
            style: context.theme.typography.sm.copyWith(
              color: AppColors.regulatoryGreen,
            ),
          ),
        ),
      );
    }

    if (summary.isException) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: AppColors.regulatoryPurple,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeException,
            style: context.theme.typography.sm.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (summary.isRestricted) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.regulatoryAmber),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeRestricted,
            style: context.theme.typography.sm.copyWith(
              color: AppColors.regulatoryAmber,
            ),
          ),
        ),
      );
    }

    if (summary.isHospitalOnly) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: AppColors.regulatoryGray,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.hospitalBadge,
            style: context.theme.typography.sm.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (summary.isDental) {
      final secondaryColor = context.theme.colors.secondary;
      final secondaryForeground = context.theme.colors.secondaryForeground;
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeDental,
            style: context.theme.typography.sm.copyWith(
              color: secondaryForeground,
            ),
          ),
        ),
      );
    }

    if (summary.isSurveillance) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: AppColors.regulatoryYellow,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeSurveillance,
            style: context.theme.typography.sm.copyWith(color: Colors.black),
          ),
        ),
      );
    }

    if (summary.isOtc) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: AppColors.regulatoryGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeOtc,
            style: context.theme.typography.sm.copyWith(
              color: AppColors.regulatoryGreen,
            ),
          ),
        ),
      );
    }

    return badges;
  }
}
