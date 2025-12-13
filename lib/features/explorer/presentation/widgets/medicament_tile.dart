import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
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

  String _heroTag(SearchResultItem item) {
    return switch (item) {
      GroupResult(group: final group) => 'group-${group.groupId}',
      PrincepsResult(groupId: final groupId) => 'group-$groupId',
      GenericResult(groupId: final groupId) => 'group-$groupId',
      StandaloneResult(representativeCip: final cip) => 'standalone-$cip',
      ClusterResult() => 'cluster-${item.hashCode}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = _heroTag(item);
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
          _buildSubtitle(princeps.formePharmaceutique, commonPrinciples),
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
          _buildSubtitle(generic.formePharmaceutique, commonPrinciples),
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
          _buildSubtitle(summary.formePharmaceutique, commonPrinciples),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isStackedLayout = constraints.maxWidth < 600;

    Widget? buildDetails({
          required TextAlign align,
          required int maxLines,
        }) {
          final detailValue = details;
          if (detailValue == null) return null;
          return Text(
            detailValue,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            textAlign: align,
            style: context.shadTextTheme.small.copyWith(
              color: context.shadColors.mutedForeground,
            ),
          );
        }

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
                              Hero(
                                tag: heroTag,
                                flightShuttleBuilder:
                                    (
                                      _,
                                      animation,
                                      direction,
                                      fromContext,
                                      toContext,
                                    ) {
                                  final target =
                                      direction == HeroFlightDirection.push
                                      ? toContext.widget
                                      : fromContext.widget;
                                  return FadeTransition(
                                    opacity: animation.drive(
                                      CurveTween(curve: Curves.easeInOut),
                                    ),
                                    child: target,
                                  );
                                },
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.shadTextTheme.p.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              if (subtitle != null) ...[
                                const Gap(4),
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
                        if (isStackedLayout) ...[
                          const Gap(AppDimens.spacing2xs),
                          if (buildDetails(
                                align: TextAlign.start,
                                maxLines: 2,
                              ) !=
                              null)
                            Expanded(
                              child:
                                  buildDetails(
                                    align: TextAlign.start,
                                    maxLines: 2,
                                  ) ??
                                  const SizedBox.shrink(),
                            ),
                        ] else ...[
                          if (buildDetails(
                                align: TextAlign.end,
                                maxLines: 1,
                              ) !=
                              null) ...[
                            const Gap(AppDimens.spacingSm),
                            Flexible(
                              child:
                                  buildDetails(
                                    align: TextAlign.end,
                                    maxLines: 1,
                                  ) ??
                                  const SizedBox.shrink(),
                            ),
                          ],
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
      },
    );
  }

  String? _buildSubtitle(String form, String? principles) {
    // Principles are already normalized from the database
    final normalizedPrinciples =
        principles
            ?.split(' + ')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .join(' + ') ??
        '';

    final segments = <String>[
      if (form.isNotEmpty) form,
      if (normalizedPrinciples.isNotEmpty) normalizedPrinciples,
    ];

    if (segments.isEmpty) return null;
    return segments.join(' • ');
  }
}
