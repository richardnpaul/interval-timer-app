
import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:interval_timer_app/models/active_timer.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/services/audio_service.dart';

class BackgroundTimerManager {
  final ServiceInstance service;
  final AudioService audioService;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  List<ActiveTimer> backgroundTimers = [];
  Timer? _ticker;

  BackgroundTimerManager(this.service, this.audioService, this.flutterLocalNotificationsPlugin);

  void start() {
    _ticker = Timer.periodic(const Duration(seconds: 1), onTick);
  }

  bool get isRunning => _ticker != null;

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  void syncTimers(List<dynamic> rawTimers) {
    backgroundTimers = rawTimers.map((e) {
      final presetJson = e['preset'] as Map<String, dynamic>;
      return ActiveTimer(
        id: e['id'],
        preset: TimerPreset.fromJson(presetJson),
        remainingSeconds: e['remainingSeconds'],
        state: TimerState.values.firstWhere((s) => s.toString() == e['state']),
      );
    }).toList();
  }

  Future<void> onTick(Timer timer) async {
    if (backgroundTimers.isNotEmpty) {
      bool soundPlayed = false;

      for (var t in backgroundTimers) {
        if (t.state == TimerState.running) {
          if (t.tick()) {
            // Timer Finished/Restarted
            audioService.playAlarm(t.preset.soundPath);
          }
        }
      }

      service.invoke(
        'update',
        {
          'timers': backgroundTimers.map((t) => t.toJson()).toList(),
        },
      );
    }

    if (service is AndroidServiceInstance) {
      try {
        if (await (service as AndroidServiceInstance).isForegroundService()) {
          final runningCount = backgroundTimers.where((t) => t.state == TimerState.running).length;

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
      } catch (e) {
        // Ignore errors from isForegroundService in background isolate
      }
    }
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (e) {
    // Log error but continue as some plugins might still work
  }

  final audioService = AudioService();
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  final manager = BackgroundTimerManager(service, audioService, flutterLocalNotificationsPlugin);

  service.on('syncTimers').listen((event) {
     if (event == null) return;
     if (event.containsKey('timers')) {
       manager.syncTimers(event['timers']);
     }
  });

  service.on('stop').listen((event) {
    manager.stop();
    service.stopSelf();
  });

  manager.start();
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
          AndroidFlutterLocalNotificationsPlugin>()
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
