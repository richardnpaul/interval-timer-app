import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/engine/engine.dart';
import 'package:interval_timer_app/engine/node_state.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Tick the engine [n] times and return whether it reported finished.
bool tickN(RoutineEngine engine, int n) {
  bool finished = false;
  for (int i = 0; i < n; i++) {
    finished = engine.tick();
    if (finished) break;
  }
  return finished;
}

/// Return the TimerInstanceState for the child at [childIndex] of the root.
TimerInstanceState rootChildInstance(RoutineEngine engine, int childIndex) {
  return engine.state.childStates[childIndex] as TimerInstanceState;
}

/// Return the GroupNodeState for the child at [childIndex] of the root.
GroupNodeState rootChildGroup(RoutineEngine engine, int childIndex) {
  return engine.state.childStates[childIndex] as GroupNodeState;
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// Root (sequential, 1 rep) → [A(3s), B(2s)]
RoutineEngine _seqAB() => RoutineEngine(
  GroupNode(
    id: 'root',
    name: 'Sequential AB',
    executionMode: ExecutionMode.sequential,
    children: [
      TimerInstance(id: 'a', name: 'A', duration: 3),
      TimerInstance(id: 'b', name: 'B', duration: 2),
    ],
  ),
);

/// Root (parallel, 1 rep) → [A(3s), B(2s)]
RoutineEngine _parallelAB() => RoutineEngine(
  GroupNode(
    id: 'root',
    name: 'Parallel AB',
    executionMode: ExecutionMode.parallel,
    children: [
      TimerInstance(id: 'a', name: 'A', duration: 3),
      TimerInstance(id: 'b', name: 'B', duration: 2),
    ],
  ),
);

/// Root (sequential, 3 reps) → [A(2s)]
RoutineEngine _seqReps3() => RoutineEngine(
  GroupNode(
    id: 'root',
    name: 'Reps3',
    executionMode: ExecutionMode.sequential,
    repetitions: 3,
    children: [TimerInstance(id: 'a', name: 'A', duration: 2)],
  ),
);

/// Root (sequential, infinite=0 reps) → [A(2s)]
RoutineEngine _seqInfinite() => RoutineEngine(
  GroupNode(
    id: 'root',
    name: 'Infinite',
    executionMode: ExecutionMode.sequential,
    repetitions: 0,
    children: [TimerInstance(id: 'a', name: 'A', duration: 2)],
  ),
);

/// Root (sequential) → [A(2s, autoRestart:true)]
RoutineEngine _autoRestartLeaf() => RoutineEngine(
  GroupNode(
    id: 'root',
    name: 'AutoRestart',
    executionMode: ExecutionMode.sequential,
    repetitions: 1,
    children: [
      TimerInstance(id: 'a', name: 'A', duration: 2, autoRestart: true),
    ],
  ),
);

// ---------------------------------------------------------------------------
// DotA 2 fixture:
//   Sequential root:
//     Prep (5s)
//     Rounds (sequential, 3 reps): [Work(3s), Rest(2s)]
//     Cooldown (4s)
//
//   Timeline (cumulative ticks):
//     0–4   : Prep running (5 ticks → finishes on tick 5)
//     5–12  : Rounds rep1: Work(3s) + Rest(2s), rep2: Work(3s) + Rest(2s)
//     13–17 : Rounds rep3: Work(3s) + Rest(2s)
//     18–21 : Cooldown (4 ticks)
//     Total : 5 + 3×(3+2) + 4 = 24 ticks
// ---------------------------------------------------------------------------
RoutineEngine _dota2Routine() => RoutineEngine(
  GroupNode(
    id: 'root',
    name: 'Dota2',
    executionMode: ExecutionMode.sequential,
    children: [
      TimerInstance(id: 'prep', name: 'Prep', duration: 5),
      GroupNode(
        id: 'rounds',
        name: 'Rounds',
        executionMode: ExecutionMode.sequential,
        repetitions: 3,
        children: [
          TimerInstance(id: 'work', name: 'Work', duration: 3),
          TimerInstance(id: 'rest', name: 'Rest', duration: 2),
        ],
      ),
      TimerInstance(id: 'cooldown', name: 'Cooldown', duration: 4),
    ],
  ),
);

// ---------------------------------------------------------------------------
// Stretching fixture:
//   Sequential root (2 reps): [Neck(4s), Shoulders(3s)]
//   Total: 2 × (4+3) = 14 ticks
// ---------------------------------------------------------------------------
RoutineEngine _stretchingRoutine() => RoutineEngine(
  GroupNode(
    id: 'root',
    name: 'Stretching',
    executionMode: ExecutionMode.sequential,
    repetitions: 2,
    children: [
      TimerInstance(id: 'neck', name: 'Neck', duration: 4),
      TimerInstance(id: 'shoulders', name: 'Shoulders', duration: 3),
    ],
  ),
);

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // -------------------------------------------------------------------------
  group('Initial state', () {
    test('root group starts as running', () {
      final engine = _seqAB();
      expect(engine.state.status, NodeStatus.running);
    });

    test('first child starts as running in sequential mode', () {
      final engine = _seqAB();
      expect(rootChildInstance(engine, 0).status, NodeStatus.running);
      expect(rootChildInstance(engine, 0).remainingSeconds, 3);
    });

    test('second child starts as waiting in sequential mode', () {
      final engine = _seqAB();
      expect(rootChildInstance(engine, 1).status, NodeStatus.waiting);
    });

    test('all children start as running in parallel mode', () {
      final engine = _parallelAB();
      expect(rootChildInstance(engine, 0).status, NodeStatus.running);
      expect(rootChildInstance(engine, 1).status, NodeStatus.running);
    });
  });

  // -------------------------------------------------------------------------
  group('Sequential group', () {
    test('first child decrements on each tick', () {
      final engine = _seqAB();
      engine.tick();
      expect(rootChildInstance(engine, 0).remainingSeconds, 2);
      engine.tick();
      expect(rootChildInstance(engine, 0).remainingSeconds, 1);
    });

    test('second child activates only after first finishes', () {
      final engine = _seqAB();
      // Tick A down to 0 (3 ticks).
      tickN(engine, 3);

      expect(rootChildInstance(engine, 0).status, NodeStatus.finished);
      expect(rootChildInstance(engine, 1).status, NodeStatus.running);
      expect(rootChildInstance(engine, 1).remainingSeconds, 2);
    });

    test('engine reports finished after all children complete', () {
      final engine = _seqAB();
      // A=3s + B=2s = 5 ticks total.
      expect(tickN(engine, 5), isTrue);
      expect(engine.state.status, NodeStatus.finished);
    });

    test('engine is not finished one tick before completing', () {
      final engine = _seqAB();
      tickN(engine, 4); // One tick remaining on B.
      expect(engine.state.status, NodeStatus.running);
    });

    test('calling tick() after finished returns true immediately', () {
      final engine = _seqAB();
      tickN(engine, 5);
      expect(engine.tick(), isTrue);
    });
  });

  // -------------------------------------------------------------------------
  group('Parallel group', () {
    test('all children decrement simultaneously', () {
      final engine = _parallelAB();
      engine.tick();
      expect(rootChildInstance(engine, 0).remainingSeconds, 2);
      expect(rootChildInstance(engine, 1).remainingSeconds, 1);
    });

    test('shorter child finishes first; longer keeps running', () {
      final engine = _parallelAB();
      // B(2s) finishes on tick 2.
      tickN(engine, 2);
      expect(rootChildInstance(engine, 1).status, NodeStatus.finished);
      expect(rootChildInstance(engine, 0).status, NodeStatus.running);
    });

    test('group finishes when the last (longest) child finishes', () {
      final engine = _parallelAB();
      // A(3s) is the longest — group finishes on tick 3.
      expect(tickN(engine, 3), isTrue);
      expect(engine.state.status, NodeStatus.finished);
    });
  });

  // -------------------------------------------------------------------------
  group('Repetitions', () {
    test('rep is 1 at start', () {
      final engine = _seqReps3();
      expect(engine.state.currentRepetition, 1);
    });

    test('increments to rep 2 after first iteration', () {
      final engine = _seqReps3();
      tickN(engine, 2); // Complete rep 1.
      expect(engine.state.currentRepetition, 2);
      expect(engine.state.status, NodeStatus.running);
    });

    test('child resets fully between reps', () {
      final engine = _seqReps3();
      tickN(engine, 2); // Complete rep 1.
      expect(rootChildInstance(engine, 0).remainingSeconds, 2);
      expect(rootChildInstance(engine, 0).status, NodeStatus.running);
    });

    test('increments to rep 3 after second iteration', () {
      final engine = _seqReps3();
      tickN(engine, 4); // Complete reps 1 and 2.
      expect(engine.state.currentRepetition, 3);
      expect(engine.state.status, NodeStatus.running);
    });

    test('finishes after all 3 reps complete', () {
      final engine = _seqReps3();
      // 3 reps × 2s each = 6 ticks.
      expect(tickN(engine, 6), isTrue);
      expect(engine.state.status, NodeStatus.finished);
      expect(engine.state.currentRepetition, 3);
    });

    test('not finished one tick before last rep completes', () {
      final engine = _seqReps3();
      tickN(engine, 5); // 1 tick remaining in rep 3.
      expect(engine.state.status, NodeStatus.running);
    });
  });

  // -------------------------------------------------------------------------
  group('Infinite repetitions (repetitions: 0)', () {
    test('never returns finished after many ticks', () {
      final engine = _seqInfinite();
      // Run for 20 full loops (2s each = 40 ticks).
      final finished = tickN(engine, 40);
      expect(finished, isFalse);
      expect(engine.state.status, NodeStatus.running);
    });

    test('repetition counter keeps incrementing', () {
      final engine = _seqInfinite();
      tickN(engine, 10); // 5 completed loops.
      expect(engine.state.currentRepetition, greaterThanOrEqualTo(5));
    });
  });

  // -------------------------------------------------------------------------
  group('autoRestart on leaf', () {
    test('leaf resets and stays running when it reaches 0', () {
      final engine = _autoRestartLeaf();
      // Tick down to 0.
      tickN(engine, 2);
      final leaf = rootChildInstance(engine, 0);
      expect(leaf.remainingSeconds, 2);
      expect(leaf.status, NodeStatus.running);
    });

    test('parent group never finishes while autoRestart leaf is running', () {
      final engine = _autoRestartLeaf();
      // Run for many cycles — group must stay running.
      final finished = tickN(engine, 30);
      expect(finished, isFalse);
      expect(engine.state.status, NodeStatus.running);
    });

    test('leaf keeps cycling without advancing activeChildIndex', () {
      final engine = _autoRestartLeaf();
      tickN(engine, 6); // 3 complete cycles.
      expect(engine.state.activeChildIndex, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('Nested groups', () {
    // Sequential outer → [Parallel inner [A(3s), B(2s)], C(4s)]
    test(
      'parallel group nested inside sequential executes before next sibling',
      () {
        final engine = RoutineEngine(
          GroupNode(
            id: 'root',
            name: 'Root',
            executionMode: ExecutionMode.sequential,
            children: [
              GroupNode(
                id: 'inner',
                name: 'ParallelInner',
                executionMode: ExecutionMode.parallel,
                children: [
                  TimerInstance(id: 'a', name: 'A', duration: 3),
                  TimerInstance(id: 'b', name: 'B', duration: 2),
                ],
              ),
              TimerInstance(id: 'c', name: 'C', duration: 4),
            ],
          ),
        );

        // After 3 ticks inner parallel finishes (longest child is 3s).
        tickN(engine, 3);
        expect(rootChildGroup(engine, 0).status, NodeStatus.finished);
        expect(rootChildInstance(engine, 1).status, NodeStatus.running);

        // After a further 4 ticks C(4s) finishes → root done.
        expect(tickN(engine, 4), isTrue);
      },
    );

    // Parallel outer → [Sequential inner [A(2s), B(3s)], C(4s)]
    test(
      'sequential group nested inside parallel runs concurrently with sibling',
      () {
        final engine = RoutineEngine(
          GroupNode(
            id: 'root',
            name: 'Root',
            executionMode: ExecutionMode.parallel,
            children: [
              GroupNode(
                id: 'inner',
                name: 'SeqInner',
                executionMode: ExecutionMode.sequential,
                children: [
                  TimerInstance(id: 'a', name: 'A', duration: 2),
                  TimerInstance(id: 'b', name: 'B', duration: 3),
                ],
              ),
              TimerInstance(id: 'c', name: 'C', duration: 4),
            ],
          ),
        );

        // Inner takes 2+3=5s; C takes 4s; outer parallel finishes at max=5.
        tickN(engine, 4); // C finishes; inner still running (on B).
        expect(rootChildInstance(engine, 1).status, NodeStatus.finished);
        expect(rootChildGroup(engine, 0).status, NodeStatus.running);

        // One more tick: B finishes, inner finishes, root finishes.
        expect(engine.tick(), isTrue);
      },
    );
  });

  // -------------------------------------------------------------------------
  group('DotA 2 routine', () {
    // Sequential root: Prep(5s) → Rounds(seq,3×[Work(3s),Rest(2s)]) → Cooldown(4s)
    // Total: 5 + 3×5 + 4 = 24 ticks

    test('Prep is running on initial state', () {
      final engine = _dota2Routine();
      expect(rootChildInstance(engine, 0).status, NodeStatus.running);
      expect(rootChildGroup(engine, 1).status, NodeStatus.waiting);
      expect(rootChildInstance(engine, 2).status, NodeStatus.waiting);
    });

    test('Rounds group activates after Prep finishes (tick 5)', () {
      final engine = _dota2Routine();
      tickN(engine, 5);
      expect(rootChildInstance(engine, 0).status, NodeStatus.finished);
      expect(rootChildGroup(engine, 1).status, NodeStatus.running);
    });

    test('Work starts inside Rounds after Prep (tick 5)', () {
      final engine = _dota2Routine();
      tickN(engine, 5);
      final rounds = rootChildGroup(engine, 1);
      expect(
        (rounds.childStates[0] as TimerInstanceState).status,
        NodeStatus.running,
      );
      expect(
        (rounds.childStates[1] as TimerInstanceState).status,
        NodeStatus.waiting,
      );
    });

    test('Rest activates after Work finishes inside Rounds (tick 8)', () {
      final engine = _dota2Routine();
      tickN(engine, 8); // 5 prep + 3 work.
      final rounds = rootChildGroup(engine, 1);
      expect(
        (rounds.childStates[0] as TimerInstanceState).status,
        NodeStatus.finished,
      );
      expect(
        (rounds.childStates[1] as TimerInstanceState).status,
        NodeStatus.running,
      );
    });

    test('Rounds enters rep 2 after first Work+Rest cycle (tick 10)', () {
      final engine = _dota2Routine();
      tickN(engine, 10); // 5 prep + 5 round-rep-1.
      final rounds = rootChildGroup(engine, 1);
      expect(rounds.currentRepetition, 2);
      expect(rounds.status, NodeStatus.running);
    });

    test('Cooldown activates after Rounds completes 3 reps (tick 20)', () {
      final engine = _dota2Routine();
      tickN(engine, 20); // 5 prep + 15 rounds.
      expect(rootChildGroup(engine, 1).status, NodeStatus.finished);
      expect(rootChildInstance(engine, 2).status, NodeStatus.running);
    });

    test('routine completes in exactly 24 ticks', () {
      final engine = _dota2Routine();
      expect(tickN(engine, 24), isTrue);
      expect(engine.state.status, NodeStatus.finished);
    });

    test('routine is not finished one tick early (tick 23)', () {
      final engine = _dota2Routine();
      tickN(engine, 23);
      expect(engine.state.status, NodeStatus.running);
    });
  });

  // -------------------------------------------------------------------------
  group('Stretching routine', () {
    // Sequential root (2 reps): [Neck(4s), Shoulders(3s)]
    // Total: 2 × (4+3) = 14 ticks

    test('Neck is running at start', () {
      final engine = _stretchingRoutine();
      expect(rootChildInstance(engine, 0).status, NodeStatus.running);
      expect(rootChildInstance(engine, 1).status, NodeStatus.waiting);
    });

    test('Shoulders activates after Neck finishes (tick 4)', () {
      final engine = _stretchingRoutine();
      tickN(engine, 4);
      expect(rootChildInstance(engine, 0).status, NodeStatus.finished);
      expect(rootChildInstance(engine, 1).status, NodeStatus.running);
    });

    test('rep 2 starts after first Neck+Shoulders cycle (tick 7)', () {
      final engine = _stretchingRoutine();
      tickN(engine, 7);
      expect(engine.state.currentRepetition, 2);
      expect(engine.state.status, NodeStatus.running);
    });

    test('Neck is running again in rep 2 (tick 7)', () {
      final engine = _stretchingRoutine();
      tickN(engine, 7);
      // After reset, Neck is active child again.
      expect(rootChildInstance(engine, 0).status, NodeStatus.running);
      expect(rootChildInstance(engine, 0).remainingSeconds, 4);
    });

    test('routine completes in exactly 14 ticks', () {
      final engine = _stretchingRoutine();
      expect(tickN(engine, 14), isTrue);
      expect(engine.state.status, NodeStatus.finished);
    });

    test('routine not finished at tick 13', () {
      final engine = _stretchingRoutine();
      tickN(engine, 13);
      expect(engine.state.status, NodeStatus.running);
    });
  });

  // -------------------------------------------------------------------------
  group('JSON serialization round-trip', () {
    test('TimerInstanceState serializes and deserializes', () {
      final s = TimerInstanceState(
        nodeId: 'x',
        totalSeconds: 10,
        status: NodeStatus.running,
      )..remainingSeconds = 7;

      final json = s.toJson();
      final restored = NodeState.fromJson(json) as TimerInstanceState;

      expect(restored.nodeId, 'x');
      expect(restored.totalSeconds, 10);
      expect(restored.remainingSeconds, 7);
      expect(restored.status, NodeStatus.running);
    });

    test('GroupNodeState serializes and deserializes with children', () {
      final child = TimerInstanceState(nodeId: 'c', totalSeconds: 5);
      final group = GroupNodeState(
        nodeId: 'g',
        childStates: [child],
        status: NodeStatus.running,
        currentRepetition: 2,
        activeChildIndex: 0,
      );

      final json = group.toJson();
      final restored = NodeState.fromJson(json) as GroupNodeState;

      expect(restored.nodeId, 'g');
      expect(restored.status, NodeStatus.running);
      expect(restored.currentRepetition, 2);
      expect(restored.childStates.length, 1);
      expect(restored.childStates[0].nodeId, 'c');
    });

    test('engine state can be resumed from serialized snapshot', () {
      final engine = _seqAB();
      tickN(engine, 2); // A has 1s remaining.

      // Serialize and reconstruct.
      final stateJson = engine.state.toJson();
      final defJson = engine.definition.toJson();

      final definition = GroupNode.fromJson(defJson);
      final restoredState = GroupNodeState.fromJson(stateJson);
      final resumed = RoutineEngine.resume(
        definition: definition,
        state: restoredState,
      );

      // One more tick should finish A (1s left) and activate B.
      resumed.tick();
      expect(rootChildInstance(resumed, 0).status, NodeStatus.finished);
      expect(rootChildInstance(resumed, 1).status, NodeStatus.running);
    });
  });
}
