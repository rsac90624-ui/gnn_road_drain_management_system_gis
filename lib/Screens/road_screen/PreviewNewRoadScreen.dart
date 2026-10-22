import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../RoadConditionScreen.dart';
import '../../Welcomescreen.dart';
import '../../constants/appconstants.dart';
import '../../models/asset_system.dart';
import '../../utils/app_error_utils.dart';
import '../../utils/app_snackbar.dart';

class PreviewNewRoadScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<String> roadAgeCategory;
  final String? zoneName;
  final String wardNo;
  final String wardName;

  const PreviewNewRoadScreen({super.key,
    required this.data,
    required this.roadAgeCategory,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
  });

  @override
  State<PreviewNewRoadScreen> createState() => _PreviewNewRoadScreenState();
}

class _PreviewNewRoadScreenState extends State<PreviewNewRoadScreen> {
  bool _isSubmitting = false;

  static const Map<String, String> _fieldLabels = {
    'roadname': 'ROAD NAME',
    'zoneno': 'ZONE NO',
    'zone_no': 'ZONE NO',
    'zonename': 'ZONE NAME',
    'wardno': 'WARD NO',
    'wardname': 'WARD NAME',
    'yoc': 'YEAR OF CONSTRUCTION',
    'major_land': 'MAJOR LANDMARK',
    'own_class': 'OWNERSHIP CLASS',
    'material_c': 'MATERIAL CLASS',
    'cus': 'CONSTRUCTION UNDER SCHEME',
    'row_meter': 'RIGHT OF WAY (METER)',
    'row_apr': 'RIGHT OF WAY (APPROX)',
    'carriage_w': 'CARRIAGE WIDTH',
    'length_met': 'ROAD LENGTH (METER)',
    'footpath': 'FOOTPATH AVAILABLE',
    'median': 'MEDIAN AVAILABLE',
    'manhole': 'MANHOLE AVAILABLE',
    'transforme': 'TRANSFORMER',
    'rmu': 'RING MAIN UNIT',
    'electric_p': 'ELECTRIC POLE',
    'trees': 'TREES',
    'trees_count': 'COUNT OF TREES',
    'pavement_condition': 'PAVEMENT CONDITION',
    'park': 'PARK AVAILABLE',
    'public_toilet': 'PUBLIC TOILET AVAILABLE',
    'toilet': 'PUBLIC TOILET AVAILABLE',
    'parking': 'PARKING AVAILABLE',
    'signboard': 'SIGNBOARD AVAILABLE',
    'other': 'OTHER FACILITIES',
    'government': 'GOVERNMENT OFFICE',
    'gov_office': 'GOVERNMENT OFFICE',
    'educationa': 'EDUCATIONAL INSTITUTION',
    'edu_instit': 'EDUCATIONAL INSTITUTION',
    'religious': 'RELIGIOUS PLACE',
    'reli_place': 'RELIGIOUS PLACE',
    'street__so': 'STREET SOLAR LIGHT',
    'streetlight': 'STREET SOLAR LIGHT',
    'graveyard': 'GRAVEYARD',
    'transport': 'TRANSPORT FACILITY',
    'drain': 'DRAIN AVAILABLE',
    'road_marking': 'ROAD MARKINGS AVAILABLE',
    'marking_available': 'MARKING VISIBLE',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),

