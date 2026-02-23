import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/timer_preset.dart';
import '../models/group_node.dart';
import 'package:interval_timer_app/engine/node_state.dart';
import 'package:interval_timer_app/services/storage_service.dart';

// --- Services & Wrappers ---

class BackgroundServiceWrapper {
  Stream<Map<String, dynamic>?> on(String method) =>
      FlutterBackgroundService().on(method);
  void invoke(String method, [Map<String, dynamic>? args]) =>
      FlutterBackgroundService().invoke(method, args);
}

final backgroundServiceWrapperProvider = Provider<BackgroundServiceWrapper>(
  (ref) => BackgroundServiceWrapper(),
);

class PermissionService {
  Future<PermissionStatus> requestNotificationPermission() =>
      Permission.notification.request();
}

final permissionServiceProvider = Provider((ref) => PermissionService());

class SettingsService {
  Future<bool> isWakelockEnabled() => WakelockPlus.enabled;
  Future<void> setWakelock(bool enabled) =>
      enabled ? WakelockPlus.enable() : WakelockPlus.disable();
}

final settingsServiceProvider = Provider((ref) => SettingsService());

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

// --- Routines ---

/// Each routine is a root GroupNode that can contain any tree of TimerNodes.
final routinesProvider = NotifierProvider<RoutinesNotifier, List<GroupNode>>(
  RoutinesNotifier.new,
);

class RoutinesNotifier extends Notifier<List<GroupNode>> {
  @override
  List<GroupNode> build() {
    return ref.read(storageServiceProvider).loadRoutines();
  }

  Future<void> saveRoutine(GroupNode routine) async {
    final existingIndex = state.indexWhere((r) => r.id == routine.id);
    if (existingIndex != -1) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) routine else state[i],
      ];
    } else {
      state = [...state, routine];
    }
    await ref.read(storageServiceProvider).saveRoutines(state);
  }

  Future<void> deleteRoutine(String id) async {
    state = state.where((r) => r.id != id).toList();
    await ref.read(storageServiceProvider).saveRoutines(state);
  }
}

// --- Active Routine (Running State) ---

/// Snapshot of the currently executing routine.
class ActiveRoutineSnapshot {
  final GroupNode definition;
  final GroupNodeState state;

  const ActiveRoutineSnapshot({required this.definition, required this.state});
}

/// Holds the currently executing routine definition + live runtime state.
final activeRoutineProvider =
    NotifierProvider<ActiveRoutineNotifier, ActiveRoutineSnapshot?>(
      ActiveRoutineNotifier.new,
    );

class ActiveRoutineNotifier extends Notifier<ActiveRoutineSnapshot?> {
  @override
  ActiveRoutineSnapshot? build() {
    _initServiceListeners();
    return null;
  }

  void _initServiceListeners() {
    final svc = ref.read(backgroundServiceWrapperProvider);

    svc.on('update').listen((event) {
      if (event == null) return;
      try {
        if (event['state'] == null) {
          state = null;
          return;
        }
        final definition = GroupNode.fromJson(
          Map<String, dynamic>.from(event['definition']),
        );
        final runState = GroupNodeState.fromJson(
          Map<String, dynamic>.from(event['state']),
        );
        state = ActiveRoutineSnapshot(definition: definition, state: runState);
      } catch (e) {
        debugPrint('Error deserializing routine update: $e');
      }
    });

    svc.on('routineFinished').listen((_) {
      state = null;
    });
  }

  void _syncToService(GroupNode? routine) {
    ref.read(backgroundServiceWrapperProvider).invoke('syncRoutine', {
      'routine': routine?.toJson(),
    });
  }

  /// Start executing a routine.
  void startRoutine(GroupNode routine) {
    _syncToService(routine);
    // State will be updated via the 'update' event from the service.
  }

  /// Stop the currently running routine.
  void stopRoutine() {
    state = null;
    _syncToService(null);
  }
}
