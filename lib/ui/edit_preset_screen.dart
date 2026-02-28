import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/widgets/audio_picker_tile.dart';
import 'package:interval_timer_app/ui/widgets/color_swatch_picker.dart';

/// Create or edit a [TimerPreset].
/// Pass [preset] to edit an existing one; leave null to create new.
class EditPresetScreen extends ConsumerStatefulWidget {
  final TimerPreset? preset;

  const EditPresetScreen({super.key, this.preset});

  @override
  ConsumerState<EditPresetScreen> createState() => _EditPresetScreenState();
}

class _EditPresetScreenState extends ConsumerState<EditPresetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _durationCtrl;
  String? _selectedColor;
  String? _soundPath;
  int _soundOffset = 0;

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _durationCtrl = TextEditingController(text: '${p?.defaultDuration ?? 60}');
    _selectedColor = p?.color ?? kColorPalette.first;
    _soundPath = p?.soundPath;
    _soundOffset = p?.soundOffset ?? 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 60;
    final preset = TimerPreset(
      id: widget.preset?.id,
      name: _nameCtrl.text.trim(),
      defaultDuration: duration,
      color: _selectedColor,
      soundPath: _soundPath,
      soundOffset: _soundOffset,
    );
    await ref.read(presetsProvider.notifier).savePreset(preset);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.preset == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New Preset' : 'Edit Preset'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Name ──────────────────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 20),

            // ── Default Duration ──────────────────────────────────────────
            Text(
              'Default Duration',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Seconds',
                      border: OutlineInputBorder(),
                      suffixText: 's',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) {
                        return 'Must be a positive number';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDuration(
                    int.tryParse(_durationCtrl.text.trim()) ?? 60,
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Color ────────────────────────────────────────────────────
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            ColorSwatchPicker(
              selected: _selectedColor,
              onChanged: (hex) => setState(() => _selectedColor = hex),
            ),
            const SizedBox(height: 24),

            // ── Sound ────────────────────────────────────────────────────
            AudioPickerTile(
              initialPath: _soundPath,
              soundOffset: _soundOffset,
              onPathChanged: (newPath) => setState(() => _soundPath = newPath),
              onOffsetChanged: (newOffset) =>
                  setState(() => _soundOffset = newOffset),
            ),
            if (!isNew) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'Delete Preset',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Preset'),
                      content: const Text(
                        'Are you sure you want to delete this preset?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(presetsProvider.notifier)
                        .deletePreset(widget.preset!.id);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
