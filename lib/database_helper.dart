import 'dart:async';
import 'package:flutter/cupertino.dart';
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
        imagePath TEXT
      )
    ''');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert(
        'users', user, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUserByEmailOrPhone(String email,
      String phone) async {
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

  // MARK: - User Operations
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

  Future<List<Map<String, dynamic>>> getRecentFriendsByUserId(int userId) async {
    final db = await database;

    // Fetch the most recent 5 friends based on friend_id order
    final result = await db.rawQuery('''
    SELECT u.id, u.username, u.email, u.phone, u.imagePath
    FROM users u
    INNER JOIN friends f ON u.id = f.friend_id
    WHERE f.user_id = ?
    ORDER BY f.friend_id DESC
    LIMIT 10
  ''', [userId]);

    return result;
  }

  // MARK: - Events Operations

  Future<void> _createEventsTable(Database db) async {
    // Create the new 'events' table
    await db.execute('''
    CREATE TABLE events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      status TEXT NOT NULL,
      deadline TEXT NOT NULL,
      email TEXT NOT NULL,
      user_id INTEGER, -- Added user_id column for foreign key
      FOREIGN KEY(user_id) REFERENCES users(id)
    )
  ''');
  }

  // Insert event
  Future<int> insertEvent(Map<String, dynamic> event) async {
    final db = await database;
    return await db.insert('events', event);
  }

  // Update event
  Future<int> updateEvent(int id, Map<String, dynamic> event) async {
    final db = await database;
    return await db.update('events', event, where: 'id = ?', whereArgs: [id]);
  }

  // Delete event
  Future<int> deleteEvent(int id) async {
    final db = await database;
    return await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  // Get events by email
  Future<List<Map<String, dynamic>>> getEventsByEmail(String email) async {
    final db = await database;
    return await db.query('events', where: 'email = ?', whereArgs: [email]);
  }

  // MARK: - Gift Operations

  Future<void> _createGiftsTable(Database db) async {
    await db.execute('''
    CREATE TABLE gifts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      category TEXT,
      price REAL NOT NULL CHECK(price >= 0), -- Ensure price is non-negative
      status TEXT CHECK(status IN ('Available', 'Pledged'), -- Status constraint
      event_id INTEGER NOT NULL,
      FOREIGN KEY(event_id) REFERENCES events(id) ON DELETE CASCADE
    )
  ''');
  }
  Future<int> insertGift(Map<String, dynamic> gift) async {
    final db = await database;
    return await db.insert('gifts', gift);
  }

  Future<List<Map<String, dynamic>>> getGiftsByEventId(int eventId) async {
    final db = await database;
    return await db.query(
      'gifts',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'name ASC', // Optionally order by name or other fields
    );
  }

  Future<int> updateGift(Map<String, dynamic> gift) async {
    final db = await database;
    return await db.update(
      'gifts',
      gift,
      where: 'id = ?',
      whereArgs: [gift['id']],
    );
  }

    Future<int> deleteGift(int id) async {
      final db = await database;
      return await db.delete(
        'gifts',
        where: 'id = ?',
        whereArgs: [id],
      );
    }

  Future<void> _createPledgesTable(Database db) async {
    await db.execute('''
    CREATE TABLE pledges (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userEmail TEXT NOT NULL, 
      giftId INTEGER NOT NULL,
      pledgedAt TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(giftId) REFERENCES gifts(id) ON DELETE CASCADE
    )
  ''');
  }

  Future<int> insertPledge(String userEmail, int giftId) async {
    final db = await database;
    return await db.insert('pledges', {
      'userEmail': userEmail,
      'giftId': giftId,
    });
  }
  Future<List<Map<String, dynamic>>> getPledgedGiftsByUser(String userEmail) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT g.*
    FROM gifts g
    INNER JOIN pledges p ON g.id = p.giftId
    WHERE p.userEmail = ?
    ORDER BY p.pledgedAt DESC
  ''', [userEmail]);
  }
  Future<int> removePledge(String userEmail, int giftId) async {
    final db = await database;
    return await db.delete(
      'pledges',
      where: 'userEmail = ? AND giftId = ?',
      whereArgs: [userEmail, giftId],
    );
  }
}


