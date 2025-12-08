import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
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
    final effectiveProgress = progressValue?.clamp(0.0, 1.0);
    final progressSummary =
        progressLabel ??
        (effectiveProgress != null
            ? Strings.dataOperationsProgressLabel(
                effectiveProgress * 100,
                status,
              )
            : status);

    final alert = isError
        ? ShadAlert.destructive(
            icon: Icon(icon, color: context.shadColors.destructive),
            title: Text(
              title,
              style: context.shadTextTheme.h4.copyWith(
                color: context.shadColors.destructive,
              ),
            ),
            description: _buildDescription(
              context,
              progressSummary,
              effectiveProgress,
            ),
          )
        : ShadAlert(
            icon: Icon(icon, color: context.shadColors.primary),
            title: Text(
              title,
              style: context.shadTextTheme.h4,
            ),
            description: _buildDescription(
              context,
              progressSummary,
              effectiveProgress,
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingMd,
        0,
        AppDimens.spacingMd,
        AppDimens.spacingXs,
      ),
      child: alert,
    );
  }

  Widget _buildDescription(
    BuildContext context,
    String progressSummary,
    double? effectiveProgress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          status,
          style: context.shadTextTheme.small.copyWith(
            color: context.shadColors.mutedForeground,
          ),
        ),
        if (secondaryStatus != null) ...[
          const Gap(AppDimens.spacing2xs),
          Text(
            secondaryStatus!,
            style: context.shadTextTheme.small,
          ),
        ],
        if (effectiveProgress != null || indeterminate) ...[
          const Gap(AppDimens.spacingSm),
          SizedBox(
            height: 4,
            child: indeterminate && effectiveProgress == null
                ? const ShadProgress()
                : ShadProgress(value: effectiveProgress ?? 0),
          ),
          const Gap(AppDimens.spacing2xs),
          Text(
            progressSummary,
            style: context.shadTextTheme.small,
          ),
        ],
        if (isError && onRetry != null) ...[
          const Gap(AppDimens.spacingMd),
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
