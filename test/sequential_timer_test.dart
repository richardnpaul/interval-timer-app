import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/models/active_timer.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/services/background_service.dart';
import 'package:interval_timer_app/services/audio_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'sequential_timer_test.mocks.dart';

@GenerateMocks([ServiceInstance, AudioService, FlutterLocalNotificationsPlugin])
void main() {
  late BackgroundTimerManager manager;
  late MockServiceInstance mockService;
  late MockAudioService mockAudio;
  late MockFlutterLocalNotificationsPlugin mockNotifications;

  setUp(() {
    mockService = MockServiceInstance();
    mockAudio = MockAudioService();
    mockNotifications = MockFlutterLocalNotificationsPlugin();
    manager = BackgroundTimerManager(mockService, mockAudio, mockNotifications);
  });

  test(
    'Should transition to next timer in sequence when current one finishes',
    () async {
      final p1 = TimerPreset(id: 'p1', label: 'T1', durationSeconds: 1);
      final p2 = TimerPreset(id: 'p2', label: 'T2', durationSeconds: 5);

      // Initial state: T1 is running, T2 is waiting (paused)
      // We expect these new fields: groupId and nextTimerId
      // Manually adding fields that don't exist yet will fail compilation
      // So I'll use a mocked JSON sync for now to simulate the "future" state
      manager.syncTimers([
        {
          'id': 't1',
          'preset': p1.toJson(),
          'remainingSeconds': 1,
          'state': 'TimerState.running',
          'groupId': 'g1',
          'nextTimerId': 't2',
        },
        {
          'id': 't2',
          'preset': p2.toJson(),
          'remainingSeconds': 5,
          'state': 'TimerState.paused',
          'groupId': 'g1',
          'nextTimerId': null,
        },
      ]);

      // First tick: T1 goes to 0 and finishes
      await manager.onTick(Timer(const Duration(seconds: 1), () {}));

      // Expectation:
      // 1. T1 is finished
      // 2. T2 is running
      // 3. Alarm played for T1
      expect(manager.backgroundTimers[0].state, TimerState.finished);
      expect(manager.backgroundTimers[1].state, TimerState.running);
      verify(mockAudio.playAlarm(any)).called(1);
    },
  );
}
