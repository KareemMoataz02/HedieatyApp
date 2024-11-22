import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'home_page.dart';
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
  String? _email;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      String? email = prefs.getString('email');

      setState(() {
        _isLoggedIn = isLoggedIn;
        _email = email;
      });
    } catch (e) {
      debugPrint("Error reading SharedPreferences: $e");
      setState(() {
        _isLoggedIn = false;
        _email = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('IsLoggedIn: $_isLoggedIn, Email: $_email');
    return MaterialApp(
      title: 'Hedieaty',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _isLoggedIn && _email != null
          ? HomePage(email: _email ?? "Guest") // Fallback for null
          : LoginPage(),
    );
  }
}
