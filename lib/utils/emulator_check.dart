import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<bool> isEmulator() async {
  final deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;

    return !androidInfo.isPhysicalDevice ||
        androidInfo.brand.toLowerCase().contains('generic') ||
        androidInfo.device.toLowerCase().contains('generic') ||
        androidInfo.model.toLowerCase().contains('emulator') ||
        androidInfo.product.toLowerCase().contains('sdk');
  }

  return false;
}