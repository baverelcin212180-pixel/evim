import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihaza özel ayarlar (tema gibi görünüm) — sunucuya GİTMEZ, her telefon kendi seçer.
class Settings {
  static SharedPreferences? _prefs;
  static final changed = ValueNotifier<int>(0);

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String getLocal(String key, String fallback) =>
      _prefs?.getString('local:$key') ?? fallback;

  static Future<void> setLocal(String key, String value) async {
    await _prefs?.setString('local:$key', value);
    changed.value++;
  }

  static bool getBool(String key, bool fallback) =>
      _prefs?.getBool('local:$key') ?? fallback;

  static Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool('local:$key', value);
    changed.value++;
  }
}
