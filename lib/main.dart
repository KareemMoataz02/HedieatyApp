import 'package:flutter/material.dart';
import 'profile_page.dart'; // Import the ProfilePage

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
      home: ProfilePage(), // Set the main page to ProfilePage
    );
  }
}
