
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/models/active_timer.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';

class ActiveTimerCard extends ConsumerWidget {
  final ActiveTimer timer;

  const ActiveTimerCard({
    super.key,
    required this.timer,
  });

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = timer.totalSeconds > 0
        ? timer.remainingSeconds / timer.totalSeconds
        : 0.0;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      timer.state == TimerState.running
                          ? Colors.deepOrangeAccent
                          : Colors.grey,
                    ),
                  ),
                ),
                Text(
                  _formatTime(timer.remainingSeconds),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timer.preset.label,
                    style: Theme.of(context).textTheme.headlineSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timer.preset.autoRestart)
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Auto-Restart',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (timer.state == TimerState.running)
              IconButton.filledTonal(
                icon: const Icon(Icons.pause),
                onPressed: () {
                  ref.read(activeTimersProvider.notifier).pauseTimer(timer.id);
                },
              )
            else
              IconButton.filledTonal(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {
                  if (timer.state == TimerState.finished) {
                    ref.read(activeTimersProvider.notifier).restartTimer(timer.id);
                  } else {
                    ref.read(activeTimersProvider.notifier).resumeTimer(timer.id);
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(activeTimersProvider.notifier).removeTimer(timer.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
