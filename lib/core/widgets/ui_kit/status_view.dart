import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum StatusType { empty, error, loading }

class StatusView extends StatelessWidget {
  const StatusView({
    required this.type,
    super.key,
    this.title,
    this.description,
    this.action,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final StatusType type;
  final String? title;
  final String? description;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case StatusType.loading:
        return const Center(
          child: SizedBox(
            height: 4,
            child: _ProgressBar(),
          ),
        );
      case StatusType.empty:
      case StatusType.error:
        final effectiveIcon = icon ??
            (type == StatusType.empty
                ? LucideIcons.searchX
                : LucideIcons.triangleAlert);
        final isError = type == StatusType.error;
        const maxWidth = 520.0;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spacingXl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: isError
                  ? ShadAlert.destructive(
                      icon: Icon(effectiveIcon),
                      title: title != null
                          ? Text(
                              title!,
                              style: context.typo.h4.copyWith(
                                color: context.colors.destructive,
                              ),
                            )
                          : null,
                      description: _buildDescription(context),
                    )
                  : ShadCard(
                      title: Row(
                        children: [
                          Icon(
                            effectiveIcon,
                            color: context.colors.mutedForeground,
                          ),
                          const Gap(AppDimens.spacingXs),
                          if (title != null)
                            Expanded(
                              child: Text(
                                title!,
                                style: context.typo.h4,
                              ),
                            ),
                        ],
                      ),
                      description: _buildDescription(context),
                    ),
            ),
          ),
        );
    }
  }

  Widget _buildDescription(BuildContext context) {
    final descriptionText = description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (descriptionText != null) ...[
          Text(
            descriptionText,
            style: context.typo.small.copyWith(
              color: context.colors.mutedForeground,
            ),
          ),
        ],
        if (action != null) ...[
          const Gap(AppDimens.spacingMd),
          action!,
        ],
        if (onAction != null && actionLabel != null) ...[
          const Gap(AppDimens.spacingMd),
          ShadButton.outline(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
      ),
      child: ShadProgress(
        value: null, // indéterminé
        backgroundColor: colors.mutedForeground.withValues(alpha: 0.2),
        color: colors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
