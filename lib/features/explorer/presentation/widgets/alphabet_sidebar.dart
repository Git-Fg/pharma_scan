import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';

class AlphabetSidebar extends StatefulWidget {
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
  State<AlphabetSidebar> createState() => _AlphabetSidebarState();
}

class _AlphabetSidebarState extends State<AlphabetSidebar> {
  int? _selectedIndex;
  final GlobalKey _key = GlobalKey();

  void _handleEvent(Offset localPosition, double totalHeight) {
    final itemHeight = totalHeight / widget.letters.length;
    final index = (localPosition.dy / itemHeight).floor();

    if (index >= 0 &&
        index < widget.letters.length &&
        index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      widget.onLetterChanged(widget.letters[index]);
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _clearSelection() {
    setState(() => _selectedIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final primaryColor = theme.colorScheme.primary;

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onVerticalDragDown: (details) => _handleEvent(
          details.localPosition,
          _key.currentContext!.size!.height,
        ),
        onVerticalDragUpdate: (details) => _handleEvent(
          details.localPosition,
          _key.currentContext!.size!.height,
        ),
        onVerticalDragEnd: (_) => _clearSelection(),
        onVerticalDragCancel: _clearSelection,
        onTapUp: (_) => _clearSelection(),
        onTapDown: (details) => _handleEvent(
          details.localPosition,
          _key.currentContext!.size!.height,
        ),
        child: Container(
          key: _key,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
          width: 48,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerRight,
                children: [
                  if (_selectedIndex != null)
                    Positioned(
                      right: 45,
                      top:
                          (_selectedIndex! *
                              (constraints.maxHeight / widget.letters.length)) -
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
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.letters[_selectedIndex!],
                          style: theme.textTheme.h2.copyWith(
                            color: theme.colorScheme.primaryForeground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: widget.letters.asMap().entries.map((entry) {
                      final isSelected = entry.key == _selectedIndex;
                      return Expanded(
                        child: Center(
                          child: Text(
                            entry.value,
                            style: theme.textTheme.small.copyWith(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
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
