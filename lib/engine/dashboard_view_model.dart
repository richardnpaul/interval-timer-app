import 'dart:math';

import 'package:interval_timer_app/engine/node_state.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';
import 'package:interval_timer_app/models/timer_node.dart';

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class ActiveTimerItem {
  final String nodeId;
  final String name;
  final String? color;
  final int remainingSeconds;
  final int totalSeconds;
  final bool autoRestart;

  /// Path of ancestor group names, e.g. "Rounds" or "Core > Work".
  /// Empty string for direct children of the root.
  final String breadcrumb;

  const ActiveTimerItem({
    required this.nodeId,
    required this.name,
    required this.color,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.autoRestart,
    required this.breadcrumb,
  });

  /// Fraction of time remaining: 1.0 = full, 0.0 = expired.
  double get progress =>
      totalSeconds == 0 ? 0.0 : remainingSeconds / totalSeconds;
}

class UpNextItem {
  final String name;
  final String? color;
  final int durationSeconds;
  final String breadcrumb;

  const UpNextItem({
    required this.name,
    required this.color,
    required this.durationSeconds,
    required this.breadcrumb,
  });
}

// ---------------------------------------------------------------------------
// Sealed view-model hierarchy
// ---------------------------------------------------------------------------

sealed class DashboardViewModel {}

class IdleDashboardViewModel extends DashboardViewModel {}

class FinishedDashboardViewModel extends DashboardViewModel {
  final String routineName;
  FinishedDashboardViewModel({required this.routineName});
}

class SequentialDashboardViewModel extends DashboardViewModel {
  final String routineName;
  final ActiveTimerItem? hero;
  final List<UpNextItem> upNext;
  final int currentRepetition;
  final int totalRepetitions; // 0 = infinite

  SequentialDashboardViewModel({
    required this.routineName,
    required this.hero,
    required this.upNext,
    required this.currentRepetition,
    required this.totalRepetitions,
  });
}

class ParallelDashboardViewModel extends DashboardViewModel {
  final String routineName;
  final List<ActiveTimerItem> activeTimers;
  final int currentRepetition;
  final int totalRepetitions;

