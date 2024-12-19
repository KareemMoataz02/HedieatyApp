// user_model.dart
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

class UserModel {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // MARK: - Table Definitions

  /// Creates the 'users' table in the local SQLite database.
  Future<void> createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        phone TEXT UNIQUE NOT NULL,
        imagePath TEXT,
        synced INTEGER DEFAULT 0,
        fcm_token TEXT,
        notifications INTEGER DEFAULT 0
      )
    ''');
  }

  // MARK: - Password Operations

  /// Hashes a plain text password using BCrypt.
  String hashPassword(String plainPassword) {
    final String hashed = BCrypt.hashpw(plainPassword, BCrypt.gensalt());
    return hashed;
  }

  /// Verifies a plain text password against a hashed password using BCrypt.
  bool verifyPassword(String plainPassword, String hashedPassword) {
    return BCrypt.checkpw(plainPassword, hashedPassword);
  }

  // MARK: - User CRUD Operations with Sync

  /// Inserts a new user into the local database and syncs with Firebase.
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await _databaseHelper.database;

    // Hash the password before storing
    final String hashedPassword = hashPassword(user['password']);

    // Replace plain password with hashed password
    user['password'] = hashedPassword;

    try {
      // Ensure email and phone are in lowercase for consistency
      user['email'] = user['email'].toString().toLowerCase();
      user['phone'] = user['phone'].toString().toLowerCase();

      // Set synced flag to 0 (unsynced) before insertion
      user['synced'] = 0;

      // Insert the user into the local database
      final id = await db.insert(
        'users',
        user,
        conflictAlgorithm:
        ConflictAlgorithm
            .replace, // Replace if user already exists based on email/phone
      );

      bool connected = await _databaseHelper.isConnectedToInternet();
      if (connected) {
        try {
          // Sync the user data to Firebase using the SQLite id as Firestore document ID
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(id.toString()).set({
            ...user,
            'id': id, // Ensure Firestore includes the SQLite ID
          });

          // Update synced flag after successful upload
          await db.update(
            'users',
            {'synced': 1}, // Mark as synced
            where: 'id = ?',
            whereArgs: [id],
          );
        } catch (e) {
          print("Error syncing user to Firebase: $e");
          // Optionally implement retry logic or mark the record for later synchronization
        }
      } else {
        print("No internet connection. User data will be synced when online.");
      }

      return id; // Return the ID of the inserted user
    } catch (e) {
      // Handle database insertion errors
      print("Error inserting user into local database: $e");
      rethrow;
    }
  }

  /// Updates a user's password by their email and syncs with Firebase.
  Future<int> updateUserPasswordByEmail(String email,
      String newPassword) async {
    final db = await _databaseHelper.database;

    try {
      // Ensure email is in lowercase for consistency
      email = email.toLowerCase();

      // Hash the new password
      final String hashedPassword = hashPassword(newPassword);

      // Update the password where email matches
      int count = await db.update(
        'users',
        {'password': hashedPassword, 'synced': 0},
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [email],
      );

      if (count > 0) {
        bool connected = await _databaseHelper.isConnectedToInternet();
        if (connected) {
          try {
            // Query Firestore for the user with the matching email
            final firestore = FirebaseFirestore.instance;
            final querySnapshot = await firestore
                .collection('users')
                .where('email', isEqualTo: email)
                .get();

            if (querySnapshot.docs.isNotEmpty) {
              DocumentSnapshot userDoc = querySnapshot.docs.first;

              // Update the password in Firestore
              await firestore.collection('users').doc(userDoc.id).update({
                'password': hashedPassword,
                'synced': 1,
              });

              // Update local DB to mark as synced
              await db.update(
                'users',
                {'synced': 1},
                where: 'id = ?',
                whereArgs: [int.parse(userDoc.id)],
              );
            }
          } catch (e) {
            print('Error syncing password update to Firebase: $e');
            // Optionally implement retry logic or mark the record for later synchronization
          }
        } else {
          print(
              'No internet connection. Password update will be synced when online.');
        }
      } else {
        print('No user found with email $email.');
      }

      return count;
    } catch (e) {
      print('Error updating user password: $e');
      return 0; // Indicate failure
    }
  }

  /// Retrieves a user by email or phone, with fallback to Firebase.
  Future<Map<String, dynamic>?> getUserByEmailOrPhone(String email,
      String phone) async {
    final db = await _databaseHelper.database;
    final lowerCaseEmail = email.toLowerCase();
    final lowerCasePhone = phone.toLowerCase();

    try {
      // Query local database for user by email or phone
      final results = await db.query(
        'users',
        where: 'LOWER(email) = LOWER(?) OR LOWER(phone) = LOWER(?)',
        whereArgs: [lowerCaseEmail, lowerCasePhone],
      );

      if (results.isNotEmpty) {
        return results.first;
      } else {
        // If not found locally, check Firebase
        bool connected = await _databaseHelper.isConnectedToInternet();
        if (connected) {
          try {
            final firestore = FirebaseFirestore.instance;
            final querySnapshot = await firestore
                .collection('users')
                .where('email', isEqualTo: lowerCaseEmail)
                .get();

            if (querySnapshot.docs.isNotEmpty) {
              final firebaseUser = querySnapshot.docs.first.data();

              // Safely parse Firestore doc ID to int
              try {
                firebaseUser['id'] = int.parse(querySnapshot.docs.first.id);
              } catch (parseError) {
                print(
                    "Error parsing Firestore doc ID to int for doc ${querySnapshot
                        .docs.first.id}: $parseError");
                firebaseUser['id'] =
                0; // Assign a default value or handle appropriately
              }

              firebaseUser['synced'] = 1; // Mark as synced

              // Insert into local DB
              await db.insert('users', firebaseUser,
                  conflictAlgorithm: ConflictAlgorithm.replace);
              return firebaseUser;
            }
          } catch (e) {
            print("Error fetching user from Firebase: $e");
            // Optionally handle the error
          }
        }
      }
    } catch (e) {
      print("Error fetching user by email or phone: $e");
      rethrow;
    }

    return null;
  }

  /// Updates a user's FCM token in the local database and syncs with Firebase.
  Future<void> updateFcmTokenInDatabase(String newFcmToken,
      String email) async {
    final db = await _databaseHelper.database;

    try {
      // Ensure email is in lowercase for consistency
      email = email.toLowerCase();

      // Update the user's FCM token in the local database and mark as unsynced
      int affectedRows = await db.update(
        'users',
        {'fcm_token': newFcmToken, 'synced': 0},
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [email],
      );

      if (affectedRows > 0) {
        bool connected = await _databaseHelper.isConnectedToInternet();
        if (connected) {
          try {
            // Query Firestore for the user with the matching email
            final firestore = FirebaseFirestore.instance;
            final querySnapshot = await firestore
                .collection('users')
                .where('email', isEqualTo: email)
                .get();

            if (querySnapshot.docs.isNotEmpty) {
              DocumentSnapshot userDoc = querySnapshot.docs.first;

              // Update the FCM token in Firestore
              await firestore.collection('users').doc(userDoc.id).update({
                'fcm_token': newFcmToken,
                'synced': 1,
              });

              // Update local DB to mark as synced
              await db.update(
                'users',
                {'synced': 1},
                where: 'id = ?',
                whereArgs: [int.parse(userDoc.id)],
              );
            }
          } catch (e) {
            print('Error syncing FCM token to Firebase: $e');
            // Optionally implement retry logic or mark the record for later synchronization
          }
        } else {
          print(
              'No internet connection. FCM token update will be synced when online.');
        }
      } else {
        print('No user found with email $email.');
      }
    } catch (e) {
      print("Error updating FCM token in SQLite: $e");
    }
  }

  /// Updates a user's details and syncs with Firebase.
  Future<int> updateUser(int id, Map<String, dynamic> user) async {
    final db = await _databaseHelper.database;

    try {
      // If email is being updated, ensure it's in lowercase
      if (user.containsKey('email')) {
        user['email'] = user['email'].toString().toLowerCase();
      }
      // If phone is being updated, ensure it's in lowercase
      if (user.containsKey('phone')) {
        user['phone'] = user['phone'].toString().toLowerCase();
      }

      // Update the local database and mark as unsynced
      final rowsAffected = await db.update(
        'users',
        {...user, 'synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        bool connected = await _databaseHelper.isConnectedToInternet();
        if (connected) {
          try {
            // Sync the update to Firebase using the same ID
            final firestore = FirebaseFirestore.instance;
            await firestore.collection('users').doc(id.toString()).update({
              ...user,
            });

            // Mark as synced after successful sync
            await db.update(
              'users',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [id],
            );
          } catch (e) {
            print('Error syncing user update to Firebase: $e');
            // Optionally implement retry logic or mark the record for later synchronization
          }
        } else {
          print(
              'No internet connection. User update will be synced when online.');
        }
      } else {
        print('No user found with ID $id.');
      }

      return rowsAffected;
    } catch (e) {
      print('Error updating user: $e');
      return 0; // Indicate failure
    }
  }

  /// Deletes a user from the local database and syncs the deletion with Firebase.
  Future<int> deleteUser(int id) async {
    final db = await _databaseHelper.database;
    try {
      // Fetch the user to get the email before deletion
      final List<Map<String, dynamic>> users = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (users.isEmpty) {
        print('No user found with ID $id.');
        return 0;
      }

      final String email = users.first['email'].toString().toLowerCase();

      // Delete from local database
      final rowsAffected =
      await db.delete('users', where: 'id = ?', whereArgs: [id]);

      bool connected = await _databaseHelper.isConnectedToInternet();
      if (rowsAffected > 0 && connected) {
        try {
          // Sync deletion to Firebase
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(id.toString()).delete();
        } catch (e) {
          print("Error syncing user deletion to Firebase: $e");
          // Optionally implement retry logic or mark the deletion for later synchronization
        }
      }

      return rowsAffected;
    } catch (e) {
      print("Error deleting user: $e");
      return 0; // Indicate no rows were deleted in case of an error
    }
  }

  /// Retrieves all users from the local database and syncs with Firebase if connected.
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await _databaseHelper.database;
    List<Map<String, dynamic>> localUsers = [];

    try {
      // Fetch all users from local database
      localUsers = await db.query('users');

      bool connected = await _databaseHelper.isConnectedToInternet();
      if (connected) {
        try {
          // Fetch users from Firebase
          final firestore = FirebaseFirestore.instance;
          final querySnapshot = await firestore.collection('users').get();

          for (var doc in querySnapshot.docs) {
            final userData = doc.data();
            try {
              userData['id'] =
                  int.parse(doc.id); // Use Firestore doc ID as SQLite id
            } catch (parseError) {
              print(
                  "Error parsing Firestore doc ID to int for doc ${doc
                      .id}: $parseError");
              userData['id'] =
              0; // Assign a default value or handle appropriately
            }
            userData['synced'] = 1; // Mark as synced

            // Ensure email and phone are in lowercase
            if (userData.containsKey('email')) {
              userData['email'] = userData['email'].toString().toLowerCase();
            }
            if (userData.containsKey('phone')) {
              userData['phone'] = userData['phone'].toString().toLowerCase();
            }

            // Insert or replace into local database
            await db.insert('users', userData,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }

          // Refresh the localUsers list after syncing
          localUsers = await db.query('users');
        } catch (e) {
          print("Error syncing users from Firebase: $e");
          // Optionally handle the error or notify the user
        }
      }
    } catch (e) {
      print("Error fetching all users: $e");
      rethrow;
    }

    return localUsers;
  }

  /// Retrieves a user's email by their user ID, with fallback to Firebase.
  Future<String?> getEmailById(int id) async {
    final db = await _databaseHelper.database;
    try {
      final List<Map<String, dynamic>> results = await db.query(
        'users',
        columns: ['email'],
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isNotEmpty) {
        return results.first['email'] as String?;
      }

      // If not found locally, check Firebase
      bool connected = await _databaseHelper.isConnectedToInternet();
      if (connected) {
        try {
          final firestore = FirebaseFirestore.instance;
          final docSnapshot =
          await firestore.collection('users').doc(id.toString()).get();
          if (docSnapshot.exists) {
            final firebaseUser = docSnapshot.data()!;
            firebaseUser['id'] =
                int.parse(docSnapshot.id); // Use Firestore doc ID as SQLite id
            firebaseUser['synced'] = 1; // Mark as synced

            // Insert into local DB
            await db.insert('users', firebaseUser,
                conflictAlgorithm: ConflictAlgorithm.replace);
            return firebaseUser['email'];
          }
        } catch (e) {
          print("Error fetching user by ID from Firebase: $e");
          // Optionally handle the error
        }
      }
    } catch (e) {
      print("Error fetching email by ID: $e");
      rethrow;
    }

    return null;
  }

  /// Retrieves a user by email, with fallback to Firebase.
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await _databaseHelper.database;
    final lowerCaseEmail = email.toLowerCase();

    try {
      final List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [lowerCaseEmail],
      );

      if (results.isNotEmpty) {
        return results.first;
      }

      // If not found locally, check Firebase
      bool connected = await _databaseHelper.isConnectedToInternet();
      if (connected) {
        try {
          final firestore = FirebaseFirestore.instance;
          final querySnapshot = await firestore
              .collection('users')
              .where('email', isEqualTo: lowerCaseEmail)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final firebaseUser = querySnapshot.docs.first.data();
            try {
              firebaseUser['id'] = int.parse(querySnapshot.docs.first.id);
            } catch (parseError) {
              print(
                  "Error parsing Firestore doc ID to int for doc ${querySnapshot
                      .docs.first.id}: $parseError");
              firebaseUser['id'] =
              0; // Assign a default value or handle appropriately
            }
            firebaseUser['synced'] = 1; // Mark as synced

            // Insert into local DB
            await db.insert('users', firebaseUser,
                conflictAlgorithm: ConflictAlgorithm.replace);
            return firebaseUser;
          }
        } catch (e) {
          print("Error fetching user by email from Firebase: $e");
          // Optionally handle the error
        }
      }
    } catch (e) {
      print("Error fetching user by email: $e");
      rethrow;
    }

    return null;
  }

  /// Retrieves a user by phone number, with fallback to Firebase.
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    final db = await _databaseHelper.database;
    final lowerCasePhone = phone.toLowerCase();

    try {
      final List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'LOWER(phone) = LOWER(?)',
        whereArgs: [lowerCasePhone],
      );

      if (results.isNotEmpty) {
        return results.first;
      }

      // If not found locally, check Firebase
      bool connected = await _databaseHelper.isConnectedToInternet();
      if (connected) {
        try {
          final firestore = FirebaseFirestore.instance;
          final querySnapshot = await firestore
              .collection('users')
              .where('phone', isEqualTo: lowerCasePhone)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final firebaseUser = querySnapshot.docs.first.data();
            try {
              firebaseUser['id'] = int.parse(querySnapshot.docs.first.id);
            } catch (parseError) {
              print(
                  "Error parsing Firestore doc ID to int for doc ${querySnapshot
                      .docs.first.id}: $parseError");
              firebaseUser['id'] =
              0; // Assign a default value or handle appropriately
            }
            firebaseUser['synced'] = 1; // Mark as synced

            // Insert into local DB
            await db.insert('users', firebaseUser,
                conflictAlgorithm: ConflictAlgorithm.replace);
            return firebaseUser;
          }
        } catch (e) {
          print("Error fetching user by phone from Firebase: $e");
          // Optionally handle the error
        }
      }
    } catch (e) {
      print("Error fetching user by phone: $e");
      rethrow;
    }

    return null;
  }

  /// Updates a user's image by email and syncs with Firebase.
  Future<int> updateUserImageByEmail(String email, String base64Image) async {
    final db = await _databaseHelper.database;
    final lowerCaseEmail = email.toLowerCase();

    try {
      // Update the user's image and mark as unsynced
      int count = await db.update(
        'users',
        {'imagePath': base64Image, 'synced': 0},
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [lowerCaseEmail],
      );

      if (count > 0) {
        bool connected = await _databaseHelper.isConnectedToInternet();
        if (connected) {
          try {
            // Query Firestore for the user with the matching email
            final firestore = FirebaseFirestore.instance;
            final querySnapshot = await firestore
                .collection('users')
                .where('email', isEqualTo: lowerCaseEmail)
                .get();

            if (querySnapshot.docs.isNotEmpty) {
              DocumentSnapshot userDoc = querySnapshot.docs.first;

              // Update the imagePath in Firestore
              await firestore.collection('users').doc(userDoc.id).update({
                'imagePath': base64Image,
                'synced': 1,
              });

              // Mark as synced in local DB
              await db.update(
                'users',
                {'synced': 1},
                where: 'id = ?',
                whereArgs: [int.parse(userDoc.id)],
              );
            }
          } catch (e) {
            print('Error syncing image update to Firebase: $e');
            // Optionally implement retry logic or mark the record for later synchronization
          }
        } else {
          print(
              'No internet connection. Image update will be synced when online.');
        }
      } else {
        print('No user found with email $email.');
      }

      return count;
    } catch (e) {
      print('Error updating user image: $e');
      return 0; // Indicate failure
    }
  }

  /// Retrieves the notification status of a user from Firebase Firestore.
  Future<int?> getNotificationStatusFromFirebase(String email) async {
    try {
      // Check for an active internet connection
      bool isConnected = await _databaseHelper.isConnectedToInternet();
      if (!isConnected) {
        print("No internet connection. Cannot fetch notification status.");
        return null;
      }

      // Query the Firestore database for the user's document
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Extract the 'notifications' field from the document
        final docData = querySnapshot.docs.first.data();
        final int? notificationStatus = docData['notifications'] as int?;
        print("Notification status for $email: $notificationStatus");
        return notificationStatus;
      } else {
        print("No user found with email: $email");
        return null;
      }
    } catch (e) {
      print("Error fetching notification status from Firebase: $e");
      return null;
    }
  }

  /// Updates the notification status of a user in Firebase Firestore.
  Future<bool> updateNotificationStatusInFirebase(String email,
      int status) async {
    try {
      // Check for an active internet connection
      bool isConnected = await _databaseHelper.isConnectedToInternet();
      if (!isConnected) {
        print("No internet connection. Cannot update notification status.");
        return false;
      }

      // Query the Firestore database for the user's document
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Update the 'notifications' field in the document
        final docId = querySnapshot.docs.first.id;
        await firestore.collection('users').doc(docId).update({
          'notifications': status,
        });
        print("Notification status updated for $email to: $status");
        return true;
      } else {
        print("No user found with email: $email");
        return false;
      }
    } catch (e) {
      print("Error updating notification status in Firebase: $e");
      return false;
    }
  }

  /// Retrieves the FCM token for a user based on their email from the local SQLite database.
  Future<String?> getFcmTokenFromFirebase(String email) async {
    try {
      // Check for an active internet connection
      bool isConnected = await _databaseHelper.isConnectedToInternet();
      if (!isConnected) {
        print("No internet connection. Cannot fetch FCM token.");
        return null;
      }

      // Initialize Firestore instance
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Query the 'users' collection for the document with the matching email
      QuerySnapshot querySnapshot = await firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Extract the 'fcm_token' field from the document
        Map<String, dynamic> docData = querySnapshot.docs.first.data() as Map<
            String,
            dynamic>;

        // Ensure the 'fcm_token' exists and is a non-empty string
        if (docData.containsKey('fcm_token')) {
          String? fcmToken = docData['fcm_token'] as String?;
          if (fcmToken != null && fcmToken.isNotEmpty) {
            print("FCM Token for $email: $fcmToken");
            return fcmToken;
          } else {
            print("FCM Token is null or empty for $email.");
            return null;
          }
        } else {
          print("'fcm_token' field does not exist for $email.");
          return null;
        }
      } else {
        print("No user found with email: $email");
        return null;
      }
    } catch (e) {
      print("Error fetching FCM token from Firebase: $e");
      return null;
    }
  }
}