import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../constants/appconstants.dart';
import '../authentication_screen/ModernLoginPage.dart';
import 'OnboardingScreen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    navigateAfterDelay();
  }


  Future<void> navigateAfterDelay() async {
    await Future.delayed(Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    // ✅ Load user_id from SharedPreferences and assign to AppConstants
    AppConstants.currentUserId = prefs.getString('user_id') ?? '';
    Widget nextScreen = isLoggedIn ? OnboardingScreen() : ModernLoginPage();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF8E1),
      body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon / Emblem
                Image(
                  image: AssetImage('assets/images/nagar_vikas.png'),
                  width: 250,
                  height: 250,
                ),
                SizedBox(height: 20),
                // App Name
                Text(
                  "Nagar Vikas Uttar Pradesh",
                  style: TextStyle(
                    color: Color(0xFFFF9933),
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 60),
                SpinKitFadingCube(
                  color: Color(0xFFFF9933),
                  size: 40,
                )

              ],
            ),
          )
      ),

    );
  }
}




