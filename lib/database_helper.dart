import 'package:bcrypt/bcrypt.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  // Getter for database instance
  Future<Database> get database async {
    if (_database == null) {
      _database = await _openDatabase();
    }
    return _database!;
  }

  Future<void> clearDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hedieaty.db');

    // Delete the database
    await deleteDatabase(path);
    print("Database cleared");
  }

  // Initialize database
  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hedieaty.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  // Create tables
  Future<void> _createTables(Database db) async {
    await _createUsersTable(db);
    await _createFriendsTable(db);
    await _createEventsTable(db);
    await _createGiftsTable(db);
    await _createPledgesTable(db);
  }

  // MARK: - Table Definitions

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE users (
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

  Future<void> _createFriendsTable(Database db) async {
    await db.execute('''
      CREATE TABLE friends (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        friend_id INTEGER NOT NULL,
        status TEXT DEFAULT 'pending',
        synced INTEGER DEFAULT 0,  
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(friend_id) REFERENCES users(id)
      )
    ''');
  }

  Future<void> _createEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        status TEXT NOT NULL,
        deadline TEXT NOT NULL,
        email TEXT NOT NULL,
        user_id INTEGER,
        synced INTEGER DEFAULT 0,  
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');
  }

  Future<void> _createGiftsTable(Database db) async {// Function to get the friend's email by their user_id (friend_id)
    Future<String?> getEmailById(int id) async {
      final db = await database;
      final results = await db.query(
        'users',
        where: 'LOWER(email) = LOWER(?)',
        whereArgs: [id],
      );

      // If the email is found in the local database
      if (results.isNotEmpty) {
        // Explicitly cast to String to match return type
        return results.first['email'] as String?;
      }
      // If not found locally, check Firebase
      if (results.isEmpty) {
        bool connected = await isConnectedToInternet();
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
            print("Error fetching user by email from Firebase: $e");
            // Optionally handle the error
          }
        }
      }
    }
    await db.execute('''
      CREATE TABLE gifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT,
        price REAL NOT NULL CHECK(price >= 0),
        status TEXT CHECK(status IN ('Available', 'Pledged')),
        image_path TEXT,
        event_id INTEGER NOT NULL,
        synced INTEGER DEFAULT 0,  
        FOREIGN KEY(event_id) REFERENCES events(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createPledgesTable(Database db) async {
    await db.execute('''
      CREATE TABLE pledges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userEmail TEXT NOT NULL,
        giftId INTEGER NOT NULL,
        pledgedAt TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0, 
        FOREIGN KEY(giftId) REFERENCES gifts(id) ON DELETE CASCADE
      )
    ''');
  }

  // MARK: - Connectivity Check

  // Future<bool> isConnectedToInternet() async {
  //   // Get the instance of the connection status singleton
  //   ConnectionStatusSingleton connectionStatus = ConnectionStatusSingleton.getInstance();
  //
  //   // Initialize connection status and start listening
  //   connectionStatus.initialize();
  //
  //   // Await the first value emitted by the connectionChange stream
  //   bool isConnected = await connectionStatus.connectionChange.first;
  //
  //   // Return the status (true or false)
  //   return isConnected;
  // }

  Future<bool> isConnectedToInternet() async {
    List<ConnectivityResult> results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile);
  }
  // MARK: - Users Operations with Sync

  String hashPassword(String plainPassword) {
    final String hashed = BCrypt.hashpw(plainPassword, BCrypt.gensalt());
    return hashed;
  }

  bool verifyPassword(String plainPassword, String hashedPassword) {
    return BCrypt.checkpw(plainPassword, hashedPassword);
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;

    final String hashedPassword = hashPassword(user['password']);

    // Replace plain password with hashed password
    user['password'] = hashedPassword;

    try {
      // Set synced flag to 0 (unsynced) before insertion
      user['synced'] = 0;

      // Insert the user into the local database
      final id = await db.insert(
        'users',
        user,
        conflictAlgorithm: ConflictAlgorithm
            .replace, // Replace if user already exists based on email/phone
      );

      bool connected = await isConnectedToInternet();
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
          print("Error syncing with Firebase: $e");
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

  Future<int> updateUserPasswordByEmail(String email, String newPassword) async {
    final db = await database;

    try {
      // Hash the new password
      final String hashedPassword = hashPassword(newPassword);

      // Update the password where email matches
      int count = await db.update(
        'users',
        {'password': hashedPassword, 'synced': 0},
        where: 'email = ?',
        whereArgs: [email],
      );

      if (count > 0) {
        bool connected = await isConnectedToInternet();
        if (connected) {
          try {
            // Fetch the user document from Firestore
            QuerySnapshot userSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: email)
                .get();

            if (userSnapshot.docs.isNotEmpty) {
              DocumentSnapshot userDoc = userSnapshot.docs.first;

              // Update the password in Firestore
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userDoc.id)
                  .update({'password': hashedPassword, 'synced': 1});

              // Update local DB to mark as synced
              await db.update(
                'users',
                {'synced': 1},
                where: 'email = ?',
                whereArgs: [email],
              );
            }
          } catch (e) {
            print('Error syncing password update to Firebase: $e');
            // Optionally implement retry logic or mark the record for later synchronization
          }
        } else {
          print('No internet connection. Password update will be synced when online.');
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

  Future<Map<String, dynamic>?> getUserByEmailOrPhone(
      String email, String phone) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'LOWER(email) = LOWER(?) OR LOWER(phone) = LOWER(?)',
      whereArgs: [email, phone],
    );

    // If not found locally, check Firebase
    if (results.isEmpty) {
      bool connected = await isConnectedToInternet();
      if (connected) {
        try {
          final firestore = FirebaseFirestore.instance;
          final querySnapshot = await firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final firebaseUser = querySnapshot.docs.first.data();
            firebaseUser['id'] = int.parse(querySnapshot
                .docs.first.id); // Use Firestore doc ID as SQLite id
            firebaseUser['synced'] = 1; // Mark as synced

            // Insert into local DB
            await db.insert('users', firebaseUser,
                conflictAlgorithm: ConflictAlgorithm.replace);
            return firebaseUser;
          }
        } catch (e) {
          print("Error fetching user from Firebase: $e");
        }
      }
    }

    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateFcmTokenInDatabase(String newFcmToken,String email) async {
    try {
      final db = await database;

      // Update the user's FCM token in the local database
      int affectedRows = await db.update(
        'users',
        {'fcm_token': newFcmToken}, // The new token to update
        where: 'email = ?', // The condition to identify the user
        whereArgs: [email],
      );

      if (affectedRows > 0) {
        print("FCM Token updated in SQLite database.");
      } else {
        print("No rows updated in SQLite.");
      }
    } catch (e) {
      print("Error updating token in SQLite: $e");
    }
  }

// Update a user and sync to Firebase
  Future<int> updateUser(int id, Map<String, dynamic> user) async {
    final db = await database;

    try {
      // Update the local database
      final rowsAffected = await db.update(
        'users',
        {...user, 'synced': 0}, // Set synced to 0 to indicate unsynced changes
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        bool connected = await isConnectedToInternet();
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

  Future<int> deleteUser(int id) async {
    final db = await database;
    final user = await db.query('users', where: 'id = ?', whereArgs: [id]);

    bool connected = await isConnectedToInternet();
    if (user.isNotEmpty && connected) {
      final email = user.first['email'];
      try {
        final firestore = FirebaseFirestore.instance;
        await firestore
            .collection('users')
            .doc(id.toString())
            .delete(); // Sync deletion to Firebase
      } catch (e) {
        print("Error deleting user from Firebase: $e");
        // Optionally implement retry logic or mark the deletion for later synchronization
      }
    }

    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    final localUsers = await db.query('users');

    // Sync from Firebase to local DB if needed
    bool connected = await isConnectedToInternet();
    if (connected) {
      try {
        final firestore = FirebaseFirestore.instance;
        final firebaseUsers = await firestore.collection('users').get();
        for (var doc in firebaseUsers.docs) {
          final user = doc.data();
          user['id'] = int.parse(doc.id); // Use Firestore doc ID as SQLite id
          user['synced'] = 1; // Mark as synced

          if (localUsers.where((u) => u['id'] == user['id']).isEmpty) {
            await db.insert('users', user,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      } catch (e) {
        print("Error syncing users from Firebase: $e");
        // Optionally handle the error
      }
    }

    return await db.query('users');
  }

  // Function to get the friend's email by their user_id (friend_id)
  Future<String?> getEmailById(int id) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'LOWER(email) = LOWER(?)',
      whereArgs: [id],
    );

    // If the email is found in the local database
    if (results.isNotEmpty) {
      // Explicitly cast to String to match return type
      return results.first['email'] as String?;
    }
    // If not found locally, check Firebase
    if (results.isEmpty) {
      bool connected = await isConnectedToInternet();
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
          print("Error fetching user by email from Firebase: $e");
          // Optionally handle the error
        }
      }
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'LOWER(email) = LOWER(?)',
      whereArgs: [email],
    );

    // If not found locally, check Firebase
    if (results.isEmpty) {
      bool connected = await isConnectedToInternet();
      if (connected) {
        try {
          final firestore = FirebaseFirestore.instance;
          final docSnapshot =
              await firestore.collection('users').doc(email).get();
          if (docSnapshot.exists) {
            final firebaseUser = docSnapshot.data()!;
            firebaseUser['id'] =
                int.parse(docSnapshot.id); // Use Firestore doc ID as SQLite id
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
    }

    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'LOWER(phone) = LOWER(?)',
      whereArgs: [phone],
    );

    // If not found locally, check Firebase
    if (results.isEmpty) {
      bool connected = await isConnectedToInternet();
      if (connected) {
        try {
          final firestore = FirebaseFirestore.instance;
          final querySnapshot = await firestore
              .collection('users')
              .where('phone', isEqualTo: phone)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final firebaseUser = querySnapshot.docs.first.data();
            firebaseUser['id'] = int.parse(querySnapshot
                .docs.first.id); // Use Firestore doc ID as SQLite id
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
    }

    return results.isNotEmpty ? results.first : null;
  }

  // database_helper.dart (Additional method)

  /// Updates a user's image by email
  Future<int> updateUserImageByEmail(String email, String base64Image) async {
    final db = await database;

    try {
      int count = await db.update(
        'users',
        {'imagePath': base64Image, 'synced': 0}, // Mark as unsynced
        where: 'email = ?',
        whereArgs: [email],
      );

      if (count > 0) {
        bool connected = await isConnectedToInternet();
        if (connected) {
          try {
            // Optionally, sync the image to Firestore or another backend service
            // Example: Upload to Firebase Storage and store the URL
          } catch (e) {
            print('Error syncing image update to Firebase: $e');
            // Optionally implement retry logic or mark the record for later synchronization
          }
        } else {
          print('No internet connection. Image update will be synced when online.');
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


  // MARK: - Friends Operations with Sync

  // Add a friend and sync to Firebase
  Future<void> sendFriendRequest(int userId, int friendId) async {
    final db = await database;

    // Check if the friend relationship already exists
    if (!await checkIfFriendExists(userId, friendId)) {
      var entry = {
        'user_id': userId,
        'friend_id': friendId,
        'status': 'pending',
        'synced': 0
      };

      int insertedId;
      try {
        // Insert the friend request into the local database
        insertedId = await db.insert('friends', entry);
      } catch (e) {
        print('Error inserting friend request into local database: $e');
        return;
      }

      // Check internet connectivity before syncing with Firebase
      bool connected = await isConnectedToInternet();
      if (connected) {
        try {
          // Sync to Firebase using the SQLite id as Firestore document ID
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('friends').doc(insertedId.toString()).set({
            ...entry,
            'id': insertedId, // Ensure Firestore includes the SQLite ID
          });

          // Mark the friend request as synced in the local database
          await db.update(
            'friends',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [insertedId],
          );
        } catch (e) {
          print('Error syncing friend request with Firebase: $e');
          // Optionally implement retry logic or mark the record for later synchronization
        }
      }
    }
  }

// Update the status of a friend request and sync to Firebase
  Future<void> updateFriendRequestStatus(
      int userId, int friendId, String status) async {
    final db = await database;

    try {
      // Update the original friend request status in the local database
      await db.update(
        'friends',
        {
          'status': status,
          'synced': 0
        }, // Mark as unsynced for later synchronization
        where: '(user_id = ? AND friend_id = ?)',
        whereArgs: [friendId, userId],
      );

      // Check if the reverse entry exists
      final reverseEntry = await db.query(
        'friends',
        where: '(user_id = ? AND friend_id = ?)',
        whereArgs: [userId, friendId],
      );
      print("DAH EL REVERSE ENTRY BTA3Y");
      print(reverseEntry);
      // If the reverse entry doesn't exist, create it
      if (reverseEntry.isEmpty) {
        print("IS EMPTYYYYYY");
        await db.insert(
          'friends',
          {
            'user_id': userId,
            'friend_id': friendId,
            'status': status,
            'synced': 0, // Mark as unsynced for synchronization
          },
        );
      } else {
        // If it exists, just update its status
        await db.update(
          'friends',
          {
            'status': status,
            'synced': 0
          }, // Mark as unsynced for later synchronization
          where: '(user_id = ? AND friend_id = ?)',
          whereArgs: [friendId, userId],
        );
      }

      // Check for Internet connectivity
      bool connected = await isConnectedToInternet();
      if (connected) {
        try {
          final firestore = FirebaseFirestore.instance;

          // Sync the original friend request to Firebase
          final records = await db.query(
            'friends',
            where: '(user_id = ? AND friend_id = ?)',
            whereArgs: [friendId, userId],
          );
          if (records.isNotEmpty) {
            final friendRequestId = records.first['id'];
            await firestore
                .collection('friends')
                .doc(friendRequestId.toString())
                .update({'status': status});
            await db.update(
              'friends',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [friendRequestId],
            );
          }

          // Sync the reverse entry to Firebase
          final reverseRecords = await db.query(
            'friends',
            where: '(user_id = ? AND friend_id = ?)',
            whereArgs: [userId, friendId],
          );
          print("REVERSE RECORDS FIREBASE");
          print(reverseRecords);
          if (reverseRecords.isNotEmpty) {
            final reverseFriendRequestId = reverseRecords.first['id'];
            await firestore
                .collection('friends')
                .doc(reverseFriendRequestId.toString())
                .set({
              'user_id': userId,
              'friend_id': friendId,
              'status': status,
              'id': reverseFriendRequestId,
            });
            await db.update(
              'friends',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [reverseFriendRequestId],
            );
          }
        } catch (e) {
          print('Error syncing friend request updates to Firestore: $e');
        }
      }
    } catch (e) {
      print('Error updating friend request status: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFriendRequests(int userId) async {
    final db = await database;

    // Fetch friend requests with user details from the local database
    List<Map<String, dynamic>> requests = await db.rawQuery('''
      SELECT f.id, f.user_id, u.username, u.email, u.imagePath
      FROM friends f
      INNER JOIN users u ON f.user_id = u.id
      WHERE f.friend_id = ? AND f.status = 'pending' AND f.synced = 1
    ''', [userId]);

    bool connected = await isConnectedToInternet();
    if (requests.isEmpty && connected) {
      try {
        // Fetch friend requests from Firebase
        final firestore = FirebaseFirestore.instance;
        final snapshot = await firestore
            .collection('friends')
            .where('friend_id', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .get();

        var firebaseRequests = snapshot.docs.map((doc) => doc.data()).toList();

        for (var request in firebaseRequests) {
          // Insert Firebase friend requests into the local database
          await db.insert(
            'friends',
            {
              'id': int.parse(
                  snapshot.docs.first.id), // Use Firestore doc ID as SQLite id
              'user_id': request['user_id'],
              'friend_id': request['friend_id'],
              'status': request['status'],
              'synced': 1, // Mark as synced
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // Fetch associated user details from Firebase if not in the local database
          var userSnapshot = await firestore
              .collection('users')
              .doc(request['user_id'].toString())
              .get();

          if (userSnapshot.exists) {
            var userData = userSnapshot.data();
            if (userData != null) {
              await db.insert(
                'users',
                {
                  'id': request['user_id'],
                  'username': userData['username'],
                  'email': userData['email'],
                  'phone': userData['phone'],
                  'password': userData[
                      'password'], // Ensure all required fields are included
                  'imagePath': userData['imagePath'],
                  'synced': 1,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }

        // Re-fetch the friend requests from the local database
        requests = await db.rawQuery('''
          SELECT f.id, f.user_id, u.username, u.email, u.imagePath
          FROM friends f
          INNER JOIN users u ON f.user_id = u.id
          WHERE f.friend_id = ? AND f.status = 'pending' AND f.synced = 1
        ''', [userId]);
      } catch (e) {
        print('Error fetching friend requests from Firebase: $e');
        // Optionally handle the error or notify the user
      }
    }

    return requests;
  }

  Future<List<Map<String, dynamic>>> getAcceptedFriendsByUserId(
      int userId) async {
    final db = await database;
    // Query that joins the users table on the friend_id and filters by user_id and status 'accepted'
    final List<Map<String, dynamic>> friends = await db.rawQuery('''
      SELECT u.id, u.username, u.email, u.phone, u.imagePath
      FROM friends f
      JOIN users u ON u.id = f.friend_id
      WHERE f.user_id = ? AND f.status = 'accepted'
    ''', [userId]);

    if (friends.isEmpty) {
      print("No accepted friends found for userId: $userId");
    } else {
      print("Friends list:");
      print(friends);
    }
    return friends;
  }

  Future<List<Map<String, dynamic>>> getFriendsByUserId(int userId) async {
    final db = await database;

    // Fetch from local database
    final localFriends = await db.rawQuery('''
      SELECT u.id, u.username, u.email, u.phone, u.imagePath
      FROM users u
      INNER JOIN friends f ON u.id = f.friend_id
      WHERE f.user_id = ? AND f.synced = 1
    ''', [userId]);

    bool connected = await isConnectedToInternet();
    if (localFriends.isEmpty && connected) {
      try {
        // Fallback to Firebase
        final firestore = FirebaseFirestore.instance;
        final querySnapshot = await firestore
            .collection('friends')
            .where('user_id', isEqualTo: userId)
            .get();

        final friends = querySnapshot.docs.map((doc) {
          final friendData = doc.data();
          friendData['id'] =
              int.parse(doc.id); // Use Firestore doc ID as friend ID
          return friendData;
        }).toList();

        // Sync Firebase data to local database
        for (var friend in friends) {
          await db.insert(
              'friends',
              {
                'id': friend['id'],
                'user_id': friend['user_id'],
                'friend_id': friend['friend_id'],
                'status': friend['status'],
                'synced': 1, // Mark as synced after inserting
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        return friends;
      } catch (e) {
        print('Error fetching friends from Firebase: $e');
        // Optionally handle the error
      }
    }

    return localFriends;
  }

  // Remove a friend and sync to Firebase
  Future<int> removeFriend(int id) async {
    final db = await database;

    // Delete from local database
    final rowsAffected = await db.delete(
      'friends',
      where: 'id = ?',
      whereArgs: [id],
    );

    bool connected = await isConnectedToInternet();
    if (rowsAffected > 0 && connected) {
      try {
        // Sync deletion to Firebase
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('friends').doc(id.toString()).delete();
      } catch (e) {
        print('Error syncing friend deletion to Firebase: $e');
        // Optionally implement retry logic or mark the deletion for later synchronization
      }
    }

    return rowsAffected;
  }

  // Check if a friend exists locally or in Firebase
  Future<bool> checkIfFriendExists(int userId, int friendId) async {
    final db = await database;
    bool exists = false;

    try {
      // Check if the friend exists in the local database and is synced
      final result = await db.query(
        'friends',
        where: 'user_id = ? AND friend_id = ? AND synced = 1',
        whereArgs: [userId, friendId],
      );

      bool connected = await isConnectedToInternet();
      if (result.isNotEmpty ||
          (connected && await _checkFirebaseFriendExists(userId, friendId))) {
        exists = true;
      }
    } catch (e) {
      print("Error checking if friend exists: $e");
      rethrow;
    }

    return exists;
  }

  // Helper function to check Firebase if friend exists
  Future<bool> _checkFirebaseFriendExists(int userId, int friendId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      // Assuming that each friend relationship has a unique id
      // You might need to adjust this based on how you store friend relationships
      // For simplicity, we check all friends of the user and see if any have friend_id == friendId
      final querySnapshot = await firestore
          .collection('friends')
          .where('user_id', isEqualTo: userId)
          .where('friend_id', isEqualTo: friendId)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking Firebase for friend existence: $e");
      return false;
    }
  }

  // MARK: - Events Operations with Sync

  // Insert event and sync to Firebase
  Future<int> insertEvent(Map<String, dynamic> event) async {
    final db = await database;
    int eventId = 0;

    try {
      // Set synced flag to 0 (unsynced) before insertion
      event['synced'] = 0;
      eventId = await db.insert('events', event);

      bool connected = await isConnectedToInternet();
      if (connected) {
        try {
          // Sync to Firebase using the SQLite id as Firestore document ID
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('events').doc(eventId.toString()).set({
            ...event,
            'id': eventId, // Ensure Firestore includes the SQLite ID
          });

          // Update the synced flag in the local database after syncing with Firebase
          await db.update(
            'events',
            {'synced': 1}, // Set the synced flag to 1
            where: 'id = ?',
            whereArgs: [eventId],
          );
        } catch (e) {
          print("Error syncing event to Firebase: $e");
          // Optionally implement retry logic or mark the record for later synchronization
        }
      }
    } catch (e) {
      print("Error inserting event: $e");
      rethrow;
    }

    return eventId;
  }

  // Update event and sync to Firebase
// Update an event and sync to Firebase
  Future<int> updateEvent(int id, Map<String, dynamic> event) async {
    final db = await database;

    try {
      // Update the local database
      final rowsAffected = await db.update(
        'events',
        {...event, 'synced': 0}, // Set synced to 0 to indicate unsynced changes
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        bool connected = await isConnectedToInternet();
        if (connected) {
          try {
            // Sync the update to Firebase using the same ID
            final firestore = FirebaseFirestore.instance;
            await firestore.collection('events').doc(id.toString()).update({
              ...event,
            });

            // Mark as synced after successful sync
            await db.update(
              'events',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [id],
            );
          } catch (e) {
            print('Error syncing event update to Firebase: $e');
            // Optionally implement retry logic or mark the record for later synchronization
          }
        } else {
          print(
              'No internet connection. Event update will be synced when online.');
        }
      } else {
        print('No event found with ID $id.');
      }

      return rowsAffected;
    } catch (e) {
      print('Error updating event: $e');
      return 0; // Indicate failure
    }
  }

  // Delete event and sync to Firebase
  Future<int> deleteEvent(int id) async {
    final db = await database;

    try {
      // Delete from local database
      final rowsAffected =
          await db.delete('events', where: 'id = ?', whereArgs: [id]);

      bool connected = await isConnectedToInternet();
      if (rowsAffected > 0 && connected) {
        try {
          // Sync deletion to Firebase
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('events').doc(id.toString()).delete();

          // No need to mark as synced since it's deleted
        } catch (e) {
          print("Error syncing event deletion to Firebase: $e");
          // Optionally implement retry logic or mark the deletion for later synchronization
        }
      }

      return rowsAffected;
    } catch (e) {
      print("Error deleting event: $e");
      return 0; // Indicate no rows were deleted in case of an error
    }
  }

  // Get events by email, with fallback to Firebase
  Future<List<Map<String, dynamic>>> getEventsByEmail(String email) async {
    final db = await database;
    List<Map<String, dynamic>> localEvents = [];

    try {
      // Fetch synced events from local database
      localEvents = await db.query(
        'events',
        where: 'email = ? AND synced = 1',
        whereArgs: [email],
      );

      bool connected = await isConnectedToInternet();
      if (localEvents.isEmpty && connected) {
        try {
          // Fallback to Firebase
          final firestore = FirebaseFirestore.instance;
          final querySnapshot = await firestore
              .collection('events')
              .where('email', isEqualTo: email.toLowerCase())
              .get();

          final events = querySnapshot.docs.map((doc) {
            final eventData = doc.data();
            eventData['id'] =
                int.parse(doc.id); // Use Firestore doc ID as event ID
            return eventData;
          }).toList();

          // Sync Firebase data to local database
          for (var event in events) {
            await db.insert('events', event,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }

          return events;
        } catch (e) {
          print("Error fetching events from Firebase: $e");
          // Optionally handle the error or notify the user
        }
      }
    } catch (e) {
      print("Error fetching events by email: $e");
      rethrow;
    }

    return localEvents;
  }

  Future<String?> getEventOwnerEmail(int eventId) async {
    final db = await database; // Correct use of await to get the database instance
    try {
      final List<Map<String, dynamic>> results = await db.query(
        'events',
        columns: ['email'], // Ensure 'email' is the correct column name
        where: 'id = ?',
        whereArgs: [eventId],
      );
      if (results.isNotEmpty) {
        return results.first['email'];
      }
    } catch (e) {
      print("Error fetching event owner email: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> getEventById(int eventId) async {
    final db = await database;
    Map<String, dynamic>? event;

    try {
      // Fetch from local database
      final result = await db.query(
        'events',
        where: 'id = ? AND synced = 1', // Only fetch synced events
        whereArgs: [eventId],
      );

      if (result.isNotEmpty) {
        event = result.first;
      }

      if (event == null) {
        // Fallback to Firebase
        final firestore = FirebaseFirestore.instance;
        bool connected = await isConnectedToInternet();

        if (connected) {
          try {
            final docSnapshot = await firestore
                .collection('events')
                .doc(eventId.toString())
                .get();

            if (docSnapshot.exists) {
              event = docSnapshot.data();
              event!['id'] =
                  int.parse(docSnapshot.id); // Use Firestore doc ID as event ID
              event['synced'] = 1; // Mark as synced

              // Sync Firebase data to local database
              await db.insert('events', event,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          } catch (e) {
            print("Error fetching event by ID from Firebase: $e");
            // Optionally handle the error
          }
        }
      }
    } catch (e) {
      print("Error fetching event by ID: $e");
      rethrow;
    }

    return event;
  }

  // MARK: - Gifts Operations with Sync

  // Insert gift and sync to Firebase
  Future<int> insertGift(Map<String, dynamic> gift) async {
    final db = await database;

    // Set synced flag to 0 (unsynced) before insertion
    gift['synced'] = 0;

    // Insert into local database
    final giftId = await db.insert('gifts', gift);

    bool connected = await isConnectedToInternet();
    if (connected) {
      try {
        // Sync to Firebase using the SQLite id as Firestore document ID
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('gifts').doc(giftId.toString()).set({
          ...gift,
          'id': giftId, // Ensure Firestore includes the SQLite ID
        });

        // Update the synced flag in the local database after syncing with Firebase
        await db.update(
          'gifts',
          {'synced': 1}, // Set the synced flag to 1
          where: 'id = ?',
          whereArgs: [giftId],
        );
      } catch (e) {
        print('Error syncing gift to Firebase: $e');
        // Optionally implement retry logic or mark the record for later synchronization
      }
    }

    return giftId;
  }

  // Get gifts by event ID, with fallback to Firebase
  Future<List<Map<String, dynamic>>> getGiftsByEventId(int eventId) async {
    final db = await database;

    // Fetch only synced gifts from local database
    final localGifts = await db.query(
      'gifts',
      where: 'event_id = ? AND synced = 1', // Only fetch synced gifts
      whereArgs: [eventId],
      orderBy: 'name ASC',
    );

    bool connected = await isConnectedToInternet();
    if (localGifts.isEmpty && connected) {
      try {
        // Fallback to Firebase
        final firestore = FirebaseFirestore.instance;
        final querySnapshot = await firestore
            .collection('gifts')
            .where('event_id', isEqualTo: eventId)
            .get();

        final gifts = querySnapshot.docs.map((doc) {
          final giftData = doc.data();
          giftData['id'] = int.parse(doc.id); // Use Firestore doc ID as gift ID
          return giftData;
        }).toList();

        // Sync Firebase data to local database
        for (var gift in gifts) {
          await db.insert('gifts', gift,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        return gifts;
      } catch (e) {
        print('Error fetching gifts from Firebase: $e');
        // Optionally handle the error or notify the user
      }
    }

    return localGifts;
  }

  // Update gift and sync to Firebase
  Future<int> updateGift(Map<String, dynamic> gift) async {
    final db = await database;

    if (!gift.containsKey('id')) {
      print('Error: Gift data must contain an "id" field.');
      return 0;
    }

    try {
      // Update in local database
      final rowsAffected = await db.update(
        'gifts',
        gift,
        where: 'id = ?',
        whereArgs: [gift['id']],
      );

      // Sync to Firebase
      bool connected = await isConnectedToInternet();
      if (rowsAffected > 0 && connected) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore
              .collection('gifts')
              .doc(gift['id'].toString())
              .update(gift);

          // Update the synced flag in the local database after syncing with Firebase
          await db.update(
            'gifts',
            {'synced': 1}, // Set the synced flag to 1
            where: 'id = ?',
            whereArgs: [gift['id']],
          );
        } catch (e) {
          print('Error syncing gift update to Firebase: $e');
          // Optionally implement retry logic or mark the record for later synchronization
        }
      }

      return rowsAffected;
    } catch (e) {
      print("Error updating gift: $e");
      return 0; // Indicate no rows were updated in case of an error
    }
  }

  // Delete gift and sync to Firebase
  Future<int> deleteGift(int id) async {
    final db = await database;

    try {
      // Delete from local database
      final rowsAffected = await db.delete(
        'gifts',
        where: 'id = ?',
        whereArgs: [id],
      );

      bool connected = await isConnectedToInternet();
      if (rowsAffected > 0 && connected) {
        try {
          // Sync deletion to Firebase
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('gifts').doc(id.toString()).delete();
        } catch (e) {
          print('Error syncing gift deletion to Firebase: $e');
          // Optionally implement retry logic or mark the deletion for later synchronization
        }
      }

      return rowsAffected;
    } catch (e) {
      print("Error deleting gift: $e");
      return 0; // Indicate no rows were deleted in case of an error
    }
  }

  // MARK: - Pledges Operations with Sync

  // Insert pledge and sync to Firebase
  Future<int> insertPledge(String userEmail, int giftId) async {
    final db = await database;

    // Data to insert
    final pledgeData = {
      'userEmail': userEmail,
      'giftId': giftId,
      'pledgedAt': DateTime.now().toIso8601String(),
      'synced': 0, // Set initial synced flag to 0
    };

    // Insert into local database
    final pledgeId = await db.insert('pledges', pledgeData);

    // Update the status of the gift to 'Pledged'
    await db.update(
      'gifts',
      {'status': 'Pledged'}, // Update the status to 'Pledged'
      where: 'id = ?', // Only update the gift with the corresponding giftId
      whereArgs: [giftId],
    );
    // Sync to Firebase
    bool connected = await isConnectedToInternet();
    if (connected) {
      try {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('pledges').doc(pledgeId.toString()).set({
          ...pledgeData,
          'id': pledgeId, // Ensure Firestore includes the SQLite ID
        });

        // Update the status in Firestore
        await firestore.collection('gifts').doc(giftId.toString()).update({
          'status': 'Pledged', // Update the status to 'Pledged'
        });

        // Update the synced flag in the local database after syncing with Firebase
        await db.update(
          'pledges',
          {'synced': 1}, // Set the synced flag to 1
          where: 'id = ?',
          whereArgs: [pledgeId],
        );
      } catch (e) {
        print('Error syncing pledge to Firebase: $e');
        // Optionally implement retry logic or mark the record for later synchronization
      }
    }

    return pledgeId;
  }

  // Get pledged gifts by user, with Firebase fallback
  Future<List<Map<String, dynamic>>> getPledgedGiftsByUser(
      String userEmail) async {
    final db = await database;

    // Fetch only synced pledges from the local database
    final localPledges = await db.rawQuery('''
      SELECT g.*, p.userEmail, p.pledgedAt
      FROM gifts g
      INNER JOIN pledges p ON g.id = p.giftId
      WHERE p.userEmail = ? AND p.synced = 1 
      ORDER BY p.pledgedAt DESC
    ''', [userEmail]);

    bool connected = await isConnectedToInternet();
    if (localPledges.isEmpty && connected) {
      try {
        // Fallback to Firebase
        final firestore = FirebaseFirestore.instance;
        final querySnapshot = await firestore
            .collection('pledges')
            .where('userEmail', isEqualTo: userEmail)
            .orderBy('pledgedAt', descending: true)
            .get();

        final pledges = querySnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = int.parse(doc.id); // Use Firestore doc ID as pledge ID
          return data;
        }).toList();

        // Sync Firebase data to local database
        for (var pledge in pledges) {
          await db.insert('pledges', pledge,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        return pledges;
      } catch (e) {
        if (e is FirebaseException && e.code == 'failed-precondition') {
          print(
              'Firestore index required. Please create the index using the provided URL.');
        } else {
          print('Error fetching pledges from Firebase: $e');
        }
        // Optionally handle the error or notify the user
      }
    }

    return localPledges;
  }

  // Remove pledge and sync to Firebase
// Remove a pledge and sync deletion to Firebase
  Future<int> removePledge(String userEmail, int giftId) async {
    final db = await database;

    try {
      // Find the pledge ID based on userEmail and giftId
      final List<Map<String, dynamic>> pledges = await db.query(
        'pledges',
        where: 'userEmail = ? AND giftId = ?',
        whereArgs: [userEmail, giftId],
      );

      if (pledges.isEmpty) {
        print('No pledge found for user $userEmail with gift ID $giftId.');
        return 0;
      }

      final int pledgeId = pledges.first['id'];

      // Delete the pledge from the local database
      final rowsAffected = await db.delete(
        'pledges',
        where: 'id = ?',
        whereArgs: [pledgeId],
      );

      // Update the status of the gift to 'Pledged'
      await db.update(
        'gifts',
        {'status': 'Available'}, // Update the status to 'Pledged'
        where: 'id = ?', // Only update the gift with the corresponding giftId
        whereArgs: [giftId],
      );

      if (rowsAffected > 0) {
        bool connected = await isConnectedToInternet();
        if (connected) {
          try {
            // Sync the deletion to Firebase using the same ID
            final firestore = FirebaseFirestore.instance;
            await firestore
                .collection('pledges')
                .doc(pledgeId.toString())
                .delete();

            // Update the status in Firestore
            await firestore.collection('gifts').doc(giftId.toString()).update({
              'status': 'Available', // Update the status to 'Pledged'
            });

            // Optionally, you can mark the deletion as synced, but since it's deleted, no action is needed
          } catch (e) {
            print('Error syncing pledge deletion to Firebase: $e');
            // Optionally implement retry logic or mark the record for later synchronization
          }
        } else {
          print(
              'No internet connection. Pledge deletion will be synced when online.');
        }
      }

      return rowsAffected;
    } catch (e) {
      print('Error removing pledge: $e');
      return 0; // Indicate failure
    }
  }

  // MARK: - Synchronization Methods

  // Generic method to sync unsynced records from SQLite to Firestore
  Future<void> syncTableToFirebase(
      String tableName, String firestoreCollection) async {
    final db = await database;

    // Fetch unsynced records
    final unsyncedRecords = await db.query(
      tableName,
      where: 'synced = ?',
      whereArgs: [0],
    );

    if (unsyncedRecords.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    for (var record in unsyncedRecords) {
      try {
        final docId =
            record['id'].toString(); // Use SQLite id as Firestore doc ID
        final docRef = firestore.collection(firestoreCollection).doc(docId);
        batch.set(docRef, record);
      } catch (e) {
        print('Error preparing batch for $tableName: $e');
        // Optionally handle the error
      }
    }

    try {
      await batch.commit();
      // Mark all synced records as synced
      for (var record in unsyncedRecords) {
        await db.update(
          tableName,
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [record['id']],
        );
      }
    } catch (e) {
      print('Error committing batch for $tableName: $e');
      // Optionally implement retry logic
    }
  }

  // Generic method to sync records from Firestore to SQLite
  Future<void> syncTableFromFirebase(
      String tableName, String firestoreCollection) async {
    final db = await database;
    final firestore = FirebaseFirestore.instance;

    try {
      final snapshot = await firestore.collection(firestoreCollection).get();

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = int.parse(doc.id); // Convert Firestore doc ID to integer
          data['synced'] = 1; // Mark as synced

          await db.insert(
            tableName,
            data,
            conflictAlgorithm: ConflictAlgorithm.replace, // Avoid duplicates
          );
        } catch (e) {
          print('Error inserting $tableName from Firestore: $e');
          // Optionally handle the error
        }
      }
    } catch (e) {
      print('Error fetching $tableName from Firestore: $e');
      // Optionally handle the error
    }
  }

  // Synchronize all tables
  Future<void> synchronizeDatabases() async {
    if (!await isConnectedToInternet()) {
      print('No internet connection. Synchronization aborted.');
      return;
    }

    // Sync unsynced records to Firestore
    await syncTableToFirebase('users', 'users');
    await syncTableToFirebase('friends', 'friends');
    await syncTableToFirebase('events', 'events');
    await syncTableToFirebase('gifts', 'gifts');
    await syncTableToFirebase('pledges', 'pledges');

    // Sync Firestore records to SQLite
    await syncTableFromFirebase('users', 'users');
    await syncTableFromFirebase('friends', 'friends');
    await syncTableFromFirebase('events', 'events');
    await syncTableFromFirebase('gifts', 'gifts');
    await syncTableFromFirebase('pledges', 'pledges');

    print('Synchronization complete.');
  }

  // Initialize Firebase
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
  }

  // Optional: Listen to Firestore updates in real-time
  void listenToFirebaseUpdates() {
    FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) async {
      final db = await database;
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          try {
            final data = change.doc.data()!;
            data['id'] =
                int.parse(change.doc.id); // Use Firestore doc ID as SQLite id
            data['synced'] = 1;

            await db.insert(
              'users',
              data,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            print('Error inserting/updating user from Firestore: $e');
          }
        } else if (change.type == DocumentChangeType.removed) {
          try {
            await db.delete(
              'users',
              where: 'id = ?',
              whereArgs: [int.parse(change.doc.id)],
            );
          } catch (e) {
            print('Error deleting user from SQLite: $e');
          }
        }
      }
    });
  }
}
