import 'package:shared_preferences/shared_preferences.dart';

class MiuiPref {
  static const _key = 'miui_battery_hint_shown';

  static Future<bool> wasShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
