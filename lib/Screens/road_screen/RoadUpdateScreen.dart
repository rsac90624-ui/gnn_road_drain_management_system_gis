import 'dart:convert';
import 'dart:io';

import 'package:all_nagar_nigam_road_dir/Screens/road_screen/preview_road_update_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/appconstants.dart';

class RoadUpdateScreen extends StatefulWidget {
  final Map<String, dynamic> roadData;
  final double? latitude;
  final double? longitude;
  final List<String> roadAgeCategory;
  final String? zoneName;
  final String wardNo;
  final String wardName;
  final List<String> ownershipList;
  final Map<String, dynamic>? initialFormData;

  const RoadUpdateScreen({
    super.key,
    required this.roadData,
    required this.latitude,
    required this.longitude,
    required this.roadAgeCategory,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
    required this.ownershipList,
    this.initialFormData,
  });

  @override
  State<RoadUpdateScreen> createState() => _RoadUpdateScreenState();
}

class _RoadUpdateScreenState extends State<RoadUpdateScreen> {
  late double? mobLatitude;
  late double? mobLongitude;
  late TextEditingController roadIdController;
  late TextEditingController roadNameController;
  // late TextEditingController categoryController;
  // late TextEditingController conditionController;
  late TextEditingController yocController;
  late TextEditingController majorLandController;
  late TextEditingController roadlengthController;
  late TextEditingController roadrowController;

  // late TextEditingController parkNameController;
  // late TextEditingController parkOwnershipController;

  // Declare the controller for the remarks text field
  TextEditingController remarksController = TextEditingController();

  TextEditingController ownershipOtherController = TextEditingController();
  TextEditingController materialOtherController = TextEditingController();
  TextEditingController materialClassOtherController = TextEditingController();
  TextEditingController cusOtherController = TextEditingController();
  TextEditingController categoryOtherController = TextEditingController();

  // New state variables for Manhole Type (Sewer or Storm Water)
  // String? manholeType;

  final List<String> yesNoOptions = ['Yes', 'No'];
  String? drain;

  final List<String> medianTypeOptions = [
    'Raised Median',
    'Painted Median',
    'Barrier Median',
    'Green Median',
    'Concrete Median',
    'Other',
  ];

  final Set<String> selectedMedianTypes = {};

  String? medianPaved;
  String? medianGreenCover;
  String? medianToBeGreened;
  String? medianCondition;

  final List<String> medianConditionOptions = ['Good', 'Average', 'Poor'];

  final TextEditingController medianWidthController = TextEditingController();

  final TextEditingController medianLengthController = TextEditingController();

  final TextEditingController medianGreenedLengthController =
      TextEditingController();

  final TextEditingController medianRemarkController = TextEditingController();

  final List<File> medianPhotos = [];
  // final ImagePicker _medianImagePicker = ImagePicker();

  String? roadMarking;
  String? markingAvailable;

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

  final TextEditingController roadMarkingRemarkController =
      TextEditingController();

  final List<File> markingPhotos = [];
  final ImagePicker _imagePicker = ImagePicker();

  bool _isCapturing = false;

  String? footpathSide;
  final TextEditingController footpathWidthController = TextEditingController();
  String? footpathSurfaceMaterial;
  String? footpathCondition;
  final TextEditingController footpathPavedLengthController =
      TextEditingController();
  final TextEditingController footpathGreenedLengthController =
      TextEditingController();
  String? footpathEncroachment;
  String? footpathObstruction;
  final List<File> footpathPhotos = [];
  final TextEditingController footpathRemarksController =
      TextEditingController();
  final TextEditingController treesCountController = TextEditingController();

  List<String> ownershipApiList = [];
  List<String> materialApiList = [];
  List<String> materialClassApiList = [];
  List<String> schemeApiList = [];
  List<String> categoryApiList = [];
  List<String> conditionApiList = [];

  String? selectedPavementCondition;
  final List<String> pavementConditionOptions = [
    'Good',
    'Fair',
    'Poor',
    'Very Poor',
  ];

  bool ownershipLoading = true;
  String? selectedCus;

  // text field attributes
  late Map<String, String?> textFields;
  final Map<String, TextEditingController> dynamicControllers = {};

  // yes/no radio fields
  late Map<String, String?> infraFields;

