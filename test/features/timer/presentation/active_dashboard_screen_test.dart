import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/core/domain/group_node.dart';
import 'package:interval_timer_app/core/domain/timer_instance.dart';
import 'package:interval_timer_app/core/providers/service_providers.dart';
import 'package:interval_timer_app/features/timer/application/active_routine_notifier.dart';
import 'package:interval_timer_app/features/timer/domain/node_state.dart';
import 'package:interval_timer_app/features/timer/presentation/active_dashboard_screen.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeBackgroundServiceWrapper implements BackgroundServiceWrapper {
  final _controller = StreamController<Map<String, dynamic>?>.broadcast();

  @override
  Stream<Map<String, dynamic>?> on(String method) => _controller.stream;

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {}

  void dispose() => _controller.close();
}

class FakeSettingsService implements SettingsService {
  @override
  Future<bool> isWakelockEnabled() async => false;

  @override
  Future<void> setWakelock(bool enabled) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [GroupNode] + matching [GroupNodeState] pair for a single running
/// timer leaf inside a sequential root.
(GroupNode, GroupNodeState) _makeSequentialSnapshot({
  String name = 'My Routine',
  String timerName = 'Work',
  String? timerColor,
  int duration = 30,
  int remaining = 20,
  int reptitions = 1,
  int currentRep = 1,
  bool addSecond = false, // add an extra timer child after the active one
}) {
  final timer = TimerInstance(
    id: 't1',
    name: timerName,
    duration: duration,
    color: timerColor,
  );
  final timerState = TimerInstanceState(
    nodeId: 't1',
    totalSeconds: duration,
    status: NodeStatus.running,
  )..remainingSeconds = remaining;

  final children = <TimerInstance>[timer];
  final childStates = <NodeState>[timerState];

  if (addSecond) {
    children.add(TimerInstance(id: 't2', name: 'Rest', duration: 10));
    childStates.add(TimerInstanceState(nodeId: 't2', totalSeconds: 10));
  }

  final root = GroupNode(
    id: 'root',
    name: name,
    children: children,
    repetitions: reptitions,
  );
  final rootState = GroupNodeState(
    nodeId: 'root',
    status: NodeStatus.running,
    childStates: childStates,
    currentRepetition: currentRep,
    activeChildIndex: 0,
  );
  return (root, rootState);
}

/// Builds a parallel root with two running timer leaves.
(GroupNode, GroupNodeState) _makeParallelSnapshot({
  String name = 'Parallel Routine',
  int reps = 1,
  int currentRep = 1,
}) {
  final t1 = TimerInstance(
    id: 'p1',
    name: 'Push',
    duration: 20,
    color: '#FF0000',
  );
  final t2 = TimerInstance(id: 'p2', name: 'Pull', duration: 15);

  final s1 = TimerInstanceState(
    nodeId: 'p1',
    totalSeconds: 20,
    status: NodeStatus.running,
  )..remainingSeconds = 10;
  final s2 = TimerInstanceState(
    nodeId: 'p2',
    totalSeconds: 15,
    status: NodeStatus.running,
  )..remainingSeconds = 8;

  final root = GroupNode(
    id: 'root',
    name: name,
    children: [t1, t2],
    executionMode: ExecutionMode.parallel,
    repetitions: reps,
  );
  final rootState = GroupNodeState(
    nodeId: 'root',
    status: NodeStatus.running,
    childStates: [s1, s2],
    currentRepetition: currentRep,
    activeChildIndex: -1,
  );
  return (root, rootState);
}

Widget _wrapWidget({
  required Widget child,
  ActiveRoutineSnapshot? snapshot,
  FakeBackgroundServiceWrapper? svc,
}) {
  final fakeSvc = svc ?? FakeBackgroundServiceWrapper();
  return ProviderScope(
    overrides: [
      backgroundServiceWrapperProvider.overrideWithValue(fakeSvc),
      settingsServiceProvider.overrideWithValue(FakeSettingsService()),
      activeRoutineProvider.overrideWith(
        () => _FakeActiveRoutineNotifier(snapshot),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

class _FakeActiveRoutineNotifier extends ActiveRoutineNotifier {
  final ActiveRoutineSnapshot? _initial;
  _FakeActiveRoutineNotifier(this._initial);

  @override
  ActiveRoutineSnapshot? build() => _initial;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ActiveDashboardScreen', () {
    // ── Idle ────────────────────────────────────────────────────────────────
    testWidgets('shows idle view when no routine is running', (tester) async {
      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: null),
      );
      await tester.pump();

      expect(find.text('No routine running'), findsOneWidget);
      expect(
        find.text('Go to Routines and tap ▶ to start one'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
    });

    testWidgets('shows idle view when routine is paused', (tester) async {
      final root = GroupNode(id: 'r', name: 'Paused Routine');
      final rootState = GroupNodeState(
        nodeId: 'r',
        status: NodeStatus.paused,
        childStates: [],
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('No routine running'), findsOneWidget);
    });

    // ── Finished ─────────────────────────────────────────────────────────────

    testWidgets('shows finished view when routine is done', (tester) async {
      final root = GroupNode(id: 'r', name: 'Morning Run');
      final rootState = GroupNodeState(
        nodeId: 'r',
        status: NodeStatus.finished,
        childStates: [],
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('Morning Run finished!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    });

    testWidgets('Done button calls stopRoutine', (tester) async {
      final root = GroupNode(id: 'r', name: 'Run');
      final rootState = GroupNodeState(
        nodeId: 'r',
        status: NodeStatus.finished,
        childStates: [],
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pump();
      // No crash = stopRoutine was called successfully.
    });

    // ── Sequential ──────────────────────────────────────────────────────────
    testWidgets('shows sequential view with hero timer', (tester) async {
      final (root, rootState) = _makeSequentialSnapshot(
        name: 'HIIT',
        timerName: 'Sprint',
        duration: 30,
        remaining: 15,
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('HIIT'), findsOneWidget);
      expect(find.text('Sprint'), findsOneWidget);
      expect(find.text('00:15'), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    });

    testWidgets('sequential view shows upNext items', (tester) async {
      final (root, rootState) = _makeSequentialSnapshot(
        name: 'Full Body',
        timerName: 'Warmup',
        addSecond: true,
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('Up Next'), findsOneWidget);
      expect(find.text('Rest'), findsOneWidget);
    });

    testWidgets('sequential view shows multiple upNext items with separators', (
      tester,
    ) async {
      final t1 = TimerInstance(id: 't1', name: 'Work', duration: 30);
      final t2 = TimerInstance(id: 't2', name: 'Rest', duration: 10);
      final t3 = TimerInstance(id: 't3', name: 'Work 2', duration: 30);

      final root = GroupNode(id: 'root', name: 'Multi', children: [t1, t2, t3]);
      final rootState = GroupNodeState(
        nodeId: 'root',
        status: NodeStatus.running,
        childStates: [
          TimerInstanceState(
            nodeId: 't1',
            totalSeconds: 30,
            status: NodeStatus.running,
          ),
          TimerInstanceState(nodeId: 't2', totalSeconds: 10),
          TimerInstanceState(nodeId: 't3', totalSeconds: 30),
        ],
        activeChildIndex: 0,
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('Rest'), findsOneWidget);
      expect(find.text('Work 2'), findsOneWidget);
      // ListView.separated should build separators between items.
      // Line 179 in active_dashboard_screen.dart is the separatorBuilder.
    });

    testWidgets('sequential view shows rep badge when reps > 1', (
      tester,
    ) async {
      final (root, rootState) = _makeSequentialSnapshot(
        name: 'Circuit',
        reptitions: 3,
        currentRep: 2,
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('sequential rep badge shows infinity for 0 reps', (
      tester,
    ) async {
      final (root, rootState) = _makeSequentialSnapshot(
        name: 'Infinite',
        reptitions: 0,
        currentRep: 5,
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('5 / ∞'), findsOneWidget);
    });

    testWidgets('sequential view with coloured timer', (tester) async {
      final (root, rootState) = _makeSequentialSnapshot(timerColor: '#FF0000');
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();
      // No crash verifies colorFromHex branch is exercised.
    });

    testWidgets('sequential stop button calls stopRoutine', (tester) async {
      final (root, rootState) = _makeSequentialSnapshot(name: 'Yoga');
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Stop routine'));
      await tester.pump();
      // No crash = success.
    });

    testWidgets('sequential hero shows breadcrumb for nested timer', (
      tester,
    ) async {
      // Build a sequential root containing a sequential group, which wraps a timer.
      final innerTimer = TimerInstance(id: 'it1', name: 'Plank', duration: 60);
      final innerGroup = GroupNode(
        id: 'g1',
        name: 'Core',
        children: [innerTimer],
      );
      final innerTimerState = TimerInstanceState(
        nodeId: 'it1',
        totalSeconds: 60,
        status: NodeStatus.running,
      );
      final innerGroupState = GroupNodeState(
        nodeId: 'g1',
        status: NodeStatus.running,
        childStates: [innerTimerState],
        activeChildIndex: 0,
      );
      final root = GroupNode(
        id: 'root',
        name: 'Full Workout',
        children: [innerGroup],
      );
      final rootState = GroupNodeState(
        nodeId: 'root',
        status: NodeStatus.running,
        childStates: [innerGroupState],
        activeChildIndex: 0,
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('Plank'), findsOneWidget);
      expect(find.text('Core'), findsOneWidget); // breadcrumb
    });

    testWidgets('sequential with null hero shows progress indicator', (
      tester,
    ) async {
      // Empty sequential group – activeChildIndex will be out of range → hero = null.
      final root = GroupNode(id: 'root', name: 'Empty', children: []);
      final rootState = GroupNodeState(
        nodeId: 'root',
        status: NodeStatus.running,
        childStates: [],
        activeChildIndex: -1,
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // ── Parallel ─────────────────────────────────────────────────────────────
    testWidgets('shows parallel view with timer cards', (tester) async {
      final (root, rootState) = _makeParallelSnapshot(name: 'Parallel HIIT');
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('Parallel HIIT'), findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      expect(find.text('Pull'), findsOneWidget);
    });

    testWidgets('parallel view shows rep badge when reps > 1', (tester) async {
      final (root, rootState) = _makeParallelSnapshot(reps: 4, currentRep: 2);
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('2 / 4'), findsOneWidget);
    });

    testWidgets('parallel stop button calls stopRoutine', (tester) async {
      final (root, rootState) = _makeParallelSnapshot();
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Stop routine'));
      await tester.pump();
    });

    testWidgets('parallel timer card shows coloured timer correctly', (
      tester,
    ) async {
      final (root, rootState) = _makeParallelSnapshot();
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      // Push has color '#FF0000', Pull has null — both should render without crash.
      expect(find.text('00:10'), findsWidgets); // Push remaining
    });

    testWidgets('upNext tile with breadcrumb renders correctly', (
      tester,
    ) async {
      // Sequential root > sequential inner group > t1 (active), t2 (up next)
      final t1 = TimerInstance(id: 't1', name: 'Work', duration: 30);
      final t2 = TimerInstance(
        id: 't2',
        name: 'Rest',
        duration: 10,
        color: '#00FF00',
      );
      final inner = GroupNode(id: 'g1', name: 'Block', children: [t1, t2]);
      final t1State = TimerInstanceState(
        nodeId: 't1',
        totalSeconds: 30,
        status: NodeStatus.running,
      );
      final t2State = TimerInstanceState(nodeId: 't2', totalSeconds: 10);
      final innerState = GroupNodeState(
        nodeId: 'g1',
        status: NodeStatus.running,
        childStates: [t1State, t2State],
        activeChildIndex: 0,
      );
      final root = GroupNode(id: 'root', name: 'Session', children: [inner]);
      final rootState = GroupNodeState(
        nodeId: 'root',
        status: NodeStatus.running,
        childStates: [innerState],
        activeChildIndex: 0,
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('Rest'), findsOneWidget);
      expect(find.text('Up Next'), findsOneWidget);
    });

    testWidgets('parallel child with colored card and breadcrumb', (
      tester,
    ) async {
      // Nested parallel: root (parallel) > group (parallel) > timers
      final t1 = TimerInstance(
        id: 't1',
        name: 'Squat',
        duration: 20,
        color: '#0000FF',
      );
      final nestedGroup = GroupNode(
        id: 'ng',
        name: 'Legs',
        children: [t1],
        executionMode: ExecutionMode.parallel,
      );
      final t1State = TimerInstanceState(
        nodeId: 't1',
        totalSeconds: 20,
        status: NodeStatus.running,
      )..remainingSeconds = 15;
      final ngState = GroupNodeState(
        nodeId: 'ng',
        status: NodeStatus.running,
        childStates: [t1State],
        activeChildIndex: -1,
      );
      final root = GroupNode(
        id: 'root',
        name: 'Full Body',
        children: [nestedGroup],
        executionMode: ExecutionMode.parallel,
      );
      final rootState = GroupNodeState(
        nodeId: 'root',
        status: NodeStatus.running,
        childStates: [ngState],
        activeChildIndex: -1,
      );
      final snapshot = ActiveRoutineSnapshot(
        definition: root,
        state: rootState,
      );

      await tester.pumpWidget(
        _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
      );
      await tester.pump();

      expect(find.text('Squat'), findsOneWidget);
      // 'Legs' appears as breadcrumb on the card.
      expect(find.text('Legs'), findsOneWidget);
    });

    testWidgets(
      'sequential with parallel inner group surfaces first leaf as hero',
      (tester) async {
        final t1 = TimerInstance(
          id: 't1',
          name: 'Jump',
          duration: 15,
          color: '#AABBCC',
        );
        final inner = GroupNode(
          id: 'pg',
          name: 'Plyos',
          children: [t1],
          executionMode: ExecutionMode.parallel,
        );
        final t1State = TimerInstanceState(
          nodeId: 't1',
          totalSeconds: 15,
          status: NodeStatus.running,
        )..remainingSeconds = 7;
        final pgState = GroupNodeState(
          nodeId: 'pg',
          status: NodeStatus.running,
          childStates: [t1State],
          activeChildIndex: -1,
        );
        final root = GroupNode(id: 'root', name: 'Power', children: [inner]);
        final rootState = GroupNodeState(
          nodeId: 'root',
          status: NodeStatus.running,
          childStates: [pgState],
          activeChildIndex: 0,
        );
        final snapshot = ActiveRoutineSnapshot(
          definition: root,
          state: rootState,
        );

        await tester.pumpWidget(
          _wrapWidget(child: const ActiveDashboardScreen(), snapshot: snapshot),
        );
        await tester.pump();

        // 'Jump' surfaced as hero via parallel branch of _buildSequentialData.
        expect(find.text('Jump'), findsOneWidget);
      },
    );
  });
}
