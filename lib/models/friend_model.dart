// friend_model.dart
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendModel {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // MARK: - Table Definitions

  /// Creates the 'friends' table in the local SQLite database.
  Future<void> createFriendsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS friends (
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

  // MARK: - Friends Operations with Sync

  /// Sends a friend request from [userId] to [friendId] and syncs with Firebase.
  Future<void> sendFriendRequest(int userId, int friendId) async {
    final db = await _databaseHelper.database;

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
      bool connected = await _databaseHelper.isConnectedToInternet();
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
            {'synced': 1}, // Set the synced flag to 1
            where: 'id = ?',
            whereArgs: [insertedId],
          );
        } catch (e) {
          print('Error syncing friend request with Firebase: $e');
          // Optionally implement retry logic or mark the record for later synchronization
        }
      } else {
        print('No internet connection. Friend request will be synced when online.');
      }
    } else {
      print('Friend request already exists.');
    }
  }

  /// Updates the status of a friend request between [userId] and [friendId] and syncs with Firebase.
  Future<void> updateFriendRequestStatus(
      int userId, int friendId, String status) async {
    final db = await _databaseHelper.database;

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

      // If the reverse entry doesn't exist, create it
      if (reverseEntry.isEmpty) {
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
          whereArgs: [userId, friendId],
        );
      }

      // Check for Internet connectivity
      bool connected = await _databaseHelper.isConnectedToInternet();
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
          if (reverseRecords.isNotEmpty) {
            final reverseFriendRequestId = reverseRecords.first['id'];
            await firestore.collection('friends').doc(reverseFriendRequestId.toString()).set({
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
          // Optionally implement retry logic or mark the record for later synchronization
        }
      } else {
        print('No internet connection. Friend request status will be synced when online.');
      }
    } catch (e) {
      print('Error updating friend request status: $e');
    }
  }

  /// Retrieves all pending friend requests for [userId], including requester details.
  Future<List<Map<String, dynamic>>> getFriendRequests(int userId) async {
    final db = await _databaseHelper.database;

    // Fetch friend requests with user details from the local database
    List<Map<String, dynamic>> requests = await db.rawQuery('''
      SELECT f.id, f.user_id, u.username, u.email, u.imagePath
      FROM friends f
      INNER JOIN users u ON f.user_id = u.id
      WHERE f.friend_id = ? AND f.status = 'pending' AND f.synced = 1
    ''', [userId]);

    bool connected = await _databaseHelper.isConnectedToInternet();
    if (requests.isEmpty && connected) {
      try {
        // Fetch friend requests from Firebase
        final firestore = FirebaseFirestore.instance;
        final snapshot = await firestore
            .collection('friends')
            .where('friend_id', isEqualTo: userId)
            .where('status', isEqualTo: 'pending')
            .get();

        // Iterate over each document in the snapshot
        for (var doc in snapshot.docs) {
          var request = doc.data();

          // Safely parse Firestore doc ID to int
          try {
            request['id'] = int.parse(doc.id);
          } catch (parseError) {
            print(
                "Error parsing Firestore doc ID to int for doc ${doc.id}: $parseError");
            request['id'] = 0; // Assign a default value or handle appropriately
          }

          // Insert Firebase friend requests into the local database
          await db.insert(
            'friends',
            {
              'id': request['id'], // Use parsed Firestore doc ID as SQLite id
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
              // Ensure all required fields are included
              await db.insert(
                'users',
                {
                  'id': request['user_id'],
                  'username': userData['username'],
                  'email': userData['email'],
                  'phone': userData['phone'],
                  'password': userData['password'],
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

  /// Retrieves all accepted friends for [userId], with fallback to Firebase if connected.
  Future<List<Map<String, dynamic>>> getAcceptedFriendsByUserId(int userId) async {
    final db = await _databaseHelper.database;
    List<Map<String, dynamic>> friends = [];

    try {
      // First, attempt to fetch accepted friends from the local SQLite database
      friends = await db.rawQuery('''
      SELECT u.id, u.username, u.email, u.phone, u.imagePath
      FROM friends f
      JOIN users u ON u.id = f.friend_id
      WHERE f.user_id = ? AND f.status = 'accepted' AND f.synced = 1
    ''', [userId]);

      bool connected = await _databaseHelper.isConnectedToInternet();

      // If no friends are found locally and the device is connected to the internet, fetch from Firestore
      if (friends.isEmpty && connected) {
        try {
          final firestore = FirebaseFirestore.instance;

          // Query Firestore for accepted friends
          final querySnapshot = await firestore
              .collection('friends')
              .where('user_id', isEqualTo: userId)
              .where('status', isEqualTo: 'accepted')
              .get();

          // Iterate over each document in the Firestore snapshot
          for (var doc in querySnapshot.docs) {
            var friend = doc.data();

            // Safely parse Firestore doc ID to int
            try {
              friend['id'] = int.parse(doc.id);
            } catch (parseError) {
              print("Error parsing Firestore doc ID to int for doc ${doc.id}: $parseError");
              friend['id'] = 0; // Assign a default value or handle appropriately
            }

            // Insert the friend relationship into the local SQLite database
            await db.insert(
              'friends',
              {
                'id': friend['id'], // Use parsed Firestore doc ID as SQLite id
                'user_id': friend['user_id'],
                'friend_id': friend['friend_id'],
                'status': friend['status'],
                'synced': 1, // Mark as synced
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            // Fetch associated user details from Firestore
            var userSnapshot = await firestore
                .collection('users')
                .doc(friend['friend_id'].toString())
                .get();

            if (userSnapshot.exists) {
              var userData = userSnapshot.data();
              if (userData != null) {
                // Insert or update the user details in the local SQLite database
                await db.insert(
                  'users',
                  {
                    'id': friend['friend_id'],
                    'username': userData['username'],
                    'email': userData['email'],
                    'phone': userData['phone'],
                    'password': userData['password'], // Ensure all required fields are included
                    'imagePath': userData['imagePath'],
                    'synced': 1,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }

          // Re-fetch the accepted friends from the local database after syncing
          friends = await db.rawQuery('''
          SELECT u.id, u.username, u.email, u.phone, u.imagePath
          FROM friends f
          JOIN users u ON u.id = f.friend_id
          WHERE f.user_id = ? AND f.status = 'accepted' AND f.synced = 1
        ''', [userId]);

          print("Fetched accepted friends from Firestore and updated local database.");
        } catch (e) {
          print('Error fetching accepted friends from Firestore: $e');
          // Optionally handle the error, e.g., notify the user or log the error for debugging
        }
      }

      if (friends.isEmpty) {
        print("No accepted friends found for userId: $userId");
      } else {
        print("Accepted friends list:");
        print(friends);
      }
    } catch (e) {
      print('Error retrieving accepted friends: $e');
      // Optionally handle the error
    }

    return friends;
  }

  /// Retrieves all friends for [userId], with fallback to Firebase.
  Future<List<Map<String, dynamic>>> getFriendsByUserId(int userId) async {
    final db = await _databaseHelper.database;

    // Fetch from local database
    final localFriends = await db.rawQuery('''
      SELECT u.id, u.username, u.email, u.phone, u.imagePath
      FROM users u
      INNER JOIN friends f ON u.id = f.friend_id
      WHERE f.user_id = ? AND f.synced = 1
    ''', [userId]);

    bool connected = await _databaseHelper.isConnectedToInternet();
    if (localFriends.isEmpty && connected) {
      try {
        // Fallback to Firebase
        final firestore = FirebaseFirestore.instance;
        final querySnapshot = await firestore
            .collection('friends')
            .where('user_id', isEqualTo: userId)
            .get();

        // Iterate over each document in the snapshot
        for (var doc in querySnapshot.docs) {
          var friend = doc.data();

          // Safely parse Firestore doc ID to int
          try {
            friend['id'] = int.parse(doc.id);
          } catch (parseError) {
            print(
                "Error parsing Firestore doc ID to int for doc ${doc.id}: $parseError");
            friend['id'] = 0; // Assign a default value or handle appropriately
          }

          // Insert Firebase friend relationships into the local database
          await db.insert(
              'friends',
              {
                'id': friend['id'], // Use parsed Firestore doc ID as SQLite id
                'user_id': friend['user_id'],
                'friend_id': friend['friend_id'],
                'status': friend['status'],
                'synced': 1, // Mark as synced after inserting
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Fetch associated user details from Firebase if not in the local database
        for (var doc in querySnapshot.docs) {
          var friend = doc.data();
          var userSnapshot = await firestore
              .collection('users')
              .doc(friend['friend_id'].toString())
              .get();

          if (userSnapshot.exists) {
            var userData = userSnapshot.data();
            if (userData != null) {
              await db.insert(
                'users',
                {
                  'id': friend['friend_id'],
                  'username': userData['username'],
                  'email': userData['email'],
                  'phone': userData['phone'],
                  'password': userData['password'], // Ensure all required fields are included
                  'imagePath': userData['imagePath'],
                  'synced': 1,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }

        // Fetch the list of friends from the local database after syncing
        return await getFriendsByUserId(userId);
      } catch (e) {
        print('Error fetching friends from Firebase: $e');
        // Optionally handle the error
      }
    }

    return localFriends;
  }

  /// Removes a friend by [id] and syncs the deletion with Firebase.
  Future<int> removeFriend(int id) async {
    final db = await _databaseHelper.database;

    try {
      // Delete from local database
      final rowsAffected = await db.delete(
        'friends',
        where: 'id = ?',
        whereArgs: [id],
      );

      bool connected = await _databaseHelper.isConnectedToInternet();
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
    } catch (e) {
      print("Error deleting friend: $e");
      return 0; // Indicate no rows were deleted in case of an error
    }
  }

  /// Checks if a friend relationship exists between [userId] and [friendId], either locally or in Firebase.
  Future<bool> checkIfFriendExists(int userId, int friendId) async {
    final db = await _databaseHelper.database;
    bool exists = false;

    try {
      // Check if the friend exists in the local database and is synced
      final result = await db.query(
        'friends',
        where: 'user_id = ? AND friend_id = ? AND synced = 1',
        whereArgs: [userId, friendId],
      );

      bool connected = await _databaseHelper.isConnectedToInternet();
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

  /// Helper function to check Firebase if a friend relationship exists between [userId] and [friendId].
  Future<bool> _checkFirebaseFriendExists(int userId, int friendId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      // Query Firestore for the friend relationship
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
}
