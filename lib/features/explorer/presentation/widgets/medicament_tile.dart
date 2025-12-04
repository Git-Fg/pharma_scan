import 'package:flutter/material.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_type_badge.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MedicamentTile extends StatelessWidget {
  const MedicamentTile({required this.item, required this.onTap, super.key});

  final SearchResultItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (
      String title,
      String? subtitle,
      Widget prefix,
      String? details,
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
        const ProductTypeBadge(type: ProductType.generic, compact: true),
        null,
      ),
      PrincepsResult(
        princeps: final princeps,
        commonPrinciples: final commonPrinciples,
        generics: final generics,
      ) =>
        (
          princeps.nomCanonique,
          _buildSubtitle(princeps.formePharmaceutique, commonPrinciples),
          const ProductTypeBadge(type: ProductType.princeps, compact: true),
          Strings.genericCount(generics.length),
        ),
      GenericResult(
        generic: final generic,
        commonPrinciples: final commonPrinciples,
        princeps: final princeps,
      ) =>
        (
          generic.nomCanonique,
          _buildSubtitle(generic.formePharmaceutique, commonPrinciples),
          const ProductTypeBadge(type: ProductType.generic, compact: true),
          Strings.princepsCount(princeps.length),
        ),
      StandaloneResult(
        summary: final summary,
        commonPrinciples: final commonPrinciples,
      ) =>
        (
          summary.nomCanonique,
          _buildSubtitle(summary.formePharmaceutique, commonPrinciples),
          const ProductTypeBadge(type: ProductType.standalone, compact: true),
          null,
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
          princeps.nomCanonique,
          generics.length,
        ),
      GenericResult(generic: final generic, princeps: final princeps) =>
        Strings.searchResultSemanticsForGeneric(
          generic.nomCanonique,
          princeps.length,
        ),
      StandaloneResult(
        summary: final summary,
        commonPrinciples: final commonPrinciples,
      ) =>
        Strings.standaloneSemantics(
          summary.nomCanonique,
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

    return MergeSemantics(
      child: Semantics(
        label: semanticLabel,
        hint: Strings.medicationTileHint,
        child: InkWell(
          onTap: onTap,
          child: Container(
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
                  prefix,
                  const SizedBox(width: AppDimens.spacingSm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.shadTextTheme.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.shadTextTheme.small.copyWith(
                            color: context.shadColors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (details != null) ...[
                  const SizedBox(width: AppDimens.spacingSm),
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
                const SizedBox(width: AppDimens.spacingXs),
                const ExcludeSemantics(
                  child: Icon(LucideIcons.chevronRight, size: 16),
                ),
              ],
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
