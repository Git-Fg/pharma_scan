// lib/features/explorer/widgets/medicament_tile.dart

import 'package:flutter/material.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MedicamentTile extends StatelessWidget {
  const MedicamentTile({required this.item, required this.onTap, super.key});

  final SearchResultItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final (
      String title,
      String? subtitle,
      Widget prefix,
      String? details,
    ) = switch (item) {
      GroupResult(group: final group) => (
          group.commonPrincipes.isNotEmpty
              ? group.commonPrincipes
              : Strings.notDetermined,
          group.princepsReferenceName,
          _buildGenericBadge(context),
          null,
        ),
      PrincepsResult(
        princeps: final princeps,
        commonPrinciples: final commonPrinciples,
        generics: final generics,
      ) => (
          princeps.nomCanonique,
          _buildSubtitle(princeps.formePharmaceutique, commonPrinciples),
          _buildBadge(context, Strings.badgePrinceps, isPrinceps: true),
          Strings.genericCount(generics.length),
        ),
      GenericResult(
        generic: final generic,
        commonPrinciples: final commonPrinciples,
        princeps: final princeps,
      ) => (
          generic.nomCanonique,
          _buildSubtitle(generic.formePharmaceutique, commonPrinciples),
          _buildBadge(context, Strings.badgeGeneric, isPrinceps: false),
          Strings.princepsCount(princeps.length),
        ),
      StandaloneResult(
        summary: final summary,
        commonPrinciples: final commonPrinciples,
      ) => (
          summary.nomCanonique,
          _buildSubtitle(summary.formePharmaceutique, commonPrinciples),
          _buildBadge(context, Strings.badgeStandalone, isPrinceps: false),
          null,
        ),
    };

    // Build semantic label based on medication type
    final semanticLabel = switch (item) {
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
          commonPrinciples.isNotEmpty,
          commonPrinciples,
        ),
      GroupResult(group: final group) => () {
          final principles = group.commonPrincipes.isNotEmpty
              ? group.commonPrincipes
              : Strings.notDetermined;
          return '$principles, référence ${group.princepsReferenceName}';
        }(),
    };

    // WHY: Custom Row-based widget matching Shadcn design patterns
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
                bottom: BorderSide(color: theme.colorScheme.border),
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
                        style: theme.textTheme.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
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
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
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
        .map((principle) => sanitizeActivePrinciple(principle.trim()));
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

  Widget _buildGenericBadge(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadBadge.secondary(
      child: Text(
        Strings.generics.substring(0, 1),
        style: theme.textTheme.small,
      ),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    String label, {
    required bool isPrinceps,
  }) {
    final theme = ShadTheme.of(context);
    return isPrinceps
        ? ShadBadge.secondary(
            child: Text(label.substring(0, 1), style: theme.textTheme.small),
          )
        : ShadBadge(
            child: Text(label.substring(0, 1), style: theme.textTheme.small),
          );
  }
}
