// lib/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:hedieaty/services/auth.dart';
import '../services/database_helper.dart';
import 'home_page.dart';
import '../models/user_model.dart';
import 'sign_up_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController =
  TextEditingController(); // New controller for phone
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false; // Track password visibility
  bool _isLoading = false; // Track loading state

  final AuthService _authService = AuthService(); // Instantiate AuthService
  final dbHelper = DatabaseHelper();
  final userModel = UserModel();



  /// Handles user login
  Future<void> _login(BuildContext context) async {
    String email = _emailController.text.trim();
    String phone = _phoneController.text.trim();
    String password = _passwordController.text.trim();

    // Input validation
    if ((email.isEmpty && phone.isEmpty) || password.isEmpty) {
      _showAlertDialog("Validation Error",
          "Please enter email or phone number and password.");
      return;
    }

    // Validate email format if email is provided
    if (email.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showAlertDialog(
          "Validation Error", "Please enter a valid email address.");
      return;
    }

    // Validate phone number format if phone is provided
    if (phone.isNotEmpty && !_authService.isValidPhoneNumber(phone)) {
      _showAlertDialog("Validation Error",
          "Enter a valid phone number in +201XXXXXXXXX format.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? loginError;

    if (email.isNotEmpty) {
      // Online login via AuthService
      loginError = await _authService.loginWithEmail(
        email: email,
        password: password,
      );

      if (loginError == null) {
        // Navigate to HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(email: email),
          ),
        );
      }
    } else {
      // Offline login via AuthService
      loginError = await _authService.loginWithPhone(
        phone: phone,
        password: password,
      );

      if (loginError == null) {
        // Retrieve user email from local SQLite
        var user = await userModel.getUserByPhone(phone);
        // Navigate to HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(email: user?['email']),
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });

    if (loginError != null) {
      _showAlertDialog("Login Error", loginError);
    }
  }

  /// Resets the user's password
  Future<void> _resetPassword(BuildContext context) async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showAlertDialog("Validation Error",
          "Please enter your email to reset your password.");
      return;
    }

    // Optionally, validate email format
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showAlertDialog(
          "Validation Error", "Please enter a valid email address.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? resetError = await _authService.resetPassword(email: email);

    setState(() {
      _isLoading = false;
    });

    if (resetError != null) {
      _showAlertDialog("Error", resetError);
    } else {
      _showAlertDialog(
        "Password Reset",
        "Password reset email sent. Please check your inbox.",
      );
    }
  }

  /// Shows an alert dialog with a title and message
  Future<void> _showAlertDialog(String title, String message) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Colors.deepPurple, // Updated AppBar color
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("Assets/background.jpg"),
            fit: BoxFit.cover, // Add a background image
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              elevation: 5,
              shadowColor: Colors.deepPurple.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User Avatar or Logo
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage('Assets/gift.jpg'),
                    ),
                    SizedBox(height: 20),
                    // Email Field
                    TextFormField(
                      key: const Key('email_field'),
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 20),
                    // Phone Number Field (Optional)
                    // TextFormField(
                    //   controller: _phoneController,
                    //   decoration: InputDecoration(
                    //     labelText: 'Phone +201XXXXXXXXX',
                    //     border: OutlineInputBorder(),
                    //     prefixIcon: Icon(Icons.phone),
                    //   ),
                    //   keyboardType: TextInputType.phone,
                    // ),
                    SizedBox(height: 20),
                    // Password Field
                    TextFormField(
                      key: const Key('password_field'),
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    // Login Button
                    _isLoading
                        ? CircularProgressIndicator()
                        : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('login_button'),
                        onPressed: () => _login(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          Colors.deepPurple, // Button background color
                          foregroundColor:
                          Colors.white, // Button text color
                          padding: EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Login',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    // Navigate to Sign Up Page
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => SignUpPage()),
                            );
                          },
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Reset Password Button
                    TextButton(
                      onPressed: () => _resetPassword(context),
                      child: Text('Forgot Password?'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
