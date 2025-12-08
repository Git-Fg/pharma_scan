import 'package:flutter/services.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'haptic_service.g.dart';

@Riverpod(keepAlive: true)
HapticService hapticService(Ref ref) {
  final enabled = ref
      .watch(hapticSettingsProvider)
      .maybeWhen(
        data: (value) => value,
        orElse: () => true,
      );
  return HapticService(enabled: enabled);
}

/// Single smart haptics service that owns the enabled flag.
class HapticService {
  const HapticService({required bool enabled}) : _enabled = enabled;

  final bool _enabled;

  Future<void> success() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> warning() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> error() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> selection() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> heavyImpact() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> errorVibration() async {
    if (!_enabled) return;
    await HapticFeedback.vibrate();
  }
}
