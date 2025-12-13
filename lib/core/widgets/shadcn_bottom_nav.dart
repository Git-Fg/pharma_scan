import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
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
    this.onReselect,
    super.key,
  }) : assert(items.length > 1, 'Navigation requires at least two items');

  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onReselect;
  final List<ShadcnNavItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: theme.colorScheme.background,
          border: Border(
            top: BorderSide(color: theme.colorScheme.border),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = index == currentIndex;
            final color = isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.mutedForeground;

            final button = ShadButton.raw(
              onPressed: () {
                if (isSelected && onReselect != null) {
                  onReselect!(index);
                } else {
                  onTap(index);
                }
              },
              variant: ShadButtonVariant.ghost,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected && item.activeIcon != null
                          ? item.activeIcon
                          : item.icon,
                      size: 24,
                      color: color,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: theme.textTheme.small.copyWith(
                        color: color,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 12,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );

            return Expanded(
              child: button,
            );
          }).toList(),
        ),
      ),
    );
  }
}
