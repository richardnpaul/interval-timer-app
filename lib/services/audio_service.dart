

import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as session;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

class AudioService {
  AudioPlayer? _player;

  AudioPlayer get player => _player ??= AudioPlayer();

  Future<void> playAlarm(String? customPath) async {
    try {
      // 1. Request Audio Focus (Duck others)
      final audioSession = await session.AudioSession.instance;
      await audioSession.configure(const session.AudioSessionConfiguration(
        avAudioSessionCategory: session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: session.AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: session.AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: session.AndroidAudioAttributes(
          contentType: session.AndroidAudioContentType.sonification,
          usage: session.AndroidAudioUsage.alarm,
        ),
        androidAudioFocusGainType: session.AndroidAudioFocusGainType.gainTransientMayDuck,
      ));

      if (await audioSession.setActive(true)) {
        // 2. Play Sound
        if (customPath != null && customPath.isNotEmpty) {
          // Play device file
          await player.play(DeviceFileSource(customPath));
        } else {
          // Play default asset
          // For now, we will just play a release tone if no asset
          await player.play(AssetSource('sounds/beep.mp3'));
        }

        // 3. Release focus after sound finishes
        player.onPlayerComplete.first.then((_) async {
          await audioSession.setActive(false);
        });
      }
    } catch (e) {
      print('AudioService error: $e');
      // Fallback: try playing without session management if it fails
      if (customPath != null && customPath.isNotEmpty) {
        await player.play(DeviceFileSource(customPath));
      } else {
        await player.play(AssetSource('sounds/beep.mp3'));
      }
    }
  }

  void stop() {
    _player?.stop();
  }
}
