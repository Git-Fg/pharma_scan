import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Centralized animation effects and timing constants for the PharmaScan app.
///
/// This file provides reusable Effect instances that can be used throughout
/// the application to ensure consistent animation behavior and maintainability.
class AppAnimations {
  AppAnimations._();

  // Timing constants for standardized animation durations
  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration standardDuration = Duration(milliseconds: 300);
  static const Duration mediumDuration = Duration(milliseconds: 400);
  static const Duration slowDuration = Duration(milliseconds: 600);

  // Standard animation curve used across the app
  static const Curve standardCurve = Curves.easeOutCubic;

  /// Standard card entrance animation.
  /// Used for general card widgets entering the screen.
  static const List<Effect<void>> cardEnter = [
    FadeEffect(duration: standardDuration, curve: standardCurve),
    SlideEffect(
      begin: Offset(0, -0.1),
      end: Offset.zero,
      duration: standardDuration,
      curve: standardCurve,
    ),
  ];

  /// Info bubble entrance animation.
  /// Used for scan result info bubbles (generic and princeps).
  static const List<Effect<void>> bubbleEnter = [
    FadeEffect(duration: standardDuration, curve: standardCurve),
    SlideEffect(
      begin: Offset(0, -0.2),
      end: Offset.zero,
      duration: standardDuration,
      curve: standardCurve,
    ),
  ];

  /// Banner/snackbar entrance animation.
  /// Used for status banners and notification cards.
  static const List<Effect<void>> bannerEnter = [
    FadeEffect(duration: Duration(milliseconds: 250), curve: standardCurve),
    SlideEffect(
      begin: Offset(0, -0.1),
      end: Offset.zero,
      duration: Duration(milliseconds: 250),
      curve: standardCurve,
    ),
  ];

  /// List item entrance animation (for use with staggered lists).
  /// Apply this effect to individual list items with an interval.
  static const List<Effect<void>> listItemEnter = [
    FadeEffect(duration: fastDuration, curve: standardCurve),
    SlideEffect(
      begin: Offset(0, 0.05),
      end: Offset.zero,
      duration: fastDuration,
      curve: standardCurve,
    ),
  ];

  /// Loading skeleton animation with shimmer effect.
  /// Used for loading placeholders in lists.
  ///
  /// **Theme-Aware:** Accepts a shimmer color parameter to ensure visibility
  /// in both light and dark themes. Pass a color derived from the theme:
  /// - Light mode: `theme.colorScheme.foreground.withOpacity(0.1)`
  /// - Dark mode: `theme.colorScheme.foreground.withOpacity(0.2)`
  static List<Effect<void>> getSkeletonShimmer(Color shimmerColor) => [
    const FadeEffect(
      duration: Duration(milliseconds: 180),
      curve: standardCurve,
    ),
    const SlideEffect(
      begin: Offset(0, 0.04),
      end: Offset.zero,
      duration: Duration(milliseconds: 180),
      curve: Curves.easeOut,
    ),
    ShimmerEffect(
      duration: const Duration(milliseconds: 1200),
      color: shimmerColor,
    ),
  ];

  /// Simple fade-in animation for subtle entrances.
  static const List<Effect<void>> fadeIn = [
    FadeEffect(duration: slowDuration, curve: standardCurve),
  ];

  /// Button/control panel entrance animation.
  /// Used for control panels that slide up from bottom.
  static const List<Effect<void>> controlPanelEnter = [
    FadeEffect(duration: mediumDuration, curve: standardCurve),
    SlideEffect(
      begin: Offset(0, 0.5),
      end: Offset.zero,
      duration: mediumDuration,
      delay: Duration(milliseconds: 200),
      curve: standardCurve,
    ),
  ];

  /// Loading indicator animation with pulse effect.
  /// Used for prominent loading indicators that need to grab attention.
  static const List<Effect<void>> loadingPulse = [
    FadeEffect(duration: Duration(milliseconds: 800), curve: Curves.easeInOut),
    ScaleEffect(
      begin: Offset(0.9, 0.9),
      end: Offset(1, 1),
      duration: Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
    ),
  ];
}
