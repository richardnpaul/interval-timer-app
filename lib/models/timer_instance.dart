import 'package:uuid/uuid.dart';
import 'timer_node.dart';
import 'timer_preset.dart';

/// A leaf node in the routine tree. Represents a single countdown timer.
final class TimerInstance implements TimerNode {
  @override
  final String id;

  @override
  final String name;

  /// Duration in seconds for this specific instance.
  /// May override the preset's defaultDuration.
  final int duration;

  /// Hex color string (e.g. "#FF5733"). Null = inherit from preset or app default.
  final String? color;

  /// Alarm sound path. Null = built-in beep.
  final String? soundPath;

  /// When true, this timer loops itself indefinitely without needing a GroupNode.
  final bool autoRestart;

  /// Seconds before the end of the timer to trigger the alarm sound.
  /// 0 = trigger at the end (default).
  final int soundOffset;

  /// Optional reference to the preset this was created from.
  /// Used for future "show source preset" UI, not required for execution.
  final String? presetId;

  TimerInstance({
    String? id,
    required this.name,
    required this.duration,
    this.color,
    this.soundPath,
    this.autoRestart = false,
    this.soundOffset = 0,
    this.presetId,
  }) : id = id ?? const Uuid().v4();

  /// Create a TimerInstance pre-populated from a preset's defaults.
  factory TimerInstance.fromPreset(TimerPreset preset) => TimerInstance(
    name: preset.name,
    duration: preset.defaultDuration,
    color: preset.color,
    soundPath: preset.soundPath,
    soundOffset: preset.soundOffset,
    presetId: preset.id,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'instance',
    'id': id,
    'name': name,
    'duration': duration,
    'color': color,
    'soundPath': soundPath,
    'autoRestart': autoRestart,
    'soundOffset': soundOffset,
    'presetId': presetId,
  };

  factory TimerInstance.fromJson(Map<String, dynamic> json) => TimerInstance(
    id: json['id'] as String,
    name: json['name'] as String,
    duration: json['duration'] as int,
    color: json['color'] as String?,
    soundPath: json['soundPath'] as String?,
    autoRestart: json['autoRestart'] as bool? ?? false,
    soundOffset: json['soundOffset'] as int? ?? 0,
    presetId: json['presetId'] as String?,
  );

  TimerInstance copyWith({
    String? name,
    int? duration,
    String? color,
    String? soundPath,
    bool? autoRestart,
    int? soundOffset,
  }) => TimerInstance(
    id: id,
    name: name ?? this.name,
    duration: duration ?? this.duration,
    color: color ?? this.color,
    soundPath: soundPath ?? this.soundPath,
    autoRestart: autoRestart ?? this.autoRestart,
    soundOffset: soundOffset ?? this.soundOffset,
    presetId: presetId,
  );
}
