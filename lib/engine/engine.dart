import 'package:interval_timer_app/engine/node_state.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';
import 'package:interval_timer_app/models/timer_node.dart';

/// Pure-Dart, Flutter-free execution engine for a routine tree.
/// Runs inside the background isolate and is trivially unit-testable.
class RoutineEngine {
  final GroupNode definition;
  late GroupNodeState state;

  RoutineEngine(this.definition) {
    state = _buildGroupState(definition);
    // Start the root group immediately.
    _activateGroup(state, definition);
  }

  /// Reconstruct engine from a persisted state + its original definition.
  RoutineEngine.resume({required this.definition, required this.state});

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Advance all running nodes by one second.
  /// Returns true if the root routine has fully completed.
  bool tick() {
    if (state.status == NodeStatus.finished) return true;
    _tickGroup(state, definition);
    return state.status == NodeStatus.finished;
  }

  // ---------------------------------------------------------------------------
  // State construction
  // ---------------------------------------------------------------------------

  static GroupNodeState _buildGroupState(GroupNode def) => GroupNodeState(
    nodeId: def.id,
    childStates: def.children.map(_buildNodeState).toList(),
  );

  static NodeState _buildNodeState(TimerNode def) => switch (def) {
    TimerInstance d => TimerInstanceState(
      nodeId: d.id,
      totalSeconds: d.duration,
    ),
    GroupNode d => _buildGroupState(d),
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
    final childFinished = _tickNode(childState, childDef);

    if (childFinished) {
      // Advance to the next child.
      groupState.activeChildIndex = idx + 1;
      if (groupState.activeChildIndex >= groupState.childStates.length) {
        _onGroupIterationComplete(groupState, groupDef);
      } else {
        // Activate the next child.
        _activateNode(
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
        _tickNode(childState, childDef);
        if (childState.status != NodeStatus.finished) allFinished = false;
      }
    }
    if (allFinished) {
      _onGroupIterationComplete(groupState, groupDef);
    }
  }

  /// Called when all children of a group have finished one pass.
  ///
  /// Decision table:
  ///   repetitions == 0  → infinite loop, never finishes.
  ///   currentRepetition < repetitions → more reps remain, reset & continue.
  ///   otherwise         → mark group finished.
  void _onGroupIterationComplete(
    GroupNodeState groupState,
    GroupNode groupDef,
  ) {
    final infinite = groupDef.repetitions == 0;
    // `> 1` is redundant (repetitions==1 means currentRep==1, so 1<1 is false),
    // but the explicit check makes the intent clear at a glance.
    final hasMoreReps = groupState.currentRepetition < groupDef.repetitions;

    if (infinite || hasMoreReps) {
      // Reset for the next repetition.
      groupState.currentRepetition++;
      _resetGroup(groupState, groupDef);
      _activateGroup(groupState, groupDef);
    } else {
      groupState.status = NodeStatus.finished;
    }
  }

  // ---------------------------------------------------------------------------
  // Node tick dispatch
  // ---------------------------------------------------------------------------

  /// Returns true when the node has finished (and won't restart itself).
  bool _tickNode(NodeState nodeState, TimerNode nodeDef) {
    return switch ((nodeState, nodeDef)) {
      (TimerInstanceState s, TimerInstance d) => _tickInstance(s, d),
      (GroupNodeState s, GroupNode d) => _tickGroupNode(s, d),
      _ => throw ArgumentError('State/definition type mismatch'),
    };
  }

  bool _tickInstance(TimerInstanceState s, TimerInstance def) {
    if (s.status != NodeStatus.running) return s.status == NodeStatus.finished;

    s.remainingSeconds--;

    if (s.remainingSeconds <= 0) {
      if (def.autoRestart) {
        // Loop the leaf: reset and keep running.
        s.remainingSeconds = s.totalSeconds;
        // Returns false — it never "finishes" while autoRestart is on.
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

  void _activateGroup(GroupNodeState groupState, GroupNode groupDef) {
    groupState.status = NodeStatus.running;
    if (groupDef.executionMode == ExecutionMode.sequential) {
      groupState.activeChildIndex = 0;
      if (groupState.childStates.isNotEmpty) {
        _activateNode(groupState.childStates[0], groupDef.children[0]);
      }
    } else {
      // Parallel: activate all children.
      groupState.activeChildIndex = -1;
      for (int i = 0; i < groupState.childStates.length; i++) {
        _activateNode(groupState.childStates[i], groupDef.children[i]);
      }
    }
  }

  void _activateNode(NodeState nodeState, TimerNode nodeDef) {
    switch ((nodeState, nodeDef)) {
      case (TimerInstanceState s, TimerInstance _):
        s.status = NodeStatus.running;
      case (GroupNodeState s, GroupNode d):
        _activateGroup(s, d);
      default:
        throw ArgumentError('State/definition type mismatch on activate');
    }
  }

  void _resetGroup(GroupNodeState groupState, GroupNode groupDef) {
    groupState.status = NodeStatus.waiting;
    groupState.activeChildIndex = 0;
    for (int i = 0; i < groupState.childStates.length; i++) {
      _resetNode(groupState.childStates[i], groupDef.children[i]);
    }
  }

  void _resetNode(NodeState nodeState, TimerNode nodeDef) {
    switch ((nodeState, nodeDef)) {
      case (TimerInstanceState s, TimerInstance _):
        s.reset();
      case (GroupNodeState s, GroupNode d):
        _resetGroup(s, d);
      default:
        throw ArgumentError('State/definition type mismatch on reset');
    }
  }
}
