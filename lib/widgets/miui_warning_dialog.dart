import 'package:flutter/material.dart';
import '../utils/miui_pref.dart';
import '../utils/miui_settings.dart';

class MiuiWarningDialog {
  static void show(BuildContext context, String packageName) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Performance setting required"),
        content: const Text(
            "On Redmi/Xiaomi phones, battery optimization can stop the app and cause crashes.\n\n"
                "Please set Battery usage to 'No restrictions' for stable performance.\n\n"
                "This is required only once."
        ),
        actions: [
          TextButton(
            onPressed: () {
              MiuiPref.markShown();
              Navigator.pop(context);
            },
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () {
              MiuiSettings.openBatterySettings(packageName);
              MiuiPref.markShown();
              Navigator.pop(context);
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }
}
