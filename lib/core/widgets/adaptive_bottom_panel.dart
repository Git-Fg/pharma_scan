import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// WHY: Provide a reusable safe-area-aware container for bottom control panels
/// that can gracefully handle varying font scales and small screens without
/// bespoke padding logic in each screen.
class AdaptiveBottomPanel extends StatelessWidget {
  const AdaptiveBottomPanel({
    required this.children, super.key,
    this.gap = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  final List<Widget> children;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    children[index],
                    if (index < children.length - 1) Gap(gap),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
