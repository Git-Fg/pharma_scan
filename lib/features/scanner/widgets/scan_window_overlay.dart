import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ScanWindowOverlay extends StatelessWidget {
  const ScanWindowOverlay({super.key});

  static const double _windowSize = 250;
  static const double _borderRadius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return IgnorePointer(
      child: Center(
        child: CustomPaint(
          size: const Size.square(_windowSize),
          painter: _ScanWindowPainter(
            borderColor: theme.colorScheme.foreground.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  const _ScanWindowPainter({required this.borderColor});

  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(ScanWindowOverlay._borderRadius),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanWindowPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor;
  }
}
