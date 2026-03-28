import "dart:convert";

import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:ccviewer_mobile_hub/models/theme_preferences.dart";

class ThemePreferencesService extends ChangeNotifier {
  ThemePreferencesService._internal({SharedPreferences? prefs}) : _prefs = prefs;

  factory ThemePreferencesService({SharedPreferences? prefs}) {
    return ThemePreferencesService._internal(prefs: prefs);
  }

  static final ThemePreferencesService instance = ThemePreferencesService._internal();

  static const String _storageKey = "theme_preferences_v1";

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<ThemePreferences> loadPreferences() async {
    final prefs = await _getPrefs();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return const ThemePreferences();
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return ThemePreferences.fromJson(decoded);
      }
      if (decoded is Map) {
        return ThemePreferences.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      // fall through to default
    }
    return const ThemePreferences();
  }

  Future<void> savePreferences(ThemePreferences prefs) async {
    final store = await _getPrefs();
    final jsonString = jsonEncode(prefs.toJson());
    await store.setString(_storageKey, jsonString);
    notifyListeners();
  }

  Future<void> clearPreferences() async {
    final store = await _getPrefs();
    await store.remove(_storageKey);
    notifyListeners();
  }
}
