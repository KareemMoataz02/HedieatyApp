import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'sign_up_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'database_helper.dart'; // Import DatabaseHelper

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); // New controller for phone
  final TextEditingController _passwordController = TextEditingController();
  final dbHelper = DatabaseHelper();
  bool _isPasswordVisible = false; // Track password visibility

  /// Checks and updates the FCM token in Firestore
  Future<void> _checkAndUpdateToken() async {
    try {
      // Check if the user is logged in
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("No user is logged in.");
        return; // Exit if no user is logged in
      }

      // Get the user's email
      String email = user.email ?? '';
      if (email.isEmpty) {
        print("User email is empty.");
        return;
      }

      // Print the email of the current user
      print("User Email: $email");

      // Retrieve the FCM token
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? newFcmToken = await messaging.getToken();

      if (newFcmToken != null) {
        // Query Firestore to find the user document based on email
        QuerySnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email) // Query by email
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          DocumentSnapshot userDoc = userSnapshot.docs.single;

          // Print the user document data
          print("User document data: ${userDoc.data()}");

          // Check if 'fcm_token' exists in the document, or set it if not
          var userData = userDoc.data() as Map<String, dynamic>;
          String storedFcmToken = userData['fcm_token'] ?? '';
          print("Stored token: $storedFcmToken");

          // If the token is different or doesn't exist, update it
          if (storedFcmToken.isEmpty || storedFcmToken != newFcmToken) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userDoc.id) // Use the Firestore document ID
                .set(
                {
                  'fcm_token': newFcmToken, // Add/update the FCM token
                },
                SetOptions(
                    merge:
                    true)); // Merge to avoid overwriting other fields
            print("FCM Token added/updated.");
            await dbHelper.updateFcmTokenInDatabase(newFcmToken,email);
          } else {
            print("FCM Token is the same. No update needed.");
          }
        } else {
          print("User document not found in Firestore.");
        }
      } else {
        print("FCM Token is null.");
      }
    } catch (e) {
      print("Error updating token: $e");
    }
  }

  /// Handles user login
  Future<void> _login(BuildContext context) async {
    String email = _emailController.text.trim();
    String phone = _phoneController.text.trim();
    String password = _passwordController.text.trim();

    // Input validation
    if ((email.isEmpty && phone.isEmpty) || password.isEmpty) {
      _showAlertDialog("Validation Error", "Please enter email or phone number and password.");
      return;
    }

    // Validate email format if email is provided
    if (email.isNotEmpty && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showAlertDialog("Validation Error", "Please enter a valid email address.");
      return;
    }

    // Validate phone number format if phone is provided
    if (phone.isNotEmpty && !_isValidPhoneNumber(phone)) {
      _showAlertDialog("Validation Error", "Enter a valid phone number in +201XXXXXXXXX format.");
      return;
    }

    // Instantiate DatabaseHelper
    final dbHelper = DatabaseHelper();

    try {
      UserCredential userCredential;

      if (email.isNotEmpty) {
        // Online login via FirebaseAuth
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Update FCM token in Firestore
        await _checkAndUpdateToken();
        print('FCM Token Updated');

        // Save login state in shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('email', email);

        User? user = userCredential.user;
        if (!user!.emailVerified) {
          _showAlertDialog("Error", "Please verify your account and try again.");
        } else {
          // Update local SQLite with the new password hash
          await dbHelper.updateUserPasswordByEmail(email, password);
          // Navigate to HomePage and pass the email
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(email: email),
            ),
          );
        }
      } else {
        // Offline login via local SQLite database
        // Retrieve user by phone number
        Map<String, dynamic>? user = await dbHelper.getUserByPhone(phone);

        if (user == null) {
          _showAlertDialog("Login Error", "No user found with the provided phone number.");
          return;
        }

        String storedHashedPassword = user['password'];
        bool isPasswordValid = dbHelper.verifyPassword(password, storedHashedPassword);

        if (!isPasswordValid) {
          _showAlertDialog("Login Error", "Incorrect password.");
          return;
        }

        // Save login state in shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('email', user['email']);

        // Navigate to HomePage and pass the email
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(email: user['email']),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid.';
      } else {
        errorMessage = 'An error occurred. Please try again.';
      }

      _showAlertDialog("Login Error", errorMessage);
    } catch (e) {
      _showAlertDialog("Error", "An unexpected error occurred: $e");
    }
  }

  /// Resets the user's password
  Future<void> _resetPassword(BuildContext context) async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showAlertDialog("Validation Error", "Please enter your email to reset your password.");
      return;
    }

    // Optionally, validate email format
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showAlertDialog("Validation Error", "Please enter a valid email address.");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      _showAlertDialog(
        "Password Reset",
        "Password reset email sent. Please check your inbox.",
      );
    } catch (e) {
      _showAlertDialog(
        "Error",
        "Failed to send password reset email. Please try again.",
      );
    }
  }

  /// Validates phone number format
  bool _isValidPhoneNumber(String phone) {
    final RegExp phoneRegex = RegExp(r'^\+201\d{9}$');
    return phoneRegex.hasMatch(phone);
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
            image: AssetImage("assets/background.jpg"),
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
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone +201XXXXXXXXX',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 20),
                    // Password Field
                    TextFormField(
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _login(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple, // Button background color
                          foregroundColor: Colors.white, // Button text color
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
                              MaterialPageRoute(builder: (context) => SignUpPage()),
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
