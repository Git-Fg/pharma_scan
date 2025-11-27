import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';

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
    switch (type) {
      case StatusType.loading:
        return Center(
          child: SizedBox(
            height: 4.0,
            child: LinearProgressIndicator(
              backgroundColor: context.theme.colors.muted,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.theme.colors.primary,
              ),
              minHeight: 4.0,
            ),
          ),
        );
      case StatusType.empty:
      case StatusType.error:
        final effectiveIcon =
            icon ??
            (type == StatusType.empty ? FIcons.searchX : FIcons.triangleAlert);
        final iconColor = type == StatusType.empty
            ? context.theme.colors.mutedForeground
            : context.theme.colors.destructive;

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
                    style: context.theme.typography.xl2, // h4 equivalent
                  ),
                if (description != null) ...[
                  const Gap(AppDimens.spacingXs),
                  Text(
                    description!,
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
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
