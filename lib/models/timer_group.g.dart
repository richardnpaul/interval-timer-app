// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timer_group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimerGroup _$TimerGroupFromJson(Map<String, dynamic> json) => TimerGroup(
  id: json['id'] as String?,
  label: json['label'] as String,
  timerIds: (json['timerIds'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  executionMode:
      $enumDecodeNullable(_$GroupExecutionModeEnumMap, json['executionMode']) ??
      GroupExecutionMode.parallel,
);

Map<String, dynamic> _$TimerGroupToJson(TimerGroup instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'timerIds': instance.timerIds,
      'executionMode': _$GroupExecutionModeEnumMap[instance.executionMode]!,
    };

const _$GroupExecutionModeEnumMap = {
  GroupExecutionMode.parallel: 'parallel',
  GroupExecutionMode.sequence: 'sequence',
};
