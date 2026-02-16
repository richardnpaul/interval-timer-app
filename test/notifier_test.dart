
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/models/active_timer.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/models/timer_group.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';

class MockBackgroundServiceWrapper extends BackgroundServiceWrapper {
  final StreamController<Map<String, dynamic>?> _controller = StreamController.broadcast();

  @override
  Stream<Map<String, dynamic>?> on(String method) {
    if (method == 'update') return _controller.stream;
    return const Stream.empty();
  }

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    // No-op for current tests, or we could verify calls
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('ActiveTimersNotifier Tests', () {
    late ProviderContainer container;
    late MockBackgroundServiceWrapper mockService;

    setUp(() {
      mockService = MockBackgroundServiceWrapper();
      container = ProviderContainer(
        overrides: [
          backgroundServiceWrapperProvider.overrideWithValue(mockService),
        ],
      );
    });

    tearDown(() {
      mockService.dispose();
      container.dispose();
    });

    test('Initial state should be an empty list', () {
      final timers = container.read(activeTimersProvider);
      expect(timers, isEmpty);
    });

    test('addTimer should add a new ActiveTimer to the list in running state', () {
      final preset = TimerPreset(label: 'Test', durationSeconds: 60);
      final notifier = container.read(activeTimersProvider.notifier);

      notifier.addTimer(preset);

      final state = container.read(activeTimersProvider);
      expect(state.length, 1);
      expect(state.first.preset.label, 'Test');
      expect(state.first.state, TimerState.running);
    });

    test('removeTimer should remove the specific timer', () {
      final preset = TimerPreset(label: 'Test', durationSeconds: 60);
      final notifier = container.read(activeTimersProvider.notifier);

      notifier.addTimer(preset);
      final timerId = container.read(activeTimersProvider).first.id;

      notifier.removeTimer(timerId);

      expect(container.read(activeTimersProvider), isEmpty);
    });

    test('pauseTimer and resumeTimer should change timer state correctly', () {
      final preset = TimerPreset(label: 'Test', durationSeconds: 60);
      final notifier = container.read(activeTimersProvider.notifier);

      notifier.addTimer(preset);
      final timerId = container.read(activeTimersProvider).first.id;

      // Timer starts as running
      expect(container.read(activeTimersProvider).first.state, TimerState.running);

      notifier.pauseTimer(timerId);
      expect(container.read(activeTimersProvider).first.state, TimerState.paused);

      notifier.resumeTimer(timerId);
      expect(container.read(activeTimersProvider).first.state, TimerState.running);
    });

    test('addGroup should add multiple timers in running state', () {
      final p1 = TimerPreset(id: 'p1', label: 'T1', durationSeconds: 60);
      final p2 = TimerPreset(id: 'p2', label: 'T2', durationSeconds: 30);
      final group = TimerGroup(id: 'g1', label: 'Workout', timerIds: ['p1', 'p2']);

      final notifier = container.read(activeTimersProvider.notifier);
      notifier.addGroup(group, [p1, p2]);

      final state = container.read(activeTimersProvider);
      expect(state.length, 2);
      expect(state.any((t) => t.preset.label == 'T1'), true);
      expect(state.any((t) => t.preset.label == 'T2'), true);
    });
  });
}
