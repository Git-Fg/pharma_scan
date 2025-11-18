// lib/core/models/parsed_name.dart

import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'parsed_name.freezed.dart';

@freezed
abstract class Dosage with _$Dosage {
  const factory Dosage({
    required Decimal value,
    required String unit,
    @Default(false) bool isRatio,
    String? raw,
  }) = _Dosage;
}

@freezed
abstract class ParsedName with _$ParsedName {
  const factory ParsedName({
    required String original,
    String? baseName,
    @Default(<Dosage>[]) List<Dosage> dosages,
    String? formulation,
  }) = _ParsedName;
}
