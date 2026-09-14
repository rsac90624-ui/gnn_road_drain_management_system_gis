import 'package:flutter/material.dart';
import 'PreviewMissingRoadScreen.dart';

class MissingRoadFormScreen extends StatefulWidget {
  final String geometry;
  final Map<String, dynamic>? existingData; // when clicking existing missing road
  final double? latitude;
  final double? longitude;

  const MissingRoadFormScreen({
    super.key,
    required this.geometry,
    this.existingData,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<MissingRoadFormScreen> createState() => _MissingRoadFormScreenState();
}

class _MissingRoadFormScreenState extends State<MissingRoadFormScreen> {

  // Initialize dropdown values in the form
  final List<String> categories = ['Collector', 'Local Street', 'Arterial', 'Sub Arterial'];
  final List<String> conditions = ['Good', 'Moderate', 'Poor'];
  final List<String> materials = ['Kachcha', 'Bitumen', 'Stone', 'BOE', 'CC', 'Interlocking'];
  final List<String> materialClasses = ['Kachcha', 'CC\\Bitumen', 'STONE', 'BOE', 'Interlocking\\CC', 'Bitumen', 'CC', 'Interlocking'];

  late double? mobLatitude;
  late double? mobLongitude;

  // ================= CONTROLLERS =================
  final TextEditingController roadIdController = TextEditingController();

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
  final TextEditingController parkNameController = TextEditingController();
  final TextEditingController parkOwnershipController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  final TextEditingController drainWidthController = TextEditingController();
  final TextEditingController roadLengthController = TextEditingController();



  // ================= RADIO / DROPDOWN =================
  final Map<String, String> radioLabelOverrides = {
    'foothpath': 'Footpath',
    'manhole': 'Manhole',
    'median': 'Median',
    'transforme': 'Transformer',
    'rmu': 'Ring Main Unit',
    'electric_p': 'Electric Pole',
    'strt_slr_l': 'Street Solar Light',
    'hp_well': 'Hand Pump',
    'gov_office': 'Government Office',
    'edu_instit': 'Educational Institution',
    'bank_atm': 'Bank / ATM',
    'hospital': 'Hospital',
    'stadium': 'Stadium',
    'park': 'Park',
    'reli_place': 'Religious Place',
    'graveyard': 'Graveyard',
    'transport': 'Transport Facility',
    'water_body': 'Water Bodies',
    'drain': 'Drain Available',
  };

  Map<String, String?> infraFields = {
    'foothpath': null,
    'manhole': null,
    'median': null,
    'transforme': null,
    'rmu': null,
    'electric_p': null,
    'strt_slr_l': null,
    'hp_well': null,
    'gov_office': null,
    'edu_instit': null,
    'bank_atm': null,
    'hospital': null,
    'stadium': null,
    'park': null,
    'reli_place': null,
    'graveyard': null,
    'transport': null,
    'water_body': null,
  };

  String? drain = 'No';
  String? drainType;
  String? drainMtrl;
  String? drainSides;
  String? manholeType;

  Widget _drop({
    required String label,
    required String? value,
    required List<String> items,
    required bool enabled,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: enabled ? onChanged : null,
    );
  }

  // ================= PREFILL (VERY IMPORTANT) =================
  @override
  void initState() {
    super.initState();

    final d = widget.existingData;
    if (d == null) return;

    roadIdController.text =  d['road_id'] ?? '';
    roadNameController.text = d['road_name'] ?? '';
    categoryController.text = d['category'] ?? '';
    conditionController.text = d['condition'] ?? '';
    yocController.text = d['yoc']?.toString() ?? '';
    majorLandController.text = d['major_land'] ?? '';
    zoneNoController.text = d['zone_no']?.toString() ?? '';
    zoneNameController.text = d['zone_name'] ?? '';
    wardNoController.text = d['ward_no']?.toString() ?? '';
    wardNameController.text = d['ward_name'] ?? '';
    ownershipController.text = d['ownership'] ?? '';
    ownClassController.text = d['own_class'] ?? '';
    materialController.text = d['material'] ?? '';
    materialCController.text = d['material_c'] ?? '';
    cusController.text = d['cus'] ?? '';
    rowMeterController.text = d['row_meter']?.toString() ?? '';
    rowAprController.text = d['row_apr']?.toString() ?? '';
    carriageWController.text = d['carriage_w']?.toString() ?? '';
    roadLengthController.text = d['length_met']?.toString() ?? '';
    remarksController.text = d['remark'] ?? '';

    drain = d['drain'] ?? 'No';
    drainType = d['drain_type'];
    drainMtrl = d['drain_mtrl'];
    drainSides = d['drain_sides'];
    manholeType = d['manhole_type'];
    mobLatitude = widget.latitude;
    mobLongitude = widget.longitude;

    infraFields.forEach((k, _) {
      infraFields[k] = d[k]?.toString();
    });
  }




  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Center(
          child: Text(
            "Update Missing Road",
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        backgroundColor: Colors.orange.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _sectionHeader("Road Information"),
          _field("Road Id", roadIdController),

          _field("Road Name", roadNameController),
          // _field("Category", categoryController),
          _drop(
            label: "Category",
            value: categoryController.text.isNotEmpty ? categoryController.text : null,
            items: categories,
            enabled: true,
            onChanged: (value) => setState(() {
              if (value != null) categoryController.text = value;
            }),
          ),
          SizedBox(height: 12), // Add vertical space

          // _field("Condition", conditionController),
          _drop(
            label: "Condition",
            value: conditionController.text.isNotEmpty ? conditionController.text : null,
            items: conditions,
            enabled: true,
            onChanged: (value) => setState(() {
              if (value != null) conditionController.text = value;
            }),
          ),
          SizedBox(height: 12), // Add vertical space


          _field("Year of Construction", yocController, type: TextInputType.number),
          SizedBox(height: 12), // Add vertical space

          _field("Major Landmark", majorLandController),

          _sectionHeader("Zone / Ward Details"),
          _field("Zone No", zoneNoController),
          _field("Zone Name", zoneNameController),
          _field("Ward No", wardNoController),
          _field("Ward Name", wardNameController),

          _sectionHeader("Ownership"),
          _field("Ownership", ownershipController),
          _field("Ownership Class", ownClassController),

          _sectionHeader("Material / Construction"),
          // _field("Material", materialController),
          _drop(
            label: "Material",
            value: materialController.text.isNotEmpty ? materialController.text : null,
            items: materials,
            enabled: true,
            onChanged: (value) => setState(() {
              if (value != null) materialController.text = value;
            }),
          ),
          SizedBox(height: 12), // Add vertical space

          // _field("Material Class", materialCController),
          _drop(
            label: "Material Class",
            value: materialCController.text.isNotEmpty ? materialCController.text : null,
            items: materialClasses,
            enabled: true,
            onChanged: (value) => setState(() {
              if (value != null) materialCController.text = value;
            }),
          ),
          SizedBox(height: 12), // Add vertical space

          _field("Construction Under Scheme", cusController),
          _field("Right Of Way Meter", rowMeterController, type: TextInputType.number),
          _field("Right Of Way Approx", rowAprController, type: TextInputType.number),
          _field("Carriage Width", carriageWController, type: TextInputType.number),
          _field("Road Length (in meters)", roadLengthController, type: TextInputType.number),

          _sectionHeader("Infrastructure Facilities"),
          ...infraFields.keys.map(
                (k) => _radioRow(k, infraFields[k], (v) {
              setState(() => infraFields[k] = v);
            }),
          ),



          _sectionHeader("Drain Details"),
          _radioRow("drain", drain, (v) => setState(() => drain = v)),

          if (drain == "Yes") ...[
            _drop(
              label: "Drain Type",
              value: drainType,
              enabled: true,
              items: ['Open', 'Closed', 'Covered', 'L Type', 'U Type', 'K.C'],
              onChanged: (v) => setState(() => drainType = v),
            ),
            SizedBox(height: 10),
            _drop(
              label: "Drain Material",
              value: drainMtrl,
              enabled: true,
              items: ['Cement', 'Brick', 'PVC', 'Other'],
              onChanged: (v) => setState(() => drainMtrl = v),
            ),
            SizedBox(height: 10),

            _drop(
              label: "Drain Sides",
              value: drainSides,
              enabled: true,
              items: ['Single Side', 'Both Sides'],
              onChanged: (v) => setState(() => drainSides = v),
            ),
            SizedBox(height: 10),

            _field("Drain Width (m)", drainWidthController, type: TextInputType.number),
          ],

          _field("Remarks", remarksController),

          const SizedBox(height: 25),

          Center(
            child: SizedBox(
              width: 250,
              height: 55,
              child: ElevatedButton(
                onPressed: _openPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  "Preview Missing Road",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ================= HELPERS =================

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
  );

  Widget _field(String label, TextEditingController c,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                    if (name == "park" || name == "manhole") {
                      setState(() {});
                    }
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

                    if (name == "park") {
                      parkNameController.clear();
                      parkOwnershipController.clear();
                    }

                    if (name == "manhole") {
                      manholeType = null;
                    }

                    setState(() {});
                  },
                ),
              ),
            ],
          ),

          // 🏞️ PARK → show fields
          if (name == "park" && value == "Yes") ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _field("Park Name", parkNameController),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _field("Park Ownership", parkOwnershipController),
            ),
          ],

