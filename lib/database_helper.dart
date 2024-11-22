import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
    await _createEventsTable(db);
    await _createGiftsTable(db);
    await _createFriendsTable(db);
    await _createRecentFriendsTable(db);
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
        imagePath TEXT
      )
    ''');
  }

  Future<void> _createEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        location TEXT,
        description TEXT,
        user_id INTEGER,
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');
  }

  Future<void> _createGiftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE gifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT,
        price REAL,
        status TEXT,
        event_id INTEGER,
        FOREIGN KEY(event_id) REFERENCES events(id)
      )
    ''');
  }

  Future<void> _createFriendsTable(Database db) async {
    await db.execute('''
      CREATE TABLE friends (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        friend_id INTEGER NOT NULL,
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(friend_id) REFERENCES users(id)
      )
    ''');
  }

  Future<void> _createRecentFriendsTable(Database db) async {
    await db.execute('''
      CREATE TABLE recent_friends (
        user_id INTEGER,
        email TEXT,
        phone TEXT,
        added_at INTEGER,
        PRIMARY KEY(user_id, email, phone),
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');
  }

  // MARK: - User Operations

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUserByEmailOrPhone(String email, String phone) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'LOWER(email) = LOWER(?) OR LOWER(phone) = LOWER(?)',
      whereArgs: [email, phone],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateUser(int id, Map<String, dynamic> user) async {
    try {
      final db = await database;
      final rowsAffected = await db.update(
        'users',
        user,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected > 0) {
        print('User with ID $id updated successfully.');
      } else {
        print('No user found with ID $id.');
      }

      return rowsAffected;
    } catch (e) {
      print('Error updating user: $e');
      return 0; // Indicate no rows were updated in case of an error
    }
  }


  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users');
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'LOWER(email) = LOWER(?)',
      whereArgs: [email],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'LOWER(phone) = LOWER(?)',
      whereArgs: [phone],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // MARK: - Friend Operations

  Future<void> addFriend(int userId, int friendId) async {
    final db = await database;

    // Avoid duplicate entries
    if (!await checkIfFriendExists(userId, friendId)) {
      await db.insert('friends', {'user_id': userId, 'friend_id': friendId});
      await db.insert('friends', {'user_id': friendId, 'friend_id': userId});
      print('Friendship added between $userId and $friendId');
    } else {
      print('Friendship already exists between $userId and $friendId');
    }
  }


  Future<List<Map<String, dynamic>>> getFriendsByUserId(int userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT u.id, u.username, u.email, u.phone, u.imagePath
      FROM users u
      INNER JOIN friends f ON u.id = f.friend_id
      WHERE f.user_id = ?
    ''', [userId]);
  }

  Future<int> removeFriend(int userId, int friendId) async {
    final db = await database;
    return await db.delete(
      'friends',
      where: 'user_id = ? AND friend_id = ?',
      whereArgs: [userId, friendId],
    );
  }

  Future<bool> checkIfFriendExists(int userId, int friendId) async {
    final db = await database;
    final result = await db.query(
      'friends',
      where: '(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)',
      whereArgs: [userId, friendId, friendId, userId],
    );
    return result.isNotEmpty;
  }


  // MARK: - Recent Friends Operations

  Future<int> addRecentFriend(int userId, String email, String phone) async {
    final db = await database;
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    return await db.insert('recent_friends', {
      'user_id': userId,
      'email': email,
      'phone': phone,
      'added_at': timestamp,
    });
  }

  Future<List<Map<String, dynamic>>> getRecentFriendsByUserId(int userId) async {
    final db = await database;
    return await db.query(
      'recent_friends',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'added_at DESC',
    );
  }

  // Insert a new event
  Future<int> insertEvent(Map<String, dynamic> event) async {
    Database db = await database;
    return await db.insert('events', event);
  }

  // Update an existing event
  Future<int> updateEvent(int id, Map<String, dynamic> event) async {
    Database db = await database;
    return await db.update(
      'eventsTable',
      event,
      where: 'Id = ?',
      whereArgs: [id],
    );
  }

  // Delete an event by ID
  Future<int> deleteEvent(int id) async {
    Database db = await database;
    return await db.delete(
      'events',
      where: 'Id = ?',
      whereArgs: [id],
    );
  }

  // Get all events from the database
  Future<List<Map<String, dynamic>>> getAllEvents() async {
    Database db = await database;
    return await db.query('events');
  }

  // Get an event by its ID
  Future<Map<String, dynamic>?> getEventById(int id) async {
    Database db = await database;
    var result = await db.query(
      'events',
      where: 'Id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}

