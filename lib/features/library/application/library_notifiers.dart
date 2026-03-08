import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/core/domain/timer_preset.dart';
import 'package:interval_timer_app/core/domain/group_node.dart';
import 'package:interval_timer_app/core/services/storage_service.dart';

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
