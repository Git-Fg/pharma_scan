import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RestockListItem extends StatelessWidget {
  const RestockListItem({
    required this.item,
    required this.showPrincepsSubtitle,
    required this.onIncrement,
    required this.onDecrement,
    required this.onToggleChecked,
    required this.onDismissed,
    super.key,
  });

  final RestockItemEntity item;
  final bool showPrincepsSubtitle;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onToggleChecked;
  final void Function(DismissDirection) onDismissed;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.cip),
      direction: DismissDirection.endToStart,
      background: Container(
        color: context.shadColors.destructive,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
        child: Icon(
          LucideIcons.trash,
          color: context.shadColors.destructiveForeground,
        ),
      ),
      onDismissed: onDismissed,
      child: ShadCard(
        padding: const EdgeInsets.all(AppDimens.spacingMd),
        child: Row(
          children: [
            ShadCheckbox(
              value: item.isChecked,
              onChanged: (_) => onToggleChecked(),
            ),
            const Gap(AppDimens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: context.shadTextTheme.p,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showPrincepsSubtitle && item.princepsLabel != null)
                    Text(
                      Strings.restockSubtitlePrinceps(item.princepsLabel!),
                      style: context.shadTextTheme.muted.copyWith(
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Gap(AppDimens.spacingMd),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadButton.ghost(
                  onPressed: onDecrement,
                  child: const Icon(
                    LucideIcons.minus,
                    size: AppDimens.iconSm,
                  ),
                ),
                Text(
                  item.quantity.toString(),
                  style: context.shadTextTheme.p,
                ),
                ShadButton.ghost(
                  onPressed: onIncrement,
                  child: const Icon(
                    LucideIcons.plus,
                    size: AppDimens.iconSm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
