// lib/services/auth_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart'; // Ensure the correct relative path
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final DatabaseHelper _dbHelper;

  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    DatabaseHelper? dbHelper,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _dbHelper = dbHelper ?? DatabaseHelper();

  /// Logs in the user using email/password (Online)
  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with FirebaseAuth
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if email is verified
      User? user = userCredential.user;
      if (user == null || !user.emailVerified) {
        return "Please verify your email before logging in.";
      }

      // Update FCM Token in Firestore and local SQLite
      await _updateFcmToken(email);

      // Save login state in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('email', email);

      // Update local SQLite with the new password hash
      await _dbHelper.updateUserPasswordByEmail(email, password);

      return null; // Null indicates success
    } on FirebaseAuthException catch (e) {
      // Handle FirebaseAuth-specific errors
      switch (e.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'invalid-email':
          return 'The email address is not valid.';
        default:
          return 'An unexpected error occurred. Please try again.';
      }
    } catch (e) {
      // Handle other errors
      return "An unexpected error occurred: $e";
    }
  }

  /// Logs in the user using phone/password (Offline)
  Future<String?> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    try {
      // Retrieve user by phone number from local SQLite
      Map<String, dynamic>? user = await _dbHelper.getUserByPhone(phone);

      if (user == null) {
        return "No user found with the provided phone number.";
      }
      await _updateFcmToken(user['email']);

      String storedHashedPassword = user['password'];
      bool isPasswordValid = _dbHelper.verifyPassword(password, storedHashedPassword);

      if (!isPasswordValid) {
        return "Incorrect password.";
      }

      // Save login state in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('email', user['email']);

      // Navigate to HomePage is handled in the UI

      return null; // Null indicates success
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Resets the user's password
  Future<String?> resetPassword({required String email}) async {
    try {
      // Check if the email exists in Firestore
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .get();

      if (querySnapshot.docs.isEmpty) {
        return "No user found with the provided email address.";
      }

      // Send password reset email
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return null; // Null indicates success
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Updates the FCM token in Firestore and local SQLite
  Future<void> _updateFcmToken(String email) async {
    try {
      // Retrieve the current FCM token
      String? newFcmToken = await _messaging.getToken();

      if (newFcmToken == null) {
        print("FCM Token is null.");
        return;
      }

      // Query Firestore to find the user document based on email
      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        DocumentSnapshot userDoc = userSnapshot.docs.single;
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String storedFcmToken = userData['fcm_token'] ?? '';

        // If the token is different or doesn't exist, update it
        if (storedFcmToken.isEmpty || storedFcmToken != newFcmToken) {
          await _firestore.collection('users').doc(userDoc.id).set(
            {
              'fcm_token': newFcmToken,
            },
            SetOptions(merge: true),
          );
          print("FCM Token added/updated in Firestore.");

          // Update the local SQLite database
          await _dbHelper.updateFcmTokenInDatabase(newFcmToken, email);
        } else {
          print("FCM Token is the same. No update needed.");
        }
      } else {
        print("User document not found in Firestore.");
      }
    } catch (e) {
      print("Error updating FCM token: $e");
    }
  }

  /// Validates phone number format
  bool isValidPhoneNumber(String phone) {
    final RegExp phoneRegex = RegExp(r'^\+201\d{9}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Logs out the user
  Future<void> logout() async {
    await _firebaseAuth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('email');
  }

  /// Validates input fields
  String? validateFields({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    required String phone,
    required String? base64Image,
  }) {
    if (username.isEmpty) return "Username is required.";
    if (email.isEmpty || !email.contains('@')) {
      return "Enter a valid email.";
    }
    if (password.isEmpty || password.length < 6) {
      return "Password must be at least 6 characters.";
    }
    if (password != confirmPassword) {
      return "Passwords do not match.";
    }
    if (phone.isEmpty || !isValidPhoneNumber(phone)) {
      return "Enter a valid phone number in +201XXXXXXXXX format.";
    }
    if (base64Image == null || base64Image.isEmpty) {
      return "Please upload a profile image.";
    }
    return null;
  }

  /// Sign up process with phone verification
  Future<String?> signUp({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    required String phone,
    required String base64Image,
    required BuildContext context,
  }) async {
    // Validate fields
    String? validationError = validateFields(
      username: username,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      phone: phone,
      base64Image: base64Image,
    );

    if (validationError != null) {
      return validationError;
    }

    try {
      // Check if the user already exists
      final existingUser = await _dbHelper.getUserByEmailOrPhone(email, phone);
      if (existingUser != null) {
        return "Email or phone number already in use.";
      }

      // Create a Completer to wait for phone verification
      Completer<String?> completer = Completer<String?>();

      // Verify phone number
      _verifyPhoneNumber(phone, context, (String? error) async {
        if (error != null) {
          completer.complete(error);
          return;
        }

        try {
          // Firebase Authentication
          UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

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
            'imagePath': base64Image, // Store Base64 string
          });

          await user.sendEmailVerification();

          // Update FCM Token
          await _updateFcmToken(email);

          completer.complete(null); // Success
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            completer.complete('This email is already in use.');
          } else if (e.code == 'weak-password') {
            completer.complete('The password is too weak.');
          } else {
            completer.complete('An error occurred. Please try again.');
          }
        } catch (e) {
          completer.complete("An unexpected error occurred: $e");
        }
      });

      // Await the completer
      return await completer.future;
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }

  /// Verify phone number using Firebase
  void _verifyPhoneNumber(
      String phoneNumber, BuildContext context, Function(String?) onVerificationResult) {
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Automatically sign in when verification completes
        await FirebaseAuth.instance.signInWithCredential(credential);
        onVerificationResult(null); // No error
      },
      verificationFailed: (FirebaseAuthException e) {
        String errorMessage = e.message ?? "Phone verification failed.";
        _showAlertDialog(context, "Verification Error", errorMessage);
        onVerificationResult(errorMessage);
      },
      codeSent: (String verificationId, int? resendToken) {
        _showCodeInputDialog(context, verificationId, onVerificationResult);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Auto-retrieval timeout handling if needed
      },
    );
  }

  /// Show dialog to enter verification code
  void _showCodeInputDialog(
      BuildContext context, String verificationId, Function(String?) onVerificationResult) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
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
                  _showAlertDialog(context, "Error", "Verification code cannot be empty.");
                  return;
                }
                try {
                  PhoneAuthCredential credential = PhoneAuthProvider.credential(
                    verificationId: verificationId,
                    smsCode: code,
                  );
                  await FirebaseAuth.instance.signInWithCredential(credential);
                  Navigator.of(context).pop(); // Close the dialog
                  onVerificationResult(null); // No error
                } catch (e) {
                  _showAlertDialog(context, "Error", "Invalid verification code.");
                  onVerificationResult("Invalid verification code.");
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
  Future<void> _showAlertDialog(BuildContext context, String title, String message) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
  }
}
