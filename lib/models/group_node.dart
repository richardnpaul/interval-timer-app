import 'package:uuid/uuid.dart';
import 'timer_node.dart';

enum ExecutionMode { sequential, parallel }

/// A branch node in the routine tree. Contains children (leaves or other groups),
/// an execution mode, and a repetition count.
final class GroupNode implements TimerNode {
  @override
  final String id;

  @override
  final String name;

  /// Child nodes — can be TimerInstances or nested GroupNodes.
  final List<TimerNode> children;

  final ExecutionMode executionMode;

  /// Number of times to repeat this group. 0 = loop infinitely.
  final int repetitions;

  GroupNode({
    String? id,
    required this.name,
    List<TimerNode>? children,
    this.executionMode = ExecutionMode.sequential,
    this.repetitions = 1,
  }) : id = id ?? const Uuid().v4(),
       children = children ?? [];

  @override
  Map<String, dynamic> toJson() => {
    'type': 'group',
    'id': id,
    'name': name,
    'executionMode': executionMode.name,
    'repetitions': repetitions,
    'children': children.map((c) => c.toJson()).toList(),
  };

  factory GroupNode.fromJson(Map<String, dynamic> json) => GroupNode(
    id: json['id'] as String,
    name: json['name'] as String,
    executionMode: ExecutionMode.values.byName(
      json['executionMode'] as String? ?? 'sequential',
    ),
    repetitions: json['repetitions'] as int? ?? 1,
    children: (json['children'] as List<dynamic>? ?? [])
        .map((c) => TimerNode.fromJson(Map<String, dynamic>.from(c)))
        .toList(),
  );

  GroupNode copyWith({
    String? name,
    List<TimerNode>? children,
    ExecutionMode? executionMode,
    int? repetitions,
  }) => GroupNode(
    id: id,
    name: name ?? this.name,
    children: children ?? List.of(this.children),
    executionMode: executionMode ?? this.executionMode,
    repetitions: repetitions ?? this.repetitions,
  );

  /// Returns a new GroupNode with a child appended.
  GroupNode addChild(TimerNode child) =>
      copyWith(children: [...children, child]);

  /// Returns a new GroupNode with the child at [index] removed.
  GroupNode removeChildAt(int index) {
    final updated = List<TimerNode>.of(children)..removeAt(index);
    return copyWith(children: updated);
  }
}
