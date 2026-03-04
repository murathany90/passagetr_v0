import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReadingLevelFilterState {
  const ReadingLevelFilterState({
    required this.packId,
    required this.selectedLevels,
  });

  final String packId;
  final Set<String> selectedLevels;
}

class ReadingCompletionOverrideState {
  const ReadingCompletionOverrideState({
    required this.packId,
    required this.overrides,
  });

  final String packId;
  final Map<String, bool> overrides;
}

class ReadingListUiStateStore {
  const ReadingListUiStateStore();

  static const String _levelsPrefix = 'reading_levels_v1';
  static const String _overridesPrefix = 'reading_overrides_v1';

  Future<ReadingLevelFilterState> loadLevelFilter(String packId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_levelsKey(packId)) ?? <String>[];
    return ReadingLevelFilterState(
      packId: packId,
      selectedLevels: saved.map((String e) => e.trim().toUpperCase()).where((String e) => e.isNotEmpty).toSet(),
    );
  }

  Future<void> saveLevelFilter({
    required String packId,
    required Set<String> selectedLevels,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> ordered = selectedLevels
        .map((String e) => e.trim().toUpperCase())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false)
      ..sort();
    await prefs.setStringList(_levelsKey(packId), ordered);
  }

  Future<ReadingCompletionOverrideState> loadCompletionOverrides(
    String packId,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_overridesKey(packId)) ?? '{}';
    final Map<String, bool> parsed = <String, bool>{};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final MapEntry<String, dynamic> entry in decoded.entries) {
          if (entry.value is bool) {
            parsed[entry.key] = entry.value as bool;
          }
        }
      }
    } catch (_) {
      // Corrupt state ignored, caller gets empty map.
    }

    return ReadingCompletionOverrideState(packId: packId, overrides: parsed);
  }

  Future<void> saveCompletionOverrides({
    required String packId,
    required Map<String, bool> overrides,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_overridesKey(packId), jsonEncode(overrides));
  }

  String _levelsKey(String packId) => '$_levelsPrefix:$packId';

  String _overridesKey(String packId) => '$_overridesPrefix:$packId';
}
