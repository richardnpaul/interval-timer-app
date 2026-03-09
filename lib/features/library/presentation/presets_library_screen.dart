import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/features/library/application/library_notifiers.dart';
import 'package:interval_timer_app/features/library/presentation/edit_preset_screen.dart';
import 'package:interval_timer_app/features/routine_builder/presentation/routine_builder_screen.dart';
import 'package:interval_timer_app/core/domain/group_node.dart';
import 'package:interval_timer_app/core/domain/timer_preset.dart';
import 'package:interval_timer_app/core/widgets/color_swatch_picker.dart';

/// Full Library screen: list all presets, create, edit, delete.
class PresetsLibraryScreen extends ConsumerWidget {
  const PresetsLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);
    final routines = ref.watch(routinesProvider);

    final allItems = [
      ...presets.map((p) => (item: p, isRoutine: false)),
      ...routines.map((r) => (item: r, isRoutine: true)),
    ];

    return Scaffold(
      body: allItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Library is empty',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to create a preset or routine',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: allItems.length,
              itemBuilder: (ctx, i) {
                final entry = allItems[i];
                if (entry.isRoutine) {
                  final routine = entry.item as GroupNode;
                  return Dismissible(
                    key: ValueKey('routine_${routine.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: Theme.of(context).colorScheme.error,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(routinesProvider.notifier)
                          .deleteRoutine(routine.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Routine "${routine.name}" deleted'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: Icon(
                        routine.executionMode == ExecutionMode.parallel
                            ? Icons.grid_view
                            : Icons.format_list_numbered,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(routine.name),
                      subtitle: Text(
                        'Routine • ${routine.children.length} items',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete routine',
                            onPressed: () {
                              ref
                                  .read(routinesProvider.notifier)
                                  .deleteRoutine(routine.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Routine "${routine.name}" deleted',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RoutineBuilderScreen(existing: routine),
                        ),
                      ),
                    ),
                  );
                } else {
                  final preset = entry.item as TimerPreset;
                  final color = preset.color != null
                      ? colorFromHex(preset.color!)
                      : Theme.of(context).colorScheme.primary;
                  final seconds = preset.defaultDuration;
                  final label = seconds < 60
                      ? '${seconds}s'
                      : seconds % 60 == 0
                      ? '${seconds ~/ 60}m'
                      : '${seconds ~/ 60}m ${seconds % 60}s';
                  return Dismissible(
                    key: ValueKey('preset_${preset.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: Theme.of(context).colorScheme.error,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(presetsProvider.notifier)
                          .deletePreset(preset.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Preset "${preset.name}" deleted'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        child: Text(
                          preset.name.isEmpty
                              ? '?'
                              : preset.name[0].toUpperCase(),
                        ),
                      ),
                      title: Text(preset.name),
                      subtitle: Text(label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete preset',
                            onPressed: () {
                              ref
                                  .read(presetsProvider.notifier)
                                  .deletePreset(preset.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Preset "${preset.name}" deleted',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EditPresetScreen(preset: preset),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        tooltip: 'Add to Library',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('New Timer Preset'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditPresetScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('New Routine Build'),
              onTap: () {
                Navigator.pop(ctx);
                // Placeholder navigation for new routine (can reuse RoutineBuilderScreen)
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RoutineBuilderScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
