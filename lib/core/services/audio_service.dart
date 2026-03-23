import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as session;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

class AudioService {
  AudioPlayer? _player;

  AudioPlayer get player => _player ??= AudioPlayer();

  final Set<String> _activePaths = {};

  Future<void> playAlarm(String? customPath) async {
    final bool isAsset = customPath == null || !customPath.startsWith('/');
    final path = customPath ?? 'sounds/beep.mp3';

    // Simple throttle: don't play same sound if it started < 500ms ago
    if (_activePaths.contains(path)) return;
    _activePaths.add(path);
    Timer(const Duration(milliseconds: 500), () => _activePaths.remove(path));

    try {
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
        if (isAsset) {
          await player.play(AssetSource(path));
        } else {
          await player.play(DeviceFileSource(path));
        }

        // 3. Release focus after sound finishes
        player.onPlayerComplete.first.then((_) async {
          await audioSession.setActive(false);
        });
      }
    } catch (e) {
      debugPrint('AudioService error: $e');
      // Fallback
      if (isAsset) {
        await player.play(AssetSource(path));
      } else {
        await player.play(DeviceFileSource(path));
      }
    }
  }

  void stop() {
    _player?.stop();
  }
}
