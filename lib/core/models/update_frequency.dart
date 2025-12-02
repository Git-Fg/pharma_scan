enum UpdateFrequency {
  none(Duration.zero),
  daily(Duration(days: 1)),
  weekly(Duration(days: 7)),
  monthly(Duration(days: 30));

  const UpdateFrequency(this.interval);

  final Duration interval;

  String get storageValue => name;

  static UpdateFrequency fromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return UpdateFrequency.daily;
    return UpdateFrequency.values.firstWhere(
      (value) => value.storageValue == raw,
      orElse: () => UpdateFrequency.daily,
    );
  }
}
