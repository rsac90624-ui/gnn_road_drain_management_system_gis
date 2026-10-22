import 'package:flutter/material.dart';

typedef LegendItemBuilder = Widget Function(Color color, String label);

class DynamicLegend {

  static const Map<String, Color> materialColors = {
    "CC": Colors.grey,
    "Bitumen": Color(0xFF3A4F7A),
    "Interlocking": Colors.orange,
    "BOE": Colors.blueGrey,
    "Kachcha": Colors.brown,
  };

  static List<Widget> getLegendItems({
    required List<String> selectedPriority,
    required String? selectedMaterial,   // 👈 ADD THIS
    required LegendItemBuilder buildLegendItem,
  }) {
    List<Widget> legendItems = [];

    // Always show ward boundary
    legendItems.add(buildLegendItem(Colors.black, "Ward Boundary"));
    legendItems.add(buildLegendItem(Colors.deepOrange.shade400, "Missing Road"));
    legendItems.add(buildLegendItem(Colors.yellow.shade700, "Search Highlight"));


    // Confirmed road
    legendItems.add(
      buildLegendItem(Colors.lightBlueAccent.shade200, "Updated Missing Road"),
    );

    legendItems.addAll([
      buildLegendItem(Colors.blueAccent.shade700, "Confirmed Road"),
      buildLegendItem(Colors.cyanAccent.shade700, "Road Width >= 12m"),
      buildLegendItem(Colors.deepPurpleAccent, "Updated Road"),
      buildLegendItem(Colors.black, "Road Not Exists"),
    ]);

    // Default legends when no priority selected
    if (selectedPriority.isEmpty) {
      legendItems.addAll([
        buildLegendItem(Colors.red, "Poor Condition"),
        buildLegendItem(Colors.yellow, "Moderate Condition"),
        buildLegendItem(Colors.green, "Good Condition"),
      ]);
    } else {
      if (selectedPriority.contains("VIP")) {
        legendItems.add(
          buildLegendItem(Colors.deepPurple.shade800, "Main Roads"),
        );
      }
      if (selectedPriority.contains("Bank")) {
        legendItems.add(buildLegendItem(Colors.brown.shade600, "Bank"));
      }
      if (selectedPriority.contains("Hospital")) {
        legendItems.add(buildLegendItem(Colors.teal.shade700, "Hospital"));
      }
      if (selectedPriority.contains("School")) {
        legendItems.add(buildLegendItem(Colors.indigo.shade700, "School"));
      }
      if (selectedPriority.contains("Poor")) {
        legendItems.add(
          buildLegendItem(Colors.red.shade700, "Poor Condition Roads"),
        );
      }
    }

    // point assets
    legendItems.add(const Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Text("Point Assets", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    ));
    legendItems.addAll([
      buildLegendItem(Colors.blue, "Manhole"),
      buildLegendItem(Colors.deepPurple, "Bus Stop"),
      buildLegendItem(Colors.green, "Green Median"),
      buildLegendItem(Colors.blueAccent, "Parking Area"),
      buildLegendItem(Colors.amber, "Road Signage"),
      buildLegendItem(Colors.redAccent, "Traffic Safety"),
      buildLegendItem(Colors.orangeAccent, "Pavement Distress"),
      buildLegendItem(Colors.purple, "Public Toilet"),
      buildLegendItem(Colors.yellow, "Electric Pole"),
      buildLegendItem(Colors.red, "Transformer"),
      buildLegendItem(Colors.lightBlue, "Street Light"),
      buildLegendItem(Colors.teal, "Telecom Box"),
    ]);

    return legendItems;
  }
}
