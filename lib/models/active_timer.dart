import 'package:uuid/uuid.dart';
import 'timer_preset.dart';

enum TimerState { running, paused, finished }

class ActiveTimer {
  final String id;
  final TimerPreset preset;
  int remainingSeconds;
  // We keep track of the total duration for progress bars
  final int totalSeconds;
  TimerState state;

  ActiveTimer({
    String? id,
    required this.preset,
    int? remainingSeconds,
    TimerState? state,
  }) : id = id ?? const Uuid().v4(),
       remainingSeconds = remainingSeconds ?? preset.durationSeconds,
       totalSeconds = preset.durationSeconds,
       state = state ?? TimerState.paused;

  /// Returns true if the timer has finished
  bool tick() {
    if (state != TimerState.running) return false;

    if (remainingSeconds > 0) {
      remainingSeconds--;
    }

    if (remainingSeconds == 0) {
      // Logic for autoRestart is handled by the Service/Manager,
      // not the model itself, to avoid side effects here.
      state = TimerState.finished;
      return true;
    }
    return false;
  }

  void reset() {
    remainingSeconds = totalSeconds;
    state = TimerState.running; // Auto-start on reset? Or paused?
    // Project requirement: "Looping" implies auto-start.
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'preset': preset.toJson(),
      'remainingSeconds': remainingSeconds,
      'totalSeconds': totalSeconds,
      'state': state.toString(),
    };
  }

  factory ActiveTimer.fromJson(Map<String, dynamic> json) {
    return ActiveTimer(
      id: json['id'],
      preset: TimerPreset.fromJson(json['preset']),
      remainingSeconds: json['remainingSeconds'],
      state: TimerState.values.firstWhere((e) => e.toString() == json['state']),
    );
  }
}
