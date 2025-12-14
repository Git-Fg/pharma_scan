import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/hooks/use_scanner_logic.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/core/ui/theme/app_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum _ReticleState { idle, detecting, success }

class ScanWindowOverlay extends HookConsumerWidget {
  const ScanWindowOverlay({required this.mode, super.key});

  final ScannerMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ShadResponsiveBuilder(
      builder: (context, breakpoint) {
        final windowSize =
            (MediaQuery.sizeOf(context).width * 0.7).clamp(250.0, 350.0);
        final borderRadius = context.radiusMedium.topLeft.x;
        final scrimColor = Colors.black.withValues(alpha: 0.3);

        // Use Signals for high-frequency bubble count updates
        final scannerLogic = useScannerLogic(ref);
        final bubblesCount = scannerLogic.bubbleCount.value as int;
        final scannerAsync = ref.watch(scannerProvider);
        final isLoading = scannerAsync.isLoading;

        final reticleState = useState<_ReticleState>(_ReticleState.idle);
        final previousCount = useRef<int>(0);
        final successResetTimer = useRef<Timer?>(null);

        useEffect(
          () {
            final prev = previousCount.value;
            previousCount.value = bubblesCount;

            if (bubblesCount > prev) {
              reticleState.value = _ReticleState.success;
              successResetTimer.value?.cancel();
              successResetTimer.value =
                  Timer(const Duration(milliseconds: 650), () {
                reticleState.value = _ReticleState.idle;
              });
            } else if (reticleState.value != _ReticleState.success) {
              reticleState.value =
                  isLoading ? _ReticleState.detecting : _ReticleState.idle;
            }

            return () => successResetTimer.value?.cancel();
          },
          [bubblesCount, isLoading],
        );

        useEffect(
          () => () {
            successResetTimer.value?.cancel();
          },
          const [],
        );

        final modeColor = mode == ScannerMode.restock
            ? context.textNegative
            : context.actionPrimary;

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _ScanScrimPainter(
                  scrimColor: scrimColor,
                  windowSize: windowSize,
                  borderRadius: borderRadius,
                ),
              ),
              Center(
                child: _Reticle(
                  windowSize: windowSize,
                  borderRadius: borderRadius,
                  state: reticleState.value,
                  modeColor: modeColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Reticle extends HookWidget {
  const _Reticle({
    required this.windowSize,
    required this.borderRadius,
    required this.state,
    required this.modeColor,
  });

  final double windowSize;
  final double borderRadius;
  final _ReticleState state;
  final Color modeColor;

  @override
  Widget build(BuildContext context) {
    final baseColor = modeColor.withValues(alpha: 0.9);
    final detectingColor = modeColor.withValues(alpha: 0.65);
    final successColor = modeColor;

    final breathingController = useAnimationController(
      duration: const Duration(milliseconds: 1500),
    );

    useEffect(
      () {
        unawaited(breathingController.repeat(reverse: true));
        return breathingController.dispose;
      },
      [],
    );
    final breathingScale = useAnimation(
      Tween<double>(begin: 1, end: 1.05).animate(
        CurvedAnimation(
          parent: breathingController,
          curve: Curves.easeInOut,
        ),
      ),
    );

    final targetScale = switch (state) {
      _ReticleState.success => 0.9,
      _ReticleState.detecting => 1.02,
      _ReticleState.idle => breathingScale,
    };

    final targetColor = switch (state) {
      _ReticleState.success => successColor,
      _ReticleState.detecting => detectingColor,
      _ReticleState.idle => baseColor,
    };

    final iconContainerSize = windowSize *
        (AppDimens.scannerWindowIconSize / AppDimens.scannerWindowSize);
    final iconInnerSize = windowSize *
        (AppDimens.scannerWindowIconInnerSize / AppDimens.scannerWindowSize);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: targetScale),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          // ignore: unchecked_use_of_nullable_value
          child: (child ?? const SizedBox())
              .animate()
              .fade(
                duration: const Duration(milliseconds: 220),
              )
              .value(state == _ReticleState.success ? 1.0 : 0.9),
        );
      },
      child: SizedBox(
        width: windowSize,
        height: windowSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              painter: _ScanCornerPainter(
                color: targetColor,
                cornerLength: AppDimens.scannerWindowCornerLength,
                cornerThickness: AppDimens.scannerWindowCornerThickness,
                borderRadius: borderRadius,
              ),
            ),
            Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: context.surfacePrimary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: targetColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.qr_code_scanner,
                color: targetColor,
                size: iconInnerSize,
              ),
            ),
          ],
        ),
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
    final inset = math.max(cornerThickness / 2, 1).toDouble();
    final path = Path()
      ..moveTo(inset, cornerLength)
      ..lineTo(inset, inset)
      ..lineTo(cornerLength, inset)
      ..moveTo((width - cornerLength), inset)
      ..lineTo((width - inset), inset)
      ..lineTo(width - inset, cornerLength)
      ..moveTo(width - inset, height - cornerLength)
      ..lineTo(width - inset, height - inset)
      ..lineTo(width - cornerLength, height - inset)
      ..moveTo(cornerLength, height - inset)
      ..lineTo(inset, (height - inset))
      ..lineTo(inset, (height - cornerLength));

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
