import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/services/audio_service.dart';

class EditTimerScreen extends ConsumerStatefulWidget {
  final TimerPreset? preset; // If null, creating new

  const EditTimerScreen({super.key, this.preset});

  @override
  ConsumerState<EditTimerScreen> createState() => _EditTimerScreenState();
}

class _EditTimerScreenState extends ConsumerState<EditTimerScreen> {
  late TextEditingController _labelController;
  int _minutes = 0;
  int _seconds = 0;
  bool _autoRestart = false;
  String? _soundPath;
  bool _saveToLibrary = false;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _labelController = TextEditingController(text: p?.label ?? 'New Timer');
    if (p != null) {
      _minutes = p.durationSeconds ~/ 60;
      _seconds = p.durationSeconds % 60;
      _autoRestart = p.autoRestart;
      _soundPath = p.soundPath;
      _saveToLibrary = true; // Default to true if editing existing
    } else {
      _minutes = 1; // Default 1 min
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickSound() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      setState(() {
        _soundPath = result.files.single.path;
      });
      // Preview sound
      ref.read(audioServiceProvider).playAlarm(_soundPath);
    }
  }

  void _save() {
    final totalSeconds = (_minutes * 60) + _seconds;
    if (totalSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duration must be greater than 0')),
      );
      return;
    }

    final newPreset = TimerPreset(
      id: widget.preset?.id, // Keep ID if editing
      label: _labelController.text,
      durationSeconds: totalSeconds,
      autoRestart: _autoRestart,
      soundPath: _soundPath,
    );

    if (_saveToLibrary) {
      ref.read(presetsProvider.notifier).savePreset(newPreset);
    }

    // If we were just editing a preset from library, we don't necessarily want to *start* it.
    // But for simplicity in v1, let's say "Save" always starts it if it was a new creation,
    // or just updates it if it was from library?
    // Actually, usually "Edit" in library should just save.
    // "Add" in library should just start.

    // Let's check if it came from library (widget.preset != null)
    if (widget.preset == null) {
      ref.read(activeTimersProvider.notifier).addTimer(newPreset);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preset updated')));
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.preset == null ? 'New Timer' : 'Edit Timer'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          Text('Duration', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _minutes,
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(60, (index) {
                    return DropdownMenuItem(
                      value: index,
                      child: Text(index.toString()),
                    );
                  }),
                  onChanged: (val) => setState(() => _minutes = val!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _seconds,
                  decoration: const InputDecoration(
                    labelText: 'Seconds',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(60, (index) {
                    return DropdownMenuItem(
                      value: index,
                      child: Text(index.toString().padLeft(2, '0')),
                    );
                  }),
                  onChanged: (val) => setState(() => _seconds = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Auto-Restart (Loop)'),
            subtitle: const Text(
              'Timer will restart immediately when finished',
            ),
            value: _autoRestart,
            onChanged: (val) => setState(() => _autoRestart = val),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          ListTile(
            title: const Text('Alarm Sound'),
            subtitle: Text(
              _soundPath != null ? _soundPath!.split('/').last : 'Default Beep',
            ),
            trailing: const Icon(Icons.music_note),
            onTap: _pickSound,
            contentPadding: EdgeInsets.zero,
          ),
          if (_soundPath != null)
            TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Reset to Default'),
              onPressed: () => setState(() => _soundPath = null),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          const Divider(),
          SwitchListTile(
            title: const Text('Save to Saved Presets'),
            subtitle: const Text('Access this timer quickly from the library'),
            value: _saveToLibrary,
            onChanged: (val) => setState(() => _saveToLibrary = val),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
