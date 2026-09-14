import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/appconstants.dart';

class TrafficSafetyFeaturesFormScreen extends StatefulWidget {
  final String geometryType;

  // Point geometry - kept internally
  final double? latitude;
  final double? longitude;

  // Line geometry - kept internally
  final List<LatLng> linePoints;

  // Basic details
  final String? zoneName;
  final String wardNo;
  final String wardName;

  const TrafficSafetyFeaturesFormScreen({
    super.key,
    required this.geometryType,
    required this.latitude,
    required this.longitude,
    required this.linePoints,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
  });

  @override
  State<TrafficSafetyFeaturesFormScreen> createState() =>
      _TrafficSafetyFeaturesFormScreenState();
}

class _TrafficSafetyFeaturesFormScreenState
    extends State<TrafficSafetyFeaturesFormScreen> {
  bool _isSubmitting = false;
  final _formKey = GlobalKey<FormState>();

  // ============================================================
  // DROPDOWN OPTIONS
  // ============================================================

  final List<String> safetyFeatureTypes = [
    'Speed Breaker',
    'Traffic Signal',
    'Crash Barrier',
    'Pedestrian Crossing',
  ];

  final List<String> sides = [
    'Left',
    'Right',
    'Median',
    'Both Sides'
  ];

  final List<String> conditions = [
    'Good',
    'Fair',
    'Poor',
    'Damaged',
  ];

  final List<String> functionalOptions = [
    'Yes',
    'No',
    'NA',
  ];

  final List<String> visibilityOptions = [
    'Good',
    'Fair',
    'Poor',
  ];

  // ============================================================
  // SELECTED VALUES
  // ============================================================

  String? selectedSafetyFeatureType;
  String? selectedSide;
  String? selectedCondition;
  String? selectedFunctional;
  String? selectedVisibility;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController quantityLengthController =
  TextEditingController();

  final TextEditingController remarksController =
  TextEditingController();

  // ============================================================
  // PHOTOGRAPH
  // ============================================================

  final ImagePicker _imagePicker = ImagePicker();

  File? photograph;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _handleLostData();
  }

  Future<void> _handleLostData() async {
    final LostDataResponse response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) return;
    if (response.file != null) {
      setState(() {
        photograph = File(response.file!.path);
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image == null) {
        setState(() => _isCapturing = false);
        return;
      }

      if (!mounted) return;
      setState(() {
        photograph = File(image.path);
        _isCapturing = false;
      });
    } catch (e) {
      debugPrint("Photo capture error: $e");
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to capture photograph: $e")),
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    quantityLengthController.dispose();
    remarksController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Traffic Safety Feature",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.orange.shade700,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =====================================================
              // BASIC DETAILS
              // =====================================================

              _sectionTitle(
                "Basic Details",
              ),

              _readOnlyField(
                label: "Zone Name",
                value: widget.zoneName ?? "N/A",
              ),

              const SizedBox(
                height: 12,
              ),

              _readOnlyField(
                label: "Ward No",
                value: widget.wardNo,
              ),

              const SizedBox(
                height: 12,
              ),

              _readOnlyField(
                label: "Ward Name",
                value: widget.wardName,
              ),

              const SizedBox(
                height: 12,
              ),

              _readOnlyField(
                label: "Geometry Type",
                value: widget.geometryType,
              ),

              const SizedBox(
                height: 24,
              ),

              // =====================================================
              // SAFETY FEATURE DETAILS
              // =====================================================

              _sectionTitle(
                "Safety Feature Details",
              ),

              DropdownButtonFormField<String>(
                value: selectedSafetyFeatureType,
                decoration: _inputDecoration(
                  "Safety Feature Type",
                ),
                items: safetyFeatureTypes.map(
                      (item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                      ),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSafetyFeatureType =
                        value;
                  });
                },
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Select Safety Feature Type";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              DropdownButtonFormField<String>(
                value: selectedSide,
                decoration: _inputDecoration(
                  "Side",
                ),
                items: sides.map(
                      (item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                      ),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSide = value;
                  });
                },
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Select Side";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              TextFormField(
                controller:
                quantityLengthController,
                keyboardType:
                const TextInputType
                    .numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDecoration(
                  widget.geometryType ==
                      "Line"
                      ? "Length"
                      : "Quantity / Length",
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Enter Quantity / Length";
                  }

                  final number =
                  double.tryParse(
                    value.trim(),
                  );

                  if (number == null) {
                    return "Enter valid numeric value";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              DropdownButtonFormField<String>(
                value: selectedCondition,
                decoration: _inputDecoration(
                  "Condition",
                ),
                items: conditions.map(
                      (item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                      ),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCondition =
                        value;
                  });
                },
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Select Condition";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              DropdownButtonFormField<String>(
                value: selectedFunctional,
                decoration: _inputDecoration(
                  "Functional",
                ),
                items: functionalOptions.map(
                      (item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                      ),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedFunctional =
                        value;
                  });
                },
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Select Functional status";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              DropdownButtonFormField<String>(
                value: selectedVisibility,
                decoration: _inputDecoration(
                  "Visibility",
                ),
                items: visibilityOptions.map(
                      (item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                      ),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedVisibility =
                        value;
                  });
                },
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Select Visibility";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 24,
              ),

              // =====================================================
              // PHOTOGRAPH
              // =====================================================

              _sectionTitle(
                "Photograph",
              ),

              if (photograph != null) ...[
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                  child: Image.file(
                    photograph!,
                    height: 200,
                    width: double.infinity,
                    cacheWidth: 300,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
              ],

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _capturePhoto,
                  icon: const Icon(
                    Icons.camera_alt,
                  ),
                  label: Text(
                    photograph == null
                        ? "Capture Photograph"
                        : "Retake Photograph",
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // =====================================================
              // REMARKS
              // =====================================================

              _sectionTitle(
                "Remarks",
              ),

              TextFormField(
                controller:
                remarksController,
                maxLines: 4,
                decoration:
                _inputDecoration(
                  "Enter Remarks",
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // =====================================================
              // SUBMIT
              // =====================================================

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.save,
                          color: Colors.white,
                        ),
                  label: Text(
                    _isSubmitting ? "Submitting..." : "Submit",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUBMIT FORM
  // ============================================================

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (photograph == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please capture a photograph")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'mobile_unknown';
      final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam') ?? '';
      final token = prefs.getString('authToken');

      final url = Uri.parse('${AppConstants.baseURL}api/traffic-safety/create');
      final request = http.MultipartRequest('POST', url);

      // Add headers
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['X-User'] = username;

      // Add basic details
      request.fields['nagarNigam'] = nagarNigam;
      request.fields['zoneName'] = widget.zoneName ?? "";
      request.fields['wardNo'] = widget.wardNo;
      request.fields['wardName'] = widget.wardName;
      request.fields['geometryType'] = widget.geometryType;
      request.fields['createdBy'] = username;

      // Add safety feature details
      request.fields['safetyFeatureType'] = selectedSafetyFeatureType ?? "";
      request.fields['side'] = selectedSide ?? "";
      request.fields['quantityLength'] = quantityLengthController.text.trim();
      request.fields['condition'] = selectedCondition ?? "";
      request.fields['functional'] = selectedFunctional ?? "";
      request.fields['visibility'] = selectedVisibility ?? "";
      request.fields['remarks'] = remarksController.text.trim();

      // Add location details
      if (widget.geometryType == "Point") {
        request.fields['latitude'] = widget.latitude.toString();
        request.fields['longitude'] = widget.longitude.toString();
      } else {
        final coordinates = widget.linePoints.map((LatLng point) {
          return {
            'latitude': point.latitude,
            'longitude': point.longitude,
          };
        }).toList();
        request.fields['coordinates'] = jsonEncode(coordinates);
      }

      // Add image
      request.files.add(
        await http.MultipartFile.fromPath(
          'photograph',
          photograph!.path,
        ),
      );

      debugPrint("📡 SUBMITTING TRAFFIC SAFETY TO: $url");
      debugPrint("📦 PAYLOAD FIELDS: ${request.fields}");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("📡 STATUS: ${response.statusCode}");
      debugPrint("📡 BODY: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Success"),
            content: const Text("Traffic safety feature details saved successfully."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context, true); // return to map
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
      String title,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight:
          FontWeight.bold,
          color:
          Colors.orange.shade800,
        ),
      ),
    );
  }

  // ============================================================
  // READ ONLY FIELD
  // ============================================================

  Widget _readOnlyField({
    required String label,
    required String value,
  }) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor:
        Colors.grey.shade100,
        border:
        const OutlineInputBorder(),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration(
      String label,
      ) {
    return InputDecoration(
      labelText: label,
      border:
      const OutlineInputBorder(),
    );
  }
}