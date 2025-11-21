import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ScanWindowOverlay extends StatefulWidget {
  const ScanWindowOverlay({super.key});

  static const double _windowSize = 220;
  static const double _borderRadius = 14;
  static const double _cornerLength = 22;

  @override
  State<ScanWindowOverlay> createState() => _ScanWindowOverlayState();
}

class _ScanWindowOverlayState extends State<ScanWindowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breathingAnimation = Tween<double>(begin: 1, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final borderColor = theme.colorScheme.primary.withValues(alpha: 0.85);

    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _breathingAnimation,
          builder: (context, child) {
            final scale = _breathingAnimation.value;
            return CustomPaint(
              size: Size.square(ScanWindowOverlay._windowSize * scale),
              painter: _ScanWindowPainter(
                borderColor: borderColor,
                cornerLength: ScanWindowOverlay._cornerLength,
                borderRadius: ScanWindowOverlay._borderRadius,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  const _ScanWindowPainter({
    required this.borderColor,
    required this.cornerLength,
    required this.borderRadius,
  });

  final Color borderColor;
  final double cornerLength;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Top-left corner
    path.moveTo(0, cornerLength);
    path.lineTo(0, 0);
    path.lineTo(cornerLength, 0);
    // Top-right corner
    path.moveTo(width - cornerLength, 0);
    path.lineTo(width, 0);
    path.lineTo(width, cornerLength);
    // Bottom-right corner
    path.moveTo(width, height - cornerLength);
    path.lineTo(width, height);
    path.lineTo(width - cornerLength, height);
    // Bottom-left corner
    path.moveTo(cornerLength, height);
    path.lineTo(0, height);
    path.lineTo(0, height - cornerLength);

    canvas.drawPath(path, cornerPaint);

    final guidePaint = Paint()
      ..color = borderColor.withValues(alpha: 0.18)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rect = Offset.zero & size;
    final roundedRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(roundedRect, guidePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanWindowPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.borderRadius != borderRadius;
  }
}
