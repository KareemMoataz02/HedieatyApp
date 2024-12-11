import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'home_page.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(HedieatyApp());
}

class HedieatyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hedieaty',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AppState(),
    );
  }
}

class AppState extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<AppState> {
  bool isLoggedIn = false;  // Track login status
  String? email;  // Track user email
  bool isConnected = false; // Track network connectivity status
  final dbHelper = DatabaseHelper();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    // Check login status and connectivity when app starts
    checkLoginStatus();
    listenToConnectivityChanges();
  }

  // Check the login status from SharedPreferences
  Future<void> checkLoginStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool loginStatus = prefs.getBool('isLoggedIn') ?? false;
      String? userEmail = prefs.getString('email');

      setState(() {
        isLoggedIn = loginStatus;
        email = userEmail;
      });
    } catch (e) {
      debugPrint("Error reading SharedPreferences: $e");
      setState(() {
        isLoggedIn = false;
        email = null;
      });
    }
  }

  // Listen for connectivity changes
  void listenToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      // Checking if the list contains mobile or Wi-Fi connectivity
      setState(() {
        isConnected = result.contains(ConnectivityResult.wifi) || result.contains(ConnectivityResult.mobile);
      });

      if (isConnected) {
        // Sync data when connectivity is restored
        synchronizeDatabases();
        checkLoginStatus();
      }
    });
  }

  // Synchronize data with Firebase
  Future<void> synchronizeDatabases() async {
    await dbHelper.synchronizeDatabases();  // Sync with local database and Firebase
  }

  @override
  Widget build(BuildContext context) {
    return isLoggedIn && email != null
        ? HomePage(email: email!) // Go to HomePage if logged in
        : LoginPage(); // Go to LoginPage if not logged in
  }

  @override
  void dispose() {
    // Cancel connectivity subscription to prevent memory leaks
    _connectivitySubscription.cancel();
    super.dispose();
  }
}
