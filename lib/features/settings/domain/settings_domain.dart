class Settings {
  final bool startCueEnabled;
  final bool endCueEnabled;

  const Settings({required this.startCueEnabled, required this.endCueEnabled});

  Settings copyWith({bool? startCueEnabled, bool? endCueEnabled}) {
    return Settings(
      startCueEnabled: startCueEnabled ?? this.startCueEnabled,
      endCueEnabled: endCueEnabled ?? this.endCueEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settings &&
          runtimeType == other.runtimeType &&
          startCueEnabled == other.startCueEnabled &&
          endCueEnabled == other.endCueEnabled;

  @override
  int get hashCode => startCueEnabled.hashCode ^ endCueEnabled.hashCode;
}

abstract class SettingsRepository {
  Settings loadSettings();
  Future<void> saveSettings(Settings settings);
}