          // 🕳️ MANHOLE → show dropdown
          if (name == "manhole" && value == "Yes") ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonFormField<String>(
                value: manholeType,
                decoration: InputDecoration(
                  labelText: "Manhole Type",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Sewer",
                    child: Text("Sewer"),
                  ),
                  DropdownMenuItem(
                    value: "Storm Water",
                    child: Text("Storm Water"),
                  ),
                ],
                onChanged: (val) {
                  setState(() => manholeType = val);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }



  // Widget _drop({
  //   required String label,
  //   required String? value,
  //   required List<String> items,
  //   required bool enabled,
  //   required Function(String?) onChanged,
  // }) {
  //   return DropdownButtonFormField<String>(
  //     value: items.contains(value) ? value : null,
  //     decoration: InputDecoration(
  //       labelText: label,
  //       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  //     ),
  //     items: items.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
  //     onChanged: enabled ? onChanged : null,
  //   );
  // }

  void _openPreview() {
    final body = {
      "geomWKT": widget.geometry,
      "mob_latitude": mobLatitude,
      "mob_longitude": mobLongitude,
      // "is_missing": true,
      "road_id" : roadIdController.text,
      "road_name": roadNameController.text,
      "zone_no": zoneNoController.text,
      "zone_name": zoneNameController.text,
      "ward_no": wardNoController.text,
      "ward_name": wardNameController.text,
      "category": categoryController.text,
      "condition": conditionController.text,
      "yoc": int.tryParse(yocController.text),
      "major_land": majorLandController.text,
      "ownership": ownershipController.text,
      "own_class": ownClassController.text,
      "material": materialController.text,
      "material_c": materialCController.text,
      "cus": cusController.text,
      "row_meter": double.tryParse(rowMeterController.text),
      "row_apr": double.tryParse(rowAprController.text),
      "carriage_w": double.tryParse(carriageWController.text),
      "length_met": double.tryParse(roadLengthController.text),
      "drain_width": double.tryParse(drainWidthController.text),
      "drain": drain,
      "drain_type": drainType,
      "drain_mtrl": drainMtrl,
      "drain_sides": drainSides,
      "remark": remarksController.text,
      "manhole_type": manholeType,
      "park_name": parkNameController.text,
      "park_ownership": parkOwnershipController.text,

      ...infraFields,
    };

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PreviewMissingRoadScreen(
          data: body
      )),
    );
  }
}
