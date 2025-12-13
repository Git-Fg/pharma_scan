import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/medication_status_extensions.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/status_badges.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Card widget for scanner result bubbles.
///
/// Displays scan results with dismissal, compact layout, and tap-to-explore.
/// Replaces the generic ProductCard for scanner-specific use cases.
class ScannerResultCard extends StatelessWidget {
  const ScannerResultCard({
    required this.summary,
    required this.cip,
    required this.badges,
    required this.subtitle,
    required this.onClose,
    this.mode = ScannerMode.analysis,
    this.onExplore,
    this.price,
    this.refundRate,
    this.boxStatus,
    this.availabilityStatus,
    this.isHospitalOnly = false,
    this.exactMatchLabel,
    this.expDate,
    bool? isExpired,
    super.key,
  }) : isExpired = isExpired ?? false;

  final MedicamentEntity summary;
  final Cip13 cip;
  final List<Widget> badges;
  final List<String> subtitle;
  final VoidCallback onClose;
  final ScannerMode mode;
  final VoidCallback? onExplore;
  final double? price;
  final String? refundRate;
  final String? boxStatus;
  final String? availabilityStatus;
  final bool isHospitalOnly;
  final String? exactMatchLabel;
  final DateTime? expDate;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final isRestockMode = mode == ScannerMode.restock;
    final backgroundColor = theme.colorScheme.background.withValues(
      alpha: 0.7,
    );
    final restockBorder = theme.colorScheme.secondary.withValues(alpha: 0.6);
    final radius = theme.radius;

    final isGenericWithPrinceps =
        !summary.data.isPrinceps &&
        summary.groupId != null &&
        summary.data.princepsDeReference.isNotEmpty &&
        summary.data.princepsDeReference != 'Inconnu';

    final commercializationStatus = boxStatus?.isNotEmpty ?? false
        ? boxStatus
        : summary.status;

    // Use princepsBrandName from DB if available
    final displayTitle = isGenericWithPrinceps
        ? (summary.data.princepsBrandName.isNotEmpty
              ? summary.data.princepsBrandName
              : summary.data.princepsDeReference)
        : (summary.data.isPrinceps
              ? (summary.data.princepsBrandName.isNotEmpty
                    ? summary.data.princepsBrandName
                    : summary.data.princepsDeReference)
              : (summary.groupId != null
                    ? summary.data.nomCanonique.split(' - ').first.trim()
                    : summary.data.nomCanonique));

    final metadataLines = List<String>.from(subtitle);
    final descriptionLine = metadataLines.isNotEmpty
        ? metadataLines.removeAt(0)
        : null;

    final statusIcons = _buildStatusIcons(context);
    final exactMatchBanner = _buildExactMatchBanner(context);
    final hasRegulatoryBadges =
        summary.data.isNarcotic ||
        summary.data.isList1 ||
        summary.data.isList2 ||
        summary.data.isException ||
        summary.data.isRestricted ||
        summary.data.isHospital ||
        summary.data.isDental ||
        summary.data.isSurveillance ||
        summary.data.isOtc;
    final regulatoryBadgesWidget = RegulatoryBadges(
      isNarcotic: summary.data.isNarcotic,
      isList1: summary.data.isList1,
      isList2: summary.data.isList2,
      isException: summary.data.isException,
      isRestricted: summary.data.isRestricted,
      isHospitalOnly: summary.data.isHospital,
      isDental: summary.data.isDental,
      isSurveillance: summary.data.isSurveillance,
      isOtc: summary.data.isOtc,
      compact: true,
    );

    final combinedMetadata = [
      descriptionLine,
      ...metadataLines,
    ].whereType<String>().where((line) => line.trim().isNotEmpty).join(' • ');

    final normalizedRefund = refundRate?.trim();
    final hasRefund =
        normalizedRefund != null &&
        normalizedRefund.isNotEmpty &&
        normalizedRefund.toLowerCase() != 'nr';
    final hasFinancialInfo = hasRefund || price != null;
    final priceText = price != null
        ? formatEuro(price!)
        : Strings.priceUnavailable;
    final refundText = (normalizedRefund != null && normalizedRefund.isNotEmpty)
        ? normalizedRefund
        : Strings.refundNotAvailable;
    final Widget? financialBadge = hasFinancialInfo
        ? FinancialBadge(
            refundRate: refundRate,
            price: price,
          )
        : null;

    final statusFlags = summary.statusFlags(
      commercializationStatus: commercializationStatus,
      availabilityStatus: availabilityStatus,
      isExpired: isExpired,
      expDate: expDate,
    );
    final statusBadges = buildStatusBadges(
      context,
      statusFlags,
      availabilityStatus: availabilityStatus,
    );

