import 'package:flutter/material.dart';

import '../RoadConditionScreen.dart';
import '../models/asset_system.dart';

class PointAssetSelectionScreen extends StatelessWidget {
  const PointAssetSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final assets = [
      {"title": "Manhole / Chamber", "icon": Icons.water_drop},
      {"title": "Street Light", "icon": Icons.light},
      {"title": "Transformer", "icon": Icons.electrical_services},
      {"title": "Electric Pole", "icon": Icons.power},
      {"title": "Sign Board", "icon": Icons.signpost},
      {"title": "Public Toilet", "icon": Icons.wc},
      {"title": "ATM / Bank", "icon": Icons.account_balance},
      {"title": "Bus Stop", "icon": Icons.directions_bus},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Point Asset Survey")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: assets.length,
        itemBuilder: (context, index) {
          final asset = assets[index];

          return Card(
            child: ListTile(
              leading: Icon(asset["icon"] as IconData),
              title: Text(asset["title"] as String),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoadConditionScreen(
                      system: AssetSystem.road,
                      pointAssetType: asset["title"] as String,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}