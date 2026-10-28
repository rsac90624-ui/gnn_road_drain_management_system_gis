import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/appconstants.dart';
import 'PreviewNewRoadScreen.dart';

class NewRoadFormScreen extends StatefulWidget {
  final String geometry;
  final double? latitude;
  final double? longitude;
  final List<String> roadAgeCategory;
  final String zoneNo;
  final String? zoneName;
  final String wardNo;
  final String wardName;

  const NewRoadFormScreen({
    super.key,
    required this.geometry,
    required this.latitude,
    required this.longitude,
    required this.roadAgeCategory,
    required this.zoneNo,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
  });

  @override
  State<NewRoadFormScreen> createState() => _NewRoadFormScreenState();
}

class _NewRoadFormScreenState extends State<NewRoadFormScreen> {
  late double? mobLatitude;
  late double? mobLongitude;
  // Main form controllers
  final TextEditingController roadNameController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController conditionController = TextEditingController();
  final TextEditingController yocController = TextEditingController();
  final TextEditingController majorLandController = TextEditingController();
  final TextEditingController zoneNoController = TextEditingController();
  final TextEditingController zoneNameController = TextEditingController();
  final TextEditingController wardNoController = TextEditingController();
  final TextEditingController wardNameController = TextEditingController();
  final TextEditingController ownershipController = TextEditingController();
  final TextEditingController ownClassController = TextEditingController();
  final TextEditingController materialController = TextEditingController();
  final TextEditingController materialCController = TextEditingController();
  final TextEditingController cusController = TextEditingController();
  final TextEditingController rowMeterController = TextEditingController();
  final TextEditingController rowAprController = TextEditingController();
  final TextEditingController carriageWController = TextEditingController();
  // Declare the controller for the remarks text field
  TextEditingController remarksController = TextEditingController();
  final TextEditingController roadLengthController = TextEditingController();

  final TextEditingController medianWidthController = TextEditingController();
  final TextEditingController medianLengthController = TextEditingController();
  final TextEditingController medianGreenedLengthController =
  TextEditingController();
  final TextEditingController medianRemarkController = TextEditingController();
  final TextEditingController roadMarkingRemarkController =
  TextEditingController();

  final TextEditingController footpathWidthController = TextEditingController();
  final TextEditingController footpathPavedLengthController = TextEditingController();
  final TextEditingController footpathGreenedLengthController = TextEditingController();
  final TextEditingController footpathRemarksController = TextEditingController();
  final TextEditingController treesCountController = TextEditingController();

  Map<String, List<String>> dropdownOptions = {};

  String? selectedOwnership;
  String? selectedOwnClass;
  String? selectedCategory;
  String? selectedCondition;
  String? selectedCus;
  bool ownershipLoading = true;

  TextEditingController ownershipOtherController = TextEditingController();
  TextEditingController cusOtherController = TextEditingController();
  String? selectedMaterial;
  String? selectedMaterialClass;

  TextEditingController materialOtherController = TextEditingController();
  TextEditingController materialClassOtherController = TextEditingController();

  TextEditingController ownClassOtherController = TextEditingController();
  TextEditingController categoryOtherController = TextEditingController();

  List<String> ownershipApiList = [];
  List<String> schemeApiList = [];

  final List<String> yesNoOptions = ['Yes', 'No'];

  final List<String> medianTypeOptions = [
    'Raised Median',
    'Painted Median',
    'Barrier Median',
    'Green Median',
    'Concrete Median',
    'Other',
  ];
  final Set<String> selectedMedianTypes = {};
  String? medianPaved = 'No';
  String? medianGreenCover = 'No';
  String? medianToBeGreened = 'No';
  String? medianCondition;
  final List<String> medianConditionOptions = ['Good', 'Average', 'Poor'];
  final List<File> medianPhotos = [];

  String? roadMarking = 'No';
  String? markingAvailable = 'No';
  final List<String> markingTypeOptions = [
    'Center Line',
    'Edge Line',
    'Stop Line',
    'Zebra Crossing',
    'Lane Marking',
    'Arrow Marking',
    'Direction Arrow',
    'Median Marking',
    'Other',
  ];
  final Set<String> selectedMarkingTypes = {};
  String? markingSide;
  final List<String> markingSideOptions = [
    'Left Side',
    'Right Side',
    'Center',
    'Both Sides',
  ];
  final List<File> markingPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  String? footpathSide;
  String? footpathSurfaceMaterial;
  String? footpathCondition;
  String? footpathEncroachment = 'No';
  String? footpathObstruction = 'No';
  final List<File> footpathPhotos = [];
  List<String> materialApiList = [];
  List<String> conditionApiList = [];

  bool _isCapturing = false;

  String? selectedPavementCondition;
  final List<String> pavementConditionOptions = ['Good', 'Fair', 'Poor', 'Very Poor'];



