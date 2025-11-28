import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';

class ScanWindowOverlay extends HookWidget {
  const ScanWindowOverlay({super.key});

  static const double _windowSize = 192; // Reduced by 20% (240 * 0.8)
  static const double _borderRadius = 14.4; // Reduced by 20% (18 * 0.8)
  static const double _cornerLength = 20.8; // Reduced by 20% (26 * 0.8)
  static const double _cornerThickness = 4; // Reduced by 20% (5 * 0.8)

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    final pulse = useMemoized(
      () => CurvedAnimation(parent: controller, curve: Curves.easeInOutSine),
      [controller],
    );
    final primary = context.theme.colors.primary;
    final scrimColor = Colors.black.withValues(alpha: 0.65);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          final pulseOpacity = lerpDouble(0.35, 0.9, pulse.value)!;
          final iconOpacity = lerpDouble(0.4, 0.85, pulse.value)!;

          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _ScanScrimPainter(
                  scrimColor: scrimColor,
                  windowSize: ScanWindowOverlay._windowSize,
                  borderRadius: ScanWindowOverlay._borderRadius,
                ),
              ),
              Center(
                child: CustomPaint(
                  size: const Size.square(ScanWindowOverlay._windowSize),
                  painter: _ScanCornerPainter(
                    color: primary.withValues(alpha: pulseOpacity),
                    cornerLength: ScanWindowOverlay._cornerLength,
                    cornerThickness: ScanWindowOverlay._cornerThickness,
                    borderRadius: ScanWindowOverlay._borderRadius,
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: iconOpacity,
                  child: Container(
                    width: 51.2, // Reduced by 20% (64 * 0.8)
                    height: 51.2, // Reduced by 20% (64 * 0.8)
                    decoration: BoxDecoration(
                      color: context.theme.colors.background.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FIcons.scanLine,
                      color: primary.withValues(alpha: 0.9),
                      size: 22.4, // Reduced by 20% (28 * 0.8)
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScanScrimPainter extends CustomPainter {
  const _ScanScrimPainter({
    required this.scrimColor,
    required this.windowSize,
    required this.borderRadius,
  });

  final Color scrimColor;
  final double windowSize;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final layerRect = Offset.zero & size;
    final cutoutRect = Rect.fromCenter(
      center: layerRect.center,
      width: windowSize,
      height: windowSize,
    );

    final paint = Paint()..color = scrimColor;

    canvas.saveLayer(layerRect, Paint());
    canvas.drawRect(layerRect, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScanScrimPainter oldDelegate) {
    return oldDelegate.scrimColor != scrimColor ||
        oldDelegate.windowSize != windowSize ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _ScanCornerPainter extends CustomPainter {
  const _ScanCornerPainter({
    required this.color,
    required this.cornerLength,
    required this.cornerThickness,
    required this.borderRadius,
  });

  final Color color;
  final double cornerLength;
  final double cornerThickness;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = cornerThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final path = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, 0)
      ..lineTo(cornerLength, 0)
      ..moveTo(width - cornerLength, 0)
      ..lineTo(width, 0)
      ..lineTo(width, cornerLength)
      ..moveTo(width, height - cornerLength)
      ..lineTo(width, height)
      ..lineTo(width - cornerLength, height)
      ..moveTo(cornerLength, height)
      ..lineTo(0, height)
      ..lineTo(0, height - cornerLength);

    canvas.drawPath(path, cornerPaint);

    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(borderRadius),
      ),
      guidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanCornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.cornerThickness != cornerThickness ||
        oldDelegate.borderRadius != borderRadius;
  }
}
