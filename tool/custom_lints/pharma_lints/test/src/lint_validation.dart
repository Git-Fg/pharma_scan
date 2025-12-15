import 'package:flutter/material.dart';

// expect_lint: avoid_direct_colors
final c = Color(0xFF000000);

// expect_lint: avoid_direct_colors
final c2 = Colors.red;

// expect_lint: enforce_dto_conversion
class BadModel {
  final String id;
  BadModel(this.id);
}

class GoodModel {
  final String id;
  GoodModel(this.id);

  String toEntity() => id;
}