  // Initialize dropdown values in the form
  final List<String> categories = [
    'Collector',
    'Local Street',
    'Arterial',
    'Sub Arterial',
  ];
  final List<String> conditions = ['Good', 'Moderate', 'Poor'];
  final List<String> materials = [
    'Kachcha',
    'Bitumen',
    'Stone',
    'BOE',
    'CC',
    'Interlocking',
    'Other',
  ];
  final List<String> materialClasses = [
    'Kachcha',
    'CC\\Bitumen',
    'STONE',
    'BOE',
    'Interlocking\\CC',
    'Bitumen',
    'CC',
    'Interlocking',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    mobLatitude = widget.latitude;
    mobLongitude = widget.longitude;

    // final String rawZone = widget.zoneName?.trim() ?? "";
    // zoneNameController.text = rawZone;
    //
    // if (rawZone.isNotEmpty) {
    //   final match = RegExp(r'\d+').firstMatch(rawZone);
    //   zoneNoController.text = match != null ? match.group(0)! : rawZone;
    // } else {
    //   zoneNoController.text = "";
    // }

    String computedZoneNo = widget.zoneNo.trim();
    if (computedZoneNo.isNotEmpty) {
      final match = RegExp(r'\d+').firstMatch(computedZoneNo);
      if (match != null) {
        computedZoneNo = match.group(0)!;
      }
    } else if (widget.zoneName != null && widget.zoneName!.isNotEmpty) {
      final match = RegExp(r'\d+').firstMatch(widget.zoneName!);
      if (match != null) {
        computedZoneNo = match.group(0)!;
      } else {
        computedZoneNo = widget.zoneName!.trim();
      }
    }

    zoneNoController.text = computedZoneNo;
    zoneNameController.text = widget.zoneName?.trim() ?? "";

    wardNoController.text = widget.wardNo;
    wardNameController.text = widget.wardName;

    debugPrint("NEW ROAD ZONE NO: ${widget.zoneNo}");
    debugPrint("NEW ROAD ZONE NAME: ${widget.zoneName}");
    debugPrint("NEW ROAD WARD NO: ${widget.wardNo}");
    debugPrint("NEW ROAD WARD NAME: ${widget.wardName}");

    loadDropdowns();
    _handleLostData();

    // ✅ Set default 'No' for all infra fields
    infraFields = {
      'footpath': 'No',
      'pavement_distress': 'No',
      'median': 'No',
      'electric_p': 'No',
      'trees': 'No',
      'toilet': 'No',
      'parking': 'No',
      'signboard': 'No',
      'other': 'No',
      'manhole': 'No',
      'transforme': 'No',
      'rmu': 'No',
      'streetlight': 'No',
      'gov_office': 'No',
      'edu_instit': 'No',
      'bank_atm': 'No',
      'hospital': 'No',
      'stadium': 'No',
      'reli_place': 'No',
      'graveyard': 'No',
      'transport': 'No',
      'road_marking': 'No',
    };
    drain = 'No';
    roadMarking = 'No';
    markingAvailable = 'No';
    footpathEncroachment = 'No';
    footpathObstruction = 'No';
    medianPaved = 'No';
    medianGreenCover = 'No';
    medianToBeGreened = 'No';
    
    // Safety check: ensure no nulls in infraFields
    infraFields.forEach((key, value) {
      if (value == null) {
        infraFields[key] = 'No';
      }
    });
  }

