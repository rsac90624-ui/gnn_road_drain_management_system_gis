import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/appconstants.dart';
import '../../utils/device_utils.dart';
import '../basic_screen/OnboardingScreen.dart';


class ModernLoginPage extends StatefulWidget {
  const ModernLoginPage({super.key});

  @override
  _ModernLoginPageState createState() => _ModernLoginPageState();
}

class _ModernLoginPageState extends State<ModernLoginPage> {
  final _formKey = GlobalKey<FormState>();


  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: const Text(
            "Login",
            style: TextStyle(color: Colors.white, fontSize: 25),
          ),
        ),
        backgroundColor: const Color(0xFFE65100), // Button color,
        elevation: 4,
      ),
      backgroundColor: const Color(0xFFFFF8E1), // Light yellow background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            color: const Color(0xFFFFF8E1), // Light yellow background
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    Image(
                      image: AssetImage('assets/images/nagar_vikas.png'),
                      width: 250,
                      height: 250,
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _usernameController,
                      decoration: _inputDecoration('Username'),
                      validator: (value) =>
                      value == null || value
                          .trim()
                          .isEmpty ? 'Enter username' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: _inputDecoration('Password'),
                      obscureText: true,
                      validator: (value) =>
                      value == null || value
                          .trim()
                          .isEmpty ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loginUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Login",
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );
  }



  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final url = Uri.parse(
        '${AppConstants.baseURL}api/roads_mobile/login_mobile',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      ).timeout(
        const Duration(seconds: 30),
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();

        final data = jsonDecode(response.body);

        // Save login status
        await prefs.setBool('isLoggedIn', true);

        // Save username
        await prefs.setString(
          'username',
          username,
        );

        // Get city from login response
        final cityValue =
        data['city']?.toString().trim().isNotEmpty == true
            ? data['city'].toString().trim()
            : data['nagarNigam']?.toString().trim().isNotEmpty == true
            ? data['nagarNigam'].toString().trim()
            : data['nagar_nigam']?.toString().trim().isNotEmpty == true
            ? data['nagar_nigam'].toString().trim()
            : data['schema']?.toString().trim().isNotEmpty == true
            ? data['schema'].toString().trim()
            : '';

        if (cityValue.isEmpty) {
          throw Exception(
            "City not found in login response",
          );
        }

        // Save city
        await prefs.setString(
          'city',
          cityValue,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OnboardingScreen(),
          ),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid credentials'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Server error: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connection failed: $e',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


}

