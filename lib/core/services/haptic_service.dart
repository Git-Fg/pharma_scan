import 'dart:async';

import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'haptic_service.g.dart';

@Riverpod(keepAlive: true)
HapticService hapticService(Ref ref) {
  // Le provider sera configuré dans core_providers.dart
  return HapticService(enabled: true);
}

/// Single smart haptics service that owns the enabled flag.
class HapticService {
  const HapticService({required bool enabled}) : _enabled = enabled;

  final bool _enabled;

  Future<void> analysisSuccess() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  Future<void> restockSuccess() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }

  Future<void> duplicate() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await HapticFeedback.heavyImpact();
  }

  Future<void> warning() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> error() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> unknown() async {
    if (!_enabled) return;
    await HapticFeedback.vibrate();
  }

  // Backward-compatible aliases
  Future<void> success() => analysisSuccess();

  Future<void> selection() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  Future<void> mediumImpact() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  Future<void> heavyImpact() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  Future<void> deleteImpact() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  Future<void> errorVibration() async {
    if (!_enabled) return;
    await HapticFeedback.vibrate();
  }
}
