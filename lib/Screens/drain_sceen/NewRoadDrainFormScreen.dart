
import 'package:flutter/material.dart';
import '../../widgets/preview_button.dart';
import 'NewRoadDrainPreviewScreen.dart';

class NewRoadDrainFormScreen extends StatefulWidget {
  final String zoneNo;
  final String zoneName;
  final String wardNo;
  final String wardName;
  final String geometry; // LINESTRING WKT
  final double? latitude;
  final double? longitude;

  const NewRoadDrainFormScreen({
    super.key,
    required this.zoneNo,
    required this.zoneName,
    required this.wardNo,
    required this.wardName,
    required this.geometry,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<NewRoadDrainFormScreen> createState() =>
      _NewRoadDrainFormScreenState();
}

class _NewRoadDrainFormScreenState extends State<NewRoadDrainFormScreen> {
  // ---------------- Controllers ----------------
  late TextEditingController widthCtrl;
  late TextEditingController depthCtrl;
  late TextEditingController lengthCtrl;
  // late TextEditingController conditionCtrl;
  late TextEditingController constYearCtrl;
  // late TextEditingController ownershipCtrl;
  // late TextEditingController statusCtrl;
  late TextEditingController remarkCtrl;

  // ---------------- Dropdown values ----------------
  String? drainType;
  String? drainMaterial;
  String? drain_sides;

  String? condition;
  String? ownership;
  String? status;

  late TextEditingController ownershipOtherCtrl;


  @override
  void initState() {
    super.initState();

    widthCtrl = TextEditingController();
    depthCtrl = TextEditingController();
    lengthCtrl = TextEditingController();
    // conditionCtrl = TextEditingController();
    constYearCtrl = TextEditingController();
    // ownershipCtrl = TextEditingController();
    // statusCtrl = TextEditingController();
    remarkCtrl = TextEditingController();
    ownershipOtherCtrl = TextEditingController();

  }

  @override
  void dispose() {
    widthCtrl.dispose();
    depthCtrl.dispose();
    lengthCtrl.dispose();
    constYearCtrl.dispose();
    remarkCtrl.dispose();
    ownershipOtherCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }


  void _goToPreview() {

    if (drainType == null) {
      _snack("Please select drain type");
      return;
    }

    if (condition == null) {
      _snack("Please select condition");
      return;
    }

    if (status == null) {
      _snack("Please select status");
      return;
    }

    if (ownership == "Others" &&
        ownershipOtherCtrl.text.trim().isEmpty) {
      _snack("Please specify ownership");
      return;
    }


    final previewData = {
      "zone_no": widget.zoneNo,
      "zone_name": widget.zoneName,
      "ward_no": widget.wardNo,
      "ward_name": widget.wardName,
      "wkt_geom": widget.geometry,

      "type": drainType,
      "material": drainMaterial,
      "drain_sides": drain_sides,
      "condition": condition,

      "width": double.tryParse(widthCtrl.text),
      "depth": double.tryParse(depthCtrl.text),
      "length": double.tryParse(lengthCtrl.text),
      "const_year": constYearCtrl.text,
      "remark": remarkCtrl.text,

      // ✅ FINAL, CORRECT OWNERSHIP HANDLING
      "ownership": ownership == "Others"
          ? ownershipOtherCtrl.text.trim()
          : ownership,

      "status": status,
      "mob_latitude": widget.latitude,
      "mob_longitude": widget.longitude,
    };


    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewRoadDrainPreviewScreen(data: previewData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.orange.shade700,
        centerTitle: true,
        title: const Text(
          "New Drain Network",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _readonly("Zone No", () {
              String zNo = widget.zoneNo.trim();
              if (zNo.isNotEmpty) {
                final match = RegExp(r'\d+').firstMatch(zNo);
                if (match != null) return match.group(0)!;
              }
              if (widget.zoneName.isNotEmpty) {
                final match = RegExp(r'\d+').firstMatch(widget.zoneName);
                if (match != null) return match.group(0)!;
                return widget.zoneName.trim();
              }
              return zNo;
            }()),
            _readonly("Zone Name", widget.zoneName),
            _readonly("Ward No", widget.wardNo),
            _readonly("Ward Name", widget.wardName),

            const SizedBox(height: 12),

            _dropdown(
              "Drain Type",
              ["L Type", "U Type", "K.C"],
              drainType,
                  (v) => setState(() => drainType = v),
            ),

            _dropdown(
              "Drain Material",
              ["Cement", "Brick", "PVC", "Other"],
              drainMaterial,
                  (v) => setState(() => drainMaterial = v),
            ),

            // ✅ ADD THIS BLOCK
            _dropdown(
              "Drain Sides",
              ["Left Side", "Right Side","Both Sides"],
              drain_sides,
                  (v) => setState(() => drain_sides = v),
            ),
            _dropdown(
              "Condition",
              ["Running", "Choked"],
              condition,
                  (v) => setState(() => condition = v),
            ),
            _dropdown(
              "Ownership",
              ["Nagar Nigam", "Others"],
              ownership,
                  (v) {
                setState(() {
                  ownership = v;
                  if (v != "Others") ownershipOtherCtrl.clear();
                });
              },
            ),

            if (ownership == "Others")
              _field("Specify Ownership", ownershipOtherCtrl),
            _dropdown(
              "Status",
              ["Open", "Covered"],
              status,
                  (v) => setState(() => status = v),
            ),



            _field("Width (m)", widthCtrl, isNumber: true),
            _field("Depth (m)", depthCtrl, isNumber: true),
            // _field("Length (m)", lengthCtrl, isNumber: true),
            _field("Construction Year", constYearCtrl, isNumber: true),
            _field("Remark", remarkCtrl, isMultiline: true),

            const SizedBox(height: 24),

            PreviewButton(
              onPressed: _goToPreview,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _field(
      String label,
      TextEditingController controller, {
        bool isNumber = false,
        bool isMultiline = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: isMultiline
            ? TextInputType.multiline
            : isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        maxLines: isMultiline ? 3 : 1,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _readonly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        readOnly: true,
        initialValue: value,
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
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.grey, width: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
      String label,
      List<String> items,
      String? value,
      ValueChanged<String?> onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text("Select $label"),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
