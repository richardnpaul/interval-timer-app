import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/services/audio_file_service.dart';

class AudioPickerTile extends ConsumerWidget {
  final String? initialPath;
  final ValueChanged<String?> onChanged;

  const AudioPickerTile({
    super.key,
    required this.initialPath,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioSvc = ref.read(audioFileServiceProvider);

    return ListTile(
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
              onPressed: () => onChanged(null),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        final newPath = await audioSvc.pickAndSaveAudio();
        if (newPath != null) {
          onChanged(newPath);
        }
      },
    );
  }
}
