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

class PreviewRoadUpdateScreen extends StatefulWidget {
  final String roadId;
  final Map<String, dynamic> updatedData;
  final List<String> roadAgeCategory;
  final String? zoneName;
  final String wardNo;
  final String wardName;


  const PreviewRoadUpdateScreen({
    super.key,
    required this.roadId,
    required this.updatedData,
    required this.roadAgeCategory,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,

  });

  @override
  State<PreviewRoadUpdateScreen> createState() => _PreviewRoadUpdateScreenState();
}

class _PreviewRoadUpdateScreenState extends State<PreviewRoadUpdateScreen> {
  bool _isSubmitting = false;

  static const Map<String, String> _fieldLabels = {
    'road_name': 'ROAD NAME',
    'zone_name': 'ZONE NAME',
    'ward_name': 'WARD NAME',
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
    'trees': 'TREES AVAILABLE',
    'trees_count': 'COUNT OF TREES',
    'pavement_condition': 'PAVEMENT CONDITION',
    'stadium': 'STADIUM',
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
    'park': 'PARK AVAILABLE',
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
          child: const Text("Preview Road Update",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        backgroundColor: Colors.orange.shade700,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: widget.updatedData.entries
              .where((e) {
                final key = e.key.toLowerCase();
                return key != "geomwkt" &&
                       key != "mob_latitu" &&
                       key != "mob_longit" &&
                       key != "zone_no" &&
                       key != "zone_name" &&
                       key != "ward_no" &&
                       key != "ward_name" &&
                       key != "footpath_photos" &&
                       key != "median_photos" &&
                       key != "marking_photos";
              })
              .map((e) {
            String valueText = e.value?.toString() ?? "";
            if (e.value is List) {
              valueText = (e.value as List).join(", ");
            }

            return Card(
              child: ListTile(
                title: Text(
                    _fieldLabels[e.key.toLowerCase()] ??
                        e.key.toUpperCase().replaceAll("_", " ")
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
                onPressed: () => Navigator.pop(context),
                child: const Text("Edit"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: _isSubmitting ? null : () => _submitUpdate(context),
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




  Future<void> _submitUpdate(BuildContext context) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final username = prefs.getString('username');

      final nagarNigam =
          prefs.getString('city') ??
              prefs.getString('nagarNigam');

      if (nagarNigam == null || nagarNigam.trim().isEmpty) {
        throw Exception("City/Nagar Nigam not found. Please login again.");
      }

      if (username == null || username.trim().isEmpty) {
        throw Exception("User not logged in.");
      }

      final payload =
      Map<String, dynamic>.from(widget.updatedData);

      // payload['updated_by'] = username.trim();

      payload['zoneName'] =
          widget.zoneName?.trim() ?? "";

      payload['wardNo'] =
          widget.wardNo.trim();

      payload['wardName'] =
          widget.wardName.trim();


      final List<String> roadAgeCategory =
      payload["roadAgeCategory"] is List
          ? List<String>.from(
        payload["roadAgeCategory"],
      )
          : [
        payload["roadAgeCategory"]
            ?.toString() ??
            "Unknown"
      ];


      // ==========================================================
      // EXTRACT PHOTO PATHS
      // ==========================================================

      final List<String> footpathPhotoPaths =
      List<String>.from(
        payload.remove('footpath_photos') ?? [],
      );


      final List<String> medianPhotoPaths =
      List<String>.from(
        payload.remove('median_photos') ?? [],
      );


      final List<String> markingPhotoPaths =
      List<String>.from(
        payload.remove('marking_photos') ?? [],
      );


      // ==========================================================
      // URL
      // ==========================================================

      final url = Uri.parse(
        '${AppConstants.baseURL}'
            'api/roads_mobile/update/${widget.roadId}',
      );


      debugPrint("UPDATE ROAD URL: $url");
      debugPrint(
        "UPDATE ROAD NAGAR NIGAM: ${nagarNigam.trim()}",
      );

      debugPrint(
        "UPDATE ROAD USERNAME: ${username.trim()}",
      );

      debugPrint(
        "UPDATE ROAD DATA: ${jsonEncode(payload)}",
      );


      // ==========================================================
      // MULTIPART REQUEST
      // ==========================================================

      final request =
      http.MultipartRequest(
        'PUT',
        url,
      );


      // Header
      request.headers['X-User'] =
          username.trim();

      request.headers['Accept'] =
      'application/json';


      // ==========================================================
      // NORMAL FIELDS
      // ==========================================================

      request.fields['nagarNigam'] =
          nagarNigam.trim();


      request.fields['updatedData'] =
          jsonEncode(payload);


      // ==========================================================
      // FOOTPATH PHOTOS
      // ==========================================================

      for (final path in footpathPhotoPaths) {

        if (path.trim().isEmpty) {
          continue;
        }

        final file = File(path);

        if (!await file.exists()) {
          debugPrint("Photo file not found: $path");
          continue;
        }

        request.files.add(

          await http.MultipartFile.fromPath(
            'footpathPhotos',
            path,
          ),
        );
      }


      // ==========================================================
      // MEDIAN PHOTOS
      // ==========================================================

      for (final path in medianPhotoPaths) {

        if (path.trim().isEmpty) {
          continue;
        }

        request.files.add(

          await http.MultipartFile.fromPath(
            'medianPhotos',
            path,
          ),
        );
      }


      // ==========================================================
      // ROAD MARKING PHOTOS
      // ==========================================================

      for (final path in markingPhotoPaths) {

        if (path.trim().isEmpty) {
          continue;
        }

        request.files.add(

          await http.MultipartFile.fromPath(
            'markingPhotos',
            path,
          ),
        );
      }


      debugPrint(
        "FOOTPATH PHOTOS: ${footpathPhotoPaths.length}",
      );

      debugPrint(
        "MEDIAN PHOTOS: ${medianPhotoPaths.length}",
      );

      debugPrint(
        "MARKING PHOTOS: ${markingPhotoPaths.length}",
      );


      // ==========================================================
      // SEND REQUEST
      // ==========================================================

      final streamedResponse =
      await request.send();


      final response =
      await http.Response.fromStream(
        streamedResponse,
      );


      debugPrint(
        "UPDATE ROAD STATUS: ${response.statusCode}",
      );

      debugPrint(
        "UPDATE ROAD BODY: ${response.body}",
      );


      if (!mounted) return;


      // ==========================================================
      // SUCCESS
      // ==========================================================

      if (response.statusCode == 200 ||
          response.statusCode == 201) {

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {

            return AlertDialog(

              title: const Row(
                children: [

                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 30,
                  ),

                  SizedBox(width: 10),

                  Text("Success"),
                ],
              ),
              content: const Text(
                "Road data has been updated successfully.",
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Close the success dialog
                    Navigator.pop(context);
                    // Close the preview screen
                    Navigator.pop(context);
                    // Close the form screen and return true to indicate success
                    Navigator.pop(context, true);
                  },
                  child: const Text("OK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      }

      // ==========================================================
      // UNAUTHORIZED
      // ==========================================================

      else if (response.statusCode == 401 ||
          response.statusCode == 403) {

        showDialog(
          context: context,

          builder: (context) {

            return AlertDialog(

              title: const Row(
                children: [

                  Icon(
                    Icons.lock,
                    color: Colors.red,
                    size: 30,
                  ),

                  SizedBox(width: 10),

                  Text("Unauthorized"),
                ],
              ),

              content: Text(
                "API access denied.\n\n${response.body}",
                style:
                const TextStyle(
                  fontSize: 16,
                ),
              ),

              actions: [

                TextButton(
                  onPressed: () =>
                      Navigator.pop(context),

                  child:
                  const Text("Close"),
                ),
              ],
            );
          },
        );
      } else {
        AppErrorUtils.showServerErrorDialog(context, response.statusCode, response.body);
      }
    } catch (e) {
      debugPrint(
        "UPDATE ROAD ERROR: $e",
      );
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
