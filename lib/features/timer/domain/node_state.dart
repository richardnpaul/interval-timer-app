/// Runtime status of any node in the execution tree.
enum NodeStatus { waiting, running, paused, finished }

// ---------------------------------------------------------------------------
// Abstract base
// ---------------------------------------------------------------------------

abstract interface class NodeState {
  String get nodeId;
  NodeStatus get status;

  Map<String, dynamic> toJson();

  static NodeState fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'instance' => TimerInstanceState.fromJson(json),
      'group' => GroupNodeState.fromJson(json),
      _ => throw ArgumentError('Unknown NodeState type: $type'),
    };
  }
}

// ---------------------------------------------------------------------------
// Leaf runtime state
// ---------------------------------------------------------------------------

class TimerInstanceState implements NodeState {
  @override
  final String nodeId;

  @override
  NodeStatus status;

  int remainingSeconds;
  final int totalSeconds;

  TimerInstanceState({
    required this.nodeId,
    required this.totalSeconds,
    this.status = NodeStatus.waiting,
  }) : remainingSeconds = totalSeconds;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'instance',
    'nodeId': nodeId,
    'status': status.name,
    'remainingSeconds': remainingSeconds,
    'totalSeconds': totalSeconds,
  };

  factory TimerInstanceState.fromJson(Map<String, dynamic> json) {
    final s = TimerInstanceState(
      nodeId: json['nodeId'] as String,
      totalSeconds: json['totalSeconds'] as int,
      status: NodeStatus.values.byName(json['status'] as String),
    );
    s.remainingSeconds = json['remainingSeconds'] as int;
    return s;
  }

  /// Reset back to full duration, ready to run again.
  void reset() {
    remainingSeconds = totalSeconds;
    status = NodeStatus.waiting;
  }
}

// ---------------------------------------------------------------------------
// Branch runtime state
// ---------------------------------------------------------------------------

class GroupNodeState implements NodeState {
  @override
  final String nodeId;

  @override
  NodeStatus status;

  /// 1-based. Starts at 1, increments each time all children complete.
  int currentRepetition;

  /// Sequential only: index of the child that is currently running.
  /// -1 = parallel (all children active at once).
  int activeChildIndex;

  List<NodeState> childStates;

  GroupNodeState({
    required this.nodeId,
    required this.childStates,
    this.status = NodeStatus.waiting,
    this.currentRepetition = 1,
    this.activeChildIndex = 0,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': 'group',
    'nodeId': nodeId,
    'status': status.name,
    'currentRepetition': currentRepetition,
    'activeChildIndex': activeChildIndex,
    'childStates': childStates.map((c) => c.toJson()).toList(),
  };

  factory GroupNodeState.fromJson(Map<String, dynamic> json) => GroupNodeState(
    nodeId: json['nodeId'] as String,
    status: NodeStatus.values.byName(json['status'] as String),
    currentRepetition: json['currentRepetition'] as int,
    activeChildIndex: json['activeChildIndex'] as int,
    childStates: (json['childStates'] as List<dynamic>)
        .map((c) => NodeState.fromJson(Map<String, dynamic>.from(c)))
        .toList(),
  );
}
