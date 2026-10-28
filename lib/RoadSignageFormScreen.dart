import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/appconstants.dart';

class RoadSignageFormScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? zoneName;
  final String wardNo;
  final String wardName;

  const RoadSignageFormScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
  });

  @override
  State<RoadSignageFormScreen> createState() =>
      _RoadSignageFormScreenState();
}

class _RoadSignageFormScreenState
    extends State<RoadSignageFormScreen> {
  bool _isSubmitting = false;

  // ================================
  // MULTI SELECT VALUES
  // ================================

  final Set<String> selectedSignTypes = {};
  final Set<String> selectedSignCategories = {};
  final Set<String> selectedSignSides = {};

  // ================================
  // SINGLE SELECT VALUES
  // ================================

  String? condition;
  String? visibility;
  String? reflective;
  String? poleCondition;

  // ================================
  // REMARK
  // ================================

  final TextEditingController remarkController =
  TextEditingController();

  // ================================
  // PHOTOGRAPH
  // ================================

  final ImagePicker _imagePicker = ImagePicker();

  File? signagePhoto;
  bool _isCapturing = false;

  // ================================
  // DROPDOWN DATA
  // ================================

  final List<String> signTypes = [
    'Speed Limit',
    'No Parking',
    'School Ahead',
    'Hospital',
    'Advertisement Board'
  ];

  final List<String> signCategories = [
    'Mandatory',
    'Cautionary',
    'Informatory',
    'Direction',
    'Regulatory',
    'Other',
  ];

  final List<String> signSides = [
    'Left',
    'Right',
    'Median',
    'Both Side',
  ];

  final List<String> conditions = [
    'Good',
    'Average',
    'Poor',
    'Damaged',
  ];

  final List<String> poleConditions = [
    'Good',
    'Rusty',
    'Bent',
    'Damaged',
    'Missing',
    'Not Applicable',
  ];

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
        signagePhoto = File(response.file!.path);
      });
    }
  }

  @override
  void dispose() {
    remarkController.dispose();
    super.dispose();
  }

  // ===============================================================
  // MULTI SELECT DIALOG
  // ===============================================================

  Future<void> _showMultiSelectDialog({
    required String title,
    required List<String> options,
    required Set<String> selectedValues,
  }) async {
    final Set<String> tempSelection =
    Set<String>.from(selectedValues);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),

              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((item) {
                    return CheckboxListTile(
                      title: Text(item),
                      value:
                      tempSelection.contains(item),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelection.add(item);
                          } else {
                            tempSelection.remove(item);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedValues
                        ..clear()
                        ..addAll(tempSelection);
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===============================================================
  // MULTI SELECT FIELD
  // ===============================================================

  Widget _multiSelectField({
    required String label,
    required List<String> options,
    required Set<String> selectedValues,
  }) {
    return InkWell(
      onTap: () {
        _showMultiSelectDialog(
          title: label,
          options: options,
          selectedValues: selectedValues,
        );
      },

      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon:
          const Icon(Icons.arrow_drop_down),
        ),

        child: Text(
          selectedValues.isEmpty
              ? "Select $label"
              : selectedValues.join(", "),
          style: TextStyle(
            color: selectedValues.isEmpty
                ? Colors.grey.shade600
                : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // PHOTO
  // ===============================================================

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
        signagePhoto = File(image.path);
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

  // ===============================================================
  // SUBMIT
  // ===============================================================

  Future<void> _submitForm() async {
    if (selectedSignTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one Sign Type")),
      );
      return;
    }

    if (signagePhoto == null) {
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

      final url = Uri.parse('${AppConstants.baseURL}api/road-signage/create');

      final request = http.MultipartRequest('POST', url);

      // Add headers
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['X-User'] = username;

      // Add text fields
      request.fields['nagarNigam'] = nagarNigam;
      request.fields['zoneName'] = widget.zoneName ?? "";
      request.fields['wardNo'] = widget.wardNo;
      request.fields['wardName'] = widget.wardName;
      request.fields['latitude'] = widget.latitude.toString();
      request.fields['longitude'] = widget.longitude.toString();
      request.fields['signType'] = selectedSignTypes.join(", ");
      request.fields['signCategory'] = selectedSignCategories.join(", ");
      request.fields['signSide'] = selectedSignSides.join(", ");
      request.fields['condition'] = condition ?? "";
      request.fields['visibility'] = visibility ?? "";
      request.fields['reflective'] = reflective ?? "";
      request.fields['poleCondition'] = poleCondition ?? "";
      request.fields['remarks'] = remarkController.text.trim();
      request.fields['createdBy'] = username;

      // Add image
      request.files.add(
        await http.MultipartFile.fromPath(
          'photograph',
          signagePhoto!.path,
        ),
      );

      debugPrint("📡 SUBMITTING ROAD SIGNAGE TO: $url");
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
            content: const Text("Road signage details saved successfully."),
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

  // ===============================================================
  // UI
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text("Road Signage Survey"),
        backgroundColor:
        Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,

          children: [
            // ================================
            // BASIC DETAILS
            // ================================

            const Text(
              "Basic Details",
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),



            _infoTile(
              "Zone",
              widget.zoneName ?? "N/A",
            ),

            _infoTile(
              "Ward No",
              widget.wardNo,
            ),

            _infoTile(
              "Ward Name",
              widget.wardName,
            ),

            _infoTile(
              "Latitude",
              widget.latitude.toStringAsFixed(6),
            ),

            _infoTile(
              "Longitude",
              widget.longitude.toStringAsFixed(6),
            ),

            const SizedBox(height: 20),

            // ================================
            // SIGN TYPE
            // ================================

            _multiSelectField(
              label: "Sign Type",
              options: signTypes,
              selectedValues:
              selectedSignTypes,
            ),

            const SizedBox(height: 15),

            // ================================
            // SIGN CATEGORY
            // ================================

            _multiSelectField(
              label: "Sign Category",
              options: signCategories,
              selectedValues:
              selectedSignCategories,
            ),

            const SizedBox(height: 15),

            // ================================
            // SIGN SIDE
            // ================================

            _multiSelectField(
              label: "Sign Side",
              options: signSides,
              selectedValues:
              selectedSignSides,
            ),

            const SizedBox(height: 15),

            // ================================
            // CONDITION
            // ================================

            DropdownButtonFormField<String>(
              value: condition,
              decoration:
              const InputDecoration(
                labelText: "Condition",
                border:
                OutlineInputBorder(),
              ),

              items: conditions.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item),
                );
              }).toList(),

              onChanged: (value) {
                setState(() {
                  condition = value;
                });
              },
            ),

            const SizedBox(height: 15),

            // ================================
            // VISIBILITY
            // ================================

            DropdownButtonFormField<String>(
              value: visibility,
              decoration:
              const InputDecoration(
                labelText: "Visibility",
                border:
                OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: "Yes",
                  child: Text("Yes"),
                ),
                DropdownMenuItem(
                  value: "No",
                  child: Text("No"),
                ),
              ],

              onChanged: (value) {
                setState(() {
                  visibility = value;
                });
              },
            ),

            const SizedBox(height: 15),

            // ================================
            // REFLECTIVE
            // ================================

            DropdownButtonFormField<String>(
              value: reflective,
              decoration:
              const InputDecoration(
                labelText: "Reflective",
                border:
                OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: "Yes",
                  child: Text("Yes"),
                ),
                DropdownMenuItem(
                  value: "No",
                  child: Text("No"),
                ),
              ],

              onChanged: (value) {
                setState(() {
                  reflective = value;
                });
              },
            ),

            const SizedBox(height: 15),

            // ================================
            // POLE CONDITION
            // ================================

            DropdownButtonFormField<String>(
              value: poleCondition,
              decoration:
              const InputDecoration(
                labelText: "Pole Condition",
                border:
                OutlineInputBorder(),
              ),

              items:
              poleConditions.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item),
                );
              }).toList(),

              onChanged: (value) {
                setState(() {
                  poleCondition = value;
                });
              },
            ),

            const SizedBox(height: 20),

            // ================================
            // PHOTOGRAPH
            // ================================

            const Text(
              "Photograph",
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            if (signagePhoto != null)
              ClipRRect(
                borderRadius:
                BorderRadius.circular(10),
                child: Image.file(
                  signagePhoto!,
                  height: 180,
                  width: double.infinity,
                  cacheWidth: 300,
                  fit: BoxFit.cover,
                ),
              ),

            if (signagePhoto != null)
              const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: _capturePhoto,
              icon:
              const Icon(Icons.camera_alt),
              label: Text(
                signagePhoto == null
                    ? "Capture Photograph"
                    : "Retake Photograph",
              ),
            ),

            const SizedBox(height: 20),

            // ================================
            // REMARKS
            // ================================

            TextField(
              controller:
              remarkController,
              maxLines: 3,
              decoration:
              const InputDecoration(
                labelText: "Remarks",
                hintText:
                "Enter remarks...",
                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            // ================================
            // SUBMIT
            // ================================

            ElevatedButton.icon(
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
                  : const Icon(Icons.save),
              label: Text(
                _isSubmitting ? "Submitting..." : "Submit Road Signage",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(
      String label,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}