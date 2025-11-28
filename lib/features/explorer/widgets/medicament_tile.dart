// lib/features/explorer/widgets/medicament_tile.dart

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:pharma_scan/theme/badge_styles.dart';

class MedicamentTile extends StatelessWidget {
  const MedicamentTile({required this.item, required this.onTap, super.key});

  final SearchResultItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final (
      String title,
      String? subtitle,
      Widget? prefix,
      String? details,
    ) = item.map(
      groupResult: (groupResult) => (
        groupResult.group.princepsReferenceName,
        _buildGroupSubtitle(groupResult.group),
        _buildGroupPrefix(context),
        null,
      ),
      princepsResult: (data) => (
        data.princeps.nomCanonique,
        _buildSubtitle(
          data.princeps.formePharmaceutique,
          data.commonPrinciples,
        ),
        _buildBadge(context, Strings.badgePrinceps, isPrinceps: true),
        Strings.genericCount(data.generics.length),
      ),
      genericResult: (data) => (
        data.generic.nomCanonique,
        _buildSubtitle(data.generic.formePharmaceutique, data.commonPrinciples),
        _buildBadge(context, Strings.badgeGeneric, isPrinceps: false),
        Strings.princepsCount(data.princeps.length),
      ),
      standaloneResult: (data) => (
        data.summary.nomCanonique,
        _buildSubtitle(data.summary.formePharmaceutique, data.commonPrinciples),
        _buildBadge(context, Strings.badgeStandalone, isPrinceps: false),
        null,
      ),
    );

    // Build semantic label based on medication type
    final semanticLabel = item.map(
      princepsResult: (data) => Strings.searchResultSemanticsForPrinceps(
        data.princeps.nomCanonique,
        data.generics.length,
      ),
      genericResult: (data) => Strings.searchResultSemanticsForGeneric(
        data.generic.nomCanonique,
        data.princeps.length,
      ),
      standaloneResult: (data) => Strings.standaloneSemantics(
        data.summary.nomCanonique,
        data.commonPrinciples.isNotEmpty,
        data.commonPrinciples,
      ),
      groupResult: (groupResult) =>
          'Groupe: ${groupResult.group.princepsReferenceName}',
    );

    return Semantics(
      label: semanticLabel,
      hint: Strings.medicationTileHint,
      child: FTile(
        onPress: onTap,
        prefix: prefix,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.base.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              )
            : null,
        details: details != null
            ? Text(
                details,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              )
            : null,
        suffix: const ExcludeSemantics(child: Icon(FIcons.chevronRight)),
      ),
    );
  }

  Widget? _buildGroupPrefix(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FBadge(
          style: _badgeStyleFor(context, isPrinceps: true).call,
          child: const Text(Strings.badgePrinceps),
        ),
        const Gap(AppDimens.spacing2xs),
        FBadge(
          style: _badgeStyleFor(context, isPrinceps: false).call,
          child: const Text(Strings.badgeGeneric),
        ),
      ],
    );
  }

  String? _buildGroupSubtitle(GenericGroupEntity group) {
    if (group.commonPrincipes.isEmpty) return Strings.notDetermined;
    return group.commonPrincipes;
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

  Widget _buildBadge(
    BuildContext context,
    String label, {
    required bool isPrinceps,
  }) {
    return FBadge(
      style: _badgeStyleFor(context, isPrinceps: isPrinceps).call,
      child: Text(label.substring(0, 1)),
    );
  }

  FBadgeStyle _badgeStyleFor(BuildContext context, {required bool isPrinceps}) {
    final styles = context.theme.badgeStyles;
    if (styles is PharmaBadgeStyles) {
      return isPrinceps ? styles.princeps : styles.generic;
    }

    return isPrinceps ? styles.secondary : styles.primary;
  }
}
