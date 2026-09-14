import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/appconstants.dart';
import '../../utils/success_dialog.dart';

class NewRoadDrainPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const NewRoadDrainPreviewScreen({
    super.key,
    required this.data,
  });

  Future<void> _finalSubmit(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? "mobile_unknown";

    final nagarNigam = prefs.getString('city') ?? "";
    final token = prefs.getString('authToken');

    final payload = {
      ...data,
      "width": double.tryParse(data['width']?.toString() ?? ""),
      "depth": double.tryParse(data['depth']?.toString() ?? ""),
      "length": double.tryParse(data['length']?.toString() ?? ""),
      "const_year": int.tryParse(data['const_year']?.toString() ?? ""),
    };

    final uri = Uri.parse("${AppConstants.baseURL}api/gha_drainage/drain/create")
        .replace(queryParameters: {"nagarNigam": nagarNigam});

    debugPrint("📡 SUBMIT NEW DRAIN URL: $uri");

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "X-User": username,
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );



    if (response.statusCode == 200 || response.statusCode == 201) {
      showDrainSuccessDialog(
        context,
        message: "New Drain data has been successfully submitted.",
        zoneName: data['zone_name'],
        wardNo: data['ward_no'],
        wardName: data['ward_name'],
        username: username,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Submission failed")),
      );
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
          child: Text("Preview New Drain Network", style: TextStyle(
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
            _row("Zone No", data['zone_no']),
            _row("Zone Name", data['zone_name']),
            _row("Ward No", data['ward_no']),
            _row("Ward Name", data['ward_name']),
            // _row("Latitude", data['latitude']),
            // _row("Longitude", data['longitude']),


            const SizedBox(height: 16),

            _section("Drain Details"),
            ...data.entries
                .where((e) =>
            ![
              "zone_no",
              "zone_name",
              "ward_no",
              "ward_name",
              "wkt_geom",
              "latitude",
              "longitude",
            ].contains(e.key))
                .map((e) => _row(e.key.replaceAll("_", " "), e.value)),

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

  // ---------------- UI HELPERS (same as update preview) ----------------

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
