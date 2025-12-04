import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ScanWindowOverlay extends StatelessWidget {
  const ScanWindowOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final primary = theme.colorScheme.primary;
    final scrimColor = theme.colorScheme.foreground.withValues(alpha: 0.65);

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _ScanScrimPainter(
              scrimColor: scrimColor,
              windowSize: AppDimens.scannerWindowSize,
              borderRadius: AppDimens.scannerWindowBorderRadius,
            ),
          ),
          Center(
            child: _buildAnimatedCorner(context, primary),
          ),
          Center(
            child: _buildAnimatedIcon(context, primary),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCorner(BuildContext context, Color primary) {
    return SizedBox(
          width: AppDimens.scannerWindowSize,
          height: AppDimens.scannerWindowSize,
          child: CustomPaint(
            painter: _ScanCornerPainter(
              color: primary,
              cornerLength: AppDimens.scannerWindowCornerLength,
              cornerThickness: AppDimens.scannerWindowCornerThickness,
              borderRadius: AppDimens.scannerWindowBorderRadius,
            ),
          ),
        )
        .animate(
          onPlay: (controller) {
            unawaited(controller.repeat(reverse: true));
          },
        )
        .fade(
          begin: 0.35,
          end: 0.9,
          duration: 1800.ms,
          curve: Curves.easeInOutSine,
        );
  }

  Widget _buildAnimatedIcon(BuildContext context, Color primary) {
    return Container(
          width: AppDimens.scannerWindowIconSize,
          height: AppDimens.scannerWindowIconSize,
          decoration: BoxDecoration(
            color: context.shadColors.background.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            LucideIcons.scanLine,
            color: primary.withValues(alpha: 0.9),
            size: AppDimens.scannerWindowIconInnerSize,
          ),
        )
        .animate(
          onPlay: (controller) {
            unawaited(controller.repeat(reverse: true));
          },
        )
        .fade(
          begin: 0.4,
          end: 0.85,
          duration: 1800.ms,
          curve: Curves.easeInOutSine,
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

    canvas
      ..saveLayer(layerRect, Paint())
      ..drawRect(layerRect, paint)
      ..drawRRect(
        RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();
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
