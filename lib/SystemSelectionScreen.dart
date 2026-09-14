import 'package:all_nagar_nigam_road_dir/widgets/PointAssetSelectionScreen.dart';
import 'package:flutter/material.dart';
import 'Screens/basic_screen/OnboardingScreen.dart';
import 'models/asset_system.dart';
import 'RoadConditionScreen.dart';

class SystemSelectionScreen extends StatelessWidget {
  const SystemSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8E1), // SAME as onboarding
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                Icon(Icons.layers, size: 90, color: Colors.orange.shade800),

                const SizedBox(height: 24),

                const Text(
                  "Select System",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "Choose which infrastructure you want to view",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),

                const Spacer(flex: 2),

                // ROAD SYSTEM BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.alt_route, color: Colors.white),
                    label: const Text(
                      "View Road System",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RoadConditionScreen(system: AssetSystem.road),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // DRAIN SYSTEM BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.water, color: Colors.white),
                    label: const Text(
                      "View Drainage System",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RoadConditionScreen(system: AssetSystem.drainage),
                        ),
                      );
                    },
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }


}
