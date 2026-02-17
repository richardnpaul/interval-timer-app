import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'timer_preset.g.dart';

@JsonSerializable()
class TimerPreset {
  final String id;
  final String label;
  final int durationSeconds;
  final bool autoRestart; // Handles "Looping"
  final String? soundPath; // Null for default beep

  TimerPreset({
    String? id,
    required this.label,
    required this.durationSeconds,
    this.autoRestart = false,
    this.soundPath,
  }) : id = id ?? const Uuid().v4();

  factory TimerPreset.fromJson(Map<String, dynamic> json) =>
      _$TimerPresetFromJson(json);

  Map<String, dynamic> toJson() => _$TimerPresetToJson(this);
}
