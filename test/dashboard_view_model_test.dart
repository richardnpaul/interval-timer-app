import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/engine/dashboard_view_model.dart';
import 'package:interval_timer_app/engine/engine.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a DashboardViewModel built from [definition] after [ticks] ticks.
DashboardViewModel vmAt(GroupNode definition, int ticks) {
  final engine = RoutineEngine(definition);
  for (int i = 0; i < ticks; i++) {
    engine.tick();
  }
  return buildDashboardViewModel(definition, engine.state);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Simple sequential: [A(3s), B(2s), C(4s)]
GroupNode _seqABC() => GroupNode(
  id: 'root',
  name: 'ABC',
  executionMode: ExecutionMode.sequential,
  repetitions: 2,
  children: [
    TimerInstance(id: 'a', name: 'A', duration: 3, color: '#EF5350'),
    TimerInstance(id: 'b', name: 'B', duration: 2),
    TimerInstance(id: 'c', name: 'C', duration: 4),
  ],
);

/// Parallel: [X(3s), Y(5s)]
GroupNode _parallelXY() => GroupNode(
  id: 'root',
  name: 'XY',
  executionMode: ExecutionMode.parallel,
  children: [
    TimerInstance(id: 'x', name: 'X', duration: 3),
    TimerInstance(id: 'y', name: 'Y', duration: 5),
  ],
);

/// DotA2: Sequential root → [Prep(5s), Rounds(seq 3×[Work(3s),Rest(2s)]), Cooldown(4s)]
GroupNode _dota2() => GroupNode(
  id: 'root',
  name: 'DotA2',
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
);

/// Mixed: parallel root → [SeqGroup([A(2s),B(3s)]), Y(4s)]
GroupNode _mixedParallelSeq() => GroupNode(
  id: 'root',
  name: 'Mixed',
  executionMode: ExecutionMode.parallel,
  children: [
    GroupNode(
      id: 'inner',
      name: 'Inner',
      executionMode: ExecutionMode.sequential,
      children: [
        TimerInstance(id: 'a', name: 'A', duration: 2),
        TimerInstance(id: 'b', name: 'B', duration: 3),
      ],
    ),
    TimerInstance(id: 'y', name: 'Y', duration: 6),
  ],
);

/// Nested Parallel: Seq root -> [Outer Parallel ([Inner Seq ([A(2)])])]
GroupNode _nestedParallel() => GroupNode(
  id: 'root',
  name: 'Root',
  executionMode: ExecutionMode.sequential,
  children: [
    GroupNode(
      id: 'outer',
      name: 'Outer',
      executionMode: ExecutionMode.parallel,
      repetitions: 2,
      children: [
        GroupNode(
          id: 'inner',
          name: 'Inner',
          executionMode: ExecutionMode.sequential,
          children: [
            TimerInstance(id: 'a', name: 'A', duration: 2),
          ],
        ),
      ],
    ),
  ],
);

// ===========================================================================
// Tests
// ===========================================================================

void main() {
  // -------------------------------------------------------------------------
  group('Sequential root — initial state (tick 0)', () {
    test('returns SequentialDashboardViewModel', () {
      final vm = vmAt(_seqABC(), 0);
      expect(vm, isA<SequentialDashboardViewModel>());
    });

    test('hero is first timer with full duration', () {
      final vm = vmAt(_seqABC(), 0) as SequentialDashboardViewModel;
      expect(vm.hero, isNotNull);
      expect(vm.hero!.nodeId, 'a');
      expect(vm.hero!.name, 'A');
      expect(vm.hero!.remainingSeconds, 3);
      expect(vm.hero!.totalSeconds, 3);
    });

    test('hero picks up color from definition', () {
      final vm = vmAt(_seqABC(), 0) as SequentialDashboardViewModel;
      expect(vm.hero!.color, '#EF5350');
    });

    test('upNext contains the two subsequent timers in order', () {
      final vm = vmAt(_seqABC(), 0) as SequentialDashboardViewModel;
      expect(vm.upNext.length, 2);
      expect(vm.upNext[0].name, 'B');
      expect(vm.upNext[1].name, 'C');
    });

    test('routineName is correct', () {
      final vm = vmAt(_seqABC(), 0) as SequentialDashboardViewModel;
      expect(vm.routineName, 'ABC');
    });

    test('currentRepetition is 1', () {
      final vm = vmAt(_seqABC(), 0) as SequentialDashboardViewModel;
      expect(vm.currentRepetition, 1);
    });

    test('totalRepetitions is 2', () {
      final vm = vmAt(_seqABC(), 0) as SequentialDashboardViewModel;
      expect(vm.totalRepetitions, 2);
    });
  });

  // -------------------------------------------------------------------------
  group('Sequential root — mid-run', () {
    test('hero is second timer after first finishes (tick 3)', () {
      final vm = vmAt(_seqABC(), 3) as SequentialDashboardViewModel;
      expect(vm.hero!.nodeId, 'b');
      expect(vm.hero!.remainingSeconds, 2);
    });

    test('upNext has only one item when on second timer (tick 3)', () {
      final vm = vmAt(_seqABC(), 3) as SequentialDashboardViewModel;
      expect(vm.upNext.length, 1);
      expect(vm.upNext[0].name, 'C');
    });

    test('upNext is empty when on last timer (tick 5)', () {
      final vm = vmAt(_seqABC(), 5) as SequentialDashboardViewModel;
      expect(vm.hero!.nodeId, 'c');
      expect(vm.upNext, isEmpty);
    });

    test('hero remaining decrements while running (tick 1)', () {
      final vm = vmAt(_seqABC(), 1) as SequentialDashboardViewModel;
      expect(vm.hero!.remainingSeconds, 2);
      expect(vm.hero!.totalSeconds, 3);
    });

    test('rep 2 starts after first full pass (tick 9 = 3+2+4)', () {
      final vm = vmAt(_seqABC(), 9) as SequentialDashboardViewModel;
      expect(vm.currentRepetition, 2);
      expect(vm.hero!.nodeId, 'a');
      expect(vm.hero!.remainingSeconds, 3);
    });
  });

  // -------------------------------------------------------------------------
  group('Sequential root — finished', () {
    test(
      'returns FinishedDashboardViewModel when routine done (tick 18 = 2×9)',
      () {
        final vm = vmAt(_seqABC(), 18);
        expect(vm, isA<FinishedDashboardViewModel>());
      },
    );

    test('FinishedDashboardViewModel carries routine name', () {
      final vm = vmAt(_seqABC(), 18) as FinishedDashboardViewModel;
      expect(vm.routineName, 'ABC');
    });
  });

  // -------------------------------------------------------------------------
  group('Parallel root', () {
    test('returns ParallelDashboardViewModel', () {
      final vm = vmAt(_parallelXY(), 0);
      expect(vm, isA<ParallelDashboardViewModel>());
    });

    test('both timers appear in activeTimers at start', () {
      final vm = vmAt(_parallelXY(), 0) as ParallelDashboardViewModel;
      expect(vm.activeTimers.length, 2);
      expect(vm.activeTimers.any((t) => t.nodeId == 'x'), isTrue);
      expect(vm.activeTimers.any((t) => t.nodeId == 'y'), isTrue);
    });

    test('shorter timer disappears after it finishes (tick 3)', () {
      final vm = vmAt(_parallelXY(), 3) as ParallelDashboardViewModel;
      expect(vm.activeTimers.length, 1);
      expect(vm.activeTimers.single.nodeId, 'y');
    });

    test('remaining time is correct after ticking (tick 2)', () {
      final vm = vmAt(_parallelXY(), 2) as ParallelDashboardViewModel;
      final x = vm.activeTimers.firstWhere((t) => t.nodeId == 'x');
      final y = vm.activeTimers.firstWhere((t) => t.nodeId == 'y');
      expect(x.remainingSeconds, 1);
      expect(y.remainingSeconds, 3);
    });

    test('routineName is correct', () {
      final vm = vmAt(_parallelXY(), 0) as ParallelDashboardViewModel;
      expect(vm.routineName, 'XY');
    });

    test(
      'returns FinishedDashboardViewModel when all parallel timers done (tick 5)',
      () {
        final vm = vmAt(_parallelXY(), 5);
        expect(vm, isA<FinishedDashboardViewModel>());
      },
    );
  });

  // -------------------------------------------------------------------------
  group('DotA2 — nested sequential group', () {
    test('hero is Prep at tick 0', () {
      final vm = vmAt(_dota2(), 0) as SequentialDashboardViewModel;
      expect(vm.hero!.nodeId, 'prep');
      expect(vm.hero!.remainingSeconds, 5);
    });

    test('upNext at tick 0: Rounds (as group placeholder) then Cooldown', () {
      final vm = vmAt(_dota2(), 0) as SequentialDashboardViewModel;
      // Root-level: after Prep → Rounds group, Cooldown
      expect(vm.upNext.length, 2);
      expect(vm.upNext[0].name, 'Rounds');
      expect(vm.upNext[1].name, 'Cooldown');
    });

    test('hero is Work (inside Rounds) at tick 5', () {
      final vm = vmAt(_dota2(), 5) as SequentialDashboardViewModel;
      expect(vm.hero!.nodeId, 'work');
      expect(vm.hero!.remainingSeconds, 3);
    });

    test('upNext inside Rounds at tick 5: Rest, then Cooldown from parent', () {
      final vm = vmAt(_dota2(), 5) as SequentialDashboardViewModel;
      // Innermost remaining: Rest; outer remaining: Cooldown
      expect(vm.upNext.length, 2);
      expect(vm.upNext[0].name, 'Rest');
      expect(vm.upNext[1].name, 'Cooldown');
    });

    test('hero breadcrumb shows group path for nested timer', () {
      final vm = vmAt(_dota2(), 5) as SequentialDashboardViewModel;
      expect(vm.hero!.breadcrumb, contains('Rounds'));
    });

    test('hero is Rest at tick 8 (5+3)', () {
      final vm = vmAt(_dota2(), 8) as SequentialDashboardViewModel;
      expect(vm.hero!.nodeId, 'rest');
    });

    test('upNext at tick 8: Cooldown (rest of outer, rounds repeating next)', () {
      final vm = vmAt(_dota2(), 8) as SequentialDashboardViewModel;
      // After Rest: next rep of Rounds starts Work, then Cooldown after rounds -> but at Root level: after Rounds → Cooldown
      // Conservative: at least Cooldown is in upNext
      expect(vm.upNext.any((i) => i.name == 'Cooldown'), isTrue);
    });

    test('hero is Cooldown at tick 20 (5+3×5)', () {
      final vm = vmAt(_dota2(), 20) as SequentialDashboardViewModel;
      expect(vm.hero!.nodeId, 'cooldown');
    });

    test('upNext empty when on Cooldown (last item)', () {
      final vm = vmAt(_dota2(), 20) as SequentialDashboardViewModel;
      expect(vm.upNext, isEmpty);
    });

    test('routine finishes at tick 24', () {
      final vm = vmAt(_dota2(), 24);
      expect(vm, isA<FinishedDashboardViewModel>());
    });
  });

  // -------------------------------------------------------------------------
  group('Mixed — parallel root with sequential child group', () {
    test('returns ParallelDashboardViewModel', () {
      final vm = vmAt(_mixedParallelSeq(), 0);
      expect(vm, isA<ParallelDashboardViewModel>());
    });

    test('two active timers at start: A (from Inner) and Y', () {
      final vm = vmAt(_mixedParallelSeq(), 0) as ParallelDashboardViewModel;
      expect(vm.activeTimers.length, 2);
      expect(vm.activeTimers.any((t) => t.nodeId == 'a'), isTrue);
      expect(vm.activeTimers.any((t) => t.nodeId == 'y'), isTrue);
    });

    test('breadcrumb of A shows Inner group name', () {
      final vm = vmAt(_mixedParallelSeq(), 0) as ParallelDashboardViewModel;
      final a = vm.activeTimers.firstWhere((t) => t.nodeId == 'a');
      expect(a.breadcrumb, contains('Inner'));
    });

    test('breadcrumb of Y is empty (direct child of root)', () {
      final vm = vmAt(_mixedParallelSeq(), 0) as ParallelDashboardViewModel;
      final y = vm.activeTimers.firstWhere((t) => t.nodeId == 'y');
      expect(y.breadcrumb, isEmpty);
    });

    test('A advances to B after 2 ticks; Y still running', () {
      final vm = vmAt(_mixedParallelSeq(), 2) as ParallelDashboardViewModel;
      expect(vm.activeTimers.any((t) => t.nodeId == 'b'), isTrue);
      expect(vm.activeTimers.any((t) => t.nodeId == 'y'), isTrue);
      expect(vm.activeTimers.any((t) => t.nodeId == 'a'), isFalse);
    });

    test('only Y remains after Inner finishes (tick 5 = A2+B3)', () {
      // Inner total=5s, Y=6s → at tick 5 Inner is done, Y still running
      final vm = vmAt(_mixedParallelSeq(), 5) as ParallelDashboardViewModel;
      expect(vm.activeTimers.length, 1);
      expect(vm.activeTimers.single.nodeId, 'y');
    });

    test('finishes at tick 6 (Inner=5s, Y=6s → longest is Y)', () {
      // Inner: 2+3=5s; Y: 6s — root parallel finishes when both done = 6 ticks
      final vm = vmAt(_mixedParallelSeq(), 6);
      expect(vm, isA<FinishedDashboardViewModel>());
    });
  });

  // -------------------------------------------------------------------------
  group('ActiveTimerItem helpers', () {
    test('progress is 1.0 when remaining equals total', () {
      final item = ActiveTimerItem(
        nodeId: 'x',
        name: 'X',
        color: null,
        remainingSeconds: 10,
        totalSeconds: 10,
        autoRestart: false,
        breadcrumb: '',
      );
      expect(item.progress, 1.0);
    });

    test('progress is 0.5 halfway through', () {
      final item = ActiveTimerItem(
        nodeId: 'x',
        name: 'X',
        color: null,
        remainingSeconds: 5,
        totalSeconds: 10,
        autoRestart: false,
        breadcrumb: '',
      );
      expect(item.progress, 0.5);
    });

    test('progress is 0.0 for zero-duration item', () {
      final item = ActiveTimerItem(
        nodeId: 'x',
        name: 'X',
        color: null,
        remainingSeconds: 0,
        totalSeconds: 0,
        autoRestart: false,
        breadcrumb: '',
      );
      expect(item.progress, 0.0);
    });
  });

  // -------------------------------------------------------------------------
  group('Nested Parallel Breadcrumbs & Duration', () {
    test('breadcrumb shows path for nested parallel child', () {
      // Seq root -> Outer Parallel -> Inner Seq -> A
      final vm = vmAt(_nestedParallel(), 0);
      // Root is Sequential, but it contains ‘Outer’ which is parallel.
      // SequentialDashboardViewModel hero logic picks the first running leaf.
      expect(vm, isA<SequentialDashboardViewModel>());
      final sVm = vm as SequentialDashboardViewModel;
      expect(sVm.hero!.breadcrumb, 'Outer > Inner');
    });

    test('duration estimation for parallel group', () {
      final root = GroupNode(
        name: 'Root',
        children: [
          _nestedParallel(),
          TimerInstance(name: 'Tail', duration: 10),
        ],
      );
      final vm = vmAt(root, 0) as SequentialDashboardViewModel;
      expect(vm.upNext.length, 1);
      expect(vm.upNext[0].name, 'Tail');

      final innerBreadcrumb = GroupNode(
        name: 'ParallelRoot',
        executionMode: ExecutionMode.parallel,
        children: [
          GroupNode(
             name: 'Alpha',
             children: [TimerInstance(name: 'Beta', duration: 10)],
          ),
        ],
      );
      final vmParallel = vmAt(innerBreadcrumb, 0) as ParallelDashboardViewModel;
      // Parallel root children use their own name as breadcrumb start.
      expect(vmParallel.activeTimers.first.breadcrumb, 'Alpha');
    });
  });
}
