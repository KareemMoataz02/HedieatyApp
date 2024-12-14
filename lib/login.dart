import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'sign_up_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false; // Track password visibility

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
                .set({
              'fcm_token': newFcmToken,
            }, SetOptions(merge: true)); // Update or create the token field
            print("FCM Token added/updated.");
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

  Future<void> _login(BuildContext context) async {
    if (_emailController.text
        .trim()
        .isEmpty || _passwordController.text
        .trim()
        .isEmpty) {
      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text('Validation Error'),
              content: Text('Please enter both email and password.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _checkAndUpdateToken();
      print('Added Token');

      // Save login state in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('email', _emailController.text.trim());

      // Navigate to HomePage and pass the email
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(email: _emailController.text.trim()),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'invalid-credential') {
        errorMessage = 'Wrong Email or Password';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid.';
      } else {
        errorMessage = 'An error occurred. Please try again.';
      }

      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text('Login Error'),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _resetPassword(BuildContext context) async {
    if (_emailController.text
        .trim()
        .isEmpty) {
      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text('Validation Error'),
              content: Text('Please enter your email to reset your password.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailController.text.trim());

      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text('Password Reset'),
              content: Text(
                  'Password reset email sent. Please check your inbox.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text('Error'),
              content: Text(
                  'Failed to send password reset email. Please try again.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
      );
    }
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
            // Add a background image
            fit: BoxFit.cover,
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
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage('Assets/gift.jpg'),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons
                                .visibility_off,
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
                    ElevatedButton(
                      onPressed: () => _login(context),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white, backgroundColor: Colors.deepPurple, // Button text color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Login'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignUpPage()),
                        );
                      },
                      child: Text('Don\'t have an account? Sign Up'),
                    ),
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
