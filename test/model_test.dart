import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/models/timer_instance.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_node.dart';
import 'package:interval_timer_app/models/timer_preset.dart';

void main() {
  group('TimerPreset', () {
    test('serializes and deserializes correctly', () {
      final preset = TimerPreset(
        name: 'Work',
        defaultDuration: 25 * 60,
        color: '#FF5733',
        soundPath: null,
      );

      final json = preset.toJson();
      final restored = TimerPreset.fromJson(json);

      expect(restored.id, preset.id);
      expect(restored.name, preset.name);
      expect(restored.defaultDuration, preset.defaultDuration);
      expect(restored.color, preset.color);
      expect(restored.soundPath, isNull);
    });
  });

  group('TimerInstance', () {
    test('creates with defaults', () {
      final instance = TimerInstance(name: 'Rest', duration: 5);
      expect(instance.autoRestart, isFalse);
      expect(instance.color, isNull);
      expect(instance.presetId, isNull);
    });

    test('serializes and deserializes correctly', () {
      final instance = TimerInstance(
        name: 'River Runes',
        duration: 120,
        color: '#00FFFF',
        autoRestart: true,
      );

      final json = instance.toJson();
      expect(json['type'], 'instance');

      final restored = TimerInstance.fromJson(json);
      expect(restored.id, instance.id);
      expect(restored.name, instance.name);
      expect(restored.duration, instance.duration);
      expect(restored.color, instance.color);
      expect(restored.autoRestart, isTrue);
    });

    test('copyWith overrides only specified fields', () {
      final instance = TimerInstance(
        name: 'Work',
        duration: 30,
        color: '#00FF00',
      );
      final copy = instance.copyWith(duration: 45);

      expect(copy.color, instance.color);
    });

    test('copyWith uses defaults when no arguments provided', () {
      final instance = TimerInstance(name: 'Work', duration: 30);
      final copy = instance.copyWith();
      expect(copy.id, instance.id);
      expect(copy.name, instance.name);
    });

    test('fromPreset creates correct instance', () {
      final preset = TimerPreset(
        name: 'Work',
        defaultDuration: 60,
        color: '#FF0000',
        soundPath: 'alarm.mp3',
        soundOffset: 3,
      );
      final instance = TimerInstance.fromPreset(preset);

      expect(instance.name, preset.name);
      expect(instance.duration, preset.defaultDuration);
      expect(instance.color, preset.color);
      expect(instance.soundPath, preset.soundPath);
      expect(instance.soundOffset, preset.soundOffset);
      expect(instance.presetId, preset.id);
    });
  });

  group('GroupNode', () {
    test('creates with empty children by default', () {
      final group = GroupNode(name: 'Stretching');
      expect(group.children, isEmpty);
      expect(group.repetitions, 1);
      expect(group.executionMode, ExecutionMode.sequential);
    });

    test('addChild returns new node without mutating original', () {
      final group = GroupNode(name: 'Root');
      final child = TimerInstance(name: 'Prep', duration: 10);
      final updated = group.addChild(child);

      expect(group.children, isEmpty);
      expect(updated.children.length, 1);
      expect(updated.children.first, child);
    });

    test('removeChildAt returns new node without mutating original', () {
      final child = TimerInstance(name: 'A', duration: 10);
      final group = GroupNode(name: 'Root', children: [child]);
      final updated = group.removeChildAt(0);

      expect(group.children.length, 1);
      expect(updated.children, isEmpty);
    });

    test('serializes and deserializes nested tree', () {
      final leaf1 = TimerInstance(name: 'Work', duration: 30, color: '#00FF00');
      final leaf2 = TimerInstance(name: 'Rest', duration: 5, color: '#0000FF');
      final inner = GroupNode(
        name: 'Core Exercise',
        executionMode: ExecutionMode.sequential,
        repetitions: 3,
        children: [leaf1, leaf2],
      );
      final root = GroupNode(
        name: 'Stretching Routine',
        executionMode: ExecutionMode.sequential,
        repetitions: 1,
        children: [
          TimerInstance(name: 'Prep', duration: 10),
          inner,
          TimerInstance(name: 'Cooldown', duration: 10),
        ],
      );

      final json = root.toJson();
      final restored = GroupNode.fromJson(json);

      expect(restored.name, root.name);
      expect(restored.children.length, 3);
      expect(restored.children[1], isA<GroupNode>());

      final restoredInner = restored.children[1] as GroupNode;
      expect(restoredInner.repetitions, 3);
      expect(restoredInner.children.length, 2);
      expect(restoredInner.children[0], isA<TimerInstance>());
    });

    test('parallel DotA 2 routine round-trips through JSON', () {
      final routine = GroupNode(
        name: 'DotA 2 Match',
        executionMode: ExecutionMode.parallel,
        repetitions: 1,
        children: [
          TimerInstance(
            name: 'Day/Night Cycle',
            duration: 300,
            autoRestart: true,
          ),
          TimerInstance(name: 'River Runes', duration: 120, autoRestart: true),
          TimerInstance(name: 'Bounty Runes', duration: 180, autoRestart: true),
          TimerInstance(name: 'Wisdom Runes', duration: 420, autoRestart: true),
        ],
      );

      final json = routine.toJson();
      final restored = GroupNode.fromJson(json);

      expect(restored.executionMode, ExecutionMode.parallel);
      expect(restored.children.length, 4);
      for (final child in restored.children) {
        expect(child, isA<TimerInstance>());
        expect((child as TimerInstance).autoRestart, isTrue);
      }
    });

    test('copyWith uses defaults when no arguments provided', () {
      final group = GroupNode(name: 'Root');
      final copy = group.copyWith();
      expect(copy.id, group.id);
      expect(copy.name, group.name);
    });
  });

  group('TimerNode polymorphic dispatch', () {
    test('fromJson creates correct subtype from type discriminator', () {
      final instanceJson = TimerInstance(name: 'Work', duration: 30).toJson();
      final groupJson = GroupNode(name: 'Group').toJson();

      expect(TimerNode.fromJson(instanceJson), isA<TimerInstance>());
      expect(TimerNode.fromJson(groupJson), isA<GroupNode>());
    });

    test('throws for unknown type', () {
      expect(
        () => TimerNode.fromJson({'type': 'unknown', 'id': 'x', 'name': 'y'}),
        throwsArgumentError,
      );
    });
  });
}
