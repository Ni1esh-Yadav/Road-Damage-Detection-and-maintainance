import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_damage_detector/screens/AdminDashboard.dart';
import 'package:road_damage_detector/screens/EngineerDashboard.dart';
import 'package:road_damage_detector/screens/home_page.dart';
import 'package:road_damage_detector/screens/login_screen.dart';

class SplashRouter extends StatefulWidget {
  @override
  _SplashRouterState createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final role = prefs.getString('user_role');

    if (!isLoggedIn || role == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } else {
      switch (role) {
        case 'admin':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => AdminDashboard()),
          );
          break;
        case 'engineer':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => EngineerDashboard()),
          );
          break;
        case 'user':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage()),
          );
          break;
        default:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
