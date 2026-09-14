import 'package:flutter/material.dart';
import 'emulator_check.dart';

Future<bool> blockIfEmulator(BuildContext context) async {
  if (await isEmulator()) {
    if (!context.mounted) return true;

    await showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text("Security Restriction"),
        content: Text("This operation is not allowed on emulated devices."),
      ),
    );

    return true; // blocked
  }

  return false; // allowed
}