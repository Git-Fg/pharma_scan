import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class UnifiedActivityBanner extends HookWidget {
  const UnifiedActivityBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    this.secondaryStatus,
    this.progressValue,
    this.progressLabel,
    this.startTime,
    this.estimatedRemaining,
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
  final DateTime? startTime;
  final Duration? estimatedRemaining;
  final bool indeterminate;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // WHY: Force a rebuild every second so elapsed/ETA stay fresh even if state
    // doesn't emit new values (e.g. parsing phase).
    useStream(Stream<void>.periodic(const Duration(seconds: 1)));

    final theme = ShadTheme.of(context);
    final elapsed = startTime != null
        ? DateTime.now().difference(startTime!)
        : null;
    final effectiveProgress = progressValue?.clamp(0.0, 1.0);
    final progressSummary =
        progressLabel ??
        (effectiveProgress != null
            ? Strings.dataOperationsProgressLabel(
                effectiveProgress * 100,
                status,
              )
            : status);
    final eta = estimatedRemaining == null
        ? null
        : (estimatedRemaining!.isNegative ? Duration.zero : estimatedRemaining);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingMd,
        0,
        AppDimens.spacingMd,
        AppDimens.spacingXs,
      ),
      child: ShadCard(
        title: Row(
          children: [
            Icon(
              icon,
              color: isError
                  ? theme.colorScheme.destructive
                  : theme.colorScheme.primary,
            ),
            const Gap(AppDimens.spacingXs),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.h4.copyWith(
                  color: isError
                      ? theme.colorScheme.destructive
                      : theme.colorScheme.foreground,
                ),
              ),
            ),
          ],
        ),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, style: theme.textTheme.muted),
            if (secondaryStatus != null) ...[
              const Gap(AppDimens.spacing2xs),
              Text(secondaryStatus!, style: theme.textTheme.small),
            ],
            const Gap(AppDimens.spacingSm),
            if (effectiveProgress != null || indeterminate)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  indeterminate && effectiveProgress == null
                      ? const ShadProgress()
                      : ShadProgress(value: effectiveProgress ?? 0),
                  const Gap(AppDimens.spacing2xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          progressSummary,
                          style: theme.textTheme.small,
                        ),
                      ),
                      Text(
                        '${Strings.dataOperationsElapsed}: '
                        '${elapsed != null ? _formatDuration(elapsed) : '--:--'}',
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const Gap(AppDimens.spacing2xs),
                  Text(
                    '${Strings.dataOperationsEta}: '
                    '${eta != null ? _formatDuration(eta) : Strings.dataOperationsEtaPending}',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
          ],
        ),
        footer: isError && onRetry != null
            ? Align(
                alignment: Alignment.centerRight,
                child: ShadButton.destructive(
                  onPressed: onRetry,
                  child: const Text(Strings.retry),
                ),
              )
            : null,
        child: const SizedBox.shrink(),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
