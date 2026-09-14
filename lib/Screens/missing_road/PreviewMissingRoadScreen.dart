
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/appconstants.dart';

class PreviewMissingRoadScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const PreviewMissingRoadScreen({
    super.key,
    required this.data,
  });

  // Keys that must NOT be shown in preview
  static const Set<String> _hiddenKeys = {
    "geomWKT",
  };

  // Friendly labels for technical keys
  static const Map<String, String> _labels = {
    "mob_latitude": "Mobile Latitude",
    "mob_longitude": "Mobile Longitude",
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Center(
          child: Text(
            "Preview New Road",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        backgroundColor: Colors.orange,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: data.entries
              .where((e) => !_hiddenKeys.contains(e.key))
              .map((e) {
            final title =
                _labels[e.key] ??
                    e.key.toUpperCase().replaceAll('_', ' ');

            return Card(
              child: ListTile(
                title: Text(title),
                subtitle: Text(e.value?.toString() ?? "-"),
              ),
            );
          })
              .toList(),
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Edit"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _submit(context),
                child: const Text("Submit"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('nagarNigam') ?? "";
    final username = prefs.getString('username') ?? "mobile_unknown";

    final uri = Uri.parse(
      "${AppConstants.baseURL}api/roads_mobile/saveMissingRoad?nagarNigam=$nagarNigam",
    );

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "X-User": username,
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text("Success"),
            ],
          ),
          content: const Text(
            "New road has been created successfully.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text("Error"),
            ],
          ),
          content: Text(
            "Failed to create road.\n\n${response.body}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }
  }
}
