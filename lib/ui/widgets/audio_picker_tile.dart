import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/services/audio_file_service.dart';

class AudioPickerTile extends ConsumerWidget {
  final String? initialPath;
  final int soundOffset;
  final ValueChanged<String?> onPathChanged;
  final ValueChanged<int> onOffsetChanged;

  const AudioPickerTile({
    super.key,
    required this.initialPath,
    required this.soundOffset,
    required this.onPathChanged,
    required this.onOffsetChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioSvc = ref.read(audioFileServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.music_note),
          title: const Text('Alarm Sound'),
          subtitle: Text(audioSvc.getFileName(initialPath)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (initialPath != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  tooltip: 'Reset to default',
                  onPressed: () => onPathChanged(null),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () async {
            final newPath = await audioSvc.pickAndSaveAudio();
            if (newPath != null) {
              onPathChanged(newPath);
            }
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: '$soundOffset',
                decoration: const InputDecoration(
                  labelText: 'Sound Offset (seconds before end)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final n = int.tryParse(v) ?? 0;
                  onOffsetChanged(n);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
