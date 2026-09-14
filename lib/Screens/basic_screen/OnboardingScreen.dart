import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../SystemSelectionScreen.dart';
import '../authentication_screen/ModernLoginPage.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String nagarNigam = "city"; // default
  @override
  void initState() {
    super.initState();
    _loadCityName();
  }

  String formatCityName(String raw) {
    final map = {
      "aligarh": "Aligarh Nagar Nigam",
      "kanpur": "Kanpur Nagar Nigam",
      // Lucknow variants
      // "lko_nn": "Lucknow Nagar Nigam",
      "lucknow": "Lucknow Nagar Nigam",
      "ayodhya": "Ayodhya Nagar Nigam",
      "agra": "Agra Nagar Nigam",
      "gorakhpur": "Gorakhpur Nagar Nigam",
      "shahjahanpur": "Shahjahanpur Nagar Nigam",
      "moradabad": "Moradabad Nagar Nigam",
      "ghaziabad_nn": "Ghaziabad Nagar Nigam",
      "meerut": "Meerut Nagar Nigam",
      "bareilly": "Bareilly Nagar Nigam",
      "mathura": "Mathura Nagar Nigam",
      "firozabad": "Firozabad Nagar Nigam",
      "jhansi": "Jhansi Nagar Nigam",
      "prayagraj": "Prayagraj Nagar Nigam",
      "saharanpur": "Saharanpur Nagar Nigam",
      "varanasi": "Varanasi Nagar Nigam",



    };

    return map[raw] ?? raw;
  }

  Future<void> _loadCityName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String saved = prefs.getString('city') ?? "city";
      nagarNigam = formatCityName(saved);
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => ModernLoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1), // Light yellow background
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  Image.asset(
                    'assets/images/map_icon_img.png', // Replace with actual asset path
                    height: 150,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome to\n$nagarNigam',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: const [
                      Icon(Icons.map, color: Colors.black54),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Track your location and nearby roads in real-time',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Icon(Icons.location_city, color: Colors.black54),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Verify property, road assets, and utilities with ease',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100), // Deep orange
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SystemSelectionScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Get Started',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Logout button in top-right
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _logout(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
