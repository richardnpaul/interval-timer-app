import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/core/domain/group_node.dart';
import 'package:interval_timer_app/features/timer/domain/node_state.dart';
import 'package:interval_timer_app/core/providers/service_providers.dart';

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
