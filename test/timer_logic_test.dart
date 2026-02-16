
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/models/active_timer.dart';
import 'package:interval_timer_app/models/timer_preset.dart';

void main() {
  group('ActiveTimer Logic Tests', () {
    test('Timer should decrement remainingSeconds when ticked while running', () {
      final preset = TimerPreset(label: 'Test', durationSeconds: 10);
      final timer = ActiveTimer(preset: preset);
      timer.state = TimerState.running;

      final finished = timer.tick();

      expect(timer.remainingSeconds, 9);
      expect(finished, false);
      expect(timer.state, TimerState.running);
    });

    test('Timer should transition to finished state when ticking at 1 second', () {
      final preset = TimerPreset(label: 'Test', durationSeconds: 1);
      final timer = ActiveTimer(preset: preset);
      timer.state = TimerState.running;

      final finished = timer.tick();

      expect(timer.remainingSeconds, 0);
      expect(finished, true);
      expect(timer.state, TimerState.finished);
    });

    test('Timer should not decrement if state is paused', () {
      final preset = TimerPreset(label: 'Test', durationSeconds: 10);
      final timer = ActiveTimer(preset: preset);
      timer.state = TimerState.paused;

      final finished = timer.tick();

      expect(timer.remainingSeconds, 10);
      expect(finished, false);
    });

    test('Timer should auto-restart if autoRestart is true', () {
      final preset = TimerPreset(label: 'Test', durationSeconds: 2, autoRestart: true);
      final timer = ActiveTimer(preset: preset);
      timer.state = TimerState.running;

      timer.tick(); // Down to 1
      expect(timer.remainingSeconds, 1);

      final finished = timer.tick(); // Down to 0 -> Resets to 2
      expect(timer.remainingSeconds, 2);
      expect(finished, true); // Still returns true because a cycle ended
      expect(timer.state, TimerState.running);
    });
  });
}
