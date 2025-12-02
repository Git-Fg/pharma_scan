import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum ProductType {
  princeps,
  generic,
  standalone,
}

class ProductTypeBadge extends StatelessWidget {
  const ProductTypeBadge({
    required this.type,
    this.compact = false,
    super.key,
  });

  final ProductType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final (badge, tooltip) = switch (type) {
      ProductType.princeps => (
        ShadBadge.secondary(
          child: Text(
            compact
                ? Strings.badgePrinceps.substring(0, 1)
                : Strings.badgePrinceps,
            style: theme.textTheme.small,
          ),
        ),
        Strings.badgePrincepsTooltip,
      ),
      ProductType.generic => (
        ShadBadge.outline(
          child: Text(
            compact
                ? Strings.badgeGeneric.substring(0, 1)
                : Strings.badgeGeneric,
            style: theme.textTheme.small,
          ),
        ),
        Strings.badgeGenericTooltip,
      ),
      ProductType.standalone => (
        ShadBadge.outline(
          child: Text(
            compact
                ? Strings.badgeStandalone.substring(0, 1)
                : Strings.badgeStandalone,
            style: theme.textTheme.small,
          ),
        ),
        Strings.badgeStandaloneTooltip,
      ),
    };

    return ShadTooltip(
      builder: (BuildContext tooltipContext) => Text(
        tooltip,
        style: theme.textTheme.small,
      ),
      child: badge,
    );
  }
}
