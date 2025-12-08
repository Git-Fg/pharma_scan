import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

typedef ShadcnNavItem = ({
  IconData icon,
  IconData? activeIcon,
  String label,
  String? testId,
});

class ShadcnBottomNav extends StatelessWidget {
  const ShadcnBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    super.key,
  }) : assert(items.length > 1, 'Navigation requires at least two items');

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<ShadcnNavItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border(
          top: BorderSide(color: theme.colorScheme.border),
        ),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: bottomPadding + 8,
      ),
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == currentIndex;
          final color = isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.mutedForeground;

          final button = ShadButton.raw(
            onPressed: () => onTap(index),
            variant: ShadButtonVariant.ghost,
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected && item.activeIcon != null
                      ? item.activeIcon
                      : item.icon,
                  size: 18,
                  color: color,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  style: theme.textTheme.small.copyWith(
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 11,
                    height: 1,
                  ),
                ),
              ],
            ),
          );

          return Expanded(
            child: item.testId != null
                ? Testable(
                    id: item.testId ?? TestTags.navScanner,
                    child: button,
                  )
                : button,
          );
        }).toList(),
      ),
    );
  }
}
