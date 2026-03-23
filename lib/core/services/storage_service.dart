import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interval_timer_app/core/domain/timer_preset.dart';
import 'package:interval_timer_app/core/domain/group_node.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized');
});

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const String _keyPresets = 'timer_presets_v2';
  static const String _keyRoutines = 'timer_routines_v2';
  static const String _keyStartCueEnabled = 'pref_audio_start_cue_enabled';
  static const String _keyEndCueEnabled = 'pref_audio_end_cue_enabled';

  // --- Presets ---

  List<TimerPreset> loadPresets() {
    final jsonString = _prefs.getString(_keyPresets);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((e) => TimerPreset.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> savePresets(List<TimerPreset> presets) async {
    final jsonString = jsonEncode(presets.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyPresets, jsonString);
  }

  // --- Routines ---

  List<GroupNode> loadRoutines() {
    final jsonString = _prefs.getString(_keyRoutines);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((e) => GroupNode.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveRoutines(List<GroupNode> routines) async {
    final jsonString = jsonEncode(routines.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyRoutines, jsonString);
  }

  // --- Audio Cues ---

  bool isStartCueEnabled() {
    return _prefs.getBool(_keyStartCueEnabled) ?? true;
  }

  Future<void> setStartCueEnabled(bool enabled) async {
    await _prefs.setBool(_keyStartCueEnabled, enabled);
  }

  bool isEndCueEnabled() {
    return _prefs.getBool(_keyEndCueEnabled) ?? true;
  }

  Future<void> setEndCueEnabled(bool enabled) async {
    await _prefs.setBool(_keyEndCueEnabled, enabled);
  }
}
