// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_preset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimerPreset _$TimerPresetFromJson(Map<String, dynamic> json) => TimerPreset(
  id: json['id'] as String?,
  label: json['label'] as String,
  durationSeconds: (json['durationSeconds'] as num).toInt(),
  autoRestart: json['autoRestart'] as bool? ?? false,
  soundPath: json['soundPath'] as String?,
);

Map<String, dynamic> _$TimerPresetToJson(TimerPreset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'durationSeconds': instance.durationSeconds,
      'autoRestart': instance.autoRestart,
      'soundPath': instance.soundPath,
    };
