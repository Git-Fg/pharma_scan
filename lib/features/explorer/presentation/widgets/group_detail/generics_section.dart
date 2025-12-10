import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GenericsSection extends HookWidget {
  const GenericsSection({
    required this.generics, required this.onViewDetail, super.key,
  });

  final List<GroupDetailEntity> generics;
  final ValueChanged<GroupDetailEntity> onViewDetail;

  @override
  Widget build(BuildContext context) {
    final filterController = useTextEditingController();
    useListenable(filterController);

    final filterQuery = filterController.text.trim().toLowerCase();
    final filteredGenerics = filterQuery.isEmpty
        ? generics
        : generics.where((generic) {
            final name = generic.displayName.toLowerCase();
            final lab = generic.parsedTitulaire.toLowerCase();
            return name.contains(filterQuery) || lab.contains(filterQuery);
          }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
      ),
      child: ShadAccordion<String>.multiple(
        initialValue: const <String>[],
        children: [
          ShadAccordionItem(
            value: 'generics',
            title: Row(
              children: [
                Icon(
                  LucideIcons.copy,
                  size: AppDimens.iconSm,
                  color: context.shadColors.mutedForeground,
                ),
                const Gap(AppDimens.spacingXs),
                Expanded(
                  child: Text(
                    Strings.generics,
                    style: context.shadTextTheme.h4,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Gap(AppDimens.spacingXs),
                ShadBadge(
                  child: Text(
                    '${filteredGenerics.length}',
                    style: context.shadTextTheme.small,
                  ),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimens.spacingSm,
                  ),
                  child: ShadInput(
                    controller: filterController,
                    placeholder: const Text(
                      Strings.genericFilterPlaceholder,
                    ),
                    leading: Icon(
                      LucideIcons.search,
                      size: AppDimens.iconSm,
                      color: context.shadColors.mutedForeground,
                    ),
                    trailing: filterController.text.isNotEmpty
                        ? ShadButton.ghost(
                            size: ShadButtonSize.sm,
                            onPressed: filterController.clear,
                            child: const Icon(
                              LucideIcons.x,
                              size: AppDimens.iconSm,
                            ),
                          )
                        : null,
                  ),
                ),
                ...List.generate(filteredGenerics.length, (index) {
                  final generic = filteredGenerics[index];
                  return CompactGenericTile(
                    item: generic,
                    onTap: () => onViewDetail(generic),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MedicationListTile extends StatelessWidget {
  const MedicationListTile({
    required this.item, required this.onTap, required this.showNavigationIndicator, super.key,
  });

  final GroupDetailEntity item;
  final VoidCallback? onTap;
  final bool showNavigationIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final name = item.displayName;
    final cipText = item.codeCip.isNotEmpty
        ? '${Strings.cip} ${item.codeCip}'
        : '';
    final lab = item.parsedTitulaire.isEmpty
        ? Strings.unknownHolder
        : item.parsedTitulaire;
    final subtitle = [
      cipText,
      lab,
    ].where((value) => value.isNotEmpty).join(' • ');

    final priceText = item.prixPublic != null
        ? formatEuro(item.prixPublic!)
        : null;
    final refundText = item.trimmedRefundRate;

    final statusBadge = item.isList1
        ? Strings.badgeList1
        : item.isList2
        ? Strings.badgeList2
        : item.isHospitalOnly
        ? Strings.hospitalBadge
        : null;
    final stockBadge = item.trimmedAvailabilityStatus != null
        ? Strings.stockAlert(item.trimmedAvailabilityStatus!)
        : null;

    final details = [priceText, refundText].whereType<String>().join(' • ');

    return Semantics(
      button: onTap != null,
      label: medicationSemanticsLabel(
        item,
        subtitle.isEmpty ? null : subtitle,
        details.isEmpty ? null : details,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth =
              constraints.hasBoundedWidth && constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;

          return SizedBox(
            width: itemWidth,
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: itemWidth,
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                  vertical: AppDimens.spacingSm,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.border),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.scale(
                      scale: 0.9,
                      child: ProductTypeBadge(memberType: item.memberType),
                    ),
                    const Gap(AppDimens.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            textAlign: TextAlign.start,
                            style: theme.textTheme.p.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(4),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                color: theme.colorScheme.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const Gap(AppDimens.spacing2xs),
                          Row(
                            children: [
                              if (priceText != null) ...[
                                ShadBadge(
                                  child: Text(
                                    priceText,
                                    style: theme.textTheme.small,
                                  ),
                                ),
                                const Gap(AppDimens.spacing2xs),
                              ],
                              if (refundText != null) ...[
                                ShadBadge.outline(
                                  child: Text(
                                    refundText,
                                    style: theme.textTheme.small,
                                  ),
                                ),
                                const Gap(AppDimens.spacing2xs),
                              ],
                              if (priceText == null && refundText == null)
                                Text(
                                  Strings.refundNotAvailable,
                                  style: theme.textTheme.small.copyWith(
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                          if (statusBadge != null ||
                              stockBadge != null ||
                              showNavigationIndicator) ...[
                            const Gap(AppDimens.spacing2xs),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (statusBadge != null)
                                    ShadBadge.destructive(
                                      child: Text(
                                        statusBadge,
                                        style: theme.textTheme.small,
                                      ),
                                    ),
                                  if (statusBadge != null &&
                                      (stockBadge != null ||
                                          showNavigationIndicator))
                                    const SizedBox(
                                      width: AppDimens.spacing2xs,
                                    ),
                                  if (stockBadge != null)
                                    ShadBadge.outline(
                                      child: Text(
                                        stockBadge,
                                        style: theme.textTheme.small,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (stockBadge != null &&
                                      showNavigationIndicator)
                                    const SizedBox(
                                      width: AppDimens.spacing2xs,
                                    ),
                                  if (showNavigationIndicator)
                                    const Icon(
                                      LucideIcons.chevronRight,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CompactGenericTile extends StatelessWidget {
  const CompactGenericTile({
    required this.item, required this.onTap, super.key,
  });

  final GroupDetailEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MedicationListTile(
      item: item,
      onTap: onTap,
      showNavigationIndicator: false,
    );
  }
}

String medicationSemanticsLabel(
  GroupDetailEntity member,
  String? subtitle,
  String? details,
) {
  final buffer = StringBuffer(member.displayName);
  if (subtitle != null) {
    buffer.write(', $subtitle');
  }
  if (details != null) {
    buffer.write(', $details');
  }
  if (member.trimmedAvailabilityStatus != null) {
    buffer.write(', ${Strings.stockAlert(member.trimmedAvailabilityStatus!)}');
  }
  return buffer.toString();
}
