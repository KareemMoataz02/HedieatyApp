import 'package:flutter/material.dart';
import 'login.dart'; // Import the ProfilePage

void main() {
  runApp(HedieatyApp());
}

class HedieatyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hedieaty',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(), // Set the main page to ProfilePage
    );
  }
}
