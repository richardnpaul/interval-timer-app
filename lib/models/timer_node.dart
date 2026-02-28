import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';

/// Abstract base for all nodes in a routine tree.
/// Use the 'type' key in JSON to distinguish leaves from branches.
abstract interface class TimerNode {
  String get id;
  String get name;

  Map<String, dynamic> toJson();

  /// Dispatches deserialization based on the 'type' discriminator key.
  static TimerNode fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'instance' => TimerInstance.fromJson(json),
      'group' => GroupNode.fromJson(json),
      _ => throw ArgumentError('Unknown TimerNode type: $type'),
    };
  }
}
