import 'package:flutter/material.dart';
import 'package:road_damage_detector/screens/AdminDashboard.dart';
import 'package:road_damage_detector/screens/EngineerDashboard.dart';
import 'package:road_damage_detector/screens/SplashRouter.dart';
import 'package:road_damage_detector/screens/home_page.dart';
import 'package:road_damage_detector/screens/login_screen.dart';
import 'package:road_damage_detector/services/auth_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ensures proper initialization before the app starts.
  WidgetsFlutterBinding.ensureInitialized();

  // final prefs = await SharedPreferences.getInstance();
  // await prefs.clear();

  // Check if the user is logged in
  final bool isLoggedIn = await AuthService.isLoggedIn();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({required this.isLoggedIn, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Road Damage Detector',
      debugShowCheckedModeBanner: false,
      // Define app routes
      routes: {
        '/home': (_) => HomePage(),
        '/admin': (_) => AdminDashboard(),
        '/engineer': (_) => EngineerDashboard(),
      },
      // If the user is logged in, navigate to SplashRouter; otherwise, show LoginScreen
      home: isLoggedIn ? SplashRouter() : LoginScreen(),
    );
  }
}
