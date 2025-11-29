import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class UnifiedActivityBanner extends HookWidget {
  const UnifiedActivityBanner({
    required this.icon, required this.title, required this.status, super.key,
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
    useStream(Stream<void>.periodic(const Duration(seconds: 1)));

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
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isError
                        ? ShadTheme.of(context).colorScheme.destructive
                        : ShadTheme.of(context).colorScheme.primary,
                  ),
                  const Gap(AppDimens.spacingXs),
                  Expanded(
                    child: Text(
                      title,
                      style: ShadTheme.of(context).textTheme.h4.copyWith(
                        color: isError
                            ? ShadTheme.of(context).colorScheme.destructive
                            : ShadTheme.of(context).colorScheme.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(AppDimens.spacingSm),
              Text(
                status,
                style: ShadTheme.of(context).textTheme.small.copyWith(
                  color: ShadTheme.of(context).colorScheme.mutedForeground,
                ),
              ),
              if (secondaryStatus != null) ...[
                const Gap(AppDimens.spacing2xs),
                Text(
                  secondaryStatus!,
                  style: ShadTheme.of(context).textTheme.small,
                ),
              ],
              const Gap(AppDimens.spacingSm),
              if (effectiveProgress != null || indeterminate)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: indeterminate && effectiveProgress == null
                            ? null
                            : effectiveProgress ?? 0,
                        backgroundColor: ShadTheme.of(
                          context,
                        ).colorScheme.muted,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ShadTheme.of(context).colorScheme.primary,
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const Gap(AppDimens.spacing2xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            progressSummary,
                            style: ShadTheme.of(context).textTheme.small,
                          ),
                        ),
                        Text(
                          '${Strings.dataOperationsElapsed}: '
                          '${elapsed != null ? _formatDuration(elapsed) : '--:--'}',
                          style: ShadTheme.of(context).textTheme.small.copyWith(
                            color: ShadTheme.of(
                              context,
                            ).colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const Gap(AppDimens.spacing2xs),
                    Text(
                      '${Strings.dataOperationsEta}: '
                      '${eta != null ? _formatDuration(eta) : Strings.dataOperationsEtaPending}',
                      style: ShadTheme.of(context).textTheme.small.copyWith(
                        color: ShadTheme.of(
                          context,
                        ).colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              if (isError && onRetry != null) ...[
                const Gap(AppDimens.spacingMd),
                Align(
                  alignment: Alignment.centerRight,
                  child: ShadButton(
                    onPressed: onRetry,
                    child: const Text(Strings.retry),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
