// sign_up_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'login.dart';
import 'image_converter.dart'; // Import ImageConverter

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Controllers for input fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // Confirm password
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _base64Image; // Selected and converted profile image as Base64 string
  bool _isPasswordVisible = false; // State to track password visibility
  bool _isConfirmPasswordVisible = false; // State to track confirm password visibility
  bool _isLoading = false; // State to track loading during sign-up

  final ImageConverter _imageConverter = ImageConverter(); // Instantiate ImageConverter
  final DatabaseHelper _dbHelper = DatabaseHelper(); // Instantiate DatabaseHelper

  /// Picks an image using ImageConverter
  Future<void> _pickImage() async {
    try {
      final imageString = await _imageConverter.pickAndCompressImageToString();
      if (imageString != null) {
        setState(() {
          _base64Image = imageString;
        });
      } else {
        _showAlertDialog("Error", "Failed to pick and compress image.");
      }
    } catch (e) {
      debugPrint("ImageConverter error: $e");
      _showAlertDialog("Error", "An unexpected error occurred while picking the image.");
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
    if (_passwordController.text != _confirmPasswordController.text) {
      return "Passwords do not match.";
    }
    if (_phoneController.text.isEmpty || !_isValidPhoneNumber(_phoneController.text)) {
      return "Enter a valid phone number in +201XXXXXXXXX format.";
    }
    if (_base64Image == null || _base64Image!.isEmpty) {
      return "Please upload a profile image.";
    }
    return null;
  }

  /// Validates phone number format
  bool _isValidPhoneNumber(String phone) {
    final RegExp phoneRegex = RegExp(r'^\+201\d{9}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Sign up process with phone verification
  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final imageBase64 = _base64Image ?? '';

    final validationError = _validateFields();
    if (validationError != null) {
      _showAlertDialog("Validation Error", validationError);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Check if the user already exists
    final existingUser = await _dbHelper.getUserByEmailOrPhone(email, phone);
    if (existingUser != null) {
      setState(() {
        _isLoading = false;
      });
      _showAlertDialog("Error", "Email or phone number already in use.");
      return;
    }

    // Verify phone number
    _verifyPhoneNumber(phone, () async {
      try {
        // Firebase Authentication
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        final user = userCredential.user;
        if (user == null) {
          throw Exception("Failed to create user.");
        }

        await user.updateDisplayName(username);

        // Insert user into the local database using createUser (which hashes the password)
        await _dbHelper.insertUser({
          'username': username,
          'email': email,
          'password': password, // Plain password; createUser will hash it
          'phone': phone,
          'imagePath': imageBase64, // Store Base64 string
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
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  /// Verify phone number using Firebase
  void _verifyPhoneNumber(String phoneNumber, Function onVerificationSuccess) {
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Automatically sign in when verification completes
        await FirebaseAuth.instance.signInWithCredential(credential);
        onVerificationSuccess();
      },
      verificationFailed: (FirebaseAuthException e) {
        String errorMessage = e.message ?? "Phone verification failed.";
        _showAlertDialog("Verification Error", errorMessage);
      },
      codeSent: (String verificationId, int? resendToken) {
        _showCodeInputDialog(verificationId, onVerificationSuccess);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  /// Show dialog to enter verification code
  void _showCodeInputDialog(String verificationId,
      Function onVerificationSuccess) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Enter Verification Code"),
          content: TextField(
            controller: codeController,
            decoration: InputDecoration(labelText: "Verification Code"),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.isEmpty) {
                  _showAlertDialog("Error", "Verification code cannot be empty.");
                  return;
                }
                try {
                  PhoneAuthCredential credential = PhoneAuthProvider.credential(
                    verificationId: verificationId,
                    smsCode: code,
                  );
                  await FirebaseAuth.instance.signInWithCredential(credential);
                  Navigator.of(context).pop(); // Close the dialog
                  onVerificationSuccess();
                } catch (e) {
                  _showAlertDialog("Error", "Invalid verification code.");
                }
              },
              child: Text("Verify"),
            ),
          ],
        );
      },
    );
  }

  /// Show an alert dialog
  Future<void> _showAlertDialog(String title, String message,
      {bool isSuccess = false}) async {
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
  void dispose() {
    // Dispose controllers to free resources
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
        backgroundColor: Colors.deepPurple, // Consistent color scheme
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: _base64Image != null && _base64Image!.isNotEmpty
                    ? MemoryImage(base64Decode(_base64Image!))
                    : AssetImage('assets/logo.jpeg') as ImageProvider,
                child: _base64Image == null || _base64Image!.isEmpty
                    ? Icon(
                  Icons.camera_alt,
                  size: 50,
                  color: Colors.grey[600],
                )
                    : null,
              ),
            ),
            SizedBox(height: 20),
            // Username Field
            _buildTextField(
                _usernameController, 'Username', Icons.person,
                keyboardType: TextInputType.text),
            SizedBox(height: 10),
            // Email Field
            _buildTextField(
                _emailController, 'Email', Icons.email,
                keyboardType: TextInputType.emailAddress),
            SizedBox(height: 10),
            // Password Field
            _buildPasswordField(),
            SizedBox(height: 10),
            // Confirm Password Field
            _buildConfirmPasswordField(),
            SizedBox(height: 10),
            // Phone Number Field
            _buildTextField(
                _phoneController, 'Phone +201XXXXXXXXX', Icons.phone,
                keyboardType: TextInputType.phone),
            SizedBox(height: 20),
            // Sign Up Button
            _isLoading
                ? CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _signUp(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple, // Button background color
                  foregroundColor: Colors.white, // Button text color
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            SizedBox(height: 10),
            // Navigate to Login Page
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Already have an account? "),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: Text(
                    "Login",
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a generic text field
  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  /// Builds the password field with visibility toggle
  Widget _buildPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: _passwordController,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  /// Builds the confirm password field with visibility toggle
  Widget _buildConfirmPasswordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: _confirmPasswordController,
        obscureText: !_isConfirmPasswordVisible,
        decoration: InputDecoration(
          labelText: 'Confirm Password',
          prefixIcon: Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(
                _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
            },
          ),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
