import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/core/widgets/ui_kit/stat_chip.dart';
import 'package:pharma_scan/core/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/core/ui/theme/app_theme.dart';
import 'package:pharma_scan/core/widgets/badges/status_badges.dart';
import 'package:pharma_scan/core/domain/extensions/medication_status_extensions.dart';
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
    this.mode = .analysis,
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
    final isRestockMode = mode == .restock;
    final backgroundColor = context.surfacePrimary.withValues(alpha: 0.7);
    final restockBorder = context.actionSecondary.withValues(alpha: 0.6);
    final radius = context.radiusMedium;
    final spacing = context.spacing;

    final isGenericWithPrinceps =
        !summary.isPrinceps &&
        summary.groupId != null &&
        summary.dbData.princepsDeReference.isNotEmpty &&
        summary.dbData.princepsDeReference != 'Inconnu';

    final commercializationStatus = boxStatus?.isNotEmpty ?? false
        ? boxStatus
        : summary.status;

    // Use princepsBrandName from DB if available
    final displayTitle = isGenericWithPrinceps
        ? (summary.dbData.princepsBrandName.isNotEmpty
              ? summary.dbData.princepsBrandName
              : summary.dbData.princepsDeReference)
        : (summary.isPrinceps
              ? (summary.dbData.princepsBrandName.isNotEmpty
                    ? summary.dbData.princepsBrandName
                    : summary.dbData.princepsDeReference)
              : (summary.groupId != null
                    ? summary.dbData.nomCanonique.split(' - ').first.trim()
                    : summary.dbData.nomCanonique));

    final metadataLines = List<String>.from(subtitle);
    final descriptionLine = metadataLines.isNotEmpty
        ? metadataLines.removeAt(0)
        : null;

    final statusIcons = _buildStatusIcons(context);
    final exactMatchBanner = _buildExactMatchBanner(context);
    final hasRegulatoryBadges =
        summary.isNarcotic ||
        summary.isList1 ||
        summary.isList2 ||
        summary.isException ||
        summary.isRestricted ||
        summary.isHospital ||
        summary.isDental ||
        summary.isSurveillance ||
        summary.isOtc;
    final regulatoryBadgesWidget = RegulatoryBadges(
      isNarcotic: summary.isNarcotic,
      isList1: summary.isList1,
      isList2: summary.isList2,
      isException: summary.isException,
      isRestricted: summary.isRestricted,
      isHospitalOnly: summary.isHospital,
      isDental: summary.isDental,
      isSurveillance: summary.isSurveillance,
      isOtc: summary.isOtc,
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
        ? FinancialBadge(refundRate: refundRate, price: price)
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
          color: isRestockMode ? restockBorder : context.actionSurface,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onExplore,
        child: Padding(
          padding: const .all(10),
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
                          style: context.typo.large.copyWith(
                            fontWeight: .w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isGenericWithPrinceps) ...[
                          Gap(spacing.xs / 2),
                          Text(
                            summary.dbData.princepsDeReference,
                            style: context.typo.small.copyWith(
                              color: context.colors.mutedForeground,
                              fontWeight: .w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (combinedMetadata.isNotEmpty) ...[
                          Gap(spacing.xs / 2),
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
                  Gap(spacing.xs / 2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (financialBadge != null)
                        Padding(
                          padding: .only(top: spacing.xs / 2),
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
                              Icons.close,
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
                Gap(spacing.xs / 2),
                Row(
                  children: [
                    Expanded(
                      child: StatChip(
                        label: Strings.priceShort,
                        value: priceText,
                        icon: LucideIcons.banknote,
                      ),
                    ),
                    Gap(spacing.sm),
                    Expanded(
                      child: StatChip(
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
                  padding: .only(top: spacing.xs / 2),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._withSpacing(context, badges),
                        if (hasRegulatoryBadges)
                          ..._withSpacing(context, [regulatoryBadgesWidget]),
                        if (statusIcons is! SizedBox) ...[
                          Gap(spacing.xs),
                          statusIcons,
                        ],
                      ],
                    ),
                  ),
                ),
              if (infoBadges.isNotEmpty)
                Padding(
                  padding: .only(top: spacing.xs / 2),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _withSpacing(context, infoBadges)),
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
          border: Border.all(color: restockBorder),
          borderRadius: theme.radius,
        ),
        child: card,
      );
    }

    if (isExpired) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.destructive, width: 2),
          borderRadius: context.radiusMedium,
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
      '${Strings.medication} ${summary.dbData.nomCanonique}',
    )..write(', ${Strings.cip} $cip');
    if (summary.titulaire != null && summary.titulaire!.isNotEmpty) {
      buffer.write(', ${Strings.holder} ${summary.titulaire}');
    }
    if (summary.dbData.principesActifsCommuns?.isNotEmpty ?? false) {
      final principles = summary.dbData.principesActifsCommuns!;
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
      buffer.write(', ${Strings.condition} ${summary.conditionsPrescription}');
    }
    return buffer.toString();
  }

  Widget _buildStatusIcons(BuildContext context) {
    final primaryColor = context.actionPrimary;
    final destructiveColor = context.colors.destructive;
    final spacing = context.spacing;
    final icons = <Widget>[];

    if (isHospitalOnly) {
      icons.add(Icon(Icons.local_hospital, size: 16, color: primaryColor));
    }

    if (availabilityStatus != null && availabilityStatus!.isNotEmpty) {
      icons.add(Icon(Icons.warning_amber, size: 16, color: destructiveColor));
    }

    if (boxStatus != null && boxStatus!.isNotEmpty) {
      final normalized = _normalizeStatusValue(boxStatus!);
      final isStopped =
          normalized.contains('arret') || normalized.contains('abroge');
      if (isStopped) {
        icons.add(Icon(Icons.block, size: 16, color: destructiveColor));
      }
    }

    if (icons.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs / 2,
      children: icons,
    );
  }

  String _normalizeStatusValue(String value) {
    return value.toLowerCase();
  }

  Widget? _buildExactMatchBanner(BuildContext context) {
    if (exactMatchLabel == null || exactMatchLabel!.isEmpty) {
      return null;
    }
    final mutedColor = context.surfaceSecondary;
    final mutedForeground = context.colors.mutedForeground;
    final smallRadius = context.radiusSmall.topLeft.x;
    return Container(
      padding: const .symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: mutedColor,
        borderRadius: .circular(smallRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 12, // AppDimens.iconXs
            color: mutedForeground,
          ),
          const Gap(4),
          Flexible(
            child: Text(
              exactMatchLabel!,
              style: context.typo.small.copyWith(color: mutedForeground),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(BuildContext context, List<Widget> children) {
    final spaced = <Widget>[];
    final spacing = context.spacing;
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(Gap(spacing.xs));
      }
      spaced.add(children[i]);
    }
    return spaced;
  }
}
