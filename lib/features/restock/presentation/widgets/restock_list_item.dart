import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/ui_helpers.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RestockListItem extends StatelessWidget {
  const RestockListItem({
    required this.item,
    required this.showPrincepsSubtitle,
    required this.haptics,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAddTen,
    required this.onSetQuantity,
    required this.onToggleChecked,
    required this.onDismissed,
    super.key,
  });

  final RestockItemEntity item;
  final bool showPrincepsSubtitle;
  final HapticService haptics;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onAddTen;
  final ValueChanged<int> onSetQuantity;
  final VoidCallback onToggleChecked;
  final void Function(DismissDirection) onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final isZero = item.quantity == 0;
    final contentOpacity = isZero ? 0.5 : 1.0;
    final backgroundColor = isZero
        ? theme.colorScheme.muted.withValues(alpha: 0.1)
        : theme.colorScheme.card;
    final formColor = getFormColor(context.shadColors, item.form);
    final borderColor = isZero
        ? theme.colorScheme.border.withValues(alpha: 0.5)
        : theme.colorScheme.border;

    return Dismissible(
      key: ValueKey(item.cip),
      background: Container(
        color: context.shadColors.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
        child: const Icon(
          LucideIcons.check,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        color: context.shadColors.destructive,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
        child: const Icon(
          LucideIcons.trash2,
          color: Colors.white,
          size: AppDimens.iconLg,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggleChecked();
          return false;
        }
        return true;
      },
      onDismissed: onDismissed,
      child: GestureDetector(
        onLongPress: () async {
          final text = formatForClipboard(
            quantity: item.quantity,
            label: item.label,
            cip: item.cip.toString(),
          );
          await Clipboard.setData(ClipboardData(text: text));
          await haptics.selection();
          if (!context.mounted) return;
          ShadToaster.of(context).show(
            const ShadToast(
              title: Text(Strings.restockCopiedTitle),
              description: Text(Strings.restockCopiedDescription),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(
            minHeight: AppDimens.listTileMinHeight,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: theme.radius,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: formColor,
                  borderRadius: BorderRadius.only(
                    topLeft: theme.radius.topLeft,
                    bottomLeft: theme.radius.bottomLeft,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingMd,
                    vertical: AppDimens.spacingSm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: context.shadTextTheme.p.copyWith(
                                  decoration: isZero
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (showPrincepsSubtitle &&
                                  item.princepsLabel != null)
                                Text(
                                  Strings.restockSubtitlePrinceps(
                                    item.princepsLabel!,
                                  ),
                                  style: context.shadTextTheme.muted.copyWith(
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Gap(AppDimens.spacingSm),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              foregroundColor: isZero
                                  ? theme.colorScheme.destructive
                                  : theme.colorScheme.foreground,
                            ),
                            onPressed: () async {
                              if (isZero) {
                                await haptics.deleteImpact();
                              } else if (item.quantity == 1) {
                                await haptics.heavyImpact();
                              } else {
                                await haptics.selection();
                              }
                              onDecrement();
                            },
                            icon: Icon(
                              isZero ? LucideIcons.trash2 : LucideIcons.minus,
                              size: AppDimens.iconSm,
                            ),
                          ),
                          const SizedBox(width: AppDimens.spacing2xs),
                          GestureDetector(
                            onTap: () => _showQuantityDialog(
                              context,
                              item.quantity,
                            ),
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 32,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.spacing2xs,
                                vertical: AppDimens.spacing2xs,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                item.quantity.toString(),
                                style: theme.textTheme.large.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isZero
                                      ? theme.colorScheme.mutedForeground
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimens.spacing2xs),
                          IconButton(
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            style: IconButton.styleFrom(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () async {
                              await haptics.selection();
                              onIncrement();
                            },
                            icon: const Icon(
                              LucideIcons.plus,
                              size: AppDimens.iconSm,
                            ),
                          ),
                          const SizedBox(width: AppDimens.spacing2xs),
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.spacing2xs,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () async {
                              await haptics.mediumImpact();
                              onAddTen();
                            },
                            child: const Text(
                              Strings.restockAddTenLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppDimens.spacingSm),
                      Opacity(
                        opacity: contentOpacity,
                        child: ShadCheckbox(
                          value: item.isChecked,
                          onChanged: (_) => onToggleChecked(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showQuantityDialog(BuildContext context, int current) async {
    final controller = TextEditingController(text: current.toString());
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    final result = await showShadDialog<int>(
      context: context,
      builder: (dialogContext) {
        return ShadDialog(
          title: const Text(Strings.restockSetQuantityTitle),
          description: const Text(Strings.restockSetQuantityDescription),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(Strings.cancel),
            ),
            ShadButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed < 0) return;
                Navigator.of(dialogContext).pop(parsed);
              },
              child: const Text(Strings.confirmButtonLabel),
            ),
          ],
          child: Semantics(
            textField: true,
            label: Strings.restockQuantityFieldLabel,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280),
              child: ShadInput(
                controller: controller,
                keyboardType: TextInputType.number,
                placeholder: const Text(Strings.restockQuantityFieldHint),
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    if (!context.mounted) return;
    onSetQuantity(result);
  }
}
