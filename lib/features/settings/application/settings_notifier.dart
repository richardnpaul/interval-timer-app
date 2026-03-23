import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/features/settings/domain/settings_domain.dart';
import 'package:interval_timer_app/core/services/storage_service.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final StorageService _storage;

  SettingsRepositoryImpl(this._storage);

  @override
  Settings loadSettings() {
    return Settings(
      startCueEnabled: _storage.isStartCueEnabled(),
      endCueEnabled: _storage.isEndCueEnabled(),
    );
  }

  @override
  Future<void> saveSettings(Settings settings) async {
    await _storage.setStartCueEnabled(settings.startCueEnabled);
    await _storage.setEndCueEnabled(settings.endCueEnabled);
  }
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() {
    return ref.watch(settingsRepositoryProvider).loadSettings();
  }

  Future<void> toggleStartCue(bool enabled) async {
    state = state.copyWith(startCueEnabled: enabled);
    await ref.read(settingsRepositoryProvider).saveSettings(state);
  }

  Future<void> toggleEndCue(bool enabled) async {
    state = state.copyWith(endCueEnabled: enabled);
    await ref.read(settingsRepositoryProvider).saveSettings(state);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsRepositoryImpl(storage);
});

final settingsNotifierProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
