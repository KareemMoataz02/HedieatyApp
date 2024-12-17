// lib/pages/sign_up_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hedieaty/services/auth.dart';
import 'login.dart';
import '../../services/image_converter.dart'; // Import ImageConverter

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController(); // Confirm password
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _base64Image; // Selected and converted profile image as Base64 string
  bool _isPasswordVisible = false; // State to track password visibility
  bool _isConfirmPasswordVisible =
  false; // State to track confirm password visibility
  bool _isLoading = false; // State to track loading during sign-up

  final AuthService _authService =
  AuthService(); // Instantiate AuthService
  final ImageConverter _imageConverter =
  ImageConverter(); // Instantiate ImageConverter

  /// Picks an image using ImageConverter
  Future<void> _pickImage() async {
    setState(() {
      _isLoading = true;
    });

    String? imageBase64 = await _imageConverter.pickAndCompressImageToString();
    if (imageBase64 != null) {
      setState(() {
        _base64Image = imageBase64;
      });
    } else {
      _showAlertDialog("Error", "Failed to pick and compress image.");
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Validates input fields using AuthService
  String? _validateFields() {
    return _authService.validateFields(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      confirmPassword: _confirmPasswordController.text.trim(),
      phone: _phoneController.text.trim(),
      base64Image: _base64Image,
    );
  }

  /// Sign up process by calling AuthService
  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    final validationError = _validateFields();
    if (validationError != null) {
      _showAlertDialog("Validation Error", validationError);
      return;
    }

    if (_base64Image == null || _base64Image!.isEmpty) {
      _showAlertDialog("Error", "Please upload a profile image.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? signUpError = await _authService.signUp(
      username: username,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      phone: phone,
      base64Image: _base64Image!,
      context: context,
    );

    setState(() {
      _isLoading = false;
    });

    if (signUpError != null) {
      _showAlertDialog("Sign Up Error", signUpError);
    } else {
      _showAlertDialog(
        "Success",
        "A verification email has been sent to $email. Please verify before logging in.",
        isSuccess: true,
      );
    }
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
              onTap: _pickImage, // Handle image picking on tap
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                _base64Image != null && _base64Image!.isNotEmpty
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
            _buildTextField(_usernameController, 'Username', Icons.person,
                keyboardType: TextInputType.text),
            SizedBox(height: 10),
            // Email Field
            _buildTextField(_emailController, 'Email', Icons.email,
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
                  backgroundColor:
                  Colors.deepPurple, // Button background color
                  foregroundColor:
                  Colors.white, // Button text color
                  padding:
                  EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType}) {
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
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            ),
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
              _isConfirmPasswordVisible
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
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
