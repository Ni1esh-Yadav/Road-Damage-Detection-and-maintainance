import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String mode = 'user'; // 'user' or 'admin'
  String phone = '';
  String otp = '';
  String email = '';
  String password = '';
  String selectedRole = 'admin';
  bool otpSent = false;
  bool isRegister = false;

  final baseUrl = 'http://192.168.1.7:5000';

  Future<void> sendOtp() async {
    final res = await http.post(
      Uri.parse('$baseUrl/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"phone": phone}),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode == 200) {
      setState(() {
        otpSent = true;
      });
    } else {
      showSnack(json['error']);
    }
  }

  Future<void> verifyOtp() async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"phone": phone, "otp": otp}),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode == 200) {
      await saveUserSession(json['user']);
      navigateBasedOnRole(json['user']['role']);
    } else {
      showSnack(json['error']);
    }
  }

  Future<void> loginWithEmail() async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "password": password}),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode == 200) {
      await saveUserSession(json['user']);
      navigateBasedOnRole(json['user']['role']);
    } else {
      showSnack(json['error']);
    }
  }

  Future<void> registerAdmin() async {
    final res = await http.post(
      Uri.parse('$baseUrl/create-admin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "email": email,
        "password": password,
        "role": selectedRole,
      }),
    );
    final json = jsonDecode(res.body);
    if (res.statusCode == 200) {
      showSnack("Registered successfully. Please login.");
      setState(() {
        isRegister = false;
      });
    } else {
      showSnack(json['error']);
    }
  }

  Future<void> saveUserSession(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user['id']);
    await prefs.setString('user_role', user['role']);
    await prefs.setBool('is_logged_in', true);
  }

  void navigateBasedOnRole(String role) {
    if (role == 'user') {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (role == 'engineer') {
      Navigator.pushReplacementNamed(context, '/engineer');
    }
  }

  void showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ToggleButtons(
              isSelected: [mode == 'user', mode == 'admin'],
              onPressed: (index) {
                setState(() {
                  mode = index == 0 ? 'user' : 'admin';
                  otpSent = false;
                  isRegister = false;
                });
              },
              children: [Text('User'), Text('Admin/Engineer')],
            ),
            SizedBox(height: 20),
            if (mode == 'user') ...[
              TextField(
                decoration: InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                onChanged: (val) => phone = val,
              ),
              if (!otpSent)
                ElevatedButton(onPressed: sendOtp, child: Text('Send OTP')),
              if (otpSent) ...[
                TextField(
                  decoration: InputDecoration(labelText: 'OTP'),
                  onChanged: (val) => otp = val,
                ),
                ElevatedButton(onPressed: verifyOtp, child: Text('Verify OTP')),
              ],
            ] else ...[
              TextField(
                decoration: InputDecoration(labelText: 'Email'),
                onChanged: (val) => email = val,
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                onChanged: (val) => password = val,
              ),
              if (isRegister)
                DropdownButton<String>(
                  value: selectedRole,
                  items:
                      ['admin', 'engineer'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value[0].toUpperCase() + value.substring(1),
                          ),
                        );
                      }).toList(),
                  onChanged: (newVal) {
                    setState(() {
                      selectedRole = newVal!;
                    });
                  },
                ),
              ElevatedButton(
                onPressed: isRegister ? registerAdmin : loginWithEmail,
                child: Text(isRegister ? 'Register' : 'Login'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    isRegister = !isRegister;
                  });
                },
                child: Text(
                  isRegister
                      ? "Already have an account? Login"
                      : "Don't have an account? Register",
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
