import 'package:android_intent_plus/android_intent.dart';

class MiuiSettings {
  static void openBatterySettings(String packageName) {
    final intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:$packageName',
    );
    intent.launch();
  }
}
