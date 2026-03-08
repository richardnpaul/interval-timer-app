// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_preset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimerPreset _$TimerPresetFromJson(Map<String, dynamic> json) => TimerPreset(
  id: json['id'] as String?,
  name: json['name'] as String,
  defaultDuration: (json['defaultDuration'] as num).toInt(),
  color: json['color'] as String?,
  soundPath: json['soundPath'] as String?,
  soundOffset: (json['soundOffset'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TimerPresetToJson(TimerPreset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'defaultDuration': instance.defaultDuration,
      'color': instance.color,
      'soundPath': instance.soundPath,
      'soundOffset': instance.soundOffset,
    };
