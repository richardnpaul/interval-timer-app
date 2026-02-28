import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/engine/engine.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';
import 'package:interval_timer_app/models/timer_node.dart';
import 'package:interval_timer_app/engine/node_state.dart';
import 'package:interval_timer_app/engine/dashboard_view_model.dart';

void main() {
  group('Engine Edge Cases (Coverage)', () {
    test('autoRestart with instant sound trigger (offset >= duration)', () {
      final timer = TimerInstance(
        name: 'Loop',
        duration: 2,
        autoRestart: true,
        soundOffset: 2,
      );
      final root = GroupNode(name: 'Root', children: [timer]);
      int soundCount = 0;
      final engine = RoutineEngine(root, onTimerFinished: (_) => soundCount++);

      // Tick 1: rem=1
      engine.tick();
      // Tick 2: rem=0 -> loops back to 2, triggers sound instantly
      engine.tick();
      expect(soundCount, 2); // 1 at start, 1 at loop
    });

    test('RoutineEngine activation with mismatched types throws ArgumentError', () {
      final instance = TimerInstance(name: 'A', duration: 10);
      final root = GroupNode(name: 'Root', children: [instance]);
      final engine = RoutineEngine(root);

      // We need to access private methods to force this via Fake
      expect(
        () => engine.activateNode(FakeState(), FakeNode()),
        throwsArgumentError,
      );
    });

    test('NodeState.fromJson throws for unknown type', () {
      expect(
        () => NodeState.fromJson({'type': 'unknown', 'nodeId': '1'}),
        throwsArgumentError,
      );
    });

    test('GroupNode.fromJson with missing fields uses defaults', () {
       final group = GroupNode.fromJson({'id': '1', 'name': 'G'});
       expect(group.executionMode, ExecutionMode.sequential);
       expect(group.repetitions, 1);
    });
  });

  group('Forced Engine Mismatches', () {
    test('tickNode throws on type mismatch', () {
      final root = GroupNode(
        name: 'Root',
        children: [TimerInstance(name: 'A', duration: 1)],
      );
      final engine = RoutineEngine(root);
      expect(
        () => engine.tickNode(FakeState(), FakeNode()),
        throwsArgumentError,
      );
    });

    test('activateNode throws on type mismatch', () {
      final root = GroupNode(
        name: 'Root',
        children: [TimerInstance(name: 'A', duration: 1)],
      );
      final engine = RoutineEngine(root);
      expect(
        () => engine.activateNode(FakeState(), FakeNode()),
        throwsArgumentError,
      );
    });

    test('resetNode throws on type mismatch', () {
      final root = GroupNode(
        name: 'Root',
        children: [TimerInstance(name: 'A', duration: 1)],
      );
      final engine = RoutineEngine(root);
      expect(
        () => engine.resetNode(FakeState(), FakeNode()),
        throwsArgumentError,
      );
    });

    test('RoutineEngine.buildNode throws on unknown node type', () {
      expect(
        () => RoutineEngine.buildNode(FakeNode()),
        throwsArgumentError,
      );
    });

    test('GroupNode reset recursive path', () {
      final loopGroup = GroupNode(
        name: 'Loop',
        repetitions: 2,
        children: [TimerInstance(name: 'A', duration: 1)],
      );
      final loopEngine = RoutineEngine(loopGroup);
      loopEngine.tick(); // Tick 1: A finishes, rep 1 complete -> triggers reset
      // currentRepetition increments BEFORE looping
      expect(loopEngine.state.currentRepetition, 2);

      // Hit resetNode recursive path
      final parentGroup = GroupNode(
        name: 'Parent',
        children: [loopGroup],
      );
      final parentEngine = RoutineEngine(parentGroup);
      parentEngine.resetNode(parentEngine.state, parentGroup);
    });

    test('Sequential group completion path naturally', () {
      final root = GroupNode(
        name: 'Root',
        children: [TimerInstance(name: 'A', duration: 1)],
      );
      final engine = RoutineEngine(root);
      engine.tick(); // A finishes -> triggers _onGroupIterationComplete via idx checking (line 88)
      expect(engine.state.status, NodeStatus.finished);
    });

    test('Empty group naturally completes (hits line 76)', () {
      final root = GroupNode(name: 'Empty', children: []);
      final engine = RoutineEngine(root);
      // Initial status is running, but index is 0 and length is 0.
      engine.tick(); // Should hit line 76 immediately
      expect(engine.state.status, NodeStatus.finished);
    });
  });

  group('DashboardViewModel Parallel Duration (Coverage)', () {
    test('Parallel group duration estimation', () {
      final group = GroupNode(
        name: 'P',
        executionMode: ExecutionMode.parallel,
        children: [
          TimerInstance(name: 'A', duration: 10),
          TimerInstance(name: 'B', duration: 20),
        ],
      );
      final root = GroupNode(name: 'Root', children: [group]);
      final state = RoutineEngine.buildGroupState(root);
      // We need to trigger the parallel duration estimation in dashboard_view_model
      // It's used when estimating UpNextItems or Hero duration.
      // SequentialDashboardViewModel uses _estimateDuration for upNext.
      buildDashboardViewModel(root, state);
      // Since it's Seq -> Parallel, hero is Parallel, upNext[0] would be the next child.
      // If we move to upNext...
      final root2 = GroupNode(
        name: 'Root',
        children: [
          TimerInstance(name: 'Wait', duration: 1),
          group,
        ],
      );
      final state2 = RoutineEngine.buildGroupState(root2);
      final vm2 = buildDashboardViewModel(root2, state2) as SequentialDashboardViewModel;
      expect(vm2.upNext[0].durationSeconds, 20); // max(10, 20)
    });
  });
}

class FakeNode implements TimerNode {
  @override String get id => 'fake';
  @override String get name => 'fake';
  @override Map<String, dynamic> toJson() => {};
}

class FakeState implements NodeState {
  @override String get nodeId => 'fake';
  @override NodeStatus get status => NodeStatus.waiting;
  @override Map<String, dynamic> toJson() => {};
}
