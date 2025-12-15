import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/providers/history_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class HistorySheet extends ConsumerWidget {
  const HistorySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyControllerProvider);
    final isClearing = historyAsync.isLoading && historyAsync.hasValue;
    final spacing = context.spacing;

    return ShadSheet(
      title: const Text(Strings.historyTitle),
      description: const Text(Strings.historySubtitle),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sheetHeight = (constraints.maxHeight * 0.8).clamp(400.0, 800.0);
          return SafeArea(
            minimum: EdgeInsets.symmetric(
              vertical: spacing.md,
            ),
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                children: [
                  Expanded(
                    child: historyAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, _) => Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: spacing.md,
                        ),
                        child: Text(Strings.historyError(err.toString())),
                      ),
                      data: (items) {
                        if (items.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: spacing.lg,
                            ),
                            child: Center(
                              child: Text(
                                Strings.historyEmpty,
                                style: context.typo.small.copyWith(
                                  color: context.colors.mutedForeground,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (context, _) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final princepsRef = item.princepsDeReference;
                            final showPrincepsRef = princepsRef != null &&
                                princepsRef.trim().isNotEmpty;
                            final trailingTime = DateFormat(
                              'HH:mm',
                            ).format(item.scannedAt.toLocal());

                            return ShadButton.raw(
                              onPressed: () async {
                                await Navigator.of(context).maybePop();
                              },
                              variant: ShadButtonVariant.ghost,
                              width: double.infinity,
                              padding: EdgeInsets.zero,
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 48),
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacing.md,
                                  vertical: spacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.label,
                                            style: context.typo.small.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (showPrincepsRef) ...[
                                            Gap(spacing.xs / 2),
                                            Text(
                                              Strings.historyPrincepsReference(
                                                princepsRef,
                                              ),
                                              style: context.typo.muted,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Gap(spacing.sm),
                                    Text(
                                      trailingTime,
                                      style: context.typo.muted.copyWith(
                                        fontSize: 10,
                                      ),
                                    ),
                                    Gap(spacing.xs),
                                    Icon(
                                      LucideIcons.chevronRight,
                                      size: 16,
                                      color: context.colors.mutedForeground,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Gap(spacing.sm),
                  ShadButton.destructive(
                    leading: const Icon(LucideIcons.trash2, size: 16),
                    onPressed: isClearing
                        ? null
                        : () => _confirmClearHistory(context, ref),
                    child: const Text(Strings.historyClear),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        title: const Text(Strings.historyClearConfirmTitle),
        description: Padding(
          padding: EdgeInsets.only(bottom: context.spacing.xs),
          child: const Text(Strings.historyClearConfirmDescription),
        ),
        actions: [
          ShadButton.outline(
            child: const Text(Strings.cancel),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          ShadButton.destructive(
            child: const Text(Strings.confirm),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(historyControllerProvider.notifier).clearHistory();
  }
}
