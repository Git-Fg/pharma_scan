import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';

import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';

import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_state.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/group_detail/group_actions_bar.dart';

class GroupHeader extends StatelessWidget {
  const GroupHeader({
    required this.state,
    super.key,
  });

  final GroupExplorerState state;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final metadataBadges = <Widget>[
      if (state.distinctForms.isNotEmpty)
        ...state.distinctForms.map(
          (form) => ShadBadge.secondary(
            child: Text(Strings.formWithValue(form)),
          ),
        ),
    ];
    final conditionBadges = state.aggregatedConditions
        .map((condition) => condition.trim())
        .where((condition) => condition.isNotEmpty)
        .map(
          (condition) => ShadBadge.outline(
            child: Text(condition),
          ),
        )
        .toList();

    final firstPrinceps = state.princeps.firstOrNull;
    final regulatoryBadgesWidget = firstPrinceps != null
        ? RegulatoryBadges(
            isNarcotic: firstPrinceps.isNarcotic,
            isList1: firstPrinceps.isList1,
            isList2: firstPrinceps.isList2,
            isException: firstPrinceps.isException,
            isRestricted: firstPrinceps.isRestricted,
            isHospitalOnly: firstPrinceps.isHospitalOnly,
            isDental: firstPrinceps.isDental,
            isSurveillance: firstPrinceps.isSurveillance,
            isOtc: firstPrinceps.isOtc,
          )
        : null;

    final allBadges = <Widget>[
      if (regulatoryBadgesWidget != null) regulatoryBadgesWidget,
      ...metadataBadges,
      ...conditionBadges,
    ];

    final priceLabel = state.priceLabel;
    final refundValue = state.refundLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingMd,
        AppDimens.spacingSm,
        AppDimens.spacingMd,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.commonPrincipes.isNotEmpty) ...[
            Text(
              state.commonPrincipes.join(', '),
              style: theme.textTheme.h4.copyWith(
                color: theme.colorScheme.foreground,
              ),
            ),
            const Gap(AppDimens.spacing2xs),
          ],
          Text(
            state.title,
            style: theme.textTheme.p.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(AppDimens.spacing2xs),
          ShadBadge.outline(
            child: Text(Strings.summaryLine(
                state.princeps.length, state.generics.length)),
          ),
          if (allBadges.isNotEmpty) ...[
            const Gap(AppDimens.spacingSm),
            Wrap(
              spacing: AppDimens.spacing2xs,
              runSpacing: AppDimens.spacing2xs,
              children: allBadges,
            ),
          ],
          const Gap(AppDimens.spacingSm),
          _MetadataTiles(priceLabel: priceLabel, refundValue: refundValue),
          GroupActionsBar(
            cisCode: state.princepsCisCode,
            ansmAlertUrl: state.ansmAlertUrl,
          ),
          if ((state.rawLabelAnsm?.isNotEmpty ?? false) ||
              (state.parsingMethod?.isNotEmpty ?? false) ||
              (state.princepsCisReference?.isNotEmpty ?? false)) ...[
            const Gap(AppDimens.spacingSm),
            _TechnicalInfo(state: state),
          ],
        ],
      ),
    );
  }
}

class _MetadataTiles extends StatelessWidget {
  const _MetadataTiles({
    required this.priceLabel,
    required this.refundValue,
  });

  final String priceLabel;
  final String refundValue;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spacingSm,
        horizontal: AppDimens.spacingMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetadataItem(
              icon: LucideIcons.banknote,
              label: Strings.priceShort,
              value: priceLabel,
            ),
          ),
          const Gap(AppDimens.spacingMd),
          Expanded(
            child: _MetadataItem(
              icon: LucideIcons.percent,
              label: Strings.refundShort,
              value: refundValue,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.icon,
    required this.label,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.typo;
    final muted = textTheme.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: context.colors.mutedForeground,
        ),
        const Gap(AppDimens.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: muted),
              Text(
                value ?? '',
                style: textTheme.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TechnicalInfo extends StatelessWidget {
  const _TechnicalInfo({required this.state});

  final GroupExplorerState state;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final badge = state.parsingMethod != null
        ? _buildParsingMethodBadge(theme, state.parsingMethod!)
        : null;

    return ShadAccordion<String>.multiple(
      children: [
        ShadAccordionItem(
          value: 'technical-info',
          title: Text(
            Strings.technicalInformation,
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
            padding: const EdgeInsets.symmetric(
              vertical: AppDimens.spacingSm,
              horizontal: AppDimens.spacingMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null) ...[
                  Align(alignment: Alignment.centerRight, child: badge),
                  const Gap(AppDimens.spacing2xs),
                ],
                if (state.rawLabelAnsm?.isNotEmpty ?? false) ...[
                  Text(
                    Strings.rawLabelAnsm,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    state.rawLabelAnsm!,
                    style: theme.textTheme.p,
                  ),
                  const Gap(AppDimens.spacing2xs),
                ],
                if (state.princepsCisReference?.isNotEmpty ?? false) ...[
                  Text(
                    Strings.princepsCisReference,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    state.princepsCisReference!,
                    style: theme.textTheme.p,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  ShadBadge _buildParsingMethodBadge(
    ShadThemeData theme,
    String method,
  ) {
    final label = _parsingMethodLabel(method);
    switch (method) {
      case 'relational':
        return ShadBadge(
          child: Text(label, style: theme.textTheme.small),
        );
      case 'text_split':
        return ShadBadge.outline(
          child: Text(label, style: theme.textTheme.small),
        );
      case 'text_smart_split':
      case 'fallback':
      default:
        return ShadBadge.secondary(
          child: Text(
            label,
            style: theme.textTheme.small,
          ),
        );
    }
  }

  String _parsingMethodLabel(String method) {
    switch (method) {
      case 'relational':
        return Strings.parsingMethodRelational;
      case 'text_split':
        return Strings.parsingMethodTextSplit;
      case 'text_smart_split':
        return Strings.parsingMethodSmartSplit;
      case 'fallback':
      default:
        return Strings.parsingMethodFallback;
    }
  }
}
