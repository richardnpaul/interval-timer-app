import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/features/settings/application/settings_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Routine Started Audio'),
            subtitle: const Text('Play a cue when a routine begins'),
            value: settings.startCueEnabled,
            onChanged: (value) => notifier.toggleStartCue(value),
          ),
          SwitchListTile(
            title: const Text('Routine Finished Audio'),
            subtitle: const Text('Play a cue when a routine ends'),
            value: settings.endCueEnabled,
            onChanged: (value) => notifier.toggleEndCue(value),
          ),
        ],
      ),
    );
  }
}
