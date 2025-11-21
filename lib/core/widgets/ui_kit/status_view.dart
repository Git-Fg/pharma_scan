import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum StatusType { empty, error, loading }

class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.type,
    this.title,
    this.description,
    this.action,
    this.icon,
  });

  final StatusType type;
  final String? title;
  final String? description;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    switch (type) {
      case StatusType.loading:
        return const Center(child: ShadProgress());
      case StatusType.empty:
      case StatusType.error:
        final effectiveIcon =
            icon ??
            (type == StatusType.empty
                ? LucideIcons.searchX
                : LucideIcons.triangleAlert);
        final iconColor = type == StatusType.empty
            ? theme.colorScheme.mutedForeground
            : theme.colorScheme.destructive;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spacing2xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  effectiveIcon,
                  size: AppDimens.icon2xl,
                  color: iconColor.withValues(alpha: 0.5),
                ),
                const Gap(AppDimens.spacingMd),
                if (title != null)
                  Text(
                    title!,
                    style: theme.textTheme.h4,
                    textAlign: TextAlign.center,
                  ),
                if (description != null) ...[
                  const Gap(AppDimens.spacingXs),
                  Text(
                    description!,
                    style: theme.textTheme.muted,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (action != null) ...[
                  const Gap(AppDimens.spacingXl),
                  action!,
                ],
              ],
            ),
          ),
        );
    }
  }
}
