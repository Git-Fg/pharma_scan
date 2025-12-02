import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/info_label.dart';
import 'package:pharma_scan/core/widgets/ui_kit/regulatory_badges.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.summary,
    required this.cip,
    super.key,
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
      compact: compact,
    );
    final computedBadges = [...badges];
    final shouldHighlightPrinceps =
        summary.groupId != null &&
        !summary.isPrinceps &&
        summary.princepsDeReference.isNotEmpty;
    final princepsReference = shouldHighlightPrinceps
        ? _buildPrincepsReference(context)
        : null;

    final cardPadding = compact ? AppDimens.spacing2xs : AppDimens.spacingMd;

    final card = ShadCard(
      title: _buildTitleRow(context, displayTitle, computedBadges, statusIcons),
      description: displaySubtitle.isNotEmpty
          ? _buildDescription(context, displaySubtitle)
          : null,
      footer: showActions ? _buildActions(context) : null,
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exactMatchBanner != null) ...[
              exactMatchBanner,
              Gap(compact ? 2.0 : AppDimens.spacingSm),
            ],
            if (availabilityAlert != null) ...[
              availabilityAlert,
              Gap(compact ? 2.0 : AppDimens.spacingSm),
            ],
            if (princepsReference != null) ...[
              Gap(compact ? 4.0 : AppDimens.spacingSm),
              princepsReference,
            ],
            if (hasRegulatoryBadges) ...[
              Gap(compact ? 2.0 : AppDimens.spacingXs),
              regulatoryBadgesWidget,
            ],
            if (showDetails) ...[
              Gap(compact ? 2.0 : AppDimens.spacingSm),
              ..._buildDetails(context),
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
              borderRadius: ShadTheme.of(context).radius,
              child: card,
            ),
          )
        : card;

    return wrappedCard;
  }

  Widget _buildTitleRow(
    BuildContext context,
    String displayTitle,
    List<Widget> computedBadges,
    Widget statusIcons,
  ) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: EdgeInsets.all(
        compact ? AppDimens.spacing2xs : AppDimens.spacingMd,
      ),
      child: Row(
        children: [
          if (computedBadges.isNotEmpty) ...[
            ...computedBadges.map(
              (badge) => Padding(
                padding: EdgeInsets.only(
                  right: compact ? 4.0 : AppDimens.spacingXs,
                ),
                child: badge,
              ),
            ),
            Gap(compact ? 4.0 : AppDimens.spacingXs),
          ],
          Expanded(
            child: Text(
              displayTitle,
              style: compact
                  ? theme.textTheme.p.copyWith(fontWeight: FontWeight.w600)
                  : theme.textTheme.h4,
              overflow: TextOverflow.ellipsis,
              maxLines: compact ? 1 : 2,
            ),
          ),
          if (statusIcons is! SizedBox) ...[
            Gap(compact ? 4.0 : AppDimens.spacingXs),
            statusIcons,
          ],
          if (trailing != null) ...[
            Gap(compact ? 4.0 : AppDimens.spacingXs),
            trailing!,
          ],
        ],
      ),
    );
  }

  Widget _buildDescription(BuildContext context, List<String> displaySubtitle) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: compact ? AppDimens.spacing2xs : AppDimens.spacingMd,
        right: compact ? AppDimens.spacing2xs : AppDimens.spacingMd,
        top: compact ? 2.0 : AppDimens.spacingXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: displaySubtitle
            .map(
              (line) => Padding(
                padding: EdgeInsets.only(
                  bottom: compact ? 2.0 : AppDimens.spacingXs / 2,
                ),
                child: Text(
                  line,
                  style: theme.textTheme.muted.copyWith(
                    fontSize: compact ? 12 : 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: compact ? 1 : null,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  List<Widget> _buildDetails(BuildContext context) {
    final theme = ShadTheme.of(context);
    final mutedStyle = theme.textTheme.muted.copyWith(
      fontSize: compact ? 12 : 14,
    );
    final widgets = <Widget>[];

    if (summary.titulaire != null && summary.titulaire!.isNotEmpty) {
      widgets
        ..add(
          InfoLabel(
            text: summary.titulaire!,
            icon: LucideIcons.building2,
            style: mutedStyle,
          ),
        )
        ..add(Gap(compact ? 2.0 : AppDimens.spacingXs)); // Reduced gap
    }

    widgets.add(
      InfoLabel(
        text: '${Strings.cip} $cip',
        icon: LucideIcons.barcode,
        style: mutedStyle,
      ),
    );

    if (summary.principesActifsCommuns.isNotEmpty) {
      widgets
        ..add(Gap(compact ? 2.0 : AppDimens.spacingXs)) // Reduced gap
        ..add(
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
        .map(normalizePrincipleOptimal)
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
    final theme = ShadTheme.of(context);
    return ShadAlert.destructive(
      title: Text(
        Strings.stockAlert(availabilityStatus!.trim()),
        style: compact ? theme.textTheme.small : theme.textTheme.small,
      ),
    );
  }

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
    return removeDiacritics(value).toLowerCase();
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
    final smallRadius = theme.radius.topLeft.x;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.0 : AppDimens.spacingSm, // Reduced padding
        vertical: compact ? 2.0 : AppDimens.spacingXs, // Reduced padding
      ),
      decoration: BoxDecoration(
        color: mutedColor,
        borderRadius: BorderRadius.circular(smallRadius),
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
}
