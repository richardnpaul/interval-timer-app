import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/active_timer.dart';
import '../models/timer_preset.dart';
import '../models/timer_group.dart';
import 'package:interval_timer_app/services/storage_service.dart';

// --- Presets ---

final presetsProvider = NotifierProvider<PresetsNotifier, List<TimerPreset>>(
  PresetsNotifier.new,
);

class PresetsNotifier extends Notifier<List<TimerPreset>> {
  @override
  List<TimerPreset> build() {
    return ref.read(storageServiceProvider).loadPresets();
  }

  Future<void> savePreset(TimerPreset preset) async {
    final storage = ref.read(storageServiceProvider);
    final existingIndex = state.indexWhere((p) => p.id == preset.id);
    if (existingIndex != -1) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) preset else state[i],
      ];
    } else {
      state = [...state, preset];
    }
    await storage.savePresets(state);
  }

  Future<void> deletePreset(String id) async {
    state = state.where((p) => p.id != id).toList();
    await ref.read(storageServiceProvider).savePresets(state);
  }
}

// --- Groups ---

final groupsProvider = NotifierProvider<GroupsNotifier, List<TimerGroup>>(
  GroupsNotifier.new,
);

class GroupsNotifier extends Notifier<List<TimerGroup>> {
  @override
  List<TimerGroup> build() {
    return ref.read(storageServiceProvider).loadGroups();
  }

  Future<void> saveGroup(TimerGroup group) async {
    final storage = ref.read(storageServiceProvider);
    final existingIndex = state.indexWhere((g) => g.id == group.id);
    if (existingIndex != -1) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) group else state[i],
      ];
    } else {
      state = [...state, group];
    }
    await storage.saveGroups(state);
  }

  Future<void> deleteGroup(String id) async {
    state = state.where((g) => g.id != id).toList();
    await ref.read(storageServiceProvider).saveGroups(state);
  }
}

// The source of truth for all currently active (running/paused) timers.
final activeTimersProvider =
    NotifierProvider<ActiveTimersNotifier, List<ActiveTimer>>(
      ActiveTimersNotifier.new,
    );

class ActiveTimersNotifier extends Notifier<List<ActiveTimer>> {
  @override
  List<ActiveTimer> build() {
    _initServiceListener();
    return [];
  }

  void _initServiceListener() {
    FlutterBackgroundService().on('update').listen((event) {
      if (event != null && event['timers'] != null) {
        final List<dynamic> timersData = event['timers'];
        // "Single Source of Truth" - we trust the service entirely.
        // This handles app restarts (where local state is empty) automatically.
        try {
          state = timersData
              .map(
                (data) => ActiveTimer.fromJson(Map<String, dynamic>.from(data)),
              )
              .toList();
        } catch (e) {
          debugPrint('Error deserializing timers: $e');
        }
      }
    });
  }

  void _syncToService() {
    // We schedule this to run slightly later to avoid race conditions with optimistic updates?
    // No, invoke is async.
    FlutterBackgroundService().invoke('syncTimers', {
      'timers': state.map((t) => t.toJson()).toList(),
    });
  }

  void addTimer(TimerPreset preset) {
    // Optimistic update
    state = [...state, ActiveTimer(preset: preset, state: TimerState.running)];
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
            state: TimerState.paused,
          )
        else
          t,
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
            state: TimerState.running,
          )
        else
          t,
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
            state: TimerState.running,
          )
        else
          t,
    ];
    _syncToService();
  }
}
