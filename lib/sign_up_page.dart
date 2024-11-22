import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';
import 'login.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _image;

  /// Picks an image from the gallery
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
    }
  }

  /// Validates input fields
  String? _validateFields() {
    if (_usernameController.text.isEmpty) return "Username is required.";
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      return "Enter a valid email.";
    }
    if (_passwordController.text.isEmpty || _passwordController.text.length < 6) {
      return "Password must be at least 6 characters.";
    }
    if (_phoneController.text.isEmpty || _phoneController.text.length != 11) {
      return "Enter a valid phone number.";
    }
    return null;
  }

  /// Handles the sign-up process
  Future<void> _signUp() async {
    final dbHelper = DatabaseHelper();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final imagePath = _image?.path ?? '';

    final validationError = _validateFields();
    if (validationError != null) {
      _showAlertDialog("Validation Error", validationError);
      return;
    }

    // Check if user exists in the database
    final existingUser = await dbHelper.getUserByEmailOrPhone(email, phone);
    if (existingUser != null) {
      _showAlertDialog("Error", "Email or phone number already in use.");
      return;
    }

    try {
      // Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) {
        throw Exception("Failed to create user.");
      }

      await user.updateDisplayName(username);

      // Insert user into the local database
      await dbHelper.insertUser({
        'username': username,
        'email': email,
        'password': password,
        'phone': phone,
        'imagePath': imagePath,
      });

      await user.sendEmailVerification();
      _showAlertDialog(
        "Success",
        "A verification email has been sent to $email. Please verify before logging in.",
        isSuccess: true,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already in use.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password is too weak.';
      } else {
        errorMessage = 'An error occurred. Please try again.';
      }
      _showAlertDialog("Sign Up Error", errorMessage);
    } catch (e) {
      _showAlertDialog("Error", "An unexpected error occurred: $e");
    }
  }

  /// Shows an alert dialog
  Future<void> _showAlertDialog(String title, String message, {bool isSuccess = false}) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (isSuccess) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              }
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _image != null ? FileImage(_image!) : null,
                child: _image == null ? Icon(Icons.add_a_photo, size: 50) : null,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _signUp,
              child: Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
