import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:forui/forui.dart';

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
      child: FCard.raw(
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
                        ? context.theme.colors.destructive
                        : context.theme.colors.primary,
                  ),
                  const Gap(AppDimens.spacingXs),
                  Expanded(
                    child: Text(
                      title,
                      style: context.theme.typography.xl2.copyWith(
                        color: isError
                            ? context.theme.colors.destructive
                            : context.theme.colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(AppDimens.spacingSm),
              Text(
                status,
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              if (secondaryStatus != null) ...[
                const Gap(AppDimens.spacing2xs),
                Text(secondaryStatus!, style: context.theme.typography.sm),
              ],
              const Gap(AppDimens.spacingSm),
              if (effectiveProgress != null || indeterminate)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 4.0,
                      child: LinearProgressIndicator(
                        value: indeterminate && effectiveProgress == null
                            ? null
                            : effectiveProgress ?? 0,
                        backgroundColor: context.theme.colors.muted,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.theme.colors.primary,
                        ),
                        minHeight: 4.0,
                      ),
                    ),
                    const Gap(AppDimens.spacing2xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            progressSummary,
                            style: context.theme.typography.sm,
                          ),
                        ),
                        Text(
                          '${Strings.dataOperationsElapsed}: '
                          '${elapsed != null ? _formatDuration(elapsed) : '--:--'}',
                          style: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    const Gap(AppDimens.spacing2xs),
                    Text(
                      '${Strings.dataOperationsEta}: '
                      '${eta != null ? _formatDuration(eta) : Strings.dataOperationsEtaPending}',
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              if (isError && onRetry != null) ...[
                const Gap(AppDimens.spacingMd),
                Align(
                  alignment: Alignment.centerRight,
                  child: FButton(
                    style: FButtonStyle.primary(),
                    onPress: onRetry,
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
