import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/models/active_timer.dart';
import 'package:interval_timer_app/models/timer_preset.dart';

void main() {
  group('JSON Serialization Tests', () {
    test('TimerPreset should serialize and deserialize correctly', () {
      final preset = TimerPreset(
        id: 'preset-1',
        label: 'HIIT',
        durationSeconds: 45,
        autoRestart: true,
        soundPath: 'assets/beep.mp3',
      );

      final json = preset.toJson();
      final decoded = TimerPreset.fromJson(json);

      expect(decoded.id, preset.id);
      expect(decoded.label, preset.label);
      expect(decoded.durationSeconds, preset.durationSeconds);
      expect(decoded.autoRestart, preset.autoRestart);
      expect(decoded.soundPath, preset.soundPath);
    });

    test('ActiveTimer should serialize and deserialize correctly', () {
      final preset = TimerPreset(label: 'Test', durationSeconds: 60);
      final timer = ActiveTimer(
        id: 'timer-1',
        preset: preset,
        remainingSeconds: 30,
        state: TimerState.running,
      );

      final json = timer.toJson();
      final decoded = ActiveTimer.fromJson(json);

      expect(decoded.id, timer.id);
      expect(decoded.preset.label, preset.label);
      expect(decoded.remainingSeconds, 30);
      expect(decoded.totalSeconds, 60);
      expect(decoded.state, TimerState.running);
    });
  });
}
