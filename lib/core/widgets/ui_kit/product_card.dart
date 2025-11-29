// lib/core/widgets/ui_kit/product_card.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/info_label.dart';
import 'package:pharma_scan/theme/pharma_colors.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// WHY: Universal ProductCard that handles all product display states.
/// Replaces MedicamentCard, InfoBubble variants, and StandaloneSearchResult.
/// "Trust the SQL" - displays Drift `MedicamentSummaryData` directly without transformation.
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.summary, required this.cip, super.key,
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
    final theme = ShadTheme.of(context);
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

    final card = ShadCard(
      child: Padding(
        padding: EdgeInsets.all(
          compact
              ? AppDimens.spacing2xs
              : AppDimens.spacingMd, // Reduced from spacingSm to spacing2xs
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exactMatchBanner != null) ...[
              exactMatchBanner,
              Gap(
                compact ? 2.0 : AppDimens.spacingSm,
              ), // Reduced from spacing2xs to 2.0
            ],
            if (availabilityAlert != null) ...[
              availabilityAlert,
              Gap(
                compact ? 2.0 : AppDimens.spacingSm,
              ), // Reduced from spacing2xs to 2.0
            ],
            // Title row with badges and status icons
            Row(
              children: [
                if (computedBadges.isNotEmpty) ...[
                  ...computedBadges.map(
                    (badge) => Padding(
                      padding: EdgeInsets.only(
                        right: compact
                            ? 4.0
                            : AppDimens
                                  .spacingXs, // Reduced from spacingXs to 4.0
                      ),
                      child: badge,
                    ),
                  ),
                  Gap(
                    compact ? 4.0 : AppDimens.spacingXs,
                  ), // Reduced from spacingXs to 4.0
                ],
                Expanded(
                  child: Text(
                    displayTitle,
                    style: compact ? theme.textTheme.p : theme.textTheme.h4,
                    overflow: TextOverflow.ellipsis,
                    maxLines: compact ? 1 : 2,
                  ),
                ),
                if (statusIcons is! SizedBox) ...[
                  Gap(
                    compact ? 4.0 : AppDimens.spacingXs,
                  ), // Reduced from spacingXs to 4.0
                  statusIcons,
                ],
                if (trailing != null) ...[
                  Gap(
                    compact ? 4.0 : AppDimens.spacingXs,
                  ), // Reduced from spacingXs to 4.0
                  trailing!,
                ],
              ],
            ),
            // Equivalence - highlighted and prominent (most important information)
            if (princepsReference != null) ...[
              Gap(
                compact ? 4.0 : AppDimens.spacingSm,
              ), // More space to make it stand out
              princepsReference,
            ],
            // Subtitle
            if (displaySubtitle.isNotEmpty) ...[
              Gap(
                compact ? 2.0 : AppDimens.spacingXs,
              ), // Reduced from spacing2xs to 2.0
              ...displaySubtitle.map(
                (line) => Padding(
                  padding: EdgeInsets.only(
                    bottom: compact
                        ? 2.0
                        : AppDimens.spacingXs /
                              2, // Reduced from spacing2xs to 2.0
                  ),
                  child: Text(
                    line,
                    style:
                        (compact
                                ? theme.textTheme.small
                                : theme.textTheme.small)
                            .copyWith(color: theme.colorScheme.mutedForeground),
                    overflow: TextOverflow.ellipsis,
                    maxLines: compact
                        ? 1
                        : null, // Single line for compact mode
                  ),
                ),
              ),
            ],
            if (regulatoryBadges.isNotEmpty) ...[
              Gap(
                compact ? 2.0 : AppDimens.spacingXs,
              ), // Reduced from spacing2xs to 2.0
              Wrap(
                spacing: compact
                    ? 2.0
                    : AppDimens.spacing2xs, // Reduced spacing
                runSpacing: compact
                    ? 1.0
                    : AppDimens.spacing2xs / 2, // Reduced runSpacing
                children: regulatoryBadges,
              ),
            ],
            // Details section
            if (showDetails) ...[
              Gap(
                compact ? 2.0 : AppDimens.spacingSm,
              ), // Reduced from spacing2xs to 2.0
              ..._buildDetails(context),
            ],
            // Actions
            if (showActions) ...[
              Gap(
                compact ? 2.0 : AppDimens.spacingMd,
              ), // Reduced from spacing2xs to 2.0
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
    final theme = ShadTheme.of(context);
    final mutedStyle = (compact ? theme.textTheme.small : theme.textTheme.small)
        .copyWith(color: theme.colorScheme.mutedForeground);
    final widgets = <Widget>[];

    if (summary.titulaire != null && summary.titulaire!.isNotEmpty) {
      widgets.add(
        InfoLabel(
          text: summary.titulaire!,
          icon: LucideIcons.building2,
          style: mutedStyle,
        ),
      );
      widgets.add(Gap(compact ? 2.0 : AppDimens.spacingXs)); // Reduced gap
    }

    widgets.add(
      InfoLabel(
        text: '${Strings.cip} $cip',
        icon: LucideIcons.barcode,
        style: mutedStyle,
      ),
    );

    // WHY: Price and Refund Rate are removed from card face - they belong in detail sheets only
    // Financial details are "details", not "identity" - declutter the preview card

    if (summary.principesActifsCommuns.isNotEmpty) {
      widgets.add(Gap(compact ? 2.0 : AppDimens.spacingXs)); // Reduced gap
      widgets.add(
        InfoLabel(
          text: summary.principesActifsCommuns.join(', '),
          icon: LucideIcons.flaskConical,
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
            child: ShadButton.outline(
              onPressed: onExplore,
              leading: Icon(
                LucideIcons.search,
                size: compact ? 12 : 16,
              ), // Reduced icon size
              child: Text(
                Strings.exploreGroup,
                style: compact
                    ? ShadTheme.of(context).textTheme.small
                    : null, // Smaller text for compact
              ),
            ),
          ),
        if (onExplore != null && onClose != null)
          Gap(compact ? 4.0 : AppDimens.spacingXs), // Reduced gap
        if (onClose != null)
          Semantics(
            button: true,
            label: Strings.closeCardLabel,
            hint: Strings.closeCardHint,
            child: ShadButton.ghost(
              onPressed: onClose,
              child: Text(
                Strings.close,
                style: compact
                    ? ShadTheme.of(context).textTheme.small
                    : null, // Smaller text for compact
              ),
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
    final theme = ShadTheme.of(context);
    return ShadAlert.destructive(
      title: Text(
        Strings.stockAlert(availabilityStatus!.trim()),
        style: compact ? theme.textTheme.small : theme.textTheme.small,
      ),
    );
  }

  // WHY: Build status icons with tooltips instead of text badges to save vertical space
  // Icons are more compact and provide the same information via tooltips
  Widget _buildStatusIcons(BuildContext context) {
    final theme = ShadTheme.of(context);
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

    // Hospital icon
    if (isHospitalOnly) {
      icons.add(
        buildTooltip(
          Strings.hospitalTooltip,
          Icon(LucideIcons.building2, size: 16, color: primaryColor),
        ),
      );
    }

    // Shortage/Tension icon
    if (availabilityStatus != null && availabilityStatus!.isNotEmpty) {
      icons.add(
        buildTooltip(
          availabilityStatus!,
          Icon(LucideIcons.triangleAlert, size: 16, color: destructiveColor),
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
    final theme = ShadTheme.of(context);
    final equivalentColor = theme.colorScheme.destructive;
    final equivalentText = extractPrincepsLabel(summary.princepsDeReference);

    return Row(
      children: [
        Icon(
          LucideIcons.arrowRightLeft,
          size: compact ? AppDimens.iconXs : AppDimens.iconSm,
          color: equivalentColor,
        ),
        Gap(compact ? 4.0 : AppDimens.spacingXs),
        Expanded(
          child: RichText(
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            text: TextSpan(
              style: (compact ? theme.textTheme.small : theme.textTheme.p)
                  .copyWith(color: theme.colorScheme.foreground),
              children: [
                const TextSpan(text: Strings.equivalentTo),
                TextSpan(
                  text: equivalentText,
                  style: TextStyle(
                    color: equivalentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildExactMatchBanner(BuildContext context) {
    if (exactMatchLabel == null || exactMatchLabel!.isEmpty) {
      return null;
    }
    final theme = ShadTheme.of(context);
    final mutedColor = theme.colorScheme.muted;
    final mutedForeground = theme.colorScheme.mutedForeground;
    const radiusSm = 8.0; // Standard small radius
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.0 : AppDimens.spacingSm, // Reduced padding
        vertical: compact ? 2.0 : AppDimens.spacingXs, // Reduced padding
      ),
      decoration: BoxDecoration(
        color: mutedColor,
        borderRadius: BorderRadius.circular(radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.scanBarcode,
            size: compact
                ? AppDimens.iconXs
                : AppDimens.iconSm, // Reduced icon size
            color: mutedForeground,
          ),
          Gap(compact ? 4.0 : AppDimens.spacingXs), // Reduced gap
          Expanded(
            child: Text(
              exactMatchLabel!,
              style: (compact ? theme.textTheme.small : theme.textTheme.small)
                  .copyWith(color: mutedForeground),
              overflow: TextOverflow.ellipsis,
              maxLines: compact ? 1 : 2, // Single line for compact
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRegulatoryBadges(BuildContext context) {
    // WHY: PharmaColors is always registered in theme extensions (see lib/theme/theme.dart)
    // Flow analysis confirms this is non-null, so we can safely assert
    final pharmaColors = Theme.of(context).extension<PharmaColors>()!;
    final badges = <Widget>[];
    void addBadge(Widget badge) => badges.add(badge);

    if (summary.isNarcotic) {
      addBadge(
        ShadBadge.destructive(
          child: Text(
            Strings.badgeNarcotic,
            style: ShadTheme.of(context).textTheme.small,
          ),
        ),
      );
    }

    if (summary.isList1) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: pharmaColors.regulatoryRed),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeList1,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: pharmaColors.regulatoryRed),
          ),
        ),
      );
    }

    if (summary.isList2) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: pharmaColors.regulatoryGreen),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeList2,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: pharmaColors.regulatoryGreen),
          ),
        ),
      );
    }

    if (summary.isException) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: pharmaColors.regulatoryPurple,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeException,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (summary.isRestricted) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: pharmaColors.regulatoryAmber),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeRestricted,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: pharmaColors.regulatoryAmber),
          ),
        ),
      );
    }

    if (summary.isHospitalOnly) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: pharmaColors.regulatoryGray,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.hospitalBadge,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (summary.isDental) {
      final theme = ShadTheme.of(context);
      final secondaryColor = theme.colorScheme.secondary;
      final secondaryForeground = theme.colorScheme.secondaryForeground;
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeDental,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: secondaryForeground),
          ),
        ),
      );
    }

    if (summary.isSurveillance) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: pharmaColors.regulatoryYellow,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeSurveillance,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: Colors.black),
          ),
        ),
      );
    }

    if (summary.isOtc) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: pharmaColors.regulatoryGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeOtc,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: pharmaColors.regulatoryGreen),
          ),
        ),
      );
    }

    return badges;
  }
}
