import 'package:dart_mappable/dart_mappable.dart';

part 'update_frequency.mapper.dart';

@MappableEnum(mode: ValuesMode.named)
enum UpdateFrequency {
  none(Duration.zero),
  daily(Duration(days: 1)),
  weekly(Duration(days: 7)),
  monthly(Duration(days: 30));

  const UpdateFrequency(this.interval);

  final Duration interval;
}
