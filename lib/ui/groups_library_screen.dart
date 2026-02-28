import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/routine_builder_screen.dart';

/// Full Routines screen: list all routines, create, edit, delete, start.
class GroupsLibraryScreen extends ConsumerWidget {
  const GroupsLibraryScreen({super.key});

  void _newRoutine(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Routine'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Routine name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty || !context.mounted) return;
    final newRoutine = GroupNode(name: name);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutineBuilderScreen(existing: newRoutine),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);
    return Scaffold(
      body: routines.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No routines yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to build your first routine',
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
              itemCount: routines.length,
              itemBuilder: (ctx, i) {
                final routine = routines[i];
                return Dismissible(
                  key: ValueKey(routine.id),
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
                        content: Text('"${routine.name}" deleted'),
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
                      '${routine.children.length} items  •  '
                      '${routine.executionMode.name}  •  '
                      '${routine.repetitions == 0 ? '∞ reps' : '×${routine.repetitions}'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline),
                          tooltip: 'Start routine',
                          onPressed: () => ref
                              .read(activeRoutineProvider.notifier)
                              .startRoutine(routine),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoutineBuilderScreen(existing: routine),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newRoutine(context, ref),
        tooltip: 'New Routine',
        child: const Icon(Icons.add),
      ),
    );
  }
}