  ParallelDashboardViewModel({
    required this.routineName,
    required this.activeTimers,
    required this.currentRepetition,
    required this.totalRepetitions,
  });
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

DashboardViewModel buildDashboardViewModel(
  GroupNode definition,
  GroupNodeState state,
) {
  if (state.status == NodeStatus.finished) {
    return FinishedDashboardViewModel(routineName: definition.name);
  }

  if (definition.executionMode == ExecutionMode.sequential) {
    final (hero, upNext) = _buildSequentialData(definition, state, []);
    return SequentialDashboardViewModel(
      routineName: definition.name,
      hero: hero,
      upNext: upNext,
      currentRepetition: state.currentRepetition,
      totalRepetitions: definition.repetitions,
    );
  } else {
    final activeTimers = _collectRunningLeaves(definition, state, '');
    return ParallelDashboardViewModel(
      routineName: definition.name,
      activeTimers: activeTimers,
      currentRepetition: state.currentRepetition,
      totalRepetitions: definition.repetitions,
    );
  }
}

// ---------------------------------------------------------------------------
// Sequential helpers
// ---------------------------------------------------------------------------

/// Returns (hero, upNext) for the current sequential state.
///
/// [ancestors] are the display names of group nodes above [def] in the tree,
/// used to build the hero's breadcrumb.
(ActiveTimerItem?, List<UpNextItem>) _buildSequentialData(
  GroupNode def,
  GroupNodeState state,
  List<String> ancestors,
) {
  final idx = state.activeChildIndex;
  if (idx < 0 || idx >= def.children.length) return (null, []);

  // Siblings that come after the active child at this level.
  final sibBreadcrumb = ancestors.isEmpty ? '' : ancestors.join(' > ');
  final siblingsAfter = <UpNextItem>[
    for (int i = idx + 1; i < def.children.length; i++)
      _nodeToUpNextItem(def.children[i], sibBreadcrumb),
  ];

  final activeChild = def.children[idx];
  final activeChildState = state.childStates[idx];

  if (activeChild is TimerInstance && activeChildState is TimerInstanceState) {
    final breadcrumb = ancestors.isEmpty ? '' : ancestors.join(' > ');
    final hero = ActiveTimerItem(
      nodeId: activeChild.id,
      name: activeChild.name,
      color: activeChild.color,
      remainingSeconds: activeChildState.remainingSeconds,
      totalSeconds: activeChildState.totalSeconds,
      autoRestart: activeChild.autoRestart,
      breadcrumb: breadcrumb,
    );
    return (hero, siblingsAfter);
  }

  if (activeChild is GroupNode && activeChildState is GroupNodeState) {
    if (activeChild.executionMode == ExecutionMode.sequential) {
      final (innerHero, innerUpNext) = _buildSequentialData(
        activeChild,
        activeChildState,
        [...ancestors, activeChild.name],
      );
      return (innerHero, [...innerUpNext, ...siblingsAfter]);
    } else {
      // Parallel child: surface the first running leaf as the hero.
      final nestedBreadcrumb = ancestors.isEmpty
          ? activeChild.name
          : '${ancestors.join(' > ')} > ${activeChild.name}';
      final leaves = _collectRunningLeaves(
        activeChild,
        activeChildState,
        nestedBreadcrumb,
      );
      return (leaves.firstOrNull, siblingsAfter);
    }
  }

  return (null, siblingsAfter);
}

UpNextItem _nodeToUpNextItem(TimerNode node, String breadcrumb) => UpNextItem(
  name: node.name,
  color: node is TimerInstance ? (node).color : null,
  durationSeconds: _estimateDuration(node),
  breadcrumb: breadcrumb,
);

int _estimateDuration(TimerNode node) {
  if (node is TimerInstance) return node.duration;
  if (node is GroupNode) {
    final reps = node.repetitions == 0 ? 1 : node.repetitions;
    if (node.executionMode == ExecutionMode.sequential) {
      final sum = node.children.fold(0, (acc, c) => acc + _estimateDuration(c));
      return sum * reps;
    } else {
      final maxDur = node.children.fold(
        0,
        (acc, c) => max(acc, _estimateDuration(c)),
      );
      return maxDur * reps;
    }
  }
  return 0;
}

// ---------------------------------------------------------------------------
// Parallel helpers
// ---------------------------------------------------------------------------

/// Recursively collects all running leaves from [def]/[state].
///
/// [parentBreadcrumb] is the display path leading to [def]'s children.
/// Direct children of a parallel root use '' as their breadcrumb.
List<ActiveTimerItem> _collectRunningLeaves(
  GroupNode def,
  GroupNodeState state,
  String parentBreadcrumb,
) {
  final result = <ActiveTimerItem>[];
  for (int i = 0; i < def.children.length; i++) {
    final child = def.children[i];
    final childState = state.childStates[i];

    if (childState.status == NodeStatus.finished ||
        childState.status == NodeStatus.waiting) {
      continue;
    }

    if (child is TimerInstance && childState is TimerInstanceState) {
      result.add(
        ActiveTimerItem(
          nodeId: child.id,
          name: child.name,
          color: child.color,
          remainingSeconds: childState.remainingSeconds,
          totalSeconds: childState.totalSeconds,
          autoRestart: child.autoRestart,
          breadcrumb: parentBreadcrumb,
        ),
      );
    } else if (child is GroupNode && childState is GroupNodeState) {
      final childBreadcrumb = parentBreadcrumb.isEmpty
          ? child.name
          : '$parentBreadcrumb > ${child.name}';
      result.addAll(_collectRunningLeaves(child, childState, childBreadcrumb));
    }
  }
  return result;
}
