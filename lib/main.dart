import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'home_page.dart'; // Import the home page for navigation after login
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(HedieatyApp());
}

class HedieatyApp extends StatefulWidget {
  @override
  _HedieatyAppState createState() => _HedieatyAppState();
}

class _HedieatyAppState extends State<HedieatyApp> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      // Use ?? operator to handle null gracefully
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      setState(() {
        _isLoggedIn = isLoggedIn;
      });
    } catch (e) {
      // Log the error or handle it
      debugPrint("Error reading SharedPreferences: $e");
      setState(() {
        _isLoggedIn = false; // Default to logged-out state
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hedieaty',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _isLoggedIn ? HomePage() : LoginPage(), // Navigate based on login status
    );
  }
}
