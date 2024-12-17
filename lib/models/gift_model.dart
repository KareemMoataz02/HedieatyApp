// gift_model.dart
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GiftModel {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // MARK: - Table Definitions

  /// Creates the 'gifts' table in the local SQLite database.
  Future<void> createGiftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gifts (
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

  // MARK: - Gifts Operations with Sync

  /// Inserts a new gift into the local database and syncs with Firebase.
  Future<int> insertGift(Map<String, dynamic> gift) async {
    final db = await _databaseHelper.database;

    // Set synced flag to 0 (unsynced) before insertion
    gift['synced'] = 0;

    // Insert into local database
    int giftId;
    try {
      giftId = await db.insert(
        'gifts',
        gift,
        conflictAlgorithm: ConflictAlgorithm.replace, // Handle duplicates
      );
    } catch (e) {
      print('Error inserting gift into local database: $e');
      return 0; // Indicate failure
    }

    // Check internet connectivity before syncing with Firebase
    bool connected = await _databaseHelper.isConnectedToInternet();
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
    } else {
      print('No internet connection. Gift will be synced when online.');
    }

    return giftId;
  }

  /// Retrieves all gifts associated with a specific [eventId].
  /// If no local data is found and internet is available, fetches from Firebase.
  Future<List<Map<String, dynamic>>> getGiftsByEventId(int eventId) async {
    final db = await _databaseHelper.database;

    // Fetch only synced gifts from local database
    List<Map<String, dynamic>> localGifts = await db.query(
      'gifts',
      where: 'event_id = ? AND synced = 1', // Only fetch synced gifts
      whereArgs: [eventId],
      orderBy: 'name ASC',
    );

    bool connected = await _databaseHelper.isConnectedToInternet();
    if (localGifts.isEmpty && connected) {
      try {
        // Fetch gifts from Firebase
        final firestore = FirebaseFirestore.instance;
        final querySnapshot = await firestore
            .collection('gifts')
            .where('event_id', isEqualTo: eventId)
            .get();

        List<Map<String, dynamic>> gifts = [];

        for (var doc in querySnapshot.docs) {
          Map<String, dynamic> giftData = doc.data();

          // Safely parse Firestore doc ID to int
          try {
            giftData['id'] = int.parse(doc.id);
          } catch (parseError) {
            print(
                "Error parsing Firestore doc ID to int for doc ${doc.id}: $parseError");
            giftData['id'] = 0; // Assign a default value or handle appropriately
          }

          // Mark as synced
          giftData['synced'] = 1;

          // Insert Firebase data into local database
          await db.insert(
            'gifts',
            giftData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          gifts.add(giftData);
        }

        return gifts;
      } catch (e) {
        print('Error fetching gifts from Firebase: $e');
        // Optionally handle the error or notify the user
      }
    }

    return localGifts;
  }

  /// Updates an existing gift in the local database and syncs with Firebase.
  Future<int> updateGift(Map<String, dynamic> gift) async {
    final db = await _databaseHelper.database;

    if (!gift.containsKey('id')) {
      print('Error: Gift data must contain an "id" field.');
      return 0;
    }

    try {
      // Update in local database and mark as unsynced
      final rowsAffected = await db.update(
        'gifts',
        {
          ...gift,
          'synced': 0, // Mark as unsynced for synchronization
        },
        where: 'id = ?',
        whereArgs: [gift['id']],
      );

      // Check internet connectivity
      bool connected = await _databaseHelper.isConnectedToInternet();
      if (rowsAffected > 0 && connected) {
        try {
          // Sync the update to Firebase
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('gifts').doc(gift['id'].toString()).update({
            ...gift,
          });

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
      } else if (rowsAffected > 0 && !connected) {
        print('No internet connection. Gift update will be synced when online.');
      }

      return rowsAffected;
    } catch (e) {
      print("Error updating gift: $e");
      return 0; // Indicate failure
    }
  }

  /// Deletes a gift from the local database and syncs the deletion with Firebase.
  Future<int> deleteGift(int id) async {
    final db = await _databaseHelper.database;

    try {
      // Delete from local database
      final rowsAffected = await db.delete(
        'gifts',
        where: 'id = ?',
        whereArgs: [id],
      );

      bool connected = await _databaseHelper.isConnectedToInternet();
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
}