    final infoBadges = <Widget>[];
    if (hasRegulatoryBadges) infoBadges.add(regulatoryBadgesWidget);
    if (statusIcons is! SizedBox) infoBadges.add(statusIcons);
    infoBadges.addAll(statusBadges);
    if (exactMatchBanner != null) infoBadges.add(exactMatchBanner);

    Widget card = Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: isRestockMode ? restockBorder : context.colors.border,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onExplore,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: context.typo.p.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isGenericWithPrinceps) ...[
                          const Gap(AppDimens.spacing2xs),
                          Text(
                            summary.data.princepsDeReference,
                            style: context.typo.small.copyWith(
                              color: context.colors.mutedForeground,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (combinedMetadata.isNotEmpty) ...[
                          const Gap(AppDimens.spacing2xs),
                          Text(
                            combinedMetadata,
                            style: context.typo.small.copyWith(
                              color: context.colors.mutedForeground,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Gap(AppDimens.spacing2xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (financialBadge != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppDimens.spacing2xs,
                          ),
                          child: financialBadge,
                        ),
                      Semantics(
                        button: true,
                        label: Strings.closeCardLabel,
                        hint: Strings.closeCardHint,
                        child: SizedBox(
                          height: 48,
                          width: 48,
                          child: InkResponse(
                            onTap: onClose,
                            radius: 24,
                            child: Icon(
                              LucideIcons.x,
                              size: 18,
                              color: context.colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (hasFinancialInfo) ...[
                const Gap(AppDimens.spacing2xs),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatChip(
                        context,
                        label: Strings.priceShort,
                        value: priceText,
                        icon: LucideIcons.banknote,
                      ),
                    ),
                    const Gap(AppDimens.spacingSm),
                    Expanded(
                      child: _buildStatChip(
                        context,
                        label: Strings.refundShort,
                        value: refundText,
                        icon: LucideIcons.percent,
                      ),
                    ),
                  ],
                ),
              ],
              if (badges.isNotEmpty ||
                  hasRegulatoryBadges ||
                  statusIcons is! SizedBox)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spacing2xs),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._withSpacing(badges),
                        if (hasRegulatoryBadges)
                          ..._withSpacing([regulatoryBadgesWidget]),
                        if (statusIcons is! SizedBox) ...[
                          const SizedBox(width: AppDimens.spacingXs),
                          statusIcons,
                        ],
                      ],
                    ),
                  ),
                ),
              if (infoBadges.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimens.spacing2xs),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _withSpacing(infoBadges),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (isRestockMode) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: restockBorder,
          ),
          borderRadius: theme.radius,
        ),
        child: card,
      );
    }

    if (isExpired) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: context.colors.destructive,
            width: 2,
          ),
          borderRadius: context.shadTheme.radius,
        ),
        child: card,
      );
    }

    return Semantics(
      label: _buildSemanticsLabel(),
      hint: Strings.tapToViewDetails,
      child: card,
    );
  }

  String _buildSemanticsLabel() {
    final buffer = StringBuffer(
      '${Strings.medication} ${summary.data.nomCanonique}',
    )..write(', ${Strings.cip} $cip');
    if (summary.titulaire != null && summary.titulaire!.isNotEmpty) {
      buffer.write(', ${Strings.holder} ${summary.titulaire}');
    }
    if (summary.data.principesActifsCommuns?.isNotEmpty ?? false) {
      final principles = summary.data.principesActifsCommuns!;
      final principlesList = json.decode(principles) as List<dynamic>?;
      if (principlesList != null) {
        final activePrinciples = principlesList
            .take(3)
            .map((e) => e.toString())
            .join(', ');
        buffer.write(', ${Strings.activePrinciples} $activePrinciples');
      }
    }
    if (summary.conditionsPrescription.isNotEmpty) {
      buffer.write(
        ', ${Strings.condition} ${summary.conditionsPrescription}',
      );
    }
    return buffer.toString();
  }

  Widget _buildStatChip(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = context.shadTheme;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingSm,
          vertical: AppDimens.spacing2xs,
        ),
        decoration: BoxDecoration(
          borderRadius: theme.radius,
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: theme.colorScheme.mutedForeground,
            ),
            const Gap(6),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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

    return Wrap(
      spacing: AppDimens.spacingXs,
      runSpacing: AppDimens.spacing2xs,
      children: icons,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.scanBarcode,
            size: AppDimens.iconXs,
            color: mutedForeground,
          ),
          const Gap(4),
          Flexible(
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

  List<Widget> _withSpacing(List<Widget> children) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(const SizedBox(width: AppDimens.spacingXs));
      }
      spaced.add(children[i]);
    }
    return spaced;
  }
}
