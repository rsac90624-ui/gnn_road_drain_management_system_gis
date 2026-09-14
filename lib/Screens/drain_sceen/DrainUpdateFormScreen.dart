import 'package:flutter/material.dart';
import '../../widgets/preview_button.dart';
import 'drain_update_preview_screen.dart';

class DrainUpdateFormScreen extends StatefulWidget {
  final Map<String, dynamic> drainData;
  final double? latitude;
  final double? longitude;

  const DrainUpdateFormScreen({
    super.key,
    required this.drainData,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<DrainUpdateFormScreen> createState() => _DrainUpdateFormScreenState();
}

class _DrainUpdateFormScreenState extends State<DrainUpdateFormScreen> {
  late TextEditingController widthCtrl;
  late TextEditingController depthCtrl;
  late TextEditingController lengthCtrl;
  // late TextEditingController conditionCtrl;
  late TextEditingController constYearCtrl;
  // late TextEditingController ownershipCtrl;
  // late TextEditingController statusCtrl;
  late TextEditingController remarkCtrl;

  String? condition;
  String? ownership;
  String? status;

  late TextEditingController ownershipOtherCtrl;


  String? drainType;
  String? drainMaterial;
  String? drain_sides;

  double? mobLatitude;
  double? mobLongitude;

  @override
  void initState() {
    super.initState();

    widthCtrl = TextEditingController(text: widget.drainData['width']?.toString() ?? "");
    depthCtrl = TextEditingController(text: widget.drainData['depth']?.toString() ?? "");
    lengthCtrl = TextEditingController(text: widget.drainData['length']?.toString() ?? "");
    // conditionCtrl = TextEditingController(text: widget.drainData['condition'] ?? "");
    constYearCtrl = TextEditingController(text: widget.drainData['const_year']?.toString() ?? "");
    // ownershipCtrl = TextEditingController(text: widget.drainData['ownership'] ?? "");
    // statusCtrl = TextEditingController(text: widget.drainData['status'] ?? "");
    remarkCtrl = TextEditingController(text: widget.drainData['remark'] ?? "");

    drainType = normalizeDropdownValue(
      widget.drainData['type'],
      ["L Type", "U Type", "K.C"],
    );

    drainMaterial = normalizeDropdownValue(
      widget.drainData['material'],
      ["Cement", "Brick", "PVC", "Other"],
    );

    drain_sides = normalizeDropdownValue(
      widget.drainData['drain_sides'],
      ["Left Side", "Right Side", "Both Sides"],
    );

    condition = normalizeDropdownValue(
      widget.drainData['condition'],
      ["Running", "Choked"],
    );

    ownership = normalizeDropdownValue(
      widget.drainData['ownership'],
      ["Nagar Nigam", "Others"],
    );

    status = normalizeDropdownValue(
      widget.drainData['status'],
      ["Open", "Covered"],
    );


    ownershipOtherCtrl = TextEditingController(
      text: ownership == "Others" ? widget.drainData['ownership'] ?? "" : "",
    );

    mobLatitude = widget.latitude;
    mobLongitude = widget.longitude;
  }

  // 🔐 Prevent dropdown assertion crash
  String? normalizeDropdownValue(String? value, List<String> allowed) {
    if (value == null) return null;
    final v = value.toString().trim();
    if (v.isEmpty) return null;

    for (final item in allowed) {
      if (item.toLowerCase() == v.toLowerCase()) {
        return item;
      }
    }
    return null;
  }

  void _goToPreview() {

    if (ownership == "Others" &&
        ownershipOtherCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please specify ownership")),
      );
      return;
    }

    if (drainType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select drain type")),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrainUpdatePreviewScreen(
          gid: widget.drainData['gid'],
          staticData: widget.drainData,
            editedData: {
              "type": drainType,
              "material": drainMaterial,
              "drain_sides": drain_sides,

              "width": double.tryParse(widthCtrl.text),
              "depth": double.tryParse(depthCtrl.text),
              "length": double.tryParse(lengthCtrl.text),

              "const_year": constYearCtrl.text,
              "remark": remarkCtrl.text,
              "condition": condition,

              // ✅ FIXED OWNERSHIP (same as create & reshape)
              "ownership": ownership == "Others"
                  ? ownershipOtherCtrl.text.trim()
                  : ownership,

              "status": status,

              "mob_latitude": mobLatitude,
              "mob_longitude": mobLongitude,
            }

        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Update Drain Network",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _readonly("Zone No", widget.drainData['zone_no']),
            _readonly("Zone Name", widget.drainData['zone_name']),
            _readonly("Ward No", widget.drainData['ward_no']),
            _readonly("Ward Name", widget.drainData['ward_name']),
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

            _dropdown(
              "Drain Sides",
              ["Left Side", "Right Side", "Both Sides"],
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
                  if (v != "Others") {
                    ownershipOtherCtrl.clear();
                  }
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

            // _field("Condition", conditionCtrl),
            // _field("Ownership", ownershipCtrl),

            // 🔒 STATUS NOT EDITABLE
            // _field("Status", statusCtrl),

            _field("Remark", remarkCtrl, maxLines: 3),

            const SizedBox(height: 24),
            PreviewButton(onPressed: _goToPreview),
          ],
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _field(
      String label,
      TextEditingController ctrl, {
        int maxLines = 1,
        bool enabled = true,
        bool isNumber = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }


  Widget _readonly(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        readOnly: true,
        initialValue: value?.toString() ?? "",
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text("Select $label"), // ✅ important UX fix
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem<String>(
            value: e,
            child: Text(e),
          ),
        )
            .toList(),
        onChanged: onChanged,
      ),
    );
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


}

