// event_service.dart
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Create Events Table
  Future<void> createEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
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

  // Insert Event and Sync to Firebase
  Future<int> insertEvent(Map<String, dynamic> event) async {
    final db = await _databaseHelper.database;
    int eventId = 0;

    try {
      // Set synced flag to 0 (unsynced) before insertion
      event['synced'] = 0;
      eventId = await db.insert('events', event);

      bool connected = await _databaseHelper.isConnectedToInternet();
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

  // Update Event and Sync to Firebase
  Future<int> updateEvent(int id, Map<String, dynamic> event) async {
    final db = await _databaseHelper.database;

    try {
      // Update the local database
      final rowsAffected = await db.update(
        'events',
        {...event, 'synced': 0}, // Set synced to 0 to indicate unsynced changes
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        bool connected = await _databaseHelper.isConnectedToInternet();
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
          print('No internet connection. Event update will be synced when online.');
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

  // Delete Event and Sync to Firebase
  Future<int> deleteEvent(int id) async {
    final db = await _databaseHelper.database;

    try {
      // Delete from local database
      final rowsAffected = await db.delete('events', where: 'id = ?', whereArgs: [id]);

      bool connected = await _databaseHelper.isConnectedToInternet();
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

  // Get Events by Email, with fallback to Firebase
  Future<List<Map<String, dynamic>>> getEventsByEmail(String email) async {
    final db = await _databaseHelper.database;
    List<Map<String, dynamic>> localEvents = [];

    try {
      // Fetch synced events from local database
      localEvents = await db.query(
        'events',
        where: 'email = ? AND synced = 1',
        whereArgs: [email],
      );

      bool connected = await _databaseHelper.isConnectedToInternet();
      if (connected) {
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

  // Get Event Owner Email
  Future<String?> getEventOwnerEmail(int eventId) async {
    final db = await _databaseHelper.database; // Correct use of await to get the database instance
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

  // Get Event by ID with Fallback to Firebase
  Future<Map<String, dynamic>?> getEventById(int eventId) async {
    final db = await _databaseHelper.database;
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
        bool connected = await _databaseHelper.isConnectedToInternet();

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
              await db.insert(
                'events',
                event,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
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
}
