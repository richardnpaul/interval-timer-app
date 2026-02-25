import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/services/audio_file_service.dart';

void main() {
  group('AudioFileService', () {
    final service = AudioFileService();

    group('getFileName', () {
      test('returns Default Beep for null path', () {
        expect(service.getFileName(null), 'Default Beep');
      });

      test('extracts basename for valid path', () {
        expect(service.getFileName('/path/to/sound.mp3'), 'sound.mp3');
        expect(service.getFileName('alarm.wav'), 'alarm.wav');
      });

      test('handles empty string', () {
        expect(service.getFileName(''), '');
      });
    });
  });
}
