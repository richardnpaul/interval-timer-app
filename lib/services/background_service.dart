import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:interval_timer_app/engine/engine.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/services/audio_service.dart';

// ---------------------------------------------------------------------------
// Background Timer Manager
// ---------------------------------------------------------------------------

class BackgroundTimerManager {
  final ServiceInstance service;
  final AudioService audioService;
  final FlutterLocalNotificationsPlugin notifications;

  RoutineEngine? _engine;
  Timer? _ticker;

  BackgroundTimerManager(this.service, this.audioService, this.notifications);

  void start() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  void syncRoutine(Map<String, dynamic>? routineJson) {
    if (routineJson == null) {
      _engine = null;
      service.invoke('update', {'state': null});
      return;
    }
    try {
      final definition = GroupNode.fromJson(routineJson);
      _engine = RoutineEngine(definition);
      // Immediately push initial state so UI reflects "running" straight away.
      service.invoke('update', {
        'definition': routineJson,
        'state': _engine!.state.toJson(),
      });
    } catch (e) {
      // Malformed payload — ignore.
    }
  }

  Future<void> _onTick(Timer _) async {
    final engine = _engine;
    if (engine == null) return;

    final finished = engine.tick();

    service.invoke('update', {
      'definition': engine.definition.toJson(),
      'state': engine.state.toJson(),
    });

    if (finished) {
      _engine = null;
      service.invoke('routineFinished', {});
    }

    _updateNotification(engine);
  }

  void _updateNotification(RoutineEngine engine) async {
    if (service is AndroidServiceInstance) {
      try {
        if (await (service as AndroidServiceInstance).isForegroundService()) {
          notifications.show(
            id: 888,
            title: 'Interval Timer',
            body: 'Running: ${engine.definition.name}',
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
      } catch (_) {}
    }
  }
}

// ---------------------------------------------------------------------------
// Service entry point
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();
  } catch (_) {}

  final manager = BackgroundTimerManager(
    service,
    AudioService(),
    FlutterLocalNotificationsPlugin(),
  );

  service.on('syncRoutine').listen((event) {
    manager.syncRoutine(
      event != null && event['routine'] != null
          ? Map<String, dynamic>.from(event['routine'])
          : null,
    );
  });

  service.on('stop').listen((_) {
    manager.stop();
    service.stopSelf();
  });

  manager.start();
}

// ---------------------------------------------------------------------------
// Service initializer (called from main.dart)
// ---------------------------------------------------------------------------

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
      onBackground: _onStartBackground,
    ),
  );
}

@pragma('vm:entry-point')
bool _onStartBackground(ServiceInstance service) => true;
