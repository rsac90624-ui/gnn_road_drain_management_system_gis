
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/appconstants.dart';
import '../../utils/success_dialog.dart';

class PreviewReshapeDrain extends StatelessWidget {
  final Map<String, dynamic> data;

  const PreviewReshapeDrain({super.key, required this.data});

  Future<void> _finalSubmit(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? "mobile_unknown";

    final payload = {
      ...data,
      "mob_latitude": data["latitude"],
      "mob_longitude": data["longitude"],
    };

    final url = Uri.parse("${AppConstants.baseURL}api/drainage/reshape");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "X-User": username,
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      showDrainSuccessDialog(
        context,
        message: "Drain reshaped successfully.",
        zoneName: data['zone_name'],
        wardNo: data['ward_no'],
        wardName: data['ward_name'],
        username: username,
      );
    }

    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submit failed: ${response.body}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Center(
          child: Text(
            "Preview Reshape Drain",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        backgroundColor: Colors.orange.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section("Location"),
            _row("Zone No", data["zone_no"]),
            _row("Zone Name", data["zone_name"]),
            _row("Ward No", data["ward_no"]),
            _row("Ward Name", data["ward_name"]),

            const SizedBox(height: 16),

            _section("Drain Details"),
            _row("Material", data["material"]),
            _row("Drain Type", data["type"]),
            _row("Drain Side", data["sides"]),
            _row("Width (m)", data["width"]),
            _row("Depth (m)", data["depth"]),
            _row("Length (m)", data["length"]),
            _row("Condition", data["condition"]),
            _row("Construction Year", data["const_year"]),
            _row("Ownership", data["ownership"]),
            _row("Status", data["status"]),

            const SizedBox(height: 16),

            _section("Remarks"),
            _row("Remarks", data["remark"]),

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

  // ---------------- UI HELPERS ----------------

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
