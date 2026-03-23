import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interval_timer_app/core/services/storage_service.dart';

void main() {
  group('StorageService', () {
    late StorageService storageService;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
    });

    test('isStartCueEnabled returns true by default', () {
      expect(storageService.isStartCueEnabled(), isTrue);
    });

    test('setStartCueEnabled persists value', () async {
      await storageService.setStartCueEnabled(false);
      expect(storageService.isStartCueEnabled(), isFalse);
      expect(prefs.getBool('pref_audio_start_cue_enabled'), isFalse);
    });

    test('isEndCueEnabled returns true by default', () {
      expect(storageService.isEndCueEnabled(), isTrue);
    });

    test('setEndCueEnabled persists value', () async {
      await storageService.setEndCueEnabled(false);
      expect(storageService.isEndCueEnabled(), isFalse);
      expect(prefs.getBool('pref_audio_end_cue_enabled'), isFalse);
    });
  });
}
