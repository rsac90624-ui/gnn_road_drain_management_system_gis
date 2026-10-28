import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../RoadConditionScreen.dart';
import '../../Welcomescreen.dart';
import '../../constants/appconstants.dart';
import '../../models/asset_system.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/app_snackbar.dart';

class PreviewReshapeRoadScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<String> roadAgeCategory;
  final String? zoneName;
  final String wardNo;
  final String wardName;

  const PreviewReshapeRoadScreen({
    super.key,
    required this.data,
    required this.roadAgeCategory,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
  });

  @override
  State<PreviewReshapeRoadScreen> createState() =>
      _PreviewReshapeRoadScreenState();
}

class _PreviewReshapeRoadScreenState extends State<PreviewReshapeRoadScreen> {
  bool _isSubmitting = false;

  static const Map<String, String> _fieldLabels = {'footpath': 'FOOTPATH'};
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Center(
          child: Text(
            "Preview Reshape Road",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        backgroundColor: Colors.orange.shade700,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: widget.data.entries
              .where((e) => e.key != "geomWKT") // HIDE geometry from preview
              .map((e) {
                return Card(
                  child: ListTile(
                    // title: Text(e.key.toUpperCase().replaceAll('_', ' ')),
                    title: Text(
                      _fieldLabels[e.key.toLowerCase()] ??
                          e.key.toUpperCase().replaceAll('_', ' '),
                    ),
                    subtitle: Text(e.value?.toString() ?? ''),
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
                child: Text("Edit"),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              // child: ElevatedButton(
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: Colors.green,
              //     padding: EdgeInsets.symmetric(vertical: 14),
              //   ),
              //   child: Text("Submit"),
              //   onPressed: () => _submit(context),
              // ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _isSubmitting ? null : () => _submit(context),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(_isSubmitting ? "Submitting..." : "Submit"),
                //Text("Submit"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Future<void> _submit(BuildContext context) async {
  //   if (_isSubmitting) return;
  //
  //   setState(() {
  //     _isSubmitting = true;
  //   });
  //   try {
  //     // final prefs = await SharedPreferences.getInstance();
  //     // final nagarNigam = prefs.getString('nagarNigam') ?? "";
  //     // final String? username = prefs.getString('username');
  //
  //     final prefs = await SharedPreferences.getInstance();
  //
  //     final nagarNigam =
  //         prefs.getString('city') ??
  //             prefs.getString('nagarNigam');
  //
  //     final String? username = prefs.getString('username');
  //
  //     if (nagarNigam == null || nagarNigam.trim().isEmpty) {
  //       throw Exception("City/Nagar Nigam not found. Please login again.");
  //     }
  //     // final token = prefs.getString('token');
  //
  //     if (username == null) {
  //       throw Exception("User not logged in");
  //     }
  //     widget.data['reshapedBy'] = username;
  //
  //     // final url = Uri.parse(
  //     //   "${AppConstants.baseURL}api/roads_mobile/reshape?nagarNigam=$nagarNigam",
  //     // );
  //
  //     final url = Uri.parse(
  //       "${AppConstants.baseURL}api/roads_mobile/reshape",
  //     ).replace(
  //       queryParameters: {
  //         "nagarNigam": nagarNigam.trim(),
  //       },
  //     );
  //
  //     print("RESHAPE URL: $url");
  //     print("RESHAPE NAGAR NIGAM: $nagarNigam");
  //     print("RESHAPE DATA SENT: ${jsonEncode(widget.data)}");
  //
  //     final response = await http.post(
  //       url,
  //       headers: {"Content-Type": "application/json", "X-User": username},
  //       // headers: {
  //       //   'Content-Type': 'application/json',
  //       //   'Authorization': 'Bearer $token',
  //       //   'X-User': username,
  //       // },
  //       body: jsonEncode(widget.data),
  //     );
  //
  //     print("RESHAPE DATA SENT: ${jsonEncode(widget.data)}");
  //
  //     if (response.statusCode == 200) {
  //       showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (context) {
  //           return AlertDialog(
  //             title: Row(
  //               children: [
  //                 Icon(Icons.check_circle, color: Colors.green, size: 30),
  //                 SizedBox(width: 10),
  //                 Text("Success"),
  //               ],
  //             ),
  //             content: Text(
  //               "Road reshaped and saved successfully.",
  //               style: TextStyle(fontSize: 16),
  //             ),
  //             actions: [
  //               TextButton(
  //
  //                 onPressed: () {
  //                   Navigator.pushReplacement(
  //                     context,
  //                     MaterialPageRoute(
  //                       builder: (_) => Welcomescreen(
  //                         roadAgeCategory: widget.roadAgeCategory,
  //                         // Pass the required parameters
  //                         zoneName: widget.zoneName,
  //                         wardNo: widget.wardNo,
  //                         wardName: widget.wardName,
  //                       ),
  //                     ),
  //                   );
  //                 },
  //                 child: Text(
  //                   "OK",
  //                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //                 ),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     } else {
  //       showDialog(
  //         context: context,
  //         builder: (context) {
  //           return AlertDialog(
  //             title: Row(
  //               children: [
  //                 Icon(Icons.error, color: Colors.red, size: 30),
  //                 SizedBox(width: 10),
  //                 Text("Error"),
  //               ],
  //             ),
  //             content: Text(
  //               "Failed to reshape road.\n\n${response.body}",
  //               style: TextStyle(fontSize: 16),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.pop(context),
  //                 child: Text("Close"),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     }
  //   } catch (e) {
  //     print(e);
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isSubmitting = false;
  //       });
  //     }
  //   }
  // }
  Future<void> _submit(BuildContext context) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final nagarNigam =
          prefs.getString('city') ??
              prefs.getString('nagarNigam');

      final username = prefs.getString('username');
      final token = prefs.getString('authToken');

      if (nagarNigam == null || nagarNigam.trim().isEmpty) {
        throw Exception("City/Nagar Nigam not found. Please login again.");
      }

      if (username == null || username.trim().isEmpty) {
        throw Exception("User not logged in.");
      }

      if (token == null || token.trim().isEmpty) {
        throw Exception("Auth token not found. Please login again.");
      }

      final payload = Map<String, dynamic>.from(widget.data);

      payload['reshapedBy'] = username.trim();

      // ✅ dropdown selected values
      payload['zoneName'] = widget.zoneName?.trim() ?? "";
      payload['wardNo'] = widget.wardNo.trim();
      payload['wardName'] = widget.wardName.trim();

      final url = Uri.parse(
        "${AppConstants.baseURL}api/roads_mobile_auth/reshape",
      ).replace(
        queryParameters: {
          "nagarNigam": nagarNigam.trim(),
        },
      );

      print("RESHAPE URL: $url");
      print("RESHAPE NAGAR NIGAM: ${nagarNigam.trim()}");
      print("RESHAPE USERNAME: ${username.trim()}");
      print("RESHAPE TOKEN EXISTS: ${token.trim().isNotEmpty}");
      print("RESHAPE DATA SENT: ${jsonEncode(payload)}");

      final response = await http.post(
        url,
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer ${token.trim()}",
          "X-User": username.trim(),
        },
        body: jsonEncode(payload),
      );

      print("RESHAPE STATUS: ${response.statusCode}");
      print("RESHAPE BODY: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 30),
                  SizedBox(width: 10),
                  Text("Success"),
                ],
              ),
              content: const Text(
                "Road reshaped and saved successfully.",
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    final nav = Navigator.of(context);
                    // Close the success dialog
                    nav.pop();
                    // Close the preview screen
                    nav.pop();
                    // Return back to map
                    nav.pop(true);
                  },
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.red, size: 30),
                  SizedBox(width: 10),
                  Text("Unauthorized"),
                ],
              ),
              content: Text(
                "Token missing, expired, or API is blocked.\n\n${response.body}",
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      } else {
        AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      print("RESHAPE ERROR: $e");

      if (!mounted) return;

      AppSnackBar.showError(context, AppErrorUtils.getFriendlyErrorMessage(null, e));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

}
