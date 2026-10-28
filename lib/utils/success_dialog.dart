import 'package:flutter/material.dart';

void showDrainSuccessDialog(
    BuildContext context, {
      required String message,
      required String? zoneName,
      required String wardNo,
      required String wardName,
      required String username,
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text("Success"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 8),
          if (zoneName != null) Text("Zone: $zoneName"),
          Text("Ward No: $wardNo"),
          Text("Ward Name: $wardName"),
          Text("User: $username"),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade700,
          ),
          onPressed: () {
            final nav = Navigator.of(context);
            nav.pop(); // 1️⃣ close dialog
            nav.pop(); // 2️⃣ close Preview
            nav.pop(true); // 3️⃣ close Form → back to MAP
          },
          child: const Text(
            "OK",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

