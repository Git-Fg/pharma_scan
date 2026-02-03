import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';

class AlphabetSidebar extends HookWidget {
  const AlphabetSidebar({
    required this.onLetterChanged,
    super.key,
    this.letters = const [
      '#',
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'J',
      'K',
      'L',
      'M',
      'N',
      'P',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ],
  });

  final List<String> letters;
  final ValueChanged<String> onLetterChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = useState<int?>(null);
    final key = useMemoized(GlobalKey.new);
    final theme = context.shadTheme;
    final primaryColor = theme.colorScheme.primary;

    void handleEvent(Offset localPosition, double totalHeight) {
      final itemHeight = totalHeight / letters.length;
      final index = (localPosition.dy / itemHeight).floor();

      if (index >= 0 &&
          index < letters.length &&
          index != selectedIndex.value) {
        selectedIndex.value = index;
        onLetterChanged(letters[index]);
        unawaited(HapticFeedback.selectionClick());
      }
    }

    void clearSelection() {
      selectedIndex.value = null;
    }

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onVerticalDragDown: (details) => handleEvent(
          details.localPosition,
          key.currentContext!.size!.height,
        ),
        onVerticalDragUpdate: (details) => handleEvent(
          details.localPosition,
          key.currentContext!.size!.height,
        ),
        onVerticalDragEnd: (_) => clearSelection(),
        onVerticalDragCancel: clearSelection,
        onTapUp: (_) => clearSelection(),
        onTapDown: (details) => handleEvent(
          details.localPosition,
          key.currentContext!.size!.height,
        ),
        child: Container(
          key: key,
          color: context.colors.background.withValues(alpha: 0),
          padding: const .symmetric(horizontal: 8, vertical: 20),
          width: 48,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerRight,
                children: [
                  if (selectedIndex.value != null)
                    Positioned(
                      right: 45,
                      top:
                          (selectedIndex.value! *
                              (constraints.maxHeight / letters.length)) -
                          32,
                      child: Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.foreground.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 10,
                              offset: const .new(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          letters[selectedIndex.value!],
                          style: theme.textTheme.h2.copyWith(
                            color: theme.colorScheme.primaryForeground,
                            fontWeight: .bold,
                          ),
                        ),
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: letters.asMap().entries.map((entry) {
                      final isSelected = entry.key == selectedIndex.value;
                      return Expanded(
                        child: Center(
                          child: Text(
                            entry.value,
                            style: theme.textTheme.small.copyWith(
                              fontSize: 12,
                              fontWeight: isSelected ? .w800 : .w600,
                              color: isSelected
                                  ? primaryColor
                                  : theme.colorScheme.mutedForeground,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
