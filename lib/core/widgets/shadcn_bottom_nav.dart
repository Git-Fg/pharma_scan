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
    final primaryColor = theme.colorScheme.primary;
    final backgroundColor = theme.colorScheme.background;
    final borderColor = theme.colorScheme.border;

    return SafeArea(
      top: false,
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            top: BorderSide(color: borderColor.withValues(alpha: 0.5)),
          ),
        ),
        padding: const .symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = index == currentIndex;
            final color = isSelected
                ? primaryColor
                : theme.colorScheme.mutedForeground;

            final button = ShadButton.raw(
              key: item.testId != null ? Key(item.testId!) : null,
              onPressed: () {
                if (isSelected && onReselect != null) {
                  onReselect!(index);
                } else {
                  onTap(index);
                }
              },
              variant: ShadButtonVariant.ghost,
              padding: const .symmetric(vertical: 4, horizontal: 8),
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: isSelected ? 40 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            color.withValues(alpha: 0.0),
                            color,
                            color.withValues(alpha: 0.0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(
                      isSelected && item.activeIcon != null
                          ? item.activeIcon
                          : item.icon,
                      size: 24,
                      color: color,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: theme.textTheme.small.copyWith(
                        color: color,
                        fontWeight: isSelected ? .w600 : .w400,
                        fontSize: 12,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );

            return Expanded(child: button);
          }).toList(),
        ),
      ),
    );
  }
}
