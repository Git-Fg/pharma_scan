// lib/core/widgets/ui_kit/product_card.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/core/widgets/accessible_touch.dart';
import 'package:pharma_scan/core/widgets/ui_kit/info_label.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    this.animation = false,
    this.price,
    this.refundRate,
    this.boxStatus,
    this.availabilityStatus,
    this.isHospitalOnly = false,
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

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final displayTitle = title ?? getDisplayTitle(summary);
    final displaySubtitle = subtitle ?? _buildDefaultSubtitle();
    final availabilityAlert = _buildAvailabilityAlert(theme);
    final statusIcons = _buildStatusIcons(theme);
    final computedBadges = [
      if (summary.isSurveillance) _buildSurveillanceBadge(theme),
      ...badges,
    ];

    final card = ShadCard(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (availabilityAlert != null) ...[
            availabilityAlert,
            const Gap(AppDimens.spacingSm),
          ],
          // Title row with badges and status icons
          Row(
            children: [
              if (computedBadges.isNotEmpty) ...[
                ...computedBadges.map(
                  (badge) => Padding(
                    padding: const EdgeInsets.only(right: AppDimens.spacingXs),
                    child: badge,
                  ),
                ),
                const Gap(AppDimens.spacingXs),
              ],
              Expanded(
                child: Text(
                  displayTitle,
                  style: theme.textTheme.h4,
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
          // Subtitle
          if (displaySubtitle.isNotEmpty) ...[
            const Gap(AppDimens.spacingXs),
            ...displaySubtitle.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spacingXs / 2),
                child: Text(
                  line,
                  style: theme.textTheme.muted,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          // Details section
          if (showDetails) ...[
            const Gap(AppDimens.spacingSm),
            ..._buildDetails(theme),
          ],
          // Actions
          if (showActions) ...[
            const Gap(AppDimens.spacingMd),
            _buildActions(theme),
          ],
        ],
      ),
    );

    final wrappedCard = onTap != null
        ? AccessibleTouch(
            label: _buildSemanticsLabel(),
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.04),
            child: card,
          )
        : card;

    return animation
        ? wrappedCard.animate(effects: AppAnimations.bubbleEnter)
        : wrappedCard;
  }

  List<Widget> _buildDetails(ShadThemeData theme) {
    final widgets = <Widget>[];

    if (summary.titulaire != null && summary.titulaire!.isNotEmpty) {
      widgets.add(
        InfoLabel(
          text: summary.titulaire!,
          icon: LucideIcons.building2,
          style: theme.textTheme.muted,
        ),
      );
      widgets.add(const Gap(AppDimens.spacingXs));
    }

    widgets.add(
      InfoLabel(
        text: '${Strings.cip} $cip',
        icon: LucideIcons.barcode,
        style: theme.textTheme.muted,
      ),
    );

    // WHY: Price and Refund Rate are removed from card face - they belong in detail sheets only
    // Financial details are "details", not "identity" - declutter the preview card

    if (summary.principesActifsCommuns.isNotEmpty) {
      widgets.add(const Gap(AppDimens.spacingXs));
      widgets.add(
        InfoLabel(
          text: summary.principesActifsCommuns.join(', '),
          icon: LucideIcons.flaskConical,
          style: theme.textTheme.muted,
        ),
      );
    }

    return widgets;
  }

  Widget _buildActions(ShadThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onExplore != null)
          Semantics(
            button: true,
            label: Strings.exploreMedicationGroup,
            child: ShadButton.outline(
              onPressed: onExplore,
              leading: const Icon(LucideIcons.search, size: 16),
              child: const Text(Strings.exploreGroup),
            ),
          ),
        if (onExplore != null && onClose != null)
          const Gap(AppDimens.spacingXs),
        if (onClose != null)
          Semantics(
            button: true,
            label: Strings.closeMedicationCard,
            child: ShadButton.destructive(
              onPressed: onClose,
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

    if (summary.groupId != null &&
        !summary.isPrinceps &&
        summary.princepsDeReference.isNotEmpty) {
      lines.add('${Strings.generic} de ${summary.princepsDeReference}');
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

  Widget _buildSurveillanceBadge(ShadThemeData theme) {
    return ShadBadge.destructive(
      child: Text(
        Strings.surveillanceBadge,
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.destructiveForeground,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget? _buildAvailabilityAlert(ShadThemeData theme) {
    if (availabilityStatus == null || availabilityStatus!.isEmpty) {
      return null;
    }
    return ShadAlert.destructive(
      title: Text(
        Strings.stockAlert(availabilityStatus!.trim()),
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.destructiveForeground,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // WHY: Build status icons with tooltips instead of text badges to save vertical space
  // Icons are more compact and provide the same information via tooltips
  Widget _buildStatusIcons(ShadThemeData theme) {
    final icons = <Widget>[];

    // Hospital icon
    if (isHospitalOnly) {
      icons.add(
        ShadTooltip(
          builder: (context) => const Text(Strings.hospitalTooltip),
          child: Icon(
            LucideIcons.building2,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    // Shortage/Tension icon
    if (availabilityStatus != null && availabilityStatus!.isNotEmpty) {
      icons.add(
        ShadTooltip(
          builder: (context) => Text(availabilityStatus!),
          child: Icon(
            LucideIcons.triangleAlert,
            size: 16,
            color: theme.colorScheme.destructive,
          ),
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
          ShadTooltip(
            builder: (context) => const Text(Strings.stoppedTooltip),
            child: Icon(
              LucideIcons.ban,
              size: 16,
              color: theme.colorScheme.destructive,
            ),
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
}