  final Map<String, List<String>> dropdownOptions = {};

  Future<void> loadDropdowns() async {
    final prefs = await SharedPreferences.getInstance();
    final nagarNigam = prefs.getString('city') ?? prefs.getString('nagarNigam');

    if (nagarNigam == null || nagarNigam.trim().isEmpty) {
      throw Exception("City/Nagar Nigam not found. Please login again.");
    }
    try {
      final url = Uri.parse(
        "${AppConstants.baseURL}api/roads_mobile/dropdowns",
      ).replace(queryParameters: {"nagarNigam": nagarNigam.trim()});

      debugPrint("🔥 Dropdown API calling...");

      final response = await http.get(url);
      if (!mounted) return;
      debugPrint("🔥 Dropdown response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("STATUS: ${response.statusCode}");
        debugPrint("BODY: ${response.body}");

        setState(() {
          ownershipApiList = List<String>.from(data['ownership'] ?? []);
          materialApiList = List<String>.from(data['material'] ?? []);
          materialClassApiList = List<String>.from(data['material_c'] ?? []);

          schemeApiList = List<String>.from(data['cus'] ?? []);

          categoryApiList = List<String>.from(
            data['category'] ?? [],
          ).map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();

          if (!categoryApiList.contains('Service Road')) {
            categoryApiList.add('Service Road');
          }

          if (!categoryApiList.contains('Other')) {
            categoryApiList.add('Other');
          }

          conditionApiList = List<String>.from(data['condition'] ?? []);

          dropdownOptions['ownership'] = ownershipApiList;
          dropdownOptions['material'] = materialApiList;
          dropdownOptions['material_c'] = materialClassApiList;

          dropdownOptions['cus'] = schemeApiList;
          dropdownOptions['category'] = categoryApiList;
          dropdownOptions['condition'] = conditionApiList;

          ownershipLoading = false;
        });
      } else {
        ownershipLoading = false;
      }
    } catch (e) {
      debugPrint("Dropdown error: $e");
      if (mounted) {
        setState(() {
          ownershipLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final d = widget.roadData;

    final existingMedianTypes = d['median_type'];

    if (existingMedianTypes is List) {
      selectedMedianTypes.addAll(existingMedianTypes.map((e) => e.toString()));
    } else if (existingMedianTypes is String &&
        existingMedianTypes.trim().isNotEmpty) {
      selectedMedianTypes.addAll(
        existingMedianTypes
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    medianWidthController.text = d['median_width']?.toString() ?? '';

    medianLengthController.text = d['median_length']?.toString() ?? '';

    medianPaved = d['median_paved']?.toString() ?? 'No';

    medianGreenCover = d['median_green_cover']?.toString() ?? 'No';

    medianGreenedLengthController.text =
        d['median_greened_length']?.toString() ?? '';

    medianToBeGreened = d['median_to_be_greened']?.toString() ?? 'No';

    medianCondition = d['median_condition']?.toString();

    medianRemarkController.text = d['median_remark']?.toString() ?? '';

    footpathSide = d['footpath_side']?.toString();
    footpathWidthController.text = d['footpath_width']?.toString() ?? '';
    footpathSurfaceMaterial = d['footpath_surface_material']?.toString();
    footpathCondition = d['footpath_condition']?.toString();
    footpathPavedLengthController.text =
        d['footpath_paved_length']?.toString() ?? '';
    footpathGreenedLengthController.text =
        d['footpath_greened_length']?.toString() ?? '';
    footpathEncroachment = d['footpath_encroachment']?.toString() ?? 'No';
    footpathObstruction = d['footpath_obstruction']?.toString() ?? 'No';
    footpathRemarksController.text = d['footpath_remarks']?.toString() ?? '';

    mobLatitude = widget.latitude;
    mobLongitude = widget.longitude;
    remarksController = TextEditingController(
      text: widget.roadData['remark'] ?? '',
    );
    // base controllers
    roadIdController = TextEditingController(text: d['road_id'] ?? '');
    roadNameController = TextEditingController(text: d['road_name'] ?? '');
    yocController = TextEditingController(text: d['yoc']?.toString() ?? '');
    majorLandController = TextEditingController(text: d['major_land'] ?? '');
    roadlengthController = TextEditingController(
      text: d['length_met'] != null ? d['length_met'].toString() : null,
    );
    roadrowController = TextEditingController(
      text: d['row_meter'] != null ? d['row_meter'].toString() : null,
    );

    drain = (d['drain']?.toString().toLowerCase() == 'yes') ? 'Yes' : 'No';
    roadMarking = (d['road_marking']?.toString().toLowerCase() == 'yes')
        ? 'Yes'
        : 'No';

    markingAvailable =
        (d['marking_available']?.toString().toLowerCase() == 'yes')
        ? 'Yes'
        : 'No';

    final existingMarkingTypes = d['marking_type'];

    if (existingMarkingTypes is List) {
      selectedMarkingTypes.addAll(
        existingMarkingTypes.map((e) => e.toString()),
      );
    } else if (existingMarkingTypes is String &&
        existingMarkingTypes.trim().isNotEmpty) {
      selectedMarkingTypes.addAll(
        existingMarkingTypes
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    markingSide = d['marking_side']?.toString();

    roadMarkingRemarkController.text =
        d['road_marking_remark']?.toString() ?? '';

    // ✅ text field data (first 4 read-only)
    textFields = {
      'zone_no': d['zone_no']?.toString(),
      'zone_name': d['zone_name']?.toString(),
      'ward_no': d['ward_no']?.toString(),
      'ward_name': d['ward_name']?.toString(),
      'ownership': widget.roadData['ownership']?.toString() ?? '',
      'category': d['category']?.toString(),
      'condition': d['condition']?.toString(),
      'material': d['material']?.toString(),
      'material_c': d['material_c']?.toString(),
      'cus': d['cus']?.toString(),
      'row_meter': d['row_meter'] != null ? d['row_meter'].toString() : null,
      'row_apr': d['row_apr']?.toString(),
      'carriage_w': d['carriage_w']?.toString(),
      'length_met': d['length_met'] != null ? d['length_met'].toString() : null,
    };

    loadDropdowns();
    String normalizeYesNo(dynamic val) {
      if (val == null) return 'No';
      String s = val.toString().trim().toLowerCase();
      return s == 'yes' ? 'Yes' : 'No';
    }

    // ✅ radio button data
    infraFields = {
      'footpath': normalizeYesNo(d['footpath'] ?? d['foothpath']),
      'pavement_distress': normalizeYesNo(d['pavement_distress']),
      'median': normalizeYesNo(d['median']),
      'electric_p': normalizeYesNo(d['electric_p']),
      'trees': normalizeYesNo(d['trees']),
      'toilet': normalizeYesNo(d['toilet'] ?? d['public_toilet']),
      'rmu': normalizeYesNo(d['rmu']),
      'streetlight': normalizeYesNo(
        d['streetlight'] ?? d['street__so'] ?? d['strt_slr_l'],
      ),
      'gov_office': normalizeYesNo(d['gov_office'] ?? d['government']),
      'edu_instit': normalizeYesNo(d['edu_instit'] ?? d['educationa']),
      'bank_atm': normalizeYesNo(d['bank_atm']),
      'hospital': normalizeYesNo(d['hospital']),
      'stadium': normalizeYesNo(d['stadium']),
      'parking': normalizeYesNo(d['parking'] ?? d['park']),
      'reli_place': normalizeYesNo(d['reli_place'] ?? d['religious']),
      'graveyard': normalizeYesNo(d['graveyard']),
      'transport': normalizeYesNo(d['transport']),
      'signboard': normalizeYesNo(d['signboard']),
      'other': normalizeYesNo(d['other']),
      'manhole': normalizeYesNo(d['manhole']),
      'transforme': normalizeYesNo(d['transforme']),
      'road_marking': normalizeYesNo(d['road_marking']),
    };

    treesCountController.text = d['trees_count']?.toString() ?? "";
    selectedPavementCondition = d['pavement_condition']?.toString();

    // =====================================================
    // RESTORE FORM AFTER RETURNING FROM MANHOLE MAP
    // =====================================================
    final savedForm = widget.initialFormData;

    if (savedForm != null) {
      // Basic fields
      roadNameController.text =
          savedForm['road_name']?.toString() ?? roadNameController.text;

      yocController.text = savedForm['yoc']?.toString() ?? yocController.text;

      majorLandController.text =
          savedForm['major_land']?.toString() ?? majorLandController.text;

      remarksController.text =
          savedForm['remark']?.toString() ?? remarksController.text;

      // Text/dropdown fields
      const textFieldKeys = [
        'ownership',
        'category',
        'condition',
        'material',
        'material_c',
        'cus',
        'row_meter',
        'row_apr',
        'carriage_w',
        'length_met',
      ];

      for (final key in textFieldKeys) {
        if (savedForm.containsKey(key)) {
          textFields[key] = savedForm[key]?.toString();
        }
      }

      // Drain
      if (savedForm.containsKey('drain')) {
        drain = savedForm['drain']?.toString();
      }

      // Infrastructure Yes/No fields
      for (final key in infraFields.keys) {
        if (savedForm.containsKey(key)) {
          infraFields[key] = savedForm[key]?.toString();
        }
      }

      // ============================
      // ROAD MARKING RESTORE
      // ============================

      roadMarking = savedForm['road_marking']?.toString() ?? roadMarking;

      markingAvailable =
          savedForm['marking_available']?.toString() ?? markingAvailable;

      markingSide = savedForm['marking_side']?.toString() ?? markingSide;

      roadMarkingRemarkController.text =
          savedForm['road_marking_remark']?.toString() ??
          roadMarkingRemarkController.text;

      final savedMarkingTypes = savedForm['marking_type'];

      if (savedMarkingTypes is List) {
        selectedMarkingTypes
          ..clear()
          ..addAll(savedMarkingTypes.map((e) => e.toString()));
      }

      // ============================
      // MEDIAN RESTORE
      // ============================

      final savedMedianTypes = savedForm['median_type'];

      if (savedMedianTypes is List) {
        selectedMedianTypes
          ..clear()
          ..addAll(savedMedianTypes.map((e) => e.toString()));
      }

      medianWidthController.text = savedForm['median_width']?.toString() ?? '';

      medianLengthController.text =
          savedForm['median_length']?.toString() ?? '';

      medianPaved = savedForm['median_paved']?.toString() ?? medianPaved;

      medianGreenCover =
          savedForm['median_green_cover']?.toString() ?? medianGreenCover;

      medianGreenedLengthController.text =
          savedForm['median_greened_length']?.toString() ?? '';

      medianToBeGreened =
          savedForm['median_to_be_greened']?.toString() ?? medianToBeGreened;

      medianCondition =
          savedForm['median_condition']?.toString() ?? medianCondition;

      medianRemarkController.text =
          savedForm['median_remark']?.toString() ?? '';

      footpathSide = savedForm['footpath_side']?.toString() ?? footpathSide;
      footpathWidthController.text =
          savedForm['footpath_width']?.toString() ?? '';
      footpathSurfaceMaterial =
          savedForm['footpath_surface_material']?.toString() ??
          footpathSurfaceMaterial;
      footpathCondition =
          savedForm['footpath_condition']?.toString() ?? footpathCondition;
      footpathPavedLengthController.text =
          savedForm['footpath_paved_length']?.toString() ?? '';
      footpathGreenedLengthController.text =
          savedForm['footpath_greened_length']?.toString() ?? '';
      footpathEncroachment =
          savedForm['footpath_encroachment']?.toString() ??
          footpathEncroachment;
      footpathObstruction =
          savedForm['footpath_obstruction']?.toString() ?? footpathObstruction;
      footpathRemarksController.text =
          savedForm['footpath_remarks']?.toString() ?? '';

      final savedFootpathPhotos = savedForm['footpath_photos'];
      if (savedFootpathPhotos is List) {
        footpathPhotos
          ..clear()
          ..addAll(savedFootpathPhotos.map((path) => File(path)));
      }

      // ============================
      // MANHOLES RESTORE
      // ============================

      final savedBusStops = savedForm['busStopPoints'];
      // if (savedBusStops is List) {
      //   busStopPoints..clear()..addAll(savedBusStops.map((item) => Map<String, dynamic>.from(item as Map)));
      // }
    }
    textFields.forEach((key, value) {
      dynamicControllers[key] = TextEditingController(text: value ?? '');
    });
    _handleLostData();
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

  final Map<String, String> labelOverrides = {
    'own_class': 'Ownership Class',
    'material_c': 'MATERIAL CLASS',
    'cus': 'CONSTRUCTION UNDER SCHEME',
    'carriage_w': 'Carriage Way',
    'row_apr': 'Right Of Way As Per Record ',
    'row_meter': 'Right Of Way Meter',
    'length_met': 'Length of Road (Meter)',
  };

  Future<void> _captureMarkingPhoto() async {
    if (_isCapturing) return;
    if (markingPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Maximum 4 road marking photographs allowed."),
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_picker_type', 'marking');

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) {
        await prefs.remove('last_picker_type');

        if (mounted) {
          setState(() => _isCapturing = false);
        }
        return;
      }

      await prefs.remove('last_picker_type');

      if (!mounted) return;

      setState(() {
        markingPhotos.add(File(image.path));
        _isCapturing = false;
      });
    } catch (e) {
      debugPrint("Road marking photo error: $e");
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to capture photograph: $e")),
      );
    }
  }

  Future<void> _captureMedianPhoto() async {
    if (_isCapturing) return;
    if (medianPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 4 median photographs allowed.")),
      );
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_picker_type', 'median');
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) {
        await prefs.remove('last_picker_type');

        if (mounted) {
          setState(() => _isCapturing = false);
        }
        return;
      }

      await prefs.remove('last_picker_type');

      if (!mounted) return;

      setState(() {
        medianPhotos.add(File(image.path));
        _isCapturing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to capture median photograph: $e")),
      );
    }
  }

  Future<void> _captureFootpathPhoto() async {
    if (_isCapturing) return;
    if (footpathPhotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Maximum 4 footpath photographs allowed."),
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_picker_type', 'footpath');
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) {
        await prefs.remove('last_picker_type');

        if (mounted) {
          setState(() => _isCapturing = false);
        }
        return;
      }

      await prefs.remove('last_picker_type');

      if (!mounted) return;

      setState(() {
        footpathPhotos.add(File(image.path));
        _isCapturing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to capture footpath photograph: $e")),
      );
    }
  }

  @override
  void dispose() {
    dynamicControllers.forEach((key, controller) => controller.dispose());
    roadIdController.dispose();
    roadNameController.dispose();
    yocController.dispose();
    majorLandController.dispose();
    roadlengthController.dispose();
    roadrowController.dispose();

    remarksController.dispose();

    ownershipOtherController.dispose();
    materialOtherController.dispose();
    materialClassOtherController.dispose();
    cusOtherController.dispose();
    categoryOtherController.dispose();

    roadMarkingRemarkController.dispose();
    medianWidthController.dispose();
    medianLengthController.dispose();
    medianGreenedLengthController.dispose();
    medianRemarkController.dispose();

    footpathWidthController.dispose();
    footpathPavedLengthController.dispose();
    footpathGreenedLengthController.dispose();
    footpathRemarksController.dispose();
    treesCountController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Center(
          child: const Text(
            "🛠️ Update Road Data",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),

        backgroundColor: Colors.orange.shade700,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // top-level fields
              TextField(
                controller: roadIdController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Road ID",
                  border: OutlineInputBorder(),
                ),
              ),
              const Divider(),
              // ✅ Text fields
              ...textFields.keys
                  .where((key) => key != 'category' && key != 'condition')
                  .map((key) {
                    final isReadOnly = [
                      'zone_no',
                      'zone_name',
                      'ward_no',
                      'ward_name',
                    ].contains(key);
                    final isDropdown = dropdownOptions[key] != null;
                    if (isDropdown) {
                      if (ownershipLoading) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value:
                                  dropdownOptions[key]!.contains(
                                    textFields[key],
                                  )
                                  ? textFields[key]
                                  : null,
                              decoration: InputDecoration(
                                labelText:
                                    labelOverrides[key] ??
                                    key.replaceAll('_', ' ').toUpperCase(), // ✅
                                border: const OutlineInputBorder(),
                              ),
                              items: dropdownOptions[key]!
                                  .map((v) => v.trim())
                                  .toSet()
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  textFields[key] = val;
                                });
                              },
                            ),

                            // ✅ OWNERSHIP
                            if (key == 'ownership' &&
                                textFields[key] == 'Other')
                              TextField(
                                controller: ownershipOtherController,
                                decoration: const InputDecoration(
                                  labelText: "Enter Ownership",
                                ),
                              ),

                            // ✅ MATERIAL
                            if (key == 'material' && textFields[key] == 'Other')
                              TextField(
                                controller: materialOtherController,
                                decoration: const InputDecoration(
                                  labelText: "Enter Material",
                                ),
                              ),

                            // ✅ MATERIAL CLASS
                            if (key == 'material_c' &&
                                textFields[key] == 'Other')
                              TextField(
                                controller: materialClassOtherController,
                                decoration: const InputDecoration(
                                  labelText: "Enter Material Class",
                                ),
                              ),
                            if (key == 'cus' &&
                                (textFields[key] == 'Other' ||
                                    textFields[key] == 'Others'))
                              TextField(
                                controller: cusOtherController,
                                decoration: const InputDecoration(
                                  labelText: "Enter Construction Under Scheme",
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    // normal textfields for others
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: dynamicControllers[key],
                        readOnly: isReadOnly,
                        onChanged: (val) => textFields[key] = val,
                        decoration: InputDecoration(
                          labelText:
                              labelOverrides[key] ??
                              key.replaceAll('_', ' ').toUpperCase(),
                          border: const OutlineInputBorder(),
                          fillColor: isReadOnly ? Colors.grey.shade200 : null,
                          filled: isReadOnly,
                        ),
                      ),
                    );
                  })
                  .toList(),

              const SizedBox(height: 10),
              _buildTextField("Road Name", roadNameController),

              _buildDropdown(
                label: "Category",
                value: textFields['category'],
                enabled: true,
                items: dropdownOptions['category'] ?? [],
                onChanged: (val) {
                  setState(() {
                    textFields['category'] = val;

                    if (val != 'Other') {
                      categoryOtherController.clear();
                    }
                  });
                },
              ),

              if (textFields['category'] == 'Other') ...[
                const SizedBox(height: 10),

                TextField(
                  controller: categoryOtherController,
                  decoration: const InputDecoration(
                    labelText: "Enter Road Category",
                    hintText: "Enter road category",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              _buildDropdown(
                label: "Condition",
                value: textFields['condition'],
                enabled: true,
                items: dropdownOptions['condition'] ?? [],
                onChanged: (val) {
                  setState(() {
                    textFields['condition'] = val;
                  });
                },
              ),
              const SizedBox(height: 10),

              _buildTextField(
                "Year of Construction",
                yocController,
                keyboardType: TextInputType.number,
              ),
              _buildTextField("Major Landmark", majorLandController),

              const Divider(),
              ...infraFields.keys.map((key) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRadioRow(key, infraFields[key], yesNoOptions, (val) {
                      setState(() {
                        infraFields[key] = val;

                        if (key == 'footpath' && val == 'No') {
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

                        if (key == 'median' && val == 'No') {
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

                        if (key == 'manhole' && val == 'No') {
                          // manholePoints.clear();
                        }
                        if (key == 'trees' && val == 'No') {
                          treesCountController.clear();
                        }
                        if (key == 'pavement_distress' && val == 'No') {
                          selectedPavementCondition = null;
                        }
                        if (key == 'road_marking') {
                          roadMarking = val;
                          if (val == 'No') {
                            selectedMarkingTypes.clear();
                            markingSide = null;
                            roadMarkingRemarkController.clear();
                            // markingAvailable = null;
                            markingPhotos.clear();
                          }
                        }
                      });
                    }),

                    if (key == 'pavement_distress' &&
                        infraFields['pavement_distress'] == 'Yes')
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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

                    if (key == 'median' && infraFields['median'] == 'Yes')
                      _buildMedianSection(),

                    if (key == 'footpath' && infraFields['footpath'] == 'Yes')
                      _buildFootpathSection(),
                  ],
                );
              }),

              const Divider(),
              // ===============================
              // ROAD MARKINGS
              // ===============================

              // Show additional fields only when
              // Road Markings = Yes
              if (infraFields['road_marking'] == 'Yes') ...[
                const SizedBox(height: 10),

                const Text(
                  "Marking Type",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                const SizedBox(height: 5),

                // ===============================
                // MARKING TYPE CHECKBOXES
                // ===============================
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

                // ===============================
                // PHOTOGRAPH
                // ===============================
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
                  onPressed: (markingPhotos.length < 4 && !_isCapturing)
                      ? _captureMarkingPhoto
                      : null,
                  icon: _isCapturing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(
                    _isCapturing
                        ? "Opening Camera..."
                        : "Add Photograph (${markingPhotos.length}/4)",
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Radio button for "Drain" selection
              _buildRadioRow(
                'drain',
                drain,
                yesNoOptions,
                (val) => setState(() => drain = val),
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

              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Preview Updates"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                ),
                onPressed: () async {
                  final updatedData = _buildCurrentRoadFormData();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PreviewRoadUpdateScreen(
                        roadId: widget.roadData['road_id'],
                        updatedData: updatedData,
                        roadAgeCategory: widget.roadAgeCategory,
                        zoneName: widget.zoneName,
                        wardNo: widget.wardNo,
                        wardName: widget.wardName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  final Map<String, String> radioLabelOverrides = {
    'footpath': 'Footpath',
    'pavement_distress': 'Pavement Distress',
    'manhole': 'Manhole',
    'median': 'Median',
    'electric_p': 'Electric Pole',
    'trees': 'Trees',
    'toilet': 'Public Toilet',
    'public_toilet': 'Public Toilet',
    'parking': 'Parking',
    'rmu': 'Ring Main Unit',
    'gov_office': 'Government Office',
    'edu_instit': 'Educational Institution',
    'reli_place': 'Religious Place',
    'streetlight': 'Street Solar Light',
    'graveyard': 'Graveyard',
    'transport': 'Transport Facility',
    'signboard': 'Signboard',
    'other': 'Other',
    'road_marking': 'Road Markings',
    'marking_available': 'Marking Available',
    'median_paved': 'Paved',
    'median_green_cover': 'Green Cover',
    'median_to_be_greened': 'To Be Greened',
    'footpath_encroachment': 'Encroachment',
    'footpath_obstruction': 'Obstruction',
  };

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildRadioRow(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          radioLabelOverrides[label] ??
              label.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Column(
          children: options.map((opt) {
            return RadioListTile<String>(
              title: Text(opt),
              value: opt,
              groupValue: value,
              onChanged: onChanged,
            );
          }).toList(),
        ),
      ],
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
              return DropdownMenuItem<String>(value: side, child: Text(side));
            }).toList(),
            onChanged: (value) {
              setState(() {
                footpathSide = value;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            "Width (m)",
            footpathWidthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          _buildDropdown(
            label: "Surface Material",
            value: footpathSurfaceMaterial,
            items: materialApiList,
            enabled: true,
            onChanged: (val) {
              setState(() {
                footpathSurfaceMaterial = val;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildDropdown(
            label: "Condition",
            value: footpathCondition,
            items: conditionApiList,
            enabled: true,
            onChanged: (val) {
              setState(() {
                footpathCondition = val;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildTextField(
            "Paved Length (m)",
            footpathPavedLengthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          _buildTextField(
            "Greened Length (m)",
            footpathGreenedLengthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          _buildRadioRow(
            'footpath_encroachment',
            footpathEncroachment,
            yesNoOptions,
            (val) => setState(() => footpathEncroachment = val),
          ),
          _buildRadioRow(
            'footpath_obstruction',
            footpathObstruction,
            yesNoOptions,
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
                        cacheWidth: 300,
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
            onPressed: (footpathPhotos.length < 4 && !_isCapturing)
                ? _captureFootpathPhoto
                : null,
            icon: _isCapturing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt),
            label: Text(
              _isCapturing
                  ? "Opening Camera..."
                  : "Add Footpath Photograph (${footpathPhotos.length}/4)",
            ),
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

          // MULTI SELECT MEDIAN TYPE
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

          _buildRadioRow('median_paved', medianPaved, yesNoOptions, (value) {
            setState(() {
              medianPaved = value;
            });
          }),

          _buildRadioRow('median_green_cover', medianGreenCover, yesNoOptions, (
            value,
          ) {
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

          _buildRadioRow(
            'median_to_be_greened',
            medianToBeGreened,
            yesNoOptions,
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
                        cacheWidth: 300,
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
            onPressed: (medianPhotos.length < 4 && !_isCapturing)
                ? _captureMedianPhoto
                : null,
            icon: _isCapturing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt),
            label: Text(
              _isCapturing
                  ? "Opening Camera..."
                  : "Add Median Photograph (${medianPhotos.length}/4)",
            ),
          ),

          // ElevatedButton.icon(
          //   onPressed: medianPhotos.length < 4
          //       ? _captureMedianPhoto
          //       : null,
          //   icon: const Icon(Icons.camera_alt),
          //   label: Text(
          //     "Add Median Photograph (${medianPhotos.length}/4)",
          //   ),
          // ),
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

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: enabled ? onChanged : null,
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

  Map<String, dynamic> _buildCurrentRoadFormData() {
    return {
      'road_id': roadIdController.text,
      'mob_latitu': mobLatitude,
      'mob_longit': mobLongitude,

      'road_name': roadNameController.text,

      'category': textFields['category'] == 'Other'
          ? categoryOtherController.text.trim()
          : textFields['category'],

      'condition': textFields['condition'],

      'yoc': int.tryParse(yocController.text) ?? 0,

      'major_land': majorLandController.text,

      'drain': drain,

      'footpath': infraFields['footpath'],
      'fothpath': infraFields['footpath'],
      'public_toilet': infraFields['toilet'],
      'toilet': infraFields['toilet'],
      'parking': infraFields['parking'],
      'park': infraFields['parking'],
      'signboard': infraFields['signboard'],
      'other': infraFields['other'],
      'streetlight': infraFields['streetlight'],
      'street__so': infraFields['streetlight'],
      'strt_slr_l': infraFields['streetlight'],
      'gov_office': infraFields['gov_office'],
      'government': infraFields['gov_office'],
      'edu_instit': infraFields['edu_instit'],
      'educationa': infraFields['edu_instit'],
      'reli_place': infraFields['reli_place'],
      'religious': infraFields['reli_place'],
      'transforme': infraFields['transforme'],
      // 'transformer': infraFields['transforme'],
      'transport': infraFields['transport'],

      ...infraFields,
      'trees_count': treesCountController.text.trim(),
      'pavement_condition': selectedPavementCondition,

      'length_met': textFields['length_met'],
      'row_meter': textFields['row_meter'],
      'row_apr': textFields['row_apr'],
      'carriage_w': textFields['carriage_w'],

      'remark': remarksController.text.trim(),

      'ownership': textFields['ownership'] == 'Other'
          ? ownershipOtherController.text.trim()
          : textFields['ownership'],

      'material': textFields['material'] == 'Other'
          ? materialOtherController.text.trim()
          : textFields['material'],

      'material_c': textFields['material_c'] == 'Other'
          ? materialClassOtherController.text.trim()
          : textFields['material_c'],

      'cus': (textFields['cus'] == 'Other' || textFields['cus'] == 'Others')
          ? cusOtherController.text.trim()
          : textFields['cus'],

      // ROAD MARKING
      'road_marking': roadMarking,
      'marking_type': selectedMarkingTypes.toList(),
      'marking_side': markingSide,
      'road_marking_remark': roadMarkingRemarkController.text.trim(),
      'marking_available': markingAvailable,

      'marking_photos': markingPhotos.map((photo) => photo.path).toList(),

      // MEDIAN
      'median_type': selectedMedianTypes.toList(),

      'median_width': double.tryParse(medianWidthController.text.trim()),

      'median_length': double.tryParse(medianLengthController.text.trim()),

      'median_paved': medianPaved,

      'median_green_cover': medianGreenCover,

      'median_greened_length': double.tryParse(
        medianGreenedLengthController.text.trim(),
      ),

      'median_to_be_greened': medianToBeGreened,

      'median_condition': medianCondition,

      'median_photos': medianPhotos.map((photo) => photo.path).toList(),

      'median_remark': medianRemarkController.text.trim(),

      'footpath_side': footpathSide,
      'footpath_width': double.tryParse(footpathWidthController.text.trim()),
      'footpath_surface_material': footpathSurfaceMaterial,
      'footpath_condition': footpathCondition,
      'footpath_paved_length': double.tryParse(
        footpathPavedLengthController.text.trim(),
      ),
      'footpath_greened_length': double.tryParse(
        footpathGreenedLengthController.text.trim(),
      ),
      'footpath_encroachment': footpathEncroachment,
      'footpath_obstruction': footpathObstruction,
      'footpath_remarks': footpathRemarksController.text.trim(),
      'footpath_photos': footpathPhotos.map((p) => p.path).toList(),
    };
  }
}
