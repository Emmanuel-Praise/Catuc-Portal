import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;

  const LocalStorageService();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Session Management ---

  Future<void> saveSession(Map<String, dynamic> sessionData) async {
    await _prefs?.setString('user_session', jsonEncode(sessionData));
  }

  Map<String, dynamic>? getSession() {
    final str = _prefs?.getString('user_session');
    if (str == null) return null;
    return jsonDecode(str) as Map<String, dynamic>;
  }

  Future<void> clearSession() async {
    await _prefs?.remove('user_session');
    // Clear all other keys except settings
    final keys = _prefs?.getKeys() ?? {};
    for (final key in keys) {
      if (!key.startsWith('setting_')) {
        await _prefs?.remove(key);
      }
    }
  }

  // --- Theme/Settings ---

  Future<void> saveSetting(String key, String value) async {
    await _prefs?.setString('setting_$key', value);
  }

  String? getSetting(String key) {
    return _prefs?.getString('setting_$key');
  }
}
