import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as session;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playAlarm(String? customPath) async {
    // 1. Request Audio Focus (Duck others)
    final audioSession = await session.AudioSession.instance;
    await audioSession.configure(
      const session.AudioSessionConfiguration(
        avAudioSessionCategory: session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            session.AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: session.AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: session.AndroidAudioAttributes(
          contentType: session.AndroidAudioContentType.sonification,
          usage: session.AndroidAudioUsage.alarm,
        ),
        androidAudioFocusGainType:
            session.AndroidAudioFocusGainType.gainTransientMayDuck,
      ),
    );

    if (await audioSession.setActive(true)) {
      // 2. Play Sound
      if (customPath != null && customPath.isNotEmpty) {
        // Play device file
        await _player.play(DeviceFileSource(customPath));
      } else {
        // Play default asset (Need to add this to pubspec later!)
        // For now, we will just play a release tone if no asset
        // TODO: Add 'assets/sounds/beep.mp3'
        await _player.play(AssetSource('sounds/beep.mp3'));
      }

      // 3. Release focus after sound finishes
      _player.onPlayerComplete.first.then((_) async {
        await audioSession.setActive(false);
      });
    }
  }

  void stop() {
    _player.stop();
  }
}
