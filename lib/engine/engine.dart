import 'package:meta/meta.dart';
import '../models/timer_node.dart';
import '../models/timer_instance.dart';
import '../models/group_node.dart';
import 'node_state.dart';

/// The core finite-state machine that processes routine ticks.
///
/// It holds a reference to the [definition] (static tree) and maintains [state]
/// (dynamic runtime status).
class RoutineEngine {
  final GroupNode definition;
  final void Function(TimerInstance)? onTimerFinished;
  late GroupNodeState state;

  RoutineEngine(
    this.definition, {
    this.onTimerFinished,
    GroupNodeState? state,
  }) {
    this.state = state ?? buildGroupState(definition);
    if (state == null) {
      activateGroup(this.state, definition);
    }
  }

  /// Reconstruct engine from a persisted state + its original definition.
  RoutineEngine.resume({
    required this.definition,
    required this.state,
    this.onTimerFinished,
  });

  /// Advances the entire routine by 1 second.
  /// Returns true if the routine has fully completed.
  bool tick() {
    if (state.status == NodeStatus.finished) return true;
    _tickGroup(state, definition);
    return state.status == NodeStatus.finished;
  }

  // ---------------------------------------------------------------------------
  // State construction
  // ---------------------------------------------------------------------------

  @visibleForTesting
  static GroupNodeState buildGroupState(GroupNode def) => GroupNodeState(
    nodeId: def.id,
    childStates: def.children.map(buildNode).toList(),
  );

  @visibleForTesting
  static NodeState buildNode(TimerNode def) => switch (def) {
    TimerInstance d => TimerInstanceState(
      nodeId: d.id,
      totalSeconds: d.duration,
    ),
    GroupNode d => buildGroupState(d),
    _ => throw ArgumentError('Unknown node type: ${def.runtimeType}'),
  };

  // ---------------------------------------------------------------------------
  // Group tick
  // ---------------------------------------------------------------------------

  void _tickGroup(GroupNodeState groupState, GroupNode groupDef) {
    if (groupState.status == NodeStatus.finished) return;

    if (groupDef.executionMode == ExecutionMode.sequential) {
      _tickSequential(groupState, groupDef);
    } else {
      _tickParallel(groupState, groupDef);
    }
  }

  void _tickSequential(GroupNodeState groupState, GroupNode groupDef) {
    final idx = groupState.activeChildIndex;
    if (idx >= groupState.childStates.length) {
      _onGroupIterationComplete(groupState, groupDef);
      return;
    }

    final childState = groupState.childStates[idx];
    final childDef = groupDef.children[idx];
    final childFinished = tickNode(childState, childDef);

    if (childFinished) {
      // Advance to the next child.
      groupState.activeChildIndex = idx + 1;
      if (groupState.activeChildIndex >= groupState.childStates.length) {
        _onGroupIterationComplete(groupState, groupDef);
      } else {
        // Activate the next child.
        activateNode(
          groupState.childStates[groupState.activeChildIndex],
          groupDef.children[groupState.activeChildIndex],
        );
      }
    }
  }

  void _tickParallel(GroupNodeState groupState, GroupNode groupDef) {
    bool allFinished = true;
    for (int i = 0; i < groupState.childStates.length; i++) {
      final childState = groupState.childStates[i];
      final childDef = groupDef.children[i];
      if (childState.status != NodeStatus.finished) {
        tickNode(childState, childDef);
        if (childState.status != NodeStatus.finished) allFinished = false;
      }
    }
    if (allFinished) {
      _onGroupIterationComplete(groupState, groupDef);
    }
  }

  /// Called when all children of a group have finished one pass.
  void _onGroupIterationComplete(
    GroupNodeState groupState,
    GroupNode groupDef,
  ) {
    final infinite = groupDef.repetitions == 0;
    final hasMoreReps = groupState.currentRepetition < groupDef.repetitions;

    if (infinite || hasMoreReps) {
      // Reset for the next repetition.
      groupState.currentRepetition++;
      resetGroup(groupState, groupDef);
      activateGroup(groupState, groupDef);
    } else {
      groupState.status = NodeStatus.finished;
    }
  }

  // ---------------------------------------------------------------------------
  // Node tick dispatch
  // ---------------------------------------------------------------------------

  /// Returns true when the node has finished (and won't restart itself).
  @visibleForTesting
  bool tickNode(NodeState nodeState, TimerNode nodeDef) {
    return switch ((nodeState, nodeDef)) {
      (TimerInstanceState s, TimerInstance d) => _tickInstance(s, d),
      (GroupNodeState s, GroupNode d) => _tickGroupNode(s, d),
      _ => throw ArgumentError('State/definition type mismatch'),
    };
  }

  bool _tickInstance(TimerInstanceState s, TimerInstance def) {
    if (s.status != NodeStatus.running) return s.status == NodeStatus.finished;

    s.remainingSeconds--;

    if (s.remainingSeconds == def.soundOffset &&
        def.soundOffset < s.totalSeconds) {
      onTimerFinished?.call(def);
    }

    if (s.remainingSeconds <= 0) {
      if (def.autoRestart) {
        s.remainingSeconds = s.totalSeconds;
        if (def.soundOffset >= s.totalSeconds) {
          onTimerFinished?.call(def);
        }
        return false;
      } else {
        s.status = NodeStatus.finished;
        return true;
      }
    }
    return false;
  }

  bool _tickGroupNode(GroupNodeState s, GroupNode d) {
    if (s.status == NodeStatus.finished) return true;
    _tickGroup(s, d);
    return s.status == NodeStatus.finished;
  }

  // ---------------------------------------------------------------------------
  // Activation & reset helpers
  // ---------------------------------------------------------------------------

  @visibleForTesting
  void activateGroup(GroupNodeState groupState, GroupNode groupDef) {
    groupState.status = NodeStatus.running;
    if (groupDef.executionMode == ExecutionMode.sequential) {
      groupState.activeChildIndex = 0;
      if (groupState.childStates.isNotEmpty) {
        activateNode(groupState.childStates[0], groupDef.children[0]);
      }
    } else {
      groupState.activeChildIndex = -1;
      for (int i = 0; i < groupState.childStates.length; i++) {
        activateNode(groupState.childStates[i], groupDef.children[i]);
      }
    }
  }

  @visibleForTesting
  void activateNode(NodeState nodeState, TimerNode nodeDef) {
    switch ((nodeState, nodeDef)) {
      case (TimerInstanceState s, TimerInstance d):
        s.status = NodeStatus.running;
        if (d.soundOffset >= s.totalSeconds) {
          onTimerFinished?.call(d);
        }
      case (GroupNodeState s, GroupNode d):
        activateGroup(s, d);
      default:
        throw ArgumentError('State/definition type mismatch on activate');
    }
  }

  @visibleForTesting
  void resetGroup(GroupNodeState groupState, GroupNode groupDef) {
    groupState.status = NodeStatus.waiting;
    groupState.activeChildIndex = 0;
    for (int i = 0; i < groupState.childStates.length; i++) {
      resetNode(groupState.childStates[i], groupDef.children[i]);
    }
  }

  @visibleForTesting
  void resetNode(NodeState nodeState, TimerNode nodeDef) {
    switch ((nodeState, nodeDef)) {
      case (TimerInstanceState s, TimerInstance _):
        s.reset();
      case (GroupNodeState s, GroupNode d):
        resetGroup(s, d);
      default:
        throw ArgumentError('State/definition type mismatch on reset');
    }
  }
}
