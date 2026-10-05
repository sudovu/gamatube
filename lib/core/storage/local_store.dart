import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../logging/app_logger.dart';

abstract class LocalStore {
  Future<void> init();
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<Map<String, dynamic>?> getJson(String key);
  Future<void> setJson(String key, Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>?> getJsonList(String key);
  Future<void> setJsonList(String key, List<Map<String, dynamic>> list);
  Future<void> remove(String key);
  Future<void> clearAll();
  Future<int> estimateStorageBytes();
}

class SharedPreferencesLocalStore implements LocalStore {
  SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    AppLogger.debug('LocalStore initialized via SharedPreferences');
  }

  SharedPreferences get _requirePrefs {
    if (_prefs == null) {
      throw StateError('LocalStore has not been initialized. Call init() first.');
    }
    return _prefs!;
  }

  @override
  Future<String?> getString(String key) async {
    return _requirePrefs.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _requirePrefs.setString(key, value);
  }

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final raw = _requirePrefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      AppLogger.warning('Failed to decode JSON for key $key', e);
      return null;
    }
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> data) async {
    final raw = jsonEncode(data);
    await _requirePrefs.setString(key, raw);
  }

  @override
  Future<List<Map<String, dynamic>>?> getJsonList(String key) async {
    final raw = _requirePrefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      return null;
    } catch (e) {
      AppLogger.warning('Failed to decode JSON list for key $key', e);
      return null;
    }
  }

  @override
  Future<void> setJsonList(String key, List<Map<String, dynamic>> list) async {
    final raw = jsonEncode(list);
    await _requirePrefs.setString(key, raw);
  }

  @override
  Future<void> remove(String key) async {
    await _requirePrefs.remove(key);
  }

  @override
  Future<void> clearAll() async {
    await _requirePrefs.clear();
    AppLogger.info('Cleared all local storage data');
  }

  @override
  Future<int> estimateStorageBytes() async {
    int total = 0;
    final keys = _requirePrefs.getKeys();
    for (final k in keys) {
      total += k.length;
      final val = _requirePrefs.get(k);
      if (val is String) {
        total += val.length;
      } else if (val is List<String>) {
        for (final item in val) {
          total += item.length;
        }
      }
    }
    return total;
  }
}
