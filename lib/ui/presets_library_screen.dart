import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/ui/edit_timer_screen.dart';

class PresetsLibraryScreen extends ConsumerWidget {
  const PresetsLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Presets')),
      body: presets.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved presets',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a timer and save it to see it here',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                return ListTile(
                  title: Text(preset.label),
                  subtitle: Text(_formatDuration(preset.durationSeconds)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.green),
                        onPressed: () {
                          ref
                              .read(activeTimersProvider.notifier)
                              .addTimer(preset);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Started ${preset.label}')),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditTimerScreen(preset: preset),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          _confirmDelete(context, ref, preset);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TimerPreset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset?'),
        content: Text('Are you sure you want to delete "${preset.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(presetsProvider.notifier).deletePreset(preset.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
