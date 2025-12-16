import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class UnifiedActivityBanner extends StatelessWidget {
  const UnifiedActivityBanner({
    required this.icon,
    required this.title,
    required this.status,
    super.key,
    this.secondaryStatus,
    this.progressValue,
    this.progressLabel,
    this.indeterminate = false,
    this.isError = false,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String status;
  final String? secondaryStatus;
  final double? progressValue;
  final String? progressLabel;
  final bool indeterminate;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final effectiveProgress = progressValue?.clamp(0.0, 1.0);
    final progressSummary = progressLabel ??
        (effectiveProgress != null
            ? Strings.dataOperationsProgressLabel(
                effectiveProgress * 100,
                status,
              )
            : status);

    final alert = isError
        ? ShadAlert.destructive(
            icon: Icon(icon, color: context.colors.destructive),
            title: Text(
              title,
              style: context.typo.h4.copyWith(
                color: context.colors.destructive,
              ),
            ),
            description: _buildDescription(
              context,
              progressSummary,
              effectiveProgress,
            ),
          )
        : ShadAlert(
            icon: Icon(icon, color: context.colors.primary),
            title: Text(
              title,
              style: context.typo.h4,
            ),
            description: _buildDescription(
              context,
              progressSummary,
              effectiveProgress,
            ),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.xs,
        spacing.md,
        spacing.xs,
      ),
      child: alert,
    );
  }

  Widget _buildDescription(
    BuildContext context,
    String progressSummary,
    double? effectiveProgress,
  ) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status,
          style: context.typo.small.copyWith(
            color: context.colors.mutedForeground,
          ),
        ),
        if (secondaryStatus != null) ...[
          Gap(spacing.xs / 2),
          Text(
            secondaryStatus!,
            style: context.typo.small,
          ),
        ],
        if (effectiveProgress != null || indeterminate) ...[
          Gap(spacing.sm),
          SizedBox(
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: indeterminate && effectiveProgress == null
                    ? null
                    : effectiveProgress ?? 0,
                backgroundColor: context.colors.mutedForeground.withValues(
                  alpha: 0.2,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.colors.primary,
                ),
              ),
            ),
          ),
          Gap(spacing.xs / 2),
          Text(
            progressSummary,
            style: context.typo.small,
          ),
        ],
        if (isError && onRetry != null) ...[
          Gap(spacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: ShadButton.outline(
              onPressed: onRetry,
              child: const Text(Strings.retry),
            ),
          ),
        ],
      ],
    );
  }
}
