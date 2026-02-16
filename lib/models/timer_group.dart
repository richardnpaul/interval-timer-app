import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'timer_group.g.dart';

enum GroupExecutionMode {
  parallel,
  sequence, // Stub for future V2
}

@JsonSerializable()
class TimerGroup {
  final String id;
  final String label;
  final List<String> timerIds;
  final GroupExecutionMode executionMode;

  TimerGroup({
    String? id,
    required this.label,
    required this.timerIds,
    this.executionMode = GroupExecutionMode.parallel,
  }) : id = id ?? const Uuid().v4();

  factory TimerGroup.fromJson(Map<String, dynamic> json) =>
      _$TimerGroupFromJson(json);

  Map<String, dynamic> toJson() => _$TimerGroupToJson(this);
}
