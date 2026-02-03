import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/core/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/core/domain/extensions/medication_status_extensions.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:pharma_scan/core/widgets/badges/status_badges.dart';
import 'package:pharma_scan/core/ui/organisms/app_sheet.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MedicationDetailSheet extends ConsumerWidget {
  const MedicationDetailSheet({required this.item, super.key});

  final GroupDetailEntity item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return AppSheetWidget(
      title: Text(Strings.medicationDetails, style: theme.textTheme.h4),
      description: Text(
        item.displayName,
        style: theme.textTheme.p.copyWith(fontWeight: .w600),
      ),
      child: SingleChildScrollView(
        padding: const .all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProductTypeBadge(memberType: item.memberType),
                const Gap(12),
                FinancialBadge(
                  refundRate: item.trimmedRefundRate,
                  price: item.prixPublic,
                ),
              ],
            ),
            const Gap(12),
            if (availability != null || item.isHospitalOnly) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  ...buildStatusBadges(
                    context,
                    statusFlags,
                    availabilityStatus: availability,
                  ),
                  if (item.isHospitalOnly)
                    ShadBadge.secondary(child: Text(Strings.hospitalBadge)),
                ],
              ),
              const Gap(12),
            ],
            _buildInfoRow(
              context,
              label: Strings.cipCodeLabel,
              value: item.cipCode,
            ),
            _buildInfoRow(context, label: Strings.laboratoryLabel, value: lab),
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
              const Gap(4),
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
              const Gap(4),
              _buildConditions(context, conditions),
            ],
            const Gap(12),
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
            const Gap(32),
            ShadButton.outline(
              width: double.infinity,
              onPressed: () async {
                try {
                  final db = ref.read(databaseProvider());
                  final dao = db.restockDao;
                  await dao.addToRestock(Cip13.validated(item.cipCode));
                  ref.read(hapticServiceProvider).success();
                  if (context.mounted) {
                    ShadToaster.of(context).show(
                      const ShadToast(description: Text('Ajouté au rangement')),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ShadToaster.of(context).show(
                      ShadToast.destructive(description: Text('Erreur: $e')),
                    );
                  }
                }
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.packagePlus),
                  SizedBox(width: 8),
                  Text('Ajouter au rangement'),
                ],
              ),
            ),
            const Gap(16), // Bottom padding
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
      padding: const .symmetric(vertical: 4),
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
          const Gap(12),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.p.copyWith(fontWeight: .w600),
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
              fontWeight: .w600,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.border),
              borderRadius: theme.radius,
            ),
            padding: const .all(16),
            child: Text(
              conditions,
              style: theme.textTheme.p.copyWith(fontWeight: .w600),
            ),
          ),
        ),
      ],
    );
  }
}
