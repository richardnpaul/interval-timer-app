import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:interval_timer_app/models/active_timer.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/services/audio_service.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final audioService = AudioService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  List<ActiveTimer> backgroundTimers = [];

  service.on('syncTimers').listen((event) {
    if (event == null) return;
    if (event.containsKey('timers')) {
      final List<dynamic> rawTimers = event['timers'];
      backgroundTimers = rawTimers.map((e) {
        final presetJson = e['preset'] as Map<String, dynamic>;
        return ActiveTimer(
          id: e['id'],
          preset: TimerPreset.fromJson(presetJson),
          remainingSeconds: e['remainingSeconds'],
          state: TimerState.values.firstWhere(
            (s) => s.toString() == e['state'],
          ),
        );
      }).toList();
    }
  });

  service.on('stop').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (backgroundTimers.isEmpty) {
      // Idle state
    } else {
      bool soundPlayed = false;

      for (var t in backgroundTimers) {
        if (t.state == TimerState.running) {
          if (t.remainingSeconds > 0) {
            t.remainingSeconds--;
          }

          if (t.remainingSeconds == 0) {
            // Timer Finished
            if (!soundPlayed) {
              audioService.playAlarm(t.preset.soundPath);
              soundPlayed = true;
            }

            if (t.preset.autoRestart) {
              t.remainingSeconds = t.preset.durationSeconds;
            } else {
              t.state = TimerState.finished;
            }
          }
        }
      }

      service.invoke('update', {
        'timers': backgroundTimers
            .map(
              (t) => {
                'id': t.id,
                'remainingSeconds': t.remainingSeconds,
                'state': t.state.toString(),
              },
            )
            .toList(),
      });
    }

    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        final runningCount = backgroundTimers
            .where((t) => t.state == TimerState.running)
            .length;

        flutterLocalNotificationsPlugin.show(
          id: 888,
          title: 'Interval Timer',
          body: runningCount > 0 ? '$runningCount timers running' : 'Ready',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_foreground',
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );
      }
    }
  });
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Interval Timer',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onStartTimer,
    ),
  );
}

@pragma('vm:entry-point')
bool onStartTimer(ServiceInstance service) {
  return true;
}
