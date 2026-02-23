import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/edit_preset_screen.dart';
import 'package:interval_timer_app/ui/widgets/color_swatch_picker.dart';

/// Full Library screen: list all presets, create, edit, delete.
class PresetsLibraryScreen extends ConsumerWidget {
  const PresetsLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);
    return Scaffold(
      body: presets.isEmpty
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
                    'No presets yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to create your first preset',
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
              itemCount: presets.length,
              itemBuilder: (ctx, i) {
                final preset = presets[i];
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
                  key: ValueKey(preset.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    color: Theme.of(context).colorScheme.error,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    ref.read(presetsProvider.notifier).deletePreset(preset.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${preset.name}" deleted'),
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
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditPresetScreen(preset: preset),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EditPresetScreen())),
        tooltip: 'New Preset',
        child: const Icon(Icons.add),
      ),
    );
  }
}
