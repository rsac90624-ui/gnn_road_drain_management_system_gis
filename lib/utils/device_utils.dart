import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

class DeviceUtils {
  static Future<bool> isXiaomi() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    final brand = androidInfo.brand.toLowerCase();
    final manufacturer = androidInfo.manufacturer.toLowerCase();
    final model = androidInfo.model.toLowerCase();

    return brand.contains('xiaomi') ||
        brand.contains('redmi') ||
        brand.contains('poco') ||
        manufacturer.contains('xiaomi') ||
        manufacturer.contains('redmi') ||
        manufacturer.contains('poco') ||
        model.contains('xiaomi') ||
        model.contains('redmi') ||
        model.contains('poco');
  }

  static Future<bool> isEmulator() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;

      return androidInfo.isPhysicalDevice == false ||
          androidInfo.model.toLowerCase().contains('sdk') ||
          androidInfo.model.toLowerCase().contains('emulator') ||
          androidInfo.product.toLowerCase().contains('sdk') ||
          androidInfo.hardware.toLowerCase().contains('goldfish') ||
          androidInfo.hardware.toLowerCase().contains('ranchu');
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.isPhysicalDevice == false;
    }

    return false;
  }

  static Future<bool> blockIfEmulator(BuildContext context) async {
    try {
      final emulator = await isEmulator();

      if (!context.mounted) {
        return true;
      }

      if (!emulator) {
        return false;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Restricted Device'),
            content: const Text(
              'This application cannot be used on an emulator or virtual device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      return true;
    } catch (_) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Device Verification Failed'),
              content: const Text(
                'Unable to verify this device. Login has been blocked.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }

      // Fail closed: sensitive operation remains blocked.
      return true;
    }
  }

  //-------------------------------------------- Root Detection  -------------------------------------------------------------


  static Future<bool> isRooted() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      const suspiciousPaths = [
        '/system/app/Superuser.apk',
        '/system/app/SuperSU.apk',
        '/sbin/su',
        '/system/bin/su',
        '/system/xbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/data/local/su',
        '/system/bin/.ext/.su',
        '/system/usr/we-need-root/su-backup',
        '/system/xbin/mu',
        '/sbin/.magisk',
        '/data/adb/magisk',
        '/data/adb/modules',
      ];

      for (final path in suspiciousPaths) {
        if (await File(path).exists()) {
          return true;
        }
      }

      final buildTags = await Process.run(
        '/system/bin/getprop',
        ['ro.build.tags'],
      );

      if (buildTags.stdout
          .toString()
          .toLowerCase()
          .contains('test-keys')) {
        return true;
      }

      final suCommand = await Process.run(
        '/system/bin/sh',
        ['-c', 'command -v su'],
      );

      if (suCommand.exitCode == 0 &&
          suCommand.stdout.toString().trim().isNotEmpty) {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> blockIfRooted(
      BuildContext context,
      ) async {
    try {
      final rooted = await isRooted();

      if (!context.mounted) {
        return true;
      }

      if (!rooted) {
        return false;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Security Restriction'),
            content: const Text(
              'This application cannot be used on a rooted device.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      return true;
    } catch (_) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Device Verification Failed'),
              content: const Text(
                'Unable to verify device security. Login has been blocked.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }

      return true;
    }
  }

}
