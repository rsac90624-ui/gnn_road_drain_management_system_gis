import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/appconstants.dart';

class PavementDistressFormScreen extends StatefulWidget {
  final String geometryType;

  // Point geometry - stored internally
  final double? latitude;
  final double? longitude;

  // Geometry points - stored internally (for Line or Polygon)
  final List<LatLng> geometryPoints;

  // Basic details
  final String? zoneName;
  final String wardNo;
  final String wardName;

  const PavementDistressFormScreen({
    super.key,
    required this.geometryType,
    required this.latitude,
    required this.longitude,
    required this.geometryPoints,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
  });

  @override
  State<PavementDistressFormScreen> createState() =>
      _PavementDistressFormScreenState();
}

class _PavementDistressFormScreenState
    extends State<PavementDistressFormScreen> {
  bool _isSubmitting = false;

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  // ============================================================
  // DROPDOWN VALUES
  // ============================================================

  final List<String> distressTypes = [
    'Pothole',
    'Crack',
    'Damaged Paver Block',
    'Uneven Surface',
    'Waterlogging Damage',
    'Rutting',
    'Other',
  ];

  final List<String> severities = [
    'Low',
    'Medium',
    'High',
  ];

  String? selectedDistressType;
  String? selectedSeverity;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController approximateLengthController =
  TextEditingController();

  final TextEditingController approximateWidthController =
  TextEditingController();

  final TextEditingController approximateAreaController =
  TextEditingController();

  final TextEditingController remarksController =
  TextEditingController();

  // ============================================================
  // IMAGE
  // ============================================================

  final ImagePicker _imagePicker = ImagePicker();

  File? photograph;
  bool _isCapturing = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    approximateLengthController.addListener(
      _calculateArea,
    );

    approximateWidthController.addListener(
      _calculateArea,
    );
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

  // ============================================================
  // AREA CALCULATION
  // ============================================================

  void _calculateArea() {
    final double? length = double.tryParse(
      approximateLengthController.text.trim(),
    );

    final double? width = double.tryParse(
      approximateWidthController.text.trim(),
    );

    if (length != null && width != null) {
      final double area = length * width;

      approximateAreaController.text =
          area.toStringAsFixed(2);
    } else {
      approximateAreaController.clear();
    }
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
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
    approximateLengthController.removeListener(
      _calculateArea,
    );

    approximateWidthController.removeListener(
      _calculateArea,
    );

    approximateLengthController.dispose();
    approximateWidthController.dispose();
    approximateAreaController.dispose();
    remarksController.dispose();

    super.dispose();
  }

  // ============================================================
  // SUBMIT
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

      final url = Uri.parse('${AppConstants.baseURL}api/pavement-distress/create');
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

      // Add distress details
      request.fields['distressType'] = selectedDistressType ?? "";
      request.fields['severity'] = selectedSeverity ?? "";
      request.fields['approxLength'] = approximateLengthController.text.trim();
      request.fields['approxWidth'] = approximateWidthController.text.trim();
      request.fields['approxArea'] = approximateAreaController.text.trim();
      request.fields['remarks'] = remarksController.text.trim();

      // Add location details
      if (widget.geometryType == "Point") {
        request.fields['latitude'] = widget.latitude.toString();
        request.fields['longitude'] = widget.longitude.toString();
      } else {
        final coordinates = widget.geometryPoints.map((LatLng point) {
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

      debugPrint("📡 SUBMITTING PAVEMENT DISTRESS TO: $url");
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
            content: const Text("Pavement distress details saved successfully."),
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Pavement Distress",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
        Colors.red.shade700,
        iconTheme:
        const IconThemeData(
          color: Colors.white,
        ),
      ),

      body: Form(
        key: _formKey,

        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              // =================================================
              // BASIC DETAILS
              // =================================================

              _sectionTitle(
                "Basic Details",
              ),

              _readOnlyField(
                label: "Zone Name",
                value:
                widget.zoneName ??
                    "N/A",
              ),

              const SizedBox(
                height: 12,
              ),

              _readOnlyField(
                label: "Ward No",
                value:
                widget.wardNo,
              ),

              const SizedBox(
                height: 12,
              ),

              _readOnlyField(
                label: "Ward Name",
                value:
                widget.wardName,
              ),

              const SizedBox(
                height: 12,
              ),

              _readOnlyField(
                label:
                "Geometry Type",
                value:
                widget.geometryType,
              ),

              const SizedBox(
                height: 24,
              ),

              // =================================================
              // DISTRESS DETAILS
              // =================================================

              _sectionTitle(
                "Distress Details",
              ),

              DropdownButtonFormField<
                  String>(
                value:
                selectedDistressType,

                decoration:
                _inputDecoration(
                  "Distress Type",
                ),

                items:
                distressTypes.map(
                      (String item) {
                    return DropdownMenuItem<
                        String>(
                      value: item,
                      child:
                      Text(item),
                    );
                  },
                ).toList(),

                onChanged:
                    (String? value) {
                  setState(() {
                    selectedDistressType =
                        value;
                  });
                },

                validator:
                    (String? value) {
                  if (value == null) {
                    return "Select Distress Type";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // =================================================
              // SEVERITY
              // =================================================

              DropdownButtonFormField<
                  String>(
                value:
                selectedSeverity,

                decoration:
                _inputDecoration(
                  "Severity",
                ),

                items:
                severities.map(
                      (String item) {
                    return DropdownMenuItem<
                        String>(
                      value: item,
                      child:
                      Text(item),
                    );
                  },
                ).toList(),

                onChanged:
                    (String? value) {
                  setState(() {
                    selectedSeverity =
                        value;
                  });
                },

                validator:
                    (String? value) {
                  if (value == null) {
                    return "Select Severity";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // =================================================
              // APPROX LENGTH
              // =================================================

              TextFormField(
                controller:
                approximateLengthController,

                keyboardType:
                const TextInputType
                    .numberWithOptions(
                  decimal: true,
                ),

                decoration:
                _inputDecoration(
                  widget.geometryType == "Polygon"
                      ? "Approx. Length (m)"
                      : "Approx. Length (m)",
                ),

                validator:
                    (String? value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return "Enter Approx. Length";
                  }

                  if (double.tryParse(
                    value.trim(),
                  ) ==
                      null) {
                    return "Enter valid Length";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // =================================================
              // APPROX WIDTH
              // =================================================

              TextFormField(
                controller:
                approximateWidthController,

                keyboardType:
                const TextInputType
                    .numberWithOptions(
                  decimal: true,
                ),

                decoration:
                _inputDecoration(
                  "Approx. Width (m)",
                ),

                validator:
                    (String? value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return "Enter Approx. Width";
                  }

                  if (double.tryParse(
                    value.trim(),
                  ) ==
                      null) {
                    return "Enter valid Width";
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // =================================================
              // APPROX AREA
              // =================================================

              TextFormField(
                controller:
                approximateAreaController,

                readOnly: true,

                decoration:
                InputDecoration(
                  labelText:
                  "Approx. Area (sq. m)",

                  hintText:
                  "Calculated automatically",

                  filled: true,

                  fillColor:
                  Colors.grey.shade100,

                  border:
                  const OutlineInputBorder(),

                  suffixIcon:
                  const Icon(
                    Icons.calculate,
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // =================================================
              // GPS LOCATION
              // =================================================

              _sectionTitle(
                "GPS Location",
              ),

              if (widget.geometryType ==
                  "Point")
                _readOnlyField(
                  label:
                  "GPS Location",
                  value:
                  widget.latitude !=
                      null &&
                      widget.longitude !=
                          null
                      ? "${widget.latitude!.toStringAsFixed(6)}, "
                      "${widget.longitude!.toStringAsFixed(6)}"
                      : "Location not available",
                )
              else
                _readOnlyField(
                  label:
                  "GPS Location",
                  value:
                  "${widget.geometryPoints.length} mapped points",
                ),

              const SizedBox(
                height: 24,
              ),

              // =================================================
              // PHOTOGRAPH
              // =================================================

              _sectionTitle(
                "Photograph",
              ),

              if (photograph !=
                  null) ...[
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
                width:
                double.infinity,

                child:
                OutlinedButton.icon(
                  onPressed:
                  _capturePhoto,

                  icon:
                  const Icon(
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

              // =================================================
              // REMARKS
              // =================================================

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

              // =================================================
              // SUBMIT
              // =================================================

              SizedBox(
                width:
                double.infinity,

                height: 50,

                child:
                ElevatedButton.icon(
                  onPressed:
                  _isSubmitting ? null : _submitForm,

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
                    color:
                    Colors.white,
                  ),

                  label:
                  Text(
                    _isSubmitting ? "Submitting..." : "Submit",
                    style:
                    const TextStyle(
                      color:
                      Colors.white,
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.red.shade700,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
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
          Colors.red.shade800,
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

      decoration:
      InputDecoration(
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