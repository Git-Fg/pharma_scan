import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class UnifiedActivityBanner extends HookWidget {
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
    useStream(const Stream<void>.empty());
    final effectiveProgress = progressValue?.clamp(0.0, 1.0);
    final progressSummary =
        progressLabel ??
        (effectiveProgress != null
            ? Strings.dataOperationsProgressLabel(
                effectiveProgress * 100,
                status,
              )
            : status);

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
                      child: indeterminate && effectiveProgress == null
                          ? const ShadProgress()
                          : ShadProgress(value: effectiveProgress ?? 0),
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
                      ],
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
}
