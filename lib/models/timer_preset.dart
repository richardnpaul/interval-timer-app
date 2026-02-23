import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'timer_preset.g.dart';

@JsonSerializable()
class TimerPreset {
  final String id;

  /// Human-readable name shown in the Library.
  final String name;

  /// Default duration in seconds when adding to a routine.
  final int defaultDuration;

  /// Hex color string (e.g. "#FF5733"). Null = app default.
  final String? color;

  /// Default alarm sound path. Null = built-in beep.
  final String? soundPath;

  TimerPreset({
    String? id,
    required this.name,
    required this.defaultDuration,
    this.color,
    this.soundPath,
  }) : id = id ?? const Uuid().v4();

  factory TimerPreset.fromJson(Map<String, dynamic> json) =>
      _$TimerPresetFromJson(json);

  Map<String, dynamic> toJson() => _$TimerPresetToJson(this);
}
