import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum StatusType { empty, error, loading }

class StatusView extends StatelessWidget {
  const StatusView({
    required this.type,
    super.key,
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
    switch (type) {
      case StatusType.loading:
        return const Center(
          child: SizedBox(
            height: 4,
            child: ShadProgress(),
          ),
        );
      case StatusType.empty:
      case StatusType.error:
        final effectiveIcon =
            icon ??
            (type == StatusType.empty
                ? LucideIcons.searchX
                : LucideIcons.triangleAlert);
        final iconColor = type == StatusType.empty
            ? ShadTheme.of(context).colorScheme.mutedForeground
            : ShadTheme.of(context).colorScheme.destructive;

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
                  Text(title!, style: ShadTheme.of(context).textTheme.h4),
                if (description != null) ...[
                  const Gap(AppDimens.spacingXs),
                  Text(
                    description!,
                    style: ShadTheme.of(context).textTheme.small.copyWith(
                      color: ShadTheme.of(context).colorScheme.mutedForeground,
                    ),
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
