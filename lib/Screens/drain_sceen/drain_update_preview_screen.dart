import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/appconstants.dart';
import '../../utils/success_dialog.dart';

class DrainUpdatePreviewScreen extends StatelessWidget {
  final int gid;
  final Map<String, dynamic> staticData;
  final Map<String, dynamic> editedData;

  const DrainUpdatePreviewScreen({
    super.key,
    required this.gid,
    required this.staticData,
    required this.editedData,
  });

  Future<void> _finalSubmit(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? "mobile_unknown";
    final nagarNigam = prefs.getString('city') ?? "";
    final token = prefs.getString('authToken');

    final payload = {
      "zone_no": staticData['zone_no'],
      "zone_name": staticData['zone_name'],
      "ward_no": staticData['ward_no'],
      "ward_name": staticData['ward_name'],
      ...editedData,
    };

    final uri = Uri.parse("${AppConstants.baseURL}api/gha_drainage/drain/update/$gid")
        .replace(queryParameters: {"nagarNigam": nagarNigam});

    debugPrint("📡 SUBMIT DRAIN UPDATE URL: $uri");

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "X-User": username,
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    debugPrint("📡 UPDATE STATUS: ${response.statusCode}");
    debugPrint("📡 UPDATE BODY: ${response.body}");

    if (response.statusCode == 200) {
      showDrainSuccessDialog(
        context,
        message: "Drain data updated successfully",
        zoneName: staticData['zone_name'],
        wardNo: staticData['ward_no'],
        wardName: staticData['ward_name'],
        username: username,
      );
    }
    else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update failed: ${response.statusCode}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title:  Center(
          child: Text("Preview Drain Update", style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),),
        ),
        backgroundColor: Colors.orange.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section("Location"),
            _row("Zone No", staticData['zone_no']),
            _row("Zone Name", staticData['zone_name']),
            _row("Ward No", staticData['ward_no']),
            _row("Ward Name", staticData['ward_name']),
            // _row("Mobile Latitude", staticData['mob_latitude']),
            // _row("Mobile Longitude", staticData['mob_longitude']),



            const SizedBox(height: 16),

            _section("Updated Values"),
            ...editedData.entries
                .where((e) => ![
              "mob_latitude",
              "mob_longitude",
            ].contains(e.key))
                .map((e) => _row(e.key, e.value)),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Edit"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _finalSubmit(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                    ),
                    child: const Text(
                      "Final Submit",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value?.toString() ?? "-"),
          const Divider(),
        ],
      ),
    );
  }
}
