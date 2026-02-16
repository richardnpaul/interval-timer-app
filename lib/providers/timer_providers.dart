

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/active_timer.dart';
import '../models/timer_preset.dart';
import '../models/timer_group.dart';

// Provide a wrapper for the background service to allow mocking in tests.
class BackgroundServiceWrapper {
  Stream<Map<String, dynamic>?> on(String method) => FlutterBackgroundService().on(method);
  void invoke(String method, [Map<String, dynamic>? args]) => FlutterBackgroundService().invoke(method, args);
}

final backgroundServiceWrapperProvider = Provider<BackgroundServiceWrapper>((ref) => BackgroundServiceWrapper());

// The source of truth for all currently active (running/paused) timers.
final activeTimersProvider =
    NotifierProvider<ActiveTimersNotifier, List<ActiveTimer>>(ActiveTimersNotifier.new);

class ActiveTimersNotifier extends Notifier<List<ActiveTimer>> {
  @override
  List<ActiveTimer> build() {
    _initServiceListener();
    return [];
  }

  void _initServiceListener() {
    ref.read(backgroundServiceWrapperProvider).on('update').listen((event) {
      if (event != null && event['timers'] != null) {
         final List<dynamic> timersData = event['timers'];
         try {
            state = timersData.map((data) => ActiveTimer.fromJson(Map<String, dynamic>.from(data))).toList();
         } catch (e) {
           print('Error deserializing timers: $e');
         }
      }
    });
  }

  void _syncToService() {
     ref.read(backgroundServiceWrapperProvider).invoke(
       'syncTimers',
       {
         'timers': state.map((t) => t.toJson()).toList(),
       }
     );
  }

  void addTimer(TimerPreset preset) {
    // Optimistic update
    state = [
      ...state,
      ActiveTimer(preset: preset, state: TimerState.running),
    ];
    _syncToService();
  }

  void addGroup(TimerGroup group, List<TimerPreset> allPresets) {
    // Determine which timers are in this group
    final timersToAdd = allPresets
        .where((preset) => group.timerIds.contains(preset.id))
        .map((preset) => ActiveTimer(preset: preset, state: TimerState.running))
        .toList();

    // In parallel mode, we simply add them all to the active list
    state = [...state, ...timersToAdd];
    _syncToService();
  }

  void removeTimer(String activeTimerId) {
    state = state.where((t) => t.id != activeTimerId).toList();
    _syncToService();
  }

  void pauseTimer(String activeTimerId) {
    state = [
      for (final t in state)
        if (t.id == activeTimerId)
          ActiveTimer(
              id: t.id,
              preset: t.preset,
              remainingSeconds: t.remainingSeconds,
              state: TimerState.paused)
        else
          t
    ];
    _syncToService();
  }

  void resumeTimer(String activeTimerId) {
    state = [
      for (final t in state)
        if (t.id == activeTimerId)
           ActiveTimer(
              id: t.id,
              preset: t.preset,
              remainingSeconds: t.remainingSeconds,
              state: TimerState.running)
        else
          t
    ];
    _syncToService();
  }

  void restartTimer(String activeTimerId) {
      state = [
      for (final t in state)
        if (t.id == activeTimerId)
          ActiveTimer(
              id: t.id,
              preset: t.preset,
              remainingSeconds: t.preset.durationSeconds,
              state: TimerState.running)
        else
          t
    ];
    _syncToService();
  }
}

class PermissionService {
  Future<PermissionStatus> requestNotificationPermission() => Permission.notification.request();
}

final permissionServiceProvider = Provider((ref) => PermissionService());

class SettingsService {
  Future<bool> isWakelockEnabled() => WakelockPlus.enabled;
  Future<void> setWakelock(bool enabled) => enabled ? WakelockPlus.enable() : WakelockPlus.disable();
}

final settingsServiceProvider = Provider((ref) => SettingsService());
