import 'package:flutter/material.dart';

typedef LegendItemBuilder = Widget Function(Color color, String label);

class DynamicDrainLegend {

  static List<Widget> getLegendItems({
    required LegendItemBuilder buildLegendItem,
  }) {
    List<Widget> legendItems = [];

    // Ward boundary (optional but consistent)
    legendItems.add(
      buildLegendItem(Colors.black, "Ward Boundary"),
    );

    // Normal drain (default)
    legendItems.add(
      buildLegendItem(Colors.blue, "Drain"),
    );

    // Updated drain
    legendItems.add(
      buildLegendItem(Colors.green, "Updated Drain"),
    );

    return legendItems;
  }
}
