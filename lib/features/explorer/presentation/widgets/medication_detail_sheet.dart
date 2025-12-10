import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/medication_status_extensions.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/status_badges.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MedicationDetailSheet extends StatelessWidget {
  const MedicationDetailSheet({required this.item, super.key});

  final GroupDetailEntity item;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final lab = item.parsedTitulaire.isEmpty
        ? Strings.unknownHolder
        : item.parsedTitulaire;
    final availability = item.trimmedAvailabilityStatus;
    final priceText = item.prixPublic != null
        ? formatEuro(item.prixPublic!)
        : null;
    final conditions = item.trimmedConditions;
    final statusFlags = item.statusFlags(
      availabilityStatus: item.trimmedAvailabilityStatus,
    );

    return ShadSheet(
      title: Text(
        Strings.medicationDetails,
        style: theme.textTheme.h4,
      ),
      description: Text(
        item.displayName,
        style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w600),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimens.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductTypeBadge(memberType: item.memberType),
                const Gap(AppDimens.spacingSm),
                FinancialBadge(
                  refundRate: item.trimmedRefundRate,
                  price: item.prixPublic,
                ),
              ],
            ),
            const Gap(AppDimens.spacingSm),
            if (availability != null || item.isHospitalOnly) ...[
              Wrap(
                spacing: AppDimens.spacing2xs,
                runSpacing: AppDimens.spacing2xs,
                children: [
                  ...buildStatusBadges(
                    context,
                    statusFlags,
                    availabilityStatus: availability,
                  ),
                  if (item.isHospitalOnly)
                    ShadBadge.secondary(
                      child: Text(
                        Strings.hospitalBadge,
                        style: theme.textTheme.small,
                      ),
                    ),
                ],
              ),
              const Gap(AppDimens.spacingSm),
            ],
            _buildInfoRow(
              context,
              label: Strings.cipCodeLabel,
              value: item.codeCip,
            ),
            _buildInfoRow(
              context,
              label: Strings.laboratoryLabel,
              value: lab,
            ),
            if (item.dosageLabel != null)
              _buildInfoRow(
                context,
                label: Strings.dosage,
                value: item.dosageLabel!,
              ),
            if (item.formLabel != null)
              _buildInfoRow(
                context,
                label: Strings.pharmaceuticalFormLabel,
                value: item.formLabel!,
              ),
            if (priceText != null) ...[
              const Gap(AppDimens.spacing2xs),
              _buildInfoRow(
                context,
                label: Strings.priceShort,
                value: priceText,
              ),
            ],
            if (item.trimmedRefundRate != null) ...[
              _buildInfoRow(
                context,
                label: Strings.refundShort,
                value: item.trimmedRefundRate!,
              ),
            ],
            if (conditions != null && conditions.isNotEmpty) ...[
              const Gap(AppDimens.spacing2xs),
              _buildConditions(context, conditions),
            ],
            const Gap(AppDimens.spacingSm),
            RegulatoryBadges(
              isNarcotic: item.isNarcotic,
              isList1: item.isList1,
              isList2: item.isList2,
              isException: item.isException,
              isRestricted: item.isRestricted,
              isHospitalOnly: item.isHospitalOnly,
              isDental: item.isDental,
              isSurveillance: item.isSurveillance,
              isOtc: item.isOtc,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = context.shadTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ),
          const Gap(AppDimens.spacingSm),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditions(BuildContext context, String conditions) {
    final theme = context.shadTheme;
    if (conditions.length <= 50) {
      return _buildInfoRow(
        context,
        label: Strings.condition,
        value: conditions,
      );
    }

    return ShadAccordion<String>.multiple(
      children: [
        ShadAccordionItem(
          value: 'conditions',
          title: Text(
            Strings.condition,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.border),
              borderRadius: theme.radius,
            ),
            padding: const EdgeInsets.all(AppDimens.spacingMd),
            child: Text(
              conditions,
              style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
