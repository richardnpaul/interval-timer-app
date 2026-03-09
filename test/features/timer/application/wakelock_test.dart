import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/features/timer/application/active_routine_notifier.dart';
import 'package:interval_timer_app/core/providers/service_providers.dart';
import 'package:interval_timer_app/core/domain/group_node.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateNiceMocks([
  MockSpec<BackgroundServiceWrapper>(),
  MockSpec<SettingsService>(),
])
import 'wakelock_test.mocks.dart';

void main() {
  late MockBackgroundServiceWrapper mockService;
  late MockSettingsService mockSettings;

  setUp(() {
    mockService = MockBackgroundServiceWrapper();
    mockSettings = MockSettingsService();
    // Return a dummy stream for 'update' and 'routineFinished'
    when(mockService.on('update')).thenAnswer((_) => const Stream.empty());
    when(
      mockService.on('routineFinished'),
    ).thenAnswer((_) => const Stream.empty());
  });

  test(
    'ActiveRoutineNotifier enables wakelock when routine starts and disables when stopped',
    () async {
      final container = ProviderContainer(
        overrides: [
          backgroundServiceWrapperProvider.overrideWithValue(mockService),
          settingsServiceProvider.overrideWithValue(mockSettings),
        ],
      );

      final notifier = container.read(activeRoutineProvider.notifier);
      final routine = GroupNode(name: 'Test');

      // Act: Start routine
      notifier.startRoutine(routine);

      // Assert: Verify wakelock enabled
      verify(mockSettings.setWakelock(true)).called(1);

      // Act: Stop routine
      notifier.stopRoutine();

      // Assert: Verify wakelock disabled
      verify(mockSettings.setWakelock(false)).called(1);
    },
  );
}
