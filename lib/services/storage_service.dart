import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/timer_preset.dart';
import '../models/timer_group.dart';

// Provider to access the storage service
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized');
});

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const String _keyPresets = 'timer_presets';
  static const String _keyGroups = 'timer_groups';

  // --- Presets ---

  List<TimerPreset> loadPresets() {
    final jsonString = _prefs.getString(_keyPresets);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => TimerPreset.fromJson(e)).toList();
  }

  Future<void> savePresets(List<TimerPreset> presets) async {
    final jsonString = jsonEncode(presets.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyPresets, jsonString);
  }

  // --- Groups ---

  List<TimerGroup> loadGroups() {
    final jsonString = _prefs.getString(_keyGroups);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => TimerGroup.fromJson(e)).toList();
  }

  Future<void> saveGroups(List<TimerGroup> groups) async {
    final jsonString = jsonEncode(groups.map((e) => e.toJson()).toList());
    await _prefs.setString(_keyGroups, jsonString);
  }
}
