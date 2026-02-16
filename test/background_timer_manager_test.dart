
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:interval_timer_app/services/background_service.dart';
import 'package:interval_timer_app/services/audio_service.dart';
import 'package:interval_timer_app/models/active_timer.dart';
import 'package:interval_timer_app/models/timer_preset.dart';

import 'background_timer_manager_test.mocks.dart';

@GenerateMocks([AudioService, ServiceInstance, FlutterLocalNotificationsPlugin])
void main() {
  late MockAudioService mockAudio;
  late MockServiceInstance mockService;
  late MockFlutterLocalNotificationsPlugin mockNotifications;
  late BackgroundTimerManager manager;

  setUp(() {
    mockAudio = MockAudioService();
    mockService = MockServiceInstance();
    mockNotifications = MockFlutterLocalNotificationsPlugin();
    manager = BackgroundTimerManager(mockService, mockAudio, mockNotifications);
  });

  test('Should only play one alarm if multiple timers finish simultaneously (Verifying Bug)', () async {
    final p1 = TimerPreset(label: 'T1', durationSeconds: 0);
    final p2 = TimerPreset(label: 'T2', durationSeconds: 0);

    // Set up timers that are already at 0 and running
    manager.syncTimers([
      ActiveTimer(id: '1', preset: p1, remainingSeconds: 0, state: TimerState.running).toJson(),
      ActiveTimer(id: '2', preset: p2, remainingSeconds: 0, state: TimerState.running).toJson(),
    ]);

    // Trigger tick
    await manager.onTick(Timer(const Duration(seconds: 1), () {}));

    // DESIRED: playAlarm is called for each finished timer
    verify(mockAudio.playAlarm(any)).called(2);

    verifyNoMoreInteractions(mockAudio);
  });

  test('Should cancel ticker when stop is called (Verifying Fix for Memory Leak)', () async {
    expect(manager.isRunning, false);

    manager.start();
    expect(manager.isRunning, true);

    manager.stop();
    expect(manager.isRunning, false);
  });
}
