import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:forui/forui.dart';

/// Custom badge palette aligned with PharmaScan semantics.
FBadgeStyles badgeStyles({
  required FColors colors,
  required FTypography typography,
  required FStyle style,
}) {
  final generic = _filledBadgeStyle(
    background: colors.primary,
    foreground: colors.primaryForeground,
    typography: typography,
  );

  final princeps = _filledBadgeStyle(
    background: colors.secondary,
    foreground: colors.secondaryForeground,
    typography: typography,
  );

  final standalone = _filledBadgeStyle(
    background: colors.muted,
    foreground: colors.foreground,
    typography: typography,
  );

  final condition = FBadgeStyle(
    decoration: BoxDecoration(
      color: colors.background,
      border: Border.all(color: colors.border, width: style.borderWidth),
      borderRadius: FBadgeStyles.defaultRadius,
    ),
    contentStyle: FBadgeContentStyle(
      labelTextStyle: typography.sm.copyWith(
        color: colors.mutedForeground,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
      ),
    ),
  );

  final alert = _filledBadgeStyle(
    background: colors.destructive,
    foreground: colors.destructiveForeground,
    typography: typography,
  );

  return PharmaBadgeStyles(
    generic: generic,
    princeps: princeps,
    standalone: standalone,
    condition: condition,
    alert: alert,
  );
}

class PharmaBadgeStyles extends FBadgeStyles {
  PharmaBadgeStyles({
    required this.generic,
    required this.princeps,
    required this.standalone,
    required this.condition,
    required this.alert,
  }) : super(
         primary: generic,
         secondary: princeps,
         outline: condition,
         destructive: alert,
       );

  final FBadgeStyle generic;
  final FBadgeStyle princeps;
  final FBadgeStyle standalone;
  final FBadgeStyle condition;
  final FBadgeStyle alert;
}

extension PharmaBadgeStylesLookup on FBadgeStyles {
  PharmaBadgeStyles get _pharma => this is PharmaBadgeStyles
      ? this as PharmaBadgeStyles
      : PharmaBadgeStyles(
          generic: primary,
          princeps: secondary,
          standalone: outline,
          condition: outline,
          alert: destructive,
        );

  FBaseBadgeStyle Function(FBadgeStyle) get generic =>
      (_) => _pharma.generic;

  FBaseBadgeStyle Function(FBadgeStyle) get princeps =>
      (_) => _pharma.princeps;

  FBaseBadgeStyle Function(FBadgeStyle) get standalone =>
      (_) => _pharma.standalone;

  FBaseBadgeStyle Function(FBadgeStyle) get condition =>
      (_) => _pharma.condition;

  FBaseBadgeStyle Function(FBadgeStyle) get alert =>
      (_) => _pharma.alert;
}

FBadgeStyle _filledBadgeStyle({
  required Color background,
  required Color foreground,
  required FTypography typography,
}) => FBadgeStyle(
  decoration: BoxDecoration(
    color: background,
    borderRadius: FBadgeStyles.defaultRadius,
  ),
  contentStyle: FBadgeContentStyle(
    labelTextStyle: typography.sm.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.25,
    ),
  ),
);