        title: Center(
          child: Text("Preview New Road",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        backgroundColor: Colors.orange.shade700,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: widget.data.entries
              .where((e) {
                final key = e.key.toLowerCase();
                return key != "geomwkt" &&
                       key != "mob_latitu" &&
                       key != "mob_longit" &&
                       key != "createdby" &&
                       key != "footpath_photos" &&
                       key != "median_photos" &&
                       key != "marking_photos";
              })
              .map((e) {
            String valueText = e.value?.toString() ?? '';
            if (e.value is List) {
              valueText = (e.value as List).join(", ");
            }

            return Card(
              child: ListTile(
                title: Text(
                    _fieldLabels[e.key.toLowerCase()] ??
                        e.key.toUpperCase().replaceAll('_', ' ')
                ),
                subtitle: Text(valueText),
              ),
            );
          }).toList(),
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                onPressed: _isSubmitting ? null : () => _submit(context),
                child: _isSubmitting
                    ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : Text(_isSubmitting ? "Submitting..." : "Submit")
                //Text("Submit"),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

      final String? username = prefs.getString('username');
      // final token = prefs.getString('authToken');


      if (nagarNigam == null || nagarNigam
          .trim()
          .isEmpty) {
        throw Exception("City/Nagar Nigam not found. Please login again.");
      }

      if (username == null || username
          .trim()
          .isEmpty) {
        throw Exception("User not logged in.");
      }

      // if (token == null || token
      //     .trim()
      //     .isEmpty) {
      //   throw Exception("Auth token not found. Please login again.");
      // }
      final payload = Map<String, dynamic>.from(widget.data);

      payload['createdBy'] = username.trim();

      // ✅ selected dropdown values
      payload['zoneName'] = widget.zoneName?.trim() ?? "";
      payload['wardNo'] = widget.wardNo.trim();
      payload['wardName'] = widget.wardName.trim();

      // ==========================================================
      // EXTRACT PHOTO PATHS
      // ==========================================================
      final List<String> footpathPhotoPaths =
      List<String>.from(payload.remove('footpath_photos') ?? []);

      final List<String> medianPhotoPaths =
      List<String>.from(payload.remove('median_photos') ?? []);

      final List<String> markingPhotoPaths =
      List<String>.from(payload.remove('marking_photos') ?? []);

      String baseUrl = AppConstants.baseURL;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      final url = Uri.parse(
        "$baseUrl/api/roads_mobile/createWithAttributes",
      ).replace(
        queryParameters: {
          "nagarNigam": nagarNigam.trim(),
        },
      );


      debugPrint("CREATE ROAD URL: $url");
      debugPrint("CREATE ROAD NAGAR NIGAM: ${nagarNigam.trim()}");
      debugPrint("CREATE ROAD USERNAME: ${username.trim()}");
      debugPrint("CREATE ROAD DATA: ${jsonEncode(payload)}");

      // ==========================================================
      // MULTIPART REQUEST
      // ==========================================================
      final request = http.MultipartRequest('POST', url);

      // Headers
      request.headers['X-User'] = username.trim();
      request.headers['Accept'] = 'application/json';
      // request.headers['Authorization'] = 'Bearer ${token.trim()}';

      // Normal fields
      request.fields['nagarNigam'] = nagarNigam.trim();
      request.fields['roadData'] = jsonEncode(payload);

      // Footpath Photos
      // for (final path in footpathPhotoPaths) {
      //   if (path.trim().isNotEmpty) {
      //     request.files.add(await http.MultipartFile.fromPath('footpathPhotos', path));
      //   }
      // }
      //
      // // Median Photos
      // for (final path in medianPhotoPaths) {
      //   if (path.trim().isNotEmpty) {
      //     request.files.add(await http.MultipartFile.fromPath('medianPhotos', path));
      //   }
      // }
      //
      // // Marking Photos
      // for (final path in markingPhotoPaths) {
      //   if (path.trim().isNotEmpty) {
      //     request.files.add(await http.MultipartFile.fromPath('markingPhotos', path));
      //   }
      // }

      for (final path in footpathPhotoPaths) {
        if (path.trim().isEmpty) continue;

        final file = File(path);

        if (!await file.exists()) {
          debugPrint("Footpath photo file not found: $path");
          continue;
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'footpathPhotos',
            path,
          ),
        );
      }

      for (final path in medianPhotoPaths) {
        if (path.trim().isEmpty) continue;

        final file = File(path);

        if (!await file.exists()) {
          debugPrint("Median photo file not found: $path");
          continue;
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'medianPhotos',
            path,
          ),
        );
      }

      for (final path in markingPhotoPaths) {
        if (path.trim().isEmpty) continue;

        final file = File(path);

        if (!await file.exists()) {
          debugPrint("Marking photo file not found: $path");
          continue;
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'markingPhotos',
            path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("CREATE ROAD STATUS: ${response.statusCode}");
      debugPrint("CREATE ROAD BODY: ${response.body}");

      if (!mounted) return; // Add this check here

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
                "New road has been created successfully.",
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Close the success dialog
                    Navigator.pop(context);
                    // Close the preview screen
                    Navigator.pop(context);
                    // Close the form screen and return true back to map
                    Navigator.pop(context, true);
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
                "API access denied or user authentication failed.\n\n${response.body}",
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
      debugPrint("CREATE ROAD ERROR: $e");

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
