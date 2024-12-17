// pledge_model.dart
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PledgeModel {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // MARK: - Table Definitions

  /// Creates the 'pledges' table in the local SQLite database.
  Future<void> createPledgesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pledges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userEmail TEXT NOT NULL,
        giftId INTEGER NOT NULL,
        pledgedAt TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0, 
        FOREIGN KEY(giftId) REFERENCES gifts(id) ON DELETE CASCADE
      )
    ''');
  }

  // MARK: - Pledges Operations with Sync

  /// Inserts a new pledge into the local database and syncs with Firebase.
  Future<int> insertPledge(String userEmail, int giftId) async {
    final db = await _databaseHelper.database;

    // Data to insert
    final pledgeData = {
      'userEmail': userEmail,
      'giftId': giftId,
      'pledgedAt': DateTime.now().toIso8601String(),
      'synced': 0, // Set initial synced flag to 0
    };

    // Insert into local database
    int pledgeId;
    try {
      pledgeId = await db.insert(
        'pledges',
        pledgeData,
        conflictAlgorithm: ConflictAlgorithm.replace, // Handle duplicates
      );
    } catch (e) {
      print('Error inserting pledge into local database: $e');
      return 0; // Indicate failure
    }

    // Update the status of the gift to 'Pledged'
    try {
      await db.update(
        'gifts',
        {'status': 'Pledged'}, // Update the status to 'Pledged'
        where: 'id = ?', // Only update the gift with the corresponding giftId
        whereArgs: [giftId],
      );
    } catch (e) {
      print('Error updating gift status to "Pledged": $e');
      // Optionally handle the error
    }

    // Check internet connectivity before syncing with Firebase
    bool connected = await _databaseHelper.isConnectedToInternet();
    if (connected) {
      try {
        // Sync to Firebase using the SQLite id as Firestore document ID
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('pledges').doc(pledgeId.toString()).set({
          ...pledgeData,
          'id': pledgeId, // Ensure Firestore includes the SQLite ID
        });

        // Update the status of the gift to 'Pledged' in Firestore
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
    } else {
      print('No internet connection. Pledge will be synced when online.');
    }

    return pledgeId;
  }

  /// Retrieves all pledged gifts for a specific [userEmail].
  /// If no local data is found and internet is available, fetches from Firebase.
  Future<List<Map<String, dynamic>>> getPledgedGiftsByUser(String userEmail) async {
    final db = await _databaseHelper.database;

    // Fetch only synced pledges from the local database
    final localPledges = await db.rawQuery('''
      SELECT g.*, p.userEmail, p.pledgedAt
      FROM gifts g
      INNER JOIN pledges p ON g.id = p.giftId
      WHERE p.userEmail = ? AND p.synced = 1 
      ORDER BY p.pledgedAt DESC
    ''', [userEmail]);

    bool connected = await _databaseHelper.isConnectedToInternet();
    if (localPledges.isEmpty && connected) {
      try {
        // Fetch pledges from Firebase
        final firestore = FirebaseFirestore.instance;
        final querySnapshot = await firestore
            .collection('pledges')
            .where('userEmail', isEqualTo: userEmail)
            .orderBy('pledgedAt', descending: true)
            .get();

        List<Map<String, dynamic>> pledges = [];

        for (var doc in querySnapshot.docs) {
          Map<String, dynamic> pledgeData = doc.data();

          // Safely parse Firestore doc ID to int
          try {
            pledgeData['id'] = int.parse(doc.id);
          } catch (parseError) {
            print(
                "Error parsing Firestore doc ID to int for doc ${doc.id}: $parseError");
            pledgeData['id'] = 0; // Assign a default value or handle appropriately
          }

          // Insert Firebase pledge into the local database
          await db.insert(
            'pledges',
            {
              'id': pledgeData['id'], // Use parsed Firestore doc ID as SQLite id
              'userEmail': pledgeData['userEmail'],
              'giftId': pledgeData['giftId'],
              'pledgedAt': pledgeData['pledgedAt'],
              'synced': 1, // Mark as synced
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          pledges.add(pledgeData);
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

  /// Removes a pledge based on [userEmail] and [giftId], and syncs the deletion with Firebase.
  Future<int> removePledge(String userEmail, int giftId) async {
    final db = await _databaseHelper.database;

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

      // Update the status of the gift to 'Available'
      try {
        await db.update(
          'gifts',
          {'status': 'Available'}, // Update the status to 'Available'
          where: 'id = ?', // Only update the gift with the corresponding giftId
          whereArgs: [giftId],
        );
      } catch (e) {
        print('Error updating gift status to "Available": $e');
        // Optionally handle the error
      }

      if (rowsAffected > 0) {
        bool connected = await _databaseHelper.isConnectedToInternet();
        if (connected) {
          try {
            // Sync the deletion to Firebase using the same ID
            final firestore = FirebaseFirestore.instance;
            await firestore.collection('pledges').doc(pledgeId.toString()).delete();

            // Update the status of the gift to 'Available' in Firestore
            await firestore.collection('gifts').doc(giftId.toString()).update({
              'status': 'Available', // Update the status to 'Available'
            });

            // Optionally, you can mark the deletion as synced, but since it's deleted, no action is needed
          } catch (e) {
            print('Error syncing pledge deletion to Firebase: $e');
            // Optionally implement retry logic or mark the deletion for later synchronization
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
}
