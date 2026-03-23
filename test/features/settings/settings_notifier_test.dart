import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:interval_timer_app/features/settings/domain/settings_domain.dart';
import 'package:interval_timer_app/core/services/storage_service.dart';
import 'package:interval_timer_app/features/settings/application/settings_notifier.dart';

@GenerateMocks([StorageService, SettingsRepository])
import 'settings_notifier_test.mocks.dart';

class MockSettingsNotifier extends SettingsNotifier {
  final SettingsRepository mockRepo;
  MockSettingsNotifier(this.mockRepo);

  @override
  Settings build() {
    return mockRepo.loadSettings();
  }

  @override
  set state(Settings value) => super.state = value;
  @override
  Settings get state => super.state;
}

void main() {
  group('Settings Entity', () {
    test('equality and hashCode', () {
      const s1 = Settings(startCueEnabled: true, endCueEnabled: true);
      const s2 = Settings(startCueEnabled: true, endCueEnabled: true);
      const s3 = Settings(startCueEnabled: false, endCueEnabled: true);

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));
      expect(s1.hashCode, isNot(equals(s3.hashCode)));
    });
  });

  group('SettingsRepository', () {
    late StorageService mockStorage;
    late SettingsRepositoryImpl repository;

    setUp(() {
      mockStorage = MockStorageService();
      repository = SettingsRepositoryImpl(mockStorage);
    });

    test('loadSettings reads from storage', () {
      when(mockStorage.isStartCueEnabled()).thenReturn(true);
      when(mockStorage.isEndCueEnabled()).thenReturn(false);

      final settings = repository.loadSettings();

      expect(settings.startCueEnabled, isTrue);
      expect(settings.endCueEnabled, isFalse);
    });

    test('saveSettings writes to storage', () async {
      final settings = const Settings(
        startCueEnabled: false,
        endCueEnabled: true,
      );

      await repository.saveSettings(settings);

      verify(mockStorage.setStartCueEnabled(false)).called(1);
      verify(mockStorage.setEndCueEnabled(true)).called(1);
    });
  });

  group('SettingsNotifier', () {
    late SettingsRepository mockRepo;

    setUp(() {
      mockRepo = MockSettingsRepository();
    });

    test('initial state is loaded from repository', () {
      const initial = Settings(startCueEnabled: true, endCueEnabled: true);
      when(mockRepo.loadSettings()).thenReturn(initial);

      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      final settings = container.read(settingsNotifierProvider);
      expect(settings, initial);
    });

    test('toggleStartCue updates state and saves', () async {
      const initial = Settings(startCueEnabled: true, endCueEnabled: true);
      when(mockRepo.loadSettings()).thenReturn(initial);

      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsNotifierProvider.notifier)
          .toggleStartCue(false);

      expect(container.read(settingsNotifierProvider).startCueEnabled, isFalse);
      verify(
        mockRepo.saveSettings(initial.copyWith(startCueEnabled: false)),
      ).called(1);
    });

    test('toggleEndCue updates state and saves', () async {
      const initial = Settings(startCueEnabled: true, endCueEnabled: true);
      when(mockRepo.loadSettings()).thenReturn(initial);

      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsNotifierProvider.notifier)
          .toggleEndCue(false);

      expect(container.read(settingsNotifierProvider).endCueEnabled, isFalse);
      verify(
        mockRepo.saveSettings(initial.copyWith(endCueEnabled: false)),
      ).called(1);
    });
  });
}
