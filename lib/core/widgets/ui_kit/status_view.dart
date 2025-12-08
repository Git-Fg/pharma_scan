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
                              style: context.shadTextTheme.h4.copyWith(
                                color: context.shadColors.destructive,
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
                            color: context.shadColors.mutedForeground,
                          ),
                          const Gap(AppDimens.spacingXs),
                          if (title != null)
                            Expanded(
                              child: Text(
                                title!,
                                style: context.shadTextTheme.h4,
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
            style: context.shadTextTheme.small.copyWith(
              color: context.shadColors.mutedForeground,
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
