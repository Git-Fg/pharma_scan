import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/highlight_text.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MedicamentTile extends StatelessWidget {
  const MedicamentTile({
    required this.item,
    required this.onTap,
    this.currentQuery = '',
    super.key,
  });

  final SearchResultItem item;
  final VoidCallback onTap;
  final String currentQuery;

  @override
  Widget build(BuildContext context) {
    final (
      String title,
      String? subtitle,
      Widget prefix,
      String? details,
      bool isRevoked,
    ) = switch (item) {
      ClusterResult() => throw StateError(
        'ClusterResult should not be rendered by MedicamentTile. '
        'Use MoleculeGroupTile instead.',
      ),
      GroupResult(group: final group) => (
        group.commonPrincipes.isNotEmpty
            ? group.commonPrincipes
            : Strings.notDetermined,
        group.princepsReferenceName,
        const ProductTypeBadge(memberType: 1, compact: true),
        null,
        false,
      ),
      PrincepsResult(
        princeps: final princeps,
        commonPrinciples: final commonPrinciples,
        generics: final generics,
      ) =>
        (
          princeps.data.nomCanonique,
          _buildSubtitle(princeps.data.formePharmaceutique, commonPrinciples),
          ProductTypeBadge(
            memberType: princeps.data.memberType,
            compact: true,
          ),
          Strings.genericCount(generics.length),
          princeps.isRevoked,
        ),
      GenericResult(
        generic: final generic,
        commonPrinciples: final commonPrinciples,
        princeps: final princeps,
      ) =>
        (
          generic.data.nomCanonique,
          _buildSubtitle(generic.data.formePharmaceutique, commonPrinciples),
          ProductTypeBadge(
            memberType: generic.data.memberType,
            compact: true,
          ),
          Strings.princepsCount(princeps.length),
          generic.isRevoked,
        ),
      StandaloneResult(
        summary: final summary,
        commonPrinciples: final commonPrinciples,
      ) =>
        (
          summary.data.nomCanonique,
          _buildSubtitle(summary.data.formePharmaceutique, commonPrinciples),
          ProductTypeBadge(
            memberType: summary.data.memberType,
            compact: true,
          ),
          null,
          summary.isRevoked,
        ),
    };

    // Build semantic label based on medication type
    final semanticLabel = switch (item) {
      ClusterResult() => throw StateError(
        'ClusterResult should not be rendered by MedicamentTile. '
        'Use MoleculeGroupTile instead.',
      ),
      PrincepsResult(princeps: final princeps, generics: final generics) =>
        Strings.searchResultSemanticsForPrinceps(
          princeps.data.nomCanonique,
          generics.length,
        ),
      GenericResult(generic: final generic, princeps: final princeps) =>
        Strings.searchResultSemanticsForGeneric(
          generic.data.nomCanonique,
          princeps.length,
        ),
      StandaloneResult(
        summary: final summary,
        commonPrinciples: final commonPrinciples,
      ) =>
        Strings.standaloneSemantics(
          summary.data.nomCanonique,
          hasPrinciples: commonPrinciples.isNotEmpty,
          principlesText: commonPrinciples,
        ),
      GroupResult(group: final group) => () {
        final principles = group.commonPrincipes.isNotEmpty
            ? group.commonPrincipes
            : Strings.notDetermined;
        return '$principles, référence ${group.princepsReferenceName}';
      }(),
    };

    return Semantics(
      label: semanticLabel,
      hint: Strings.medicationTileHint,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Opacity(
              opacity: isRevoked ? 0.6 : 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                  vertical: AppDimens.spacingSm,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: context.shadColors.border),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...[
                      ExcludeSemantics(child: prefix),
                      const Gap(AppDimens.spacingSm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HighlightText(
                            text: title,
                            query: currentQuery,
                            maxLines: 1,
                            style: context.shadTextTheme.p.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            highlightStyle: context.shadTextTheme.p.copyWith(
                              fontWeight: FontWeight.w900,
                              color: context.shadColors.primary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const Gap(4),
                            HighlightText(
                              text: subtitle,
                              query: currentQuery,
                              maxLines: 3,
                              style: context.shadTextTheme.small.copyWith(
                                color: context.shadColors.mutedForeground,
                              ),
                              highlightStyle: context.shadTextTheme.small
                                  .copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: context.shadColors.primary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (details != null) ...[
                      const Gap(AppDimens.spacingSm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: context.shadTextTheme.small.copyWith(
                            color: context.shadColors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                    if (isRevoked) ...[
                      const Gap(AppDimens.spacingXs),
                      Icon(
                        LucideIcons.circle,
                        size: 10,
                        color: context.shadColors.destructive,
                      ),
                    ],
                    const Gap(AppDimens.spacingXs),
                    const ExcludeSemantics(
                      child: Icon(LucideIcons.chevronRight, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _buildSubtitle(String? form, String? principles) {
    final sanitizedPrinciples = principles
        ?.split(' + ')
        .map((principle) => normalizePrincipleOptimal(principle.trim()));
    final normalizedPrinciples =
        sanitizedPrinciples?.where((value) => value.isNotEmpty).join(' + ') ??
        '';

    final segments = <String>[
      if (form != null && form.isNotEmpty) form,
      if (normalizedPrinciples.isNotEmpty) normalizedPrinciples,
    ];

    if (segments.isEmpty) return null;
    return segments.join(' • ');
  }
}