  Future<void> _handleLostData() async {
    final LostDataResponse response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) return;
    if (response.file != null) {
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString('last_picker_type');
      if (!mounted) return;

      setState(() {
        if (type == 'footpath') {
          footpathPhotos.add(File(response.file!.path));
        } else if (type == 'median') {
          medianPhotos.add(File(response.file!.path));
        } else if (type == 'marking') {
          markingPhotos.add(File(response.file!.path));
        }
      });
      await prefs.remove('last_picker_type');
    }
  }

  Future<void> loadDropdowns() async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ??
        prefs.getString('nagarNigam') ??
        prefs.getString('nagar_nigam') ??
        prefs.getString('schema') ??
        '';

    if (nagarNigam.trim().isEmpty) {
      debugPrint("City/Nagar Nigam not found.");
      // setState(() => ownershipLoading = false);
      if (mounted) {
        setState(() => ownershipLoading = false);
      }
      return;
    }

    try {
      String baseUrl = AppConstants.baseURL;
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      final uri = Uri.parse(
        '$baseUrl/api/roads_mobile/dropdowns?nagarNigam=${nagarNigam.trim()}',
      );

      debugPrint("📡 Fetching dropdowns from: $uri");

      final response = await http.get(uri);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("✅ Dropdowns received");

        setState(() {
          dropdownOptions['ownership'] = List<String>.from(data['ownership'] ?? []);
          dropdownOptions['cus'] = List<String>.from(data['cus'] ?? []);
          dropdownOptions['material'] = List<String>.from(data['material'] ?? []);
          dropdownOptions['material_c'] = List<String>.from(data['material_c'] ?? []);
          dropdownOptions['own_class'] = List<String>.from(data['own_class'] ?? []);
          dropdownOptions['category'] = List<String>.from(data['category'] ?? [])
              .map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
          dropdownOptions['condition'] = List<String>.from(data['condition'] ?? []);

          materialApiList = List<String>.from(data['material'] ?? []);
          conditionApiList = List<String>.from(data['condition'] ?? []);

          ownershipLoading = false;
        });
      } else {
        debugPrint("❌ Failed to load dropdowns: ${response.statusCode}");
        // setState(() => ownershipLoading = false);
        if (mounted) {
          setState(() => ownershipLoading = false);
        }
      }
    } catch (e) {
      debugPrint("❌ Dropdown error: $e");
      if (mounted) {
        setState(() => ownershipLoading = false);
      }
    }
  }

  // Dropdown widget
  Widget _dropDownField(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: items.contains(value) ? value : null,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: items.map((e) {
              return DropdownMenuItem(
                value: e,
                child: Text(e, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  final Map<String, String> radioLabelOverrides = {
    'footpath': 'Footpath',
    'pavement_distress': 'Pavement Distress',
    'manhole': 'Manhole',
    'median': 'Median',
    'transforme': 'Transformer',
    'rmu': 'Ring Main Unit',
    'electric_p': 'Electric Pole',
    'trees': 'Trees',
    'toilet': 'Public Toilet',
    'parking': 'Parking',
    'signboard': 'Signboard',
    'other': 'Other',
    'gov_office': 'Government Office',
    'edu_instit': 'Educational Institution',
    'reli_place': 'Religious Place',
    'streetlight': 'Street Solar Light',
    'bank_atm': 'Bank / ATM',
    'hospital': 'Hospital',
    'stadium': 'Stadium',
    'graveyard': 'Graveyard',
    'transport': 'Transport Facility',
    'drain': 'Drain Available',
    'road_marking': 'Road Markings',
  };

  // Radio fields
  final List<String> yesNo = ['Yes', 'No'];
  Map<String, String?> infraFields = {
    'footpath': 'No',
    'pavement_distress': 'No',
    'median': 'No',
    'electric_p': 'No',
    'trees': 'No',
    'toilet': 'No',
    'parking': 'No',
    'signboard': 'No',
    'other': 'No',
    'manhole': 'No',
    'transforme': 'No',
    'rmu': 'No',
    'streetlight': 'No',
    'gov_office': 'No',
    'edu_instit': 'No',
    'bank_atm': 'No',
    'hospital': 'No',
    'stadium': 'No',
    'reli_place': 'No',
    'graveyard': 'No',
    'transport': 'No',
    'road_marking': 'No',
  };

  // Drain fields
  String? drain = 'No';

  // Initialize dropdown values in the form
  String? categoryValue;
  String? conditionValue;
  String? materialValue;
  String? materialClassValue;

  @override
  void dispose() {
    roadNameController.dispose();
    categoryController.dispose();
    conditionController.dispose();
    yocController.dispose();
    majorLandController.dispose();
    zoneNoController.dispose();
    zoneNameController.dispose();
    wardNoController.dispose();
    wardNameController.dispose();
    ownershipController.dispose();
    ownClassController.dispose();
    materialController.dispose();
    materialCController.dispose();
    cusController.dispose();
    rowMeterController.dispose();
    rowAprController.dispose();
    carriageWController.dispose();
    remarksController.dispose();
    roadLengthController.dispose();

    medianWidthController.dispose();
    medianLengthController.dispose();
    medianGreenedLengthController.dispose();
    medianRemarkController.dispose();
    roadMarkingRemarkController.dispose();

    footpathWidthController.dispose();
    footpathPavedLengthController.dispose();
    footpathGreenedLengthController.dispose();
    footpathRemarksController.dispose();
    treesCountController.dispose();
    categoryOtherController.dispose();

    ownershipOtherController.dispose();
    cusOtherController.dispose();
    materialOtherController.dispose();
    materialClassOtherController.dispose();
    ownClassOtherController.dispose();

    super.dispose();
  }


  Future<void> _captureMarkingPhoto() async {
    if (_isCapturing) return;

    if (markingPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Maximum 4 road marking photographs allowed.",
          ),
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);

    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.setString(
        'last_picker_type',
        'marking',
      );

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        markingPhotos.add(File(image.path));
      });
    } catch (e) {
      debugPrint("Road marking photo capture error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Unable to capture road marking photograph: $e",
            ),
          ),
        );
      }
    } finally {
      await prefs.remove('last_picker_type');

      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  // Future<void> _captureMarkingPhoto() async {
  //   if (_isCapturing) return;
  //   if (markingPhotos.length >= 4) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Maximum 4 road marking photographs allowed.")),
  //     );
  //     return;
  //   }
  //   setState(() => _isCapturing = true);
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setString('last_picker_type', 'marking');
  //     final XFile? image = await _imagePicker.pickImage(
  //       source: ImageSource.camera,
  //       imageQuality: 70, // ⬅️ Reduced quality
  //       maxWidth: 1600,   // ⬅️ Limit resolution
  //       maxHeight: 1200,  // ⬅️ Limit resolution
  //     );
  //     if (image == null) {
  //       await prefs.remove('last_picker_type');
  //
  //       if (mounted) {
  //         setState(() => _isCapturing = false);
  //       }
  //       return;
  //     }
  //     await prefs.remove('last_picker_type');
  //
  //     if (!mounted) return;
  //
  //     setState(() {
  //       markingPhotos.add(File(image.path));
  //       _isCapturing = false;
  //     });
  //   } catch (e) {
  //     debugPrint("Photo capture error: $e");
  //     if (!mounted) return;
  //     setState(() => _isCapturing = false);
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Unable to capture photograph: $e")));
  //   }
  // }

  // Future<void> _captureMedianPhoto() async {
  //   if (_isCapturing) return;
  //   if (medianPhotos.length >= 4) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Maximum 4 median photographs allowed.")),
  //     );
  //     return;
  //   }
  //   setState(() => _isCapturing = true);
  //   final prefs = await SharedPreferences.getInstance();
  //
  //   try {
  //     await prefs.setString('last_picker_type', 'median');
  //
  //     final XFile? image = await _imagePicker.pickImage(
  //       source: ImageSource.camera,
  //       imageQuality: 70,
  //       maxWidth: 1600,
  //       maxHeight: 1200,
  //     );
  //
  //     if (image == null) return;
  //
  //     if (!mounted) return;
  //
  //     setState(() {
  //       markingPhotos.add(File(image.path));
  //     });
  //   } catch (e) {
  //     debugPrint("Photo capture error: $e");
  //
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text("Unable to capture photograph: $e"),
  //         ),
  //       );
  //     }
  //   } finally {
  //     await prefs.remove('last_picker_type');
  //
  //     if (mounted) {
  //       setState(() {
  //         _isCapturing = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _captureMedianPhoto() async {
    if (_isCapturing) return;

    if (medianPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Maximum 4 median photographs allowed.",
          ),
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);

    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.setString(
        'last_picker_type',
        'median',
      );

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        medianPhotos.add(File(image.path));
      });
    } catch (e) {
      debugPrint("Median photo capture error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Unable to capture median photograph: $e",
            ),
          ),
        );
      }
    } finally {
      await prefs.remove('last_picker_type');

      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  // Future<void> _captureFootpathPhoto() async {
  //   if (_isCapturing) return;
  //   if (footpathPhotos.length >= 4) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Maximum 4 footpath photographs allowed.")),
  //     );
  //     return;
  //   }
  //   setState(() => _isCapturing = true);
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setString('last_picker_type', 'footpath');
  //     final XFile? image = await _imagePicker.pickImage(
  //       source: ImageSource.camera,
  //       imageQuality: 70, // ⬅️ Reduced quality
  //       maxWidth: 1600,   // ⬅️ Limit resolution
  //       maxHeight: 1200,  // ⬅️ Limit resolution
  //     );
  //     if (image == null) {
  //       setState(() => _isCapturing = false);
  //       return;
  //     }
  //     if (!mounted) return;
  //     setState(() {
  //       footpathPhotos.add(File(image.path));
  //       _isCapturing = false;
  //     });
  //   } catch (e) {
  //     debugPrint("Photo capture error: $e");
  //     if (!mounted) return;
  //     setState(() => _isCapturing = false);
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Unable to capture footpath photograph: $e")));
  //   }
  // }

  Future<void> _captureFootpathPhoto() async {
    if (_isCapturing) return;

    if (footpathPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Maximum 4 footpath photographs allowed.",
          ),
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);

    final prefs = await SharedPreferences.getInstance();

    try {
      await prefs.setString(
        'last_picker_type',
        'footpath',
      );

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        footpathPhotos.add(File(image.path));
      });
    } catch (e) {
      debugPrint("Footpath photo capture error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Unable to capture footpath photograph: $e",
            ),
          ),
        );
      }
    } finally {
      await prefs.remove('last_picker_type');

      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          // ⬅️ Makes default back button white
          color: Colors.white,
        ),
        title: Center(
          child: const Text(
            "Create New Road",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        backgroundColor: Colors.orange.shade700,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _sectionHeader("Road Information"),
            _field("Road Name", roadNameController),
            // _field("Road Name", roadNameController, inputFormatter: camelCaseFormatter),
            _dropDownField("Category", categoryValue, 
                (dropdownOptions['category'] != null && dropdownOptions['category']!.isNotEmpty)
                    ? dropdownOptions['category']!
                    : categories, (val) {
              setState(() {
                categoryValue = val;
              });
            }),

            _dropDownField("Condition", conditionValue, 
                (dropdownOptions['condition'] != null && dropdownOptions['condition']!.isNotEmpty)
                    ? dropdownOptions['condition']!
                    : conditions, (val) {
              setState(() {
                conditionValue = val;
              });
            }),
            _field(
              "Year of Construction",
              yocController,
              type: TextInputType.number,
            ),
            _field("Major Landmark", majorLandController),

            _sectionHeader("Zone / Ward Details"),

            _readOnlyField("Zone No", zoneNoController),
            _readOnlyField("Zone Name", zoneNameController),
            _readOnlyField("Ward No", wardNoController),
            _readOnlyField("Ward Name", wardNameController),

            _sectionHeader("Ownership"),

            // 🔹 OWNERSHIP DROPDOWN
            ownershipLoading
                ? const CircularProgressIndicator()
                : _dropDownField(
                    "Ownership",
                    selectedOwnership,
                    (dropdownOptions['ownership'] != null && dropdownOptions['ownership']!.isNotEmpty)
                        ? dropdownOptions['ownership']!
                        : ['Nagar Nigam', 'PWD', 'MDA', 'Awas Vikas', 'Other'],
                    (val) {
                      setState(() {
                        selectedOwnership = val;
                      });
                    },
                  ),

            // 🔹 SHOW TEXTFIELD IF OTHER
            if (selectedOwnership == "Other")
              _field("Enter Ownership", ownershipOtherController),

            // 🔹 OWNERSHIP CLASS (STATIC or API later)
            _dropDownField(
              "Ownership Class",
              selectedOwnClass,
              dropdownOptions['own_class'] ?? [],
                  (val) {
                setState(() {
                  selectedOwnClass = val;
                });
              },
            ),
            if (selectedOwnClass == 'Other')
              _field("Enter Ownership Class ", ownClassOtherController),


            // _sectionHeader("Material / Construction"),
            // _field("Material", materialController),
            // _field("Material Class", materialCController),
            _sectionHeader("Material / Construction"),
            _dropDownField(
              "Material",
              selectedMaterial,
              (dropdownOptions['material'] != null && dropdownOptions['material']!.isNotEmpty)
                  ? dropdownOptions['material']!
                  : materials,
                  (val) {
                setState(() {
                  selectedMaterial = val;
                });
              },
            ),
            if (selectedMaterial == "Other")
              _field("Enter Material", materialOtherController),
            _dropDownField(
              "Material Class",
              selectedMaterialClass,
              (dropdownOptions['material_c'] != null && dropdownOptions['material_c']!.isNotEmpty)
                  ? dropdownOptions['material_c']!
                  : materialClasses,
                  (val) {
                setState(() {
                  selectedMaterialClass = val;
                });
              },
            ),
            if (selectedMaterialClass == "Other")
              _field("Enter Material Class", materialClassOtherController),
            _dropDownField(
              "Construction Under Scheme",
              selectedCus,
              dropdownOptions['cus'] ?? [],
                  (val) {
                setState(() {
                  selectedCus = val;
                });
              },
            ),

            if (selectedCus == "Other")
              _field("Enter Scheme", cusOtherController),
            _field(
              "Right Of Way Meter",
              rowMeterController,
              type: TextInputType.number,
            ),
            _field(
              "Right Of Way Approx",
              rowAprController,
              type: TextInputType.number,
            ),
            _field(
              "Carriage Width",
              carriageWController,
              type: TextInputType.number,
            ),
            _field(
              "Road Length (in meters)",
              roadLengthController,
              type: TextInputType.number,
            ),

            _sectionHeader("Infrastructure Facilities"),
            // ...infraFields.keys.map(
            //   (key) => _radioRow(key, infraFields[key], (v) {
            //     setState(() => infraFields[key] = v);
            //   }),
            // ),

            ...infraFields.keys.map(
                  (key) {
                return Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    _radioRow(
                      key,
                      infraFields[key],
                          (v) {
                        setState(() {
                          infraFields[key] = v;
                          if (key == 'road_marking') {
                            roadMarking = v;
                          }
                        });
                      },
                    ),

                    if (key == 'pavement_distress' && infraFields['pavement_distress'] == 'Yes')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: DropdownButtonFormField<String>(
                          value: selectedPavementCondition,
                          decoration: InputDecoration(
                            labelText: "Pavement Condition",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: pavementConditionOptions.map((String val) {
                            return DropdownMenuItem<String>(
                              value: val,
                              child: Text(val),
                            );
                          }).toList(),
                          onChanged: (String? val) {
                            setState(() {
                              selectedPavementCondition = val;
                            });
                          },
                        ),
                      ),

                    if (key == 'trees' && infraFields['trees'] == 'Yes')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: treesCountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Count of Trees",
                            hintText: "Enter number of trees",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                    if (key == 'footpath' &&
                        infraFields['footpath'] == 'Yes')
                      _buildFootpathSection(),

                    if (key == 'median' &&
                        infraFields['median'] == 'Yes')
                      _buildMedianSection(),

                    if (key == 'road_marking' &&
                        infraFields['road_marking'] == 'Yes')
                      _buildRoadMarkingSection(),
                  ],
                );
              },
            ),

            _sectionHeader("Drain Details"),
            _radioRow(
              "Drain Available",
              drain,
              (v) => setState(() => drain = v),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: remarksController, // Using the remarksController
              maxLines: 3, // Allow multiple lines if needed
              decoration: const InputDecoration(
                labelText: "Remarks",
                border: OutlineInputBorder(),
                hintText: "Add any additional remarks here...",
              ),
            ),

            const SizedBox(height: 25),

            Center(
              child: SizedBox(
                width: 220, // ⬅️ Increase width here
                height: 55, // ⬅️ Increase height here
                child: ElevatedButton(
                  onPressed: _openPreview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Preview Road",
                    style: TextStyle(
                      fontSize: 18, // ⬅️ Bigger text
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =======================================================
  // UI COMPONENTS (KANPUR STYLE)
  // =======================================================

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: c,
            keyboardType: type,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyField(
      String label,
      TextEditingController controller,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          floatingLabelBehavior: FloatingLabelBehavior.always,

          filled: true,
          fillColor: const Color(0xFFF0F0F0),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(
              color: Colors.grey,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(
              color: Colors.grey,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(
              color: Colors.grey,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _radioRow(String name, String? value, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            radioLabelOverrides[name] ??
                name.replaceAll("_", " ").toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),

          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text("Yes"),
                  value: "Yes",
                  groupValue: value,
                  onChanged: (v) {
                    onChanged(v);
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text("No"),
                  value: "No",
                  groupValue: value,
                  onChanged: (v) {
                    onChanged(v);
                    setState(() {
                      if (name == 'footpath') {
                        footpathSide = null;
                        footpathWidthController.clear();
                        footpathSurfaceMaterial = null;
                        footpathCondition = null;
                        footpathPavedLengthController.clear();
                        footpathGreenedLengthController.clear();
                        footpathEncroachment = 'No';
                        footpathObstruction = 'No';
                        footpathPhotos.clear();
                        footpathRemarksController.clear();
                      }
                      if (name == 'median') {
                        selectedMedianTypes.clear();
                        medianWidthController.clear();
                        medianLengthController.clear();
                        medianGreenedLengthController.clear();
                        medianRemarkController.clear();
                        medianPaved = 'No';
                        medianGreenCover = 'No';
                        medianToBeGreened = 'No';
                        medianCondition = null;
                        medianPhotos.clear();
                      }
                      if (name == 'trees') {
                        treesCountController.clear();
                      }
                      if (name == 'pavement_distress') {
                        selectedPavementCondition = null;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drop({
    required String label,
    required String? value,
    required List<String> items,
    required bool enabled,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: items.contains(value) ? value : null,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: items
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFootpathSection() {
    return Container(
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Footpath Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: footpathSide,
            decoration: const InputDecoration(
              labelText: 'Footpath Side',
              border: OutlineInputBorder(),
            ),
            items: ['Left', 'Right', 'Both'].map((side) {
              return DropdownMenuItem<String>(
                value: side,
                child: Text(side),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                footpathSide = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _field(
            "Width (m)",
            footpathWidthController,
            type: const TextInputType.numberWithOptions(decimal: true),
          ),
          _dropDownField(
            "Surface Material",
            footpathSurfaceMaterial,
            materialApiList,
            (val) {
              setState(() {
                footpathSurfaceMaterial = val;
              });
            },
          ),
          const SizedBox(height: 10),
          _dropDownField(
            "Condition",
            footpathCondition,
            conditionApiList,
            (val) {
              setState(() {
                footpathCondition = val;
              });
            },
          ),
          const SizedBox(height: 10),
          _field(
            "Paved Length (m)",
            footpathPavedLengthController,
            type: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            "Greened Length (m)",
            footpathGreenedLengthController,
            type: const TextInputType.numberWithOptions(decimal: true),
          ),
          _radioRow(
            'footpath_encroachment',
            footpathEncroachment,
            (val) => setState(() => footpathEncroachment = val),
          ),
          _radioRow(
            'footpath_obstruction',
            footpathObstruction,
            (val) => setState(() => footpathObstruction = val),
          ),
          const SizedBox(height: 14),
          const Text(
            'Footpath Photograph',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (footpathPhotos.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: footpathPhotos.asMap().entries.map((entry) {
                final index = entry.key;
                final photo = entry.value;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        photo,
                        height: 120,
                        width: 120,
                        cacheWidth: 300, // ⬅️ REDUCE MEMORY
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            footpathPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton.icon(
            onPressed: (footpathPhotos.length < 4 && !_isCapturing) ? _captureFootpathPhoto : null,
            icon: _isCapturing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt),
            label: Text(_isCapturing ? "Opening Camera..." : "Add Footpath Photograph (${footpathPhotos.length}/4)"),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: footpathRemarksController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Footpath Remarks',
              hintText: 'Enter footpath remarks',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedianSection() {
    return Container(
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Median Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Median Type',
              border: OutlineInputBorder(),
            ),
            child: InkWell(
              onTap: () {
                _showMedianTypeDialog();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedMedianTypes.isEmpty
                            ? 'Select Median Type'
                            : selectedMedianTypes.join(', '),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: medianWidthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Width (m)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: medianLengthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Length (m)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _radioRow('median_paved', medianPaved, (value) {
            setState(() {
              medianPaved = value;
            });
          }),
          _radioRow('median_green_cover', medianGreenCover, (value) {
            setState(() {
              medianGreenCover = value;
            });
          }),
          const SizedBox(height: 10),
          TextFormField(
            controller: medianGreenedLengthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Greened Length (m)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _radioRow(
            'median_to_be_greened',
            medianToBeGreened,
            (value) {
              setState(() {
                medianToBeGreened = value;
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: medianConditionOptions.contains(medianCondition)
                ? medianCondition
                : null,
            decoration: const InputDecoration(
              labelText: 'Condition',
              border: OutlineInputBorder(),
            ),
            items: medianConditionOptions.map((condition) {
              return DropdownMenuItem<String>(
                value: condition,
                child: Text(condition),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                medianCondition = value;
              });
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'Median Photograph',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (medianPhotos.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: medianPhotos.asMap().entries.map((entry) {
                final index = entry.key;
                final photo = entry.value;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        photo,
                        height: 120,
                        width: 120,
                        cacheWidth: 300, // ⬅️ REDUCE MEMORY
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            medianPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton.icon(
            onPressed: (medianPhotos.length < 4 && !_isCapturing) ? _captureMedianPhoto : null,
            icon: _isCapturing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt),
            label: Text(_isCapturing ? "Opening Camera..." : "Add Median Photograph (${medianPhotos.length}/4)"),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: medianRemarkController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Median Remark',
              hintText: 'Enter median remark',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadMarkingSection() {
    return Container(
      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Road Marking Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 12),
          const Text(
            "Marking Type",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 5),
          ...markingTypeOptions.map((type) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(type),
              value: selectedMarkingTypes.contains(type),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (bool? checked) {
                setState(() {
                  if (checked == true) {
                    selectedMarkingTypes.add(type);
                  } else {
                    selectedMarkingTypes.remove(type);
                  }
                });
              },
            );
          }),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: markingSide,
            decoration: const InputDecoration(
              labelText: 'Location / Side',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            items: markingSideOptions.map((side) {
              return DropdownMenuItem<String>(
                value: side,
                child: Text(side),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                markingSide = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: roadMarkingRemarkController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Road Marking Remark',
              hintText: 'Enter road marking remark',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          _radioRow(
            'marking_available',
            markingAvailable,
            (val) => setState(() => markingAvailable = val),
          ),
          const SizedBox(height: 10),
          const Text(
            "Road Marking Photograph",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (markingPhotos.isNotEmpty) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: markingPhotos.asMap().entries.map((entry) {
                final index = entry.key;
                final photo = entry.value;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        photo,
                        height: 120,
                        width: 120,
                        cacheWidth: 300, // ⬅️ REDUCE MEMORY
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            markingPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton.icon(
            onPressed: (markingPhotos.length < 4 && !_isCapturing) ? _captureMarkingPhoto : null,
            icon: _isCapturing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt),
            label: Text(_isCapturing ? "Opening Camera..." : "Add Photograph (${markingPhotos.length}/4)"),
          ),
        ],
      ),
    );
  }

  Future<void> _showMedianTypeDialog() async {
    final Set<String> tempSelected = Set<String>.from(selectedMedianTypes);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Median Type'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: medianTypeOptions.map((type) {
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(type),
                      value: tempSelected.contains(type),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            tempSelected.add(type);
                          } else {
                            tempSelected.remove(type);
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
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedMedianTypes
                        ..clear()
                        ..addAll(tempSelected);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openPreview() {
    final body = {
      "geomWKT": widget.geometry,

      "mob_latitu": mobLatitude,
      "mob_longit": mobLongitude,

      "roadName": roadNameController.text,

      "zoneNo": zoneNoController.text,
      "zone_no": zoneNoController.text,
      "zoneName": zoneNameController.text,
      "wardNo": wardNoController.text,
      "wardName": wardNameController.text,

      "category": categoryValue == 'Other'
          ? categoryOtherController.text.trim()
          : categoryValue,

      "condition": conditionValue,

      "yoc": int.tryParse(
        yocController.text,
      ) ??
          0,

      "major_land":
      majorLandController.text,

      "ownership":
      selectedOwnership == "Other"
          ? ownershipOtherController.text.trim()
          : selectedOwnership,

      "own_class":
      selectedOwnClass == 'Other'
          ? ownClassOtherController.text.trim()
          : selectedOwnClass,

      "cus":
      (selectedCus == "Other" ||
          selectedCus == "Others")
          ? cusOtherController.text.trim()
          : selectedCus,

      "material":
      selectedMaterial == "Other"
          ? materialOtherController.text.trim()
          : selectedMaterial,

      "material_c":
      selectedMaterialClass == "Other"
          ? materialClassOtherController.text.trim()
          : selectedMaterialClass,

      "row_meter":
      rowMeterController.text,

      "row_apr":
      rowAprController.text,

      "carriage_w":
      carriageWController.text,

      "drain":
      drain,

      "length_met":
      roadLengthController.text,

      "remark":
      remarksController.text,

      "footpath": infraFields['footpath'],
      "fothpath": infraFields['footpath'],
      "toilet": infraFields['toilet'],
      "public_toilet": infraFields['toilet'],
      "parking": infraFields['parking'],
      "park": infraFields['parking'],
      "signboard": infraFields['signboard'],
      "other": infraFields['other'],
      "streetlight": infraFields['streetlight'],
      "street__so": infraFields['streetlight'],
      "strt_slr_l": infraFields['streetlight'],
      "gov_office": infraFields['gov_office'],
      "government": infraFields['gov_office'],
      "edu_instit": infraFields['edu_instit'],
      "educationa": infraFields['edu_instit'],
      "reli_place": infraFields['reli_place'],
      "religious": infraFields['reli_place'],
      "transforme": infraFields['transforme'],
      "transformer": infraFields['transforme'],
      "transport": infraFields['transport'],

      ...infraFields,
      "trees_count": treesCountController.text.trim(),
      "pavement_condition": selectedPavementCondition,


      // ==========================================================
      // FOOTPATH
      // ==========================================================

      "footpath_side":
      footpathSide,

      "footpath_width":
      double.tryParse(
        footpathWidthController.text.trim(),
      ),

      "footpath_surface_material":
      footpathSurfaceMaterial,

      "footpath_condition":
      footpathCondition,

      "footpath_paved_length":
      double.tryParse(
        footpathPavedLengthController.text.trim(),
      ),

      "footpath_greened_length":
      double.tryParse(
        footpathGreenedLengthController.text.trim(),
      ),

      "footpath_encroachment":
      footpathEncroachment,

      "footpath_obstruction":
      footpathObstruction,

      "footpath_remarks":
      footpathRemarksController.text.trim(),

      "footpath_photos":
      footpathPhotos
          .map((photo) => photo.path)
          .toList(),

      // ==========================================================
      // MEDIAN
      // ==========================================================

      "median_type":
      selectedMedianTypes.toList(),

      "median_width":
      double.tryParse(
        medianWidthController.text.trim(),
      ),

      "median_length":
      double.tryParse(
        medianLengthController.text.trim(),
      ),

      "median_paved":
      medianPaved,

      "median_green_cover":
      medianGreenCover,

      "median_greened_length":
      double.tryParse(
        medianGreenedLengthController.text.trim(),
      ),

      "median_to_be_greened":
      medianToBeGreened,

      "median_condition":
      medianCondition,

      "median_remark":
      medianRemarkController.text.trim(),

      "median_photos":
      medianPhotos
          .map((photo) => photo.path)
          .toList(),

      // ==========================================================
      // ROAD MARKING
      // ==========================================================

      "road_marking":
      roadMarking,

      "marking_type":
      selectedMarkingTypes.toList(),

      "marking_side":
      markingSide,

      "marking_available":
      markingAvailable,

      "road_marking_remark":
      roadMarkingRemarkController.text.trim(),

      "marking_photos":
      markingPhotos
          .map((photo) => photo.path)
          .toList(),
    };


    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PreviewNewRoadScreen(
              data: body,
              roadAgeCategory:
              widget.roadAgeCategory,
              zoneName:
              widget.zoneName,
              wardNo:
              widget.wardNo,
              wardName:
              widget.wardName,
            ),
      ),
    );
  }

  // void _openPreview() {
  //   final body = {
  //     "geomWKT": widget.geometry,
  //     "mob_latitu": mobLatitude,
  //     "mob_longit": mobLongitude,
  //     "roadName": roadNameController.text,
  //     "zoneNo": zoneNoController.text,
  //     "zoneName": zoneNameController.text,
  //     "wardNo": wardNoController.text,
  //     "wardName": wardNameController.text,
  //     "category": categoryValue == 'Other'
  //         ? categoryOtherController.text.trim()
  //         : categoryValue,
  //     "condition": conditionValue,
  //     "yoc": int.tryParse(yocController.text) ?? 0,
  //     "major_land": majorLandController.text,
  //     "ownership": selectedOwnership == "Other"
  //         ? ownershipOtherController.text.trim()
  //         : selectedOwnership,
  //     "own_class": selectedOwnClass == 'Other'
  //         ? ownClassOtherController.text.trim()
  //         : selectedOwnClass,
  //     "cus": (selectedCus == "Other" || selectedCus == "Others")
  //         ? cusOtherController.text.trim()
  //         : selectedCus,
  //     "material": selectedMaterial == "Other"
  //         ? materialOtherController.text.trim()
  //         : selectedMaterial,
  //     "material_c": selectedMaterialClass == "Other"
  //         ? materialClassOtherController.text.trim()
  //         : selectedMaterialClass,
  //     "row_meter": rowMeterController.text,
  //     "row_apr": rowAprController.text,
  //     "carriage_w": carriageWController.text,
  //     "drain": drain,
  //     "length_met": roadLengthController.text,
  //     "remark": remarksController.text,
  //     ...infraFields,
  //   };
  //
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => PreviewNewRoadScreen(
  //         data: body,
  //         roadAgeCategory:
  //             widget.roadAgeCategory, // Pass the required parameters
  //         zoneName: widget.zoneName,
  //         wardNo: widget.wardNo,
  //         wardName: widget.wardName,
  //       ),
  //     ),
  //   );
  // }
}
