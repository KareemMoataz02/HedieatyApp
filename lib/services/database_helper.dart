import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/user_model.dart';
import '../models/event_model.dart';
import '../models/friend_model.dart';
import '../models/gift_model.dart';
import '../models/pledged_gift_model.dart';


UserModel userModel = UserModel();
EventModel eventModel = EventModel();
FriendModel friendModel = FriendModel();
GiftModel giftModel = GiftModel();
PledgeModel pledgedGiftModel = PledgeModel();


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
    await userModel.createUsersTable(db);
    await friendModel.createFriendsTable(db);
    await eventModel.createEventsTable(db);
    await giftModel.createGiftsTable(db);
    await pledgedGiftModel.createPledgesTable(db);
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
