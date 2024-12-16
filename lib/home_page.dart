// home_page.dart

import 'dart:async'; // Import for Future.delayed
import 'dart:convert'; // Import for Base64 encoding/decoding
import 'dart:typed_data'; // Import for Uint8List
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hedieaty/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hedieaty/profile_page.dart';
import 'event_list_page.dart';
import 'my_pledged_gifts_page.dart';
import 'add_friend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';
import 'image_converter.dart'; // Import ImageConverter
import 'package:hedieaty/notifications.dart';

class HomePage extends StatefulWidget {
  final String email; // Property to store email

  HomePage({required this.email}); // Constructor to accept email

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> recentFriends = [];
  String searchQuery = '';
  String username = '';
  String imagePath = '';
  bool isLoading = true; // Loading state

  final dbHelper = DatabaseHelper();
  final ImageConverter _imageConverter = ImageConverter(); // Instantiate ImageConverter
  late StreamSubscription<bool> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    // Schedule the _initializeData to run 2 seconds after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          _initializeData();
        }
      });
    });
    listenToFriendRequests(); // Start listening to friend requests
  }

  // Function to initialize data
  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _loadUsername(),
        fetchRecentFriends(),
      ]);
    } catch (e) {
      // Handle any errors during data initialization
      print('Error during data initialization: $e');
      // Optionally, show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false; // Data has been loaded
        });
      }
      print('Synchronization complete.');
    }
  }

  // Function to fetch username associated with the email
  Future<void> _loadUsername() async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserByEmail(widget.email);
    if (user == null) {
      print('Error: No user found with email: ${widget.email}');
      // Optionally, handle the case where the user is not found
      // For example, redirect to the login page or show an error message
      return;
    }
    if (mounted) {
      setState(() {
        username = user['username'] ?? 'User';
        imagePath = user['imagePath'] ?? '';
      });
      print('Username loaded: $username');
    }
  }

  // Function to load friend's image
  Future<String?> _loadFriendImage(String email) async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserByEmail(email);
    return user?['imagePath']; // Return the image path or null if not found
  }

  // Function to fetch current user ID from the database
  Future<int> getCurrentUserId() async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserByEmail(widget.email);
    if (user == null) {
      print('Error: No user found when fetching userId for email: ${widget.email}');
      // Optionally, handle the case where the user is not found
      return 0;
    }
    final userId = user['id'] ?? 0;
    print('Fetched userId: $userId for email: ${widget.email}');
    return userId;
  }

  // Function to load recent friends from the database
  Future<void> fetchRecentFriends() async {
    try {
      int userId = await getCurrentUserId(); // Ensure the correct userId is fetched
      if (userId == 0) {
        print('Warning: userId is 0, no friends will be fetched.');
        setState(() {
          recentFriends = []; // Clear the friends list if userId is invalid
        });
        return;
      }
      print('Fetching friends for userId: $userId');
      final dbHelper = DatabaseHelper();

      // Fetch the recent friends from the database
      final friends = await dbHelper.getAcceptedFriendsByUserId(userId);
      print('Number of accepted friends found: ${friends.length}');

      if (mounted) {
        setState(() {
          recentFriends = friends;
        });
      }
    } catch (e) {
      print('Error fetching friends: $e');
      // Optionally, handle the error, e.g., show a SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch friends: $e')),
      );
    }
  }


  // Function to send notifications when friend status is updated to accepted
  Future<void> sendNotificationOnFriendStatusChange(String friendEmail) async {
    // This is where you would send a notification using the previously defined showNotification method.
    // For example, you could create a notification when the friend status changes to accepted.

    final message = RemoteMessage(
      notification: RemoteNotification(
        title: 'Friend Request Accepted',
        body: 'Your friend request to $friendEmail has been accepted!',
      ),
      data: {'friendEmail': friendEmail},
    );

    await NotificationsHelper.showNotification(message); // Use your showNotification method here
  }

// Firestore listener to monitor friend status changes
  void listenToFriendRequests() {
    final dbHelper = DatabaseHelper();
    FirebaseFirestore.instance.collection('friends')
        .where('user_id', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        // Get the previous status and current status
        String currentStatus = doc['status'];
        String previousStatus = doc.metadata.hasPendingWrites ? 'pending' : doc['status']; // Assuming previous status is pending initially

        // Check if the status changed from 'pending' to 'accepted'
        if (previousStatus == 'pending' && currentStatus == 'accepted') {
          int friendId = doc['friend_id'];  // friend_id is stored
          String? friendEmail = await dbHelper.getEmailById(friendId); // Fetch the email by friend_id

          if (friendEmail != null) {
            sendNotificationOnFriendStatusChange(friendEmail);
          }
        }
      }
    });
  }
  // Function to handle logout
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false); // Mark as logged out

    await FirebaseAuth.instance.signOut(); // Firebase logout

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while data is being fetched
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Friends List'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Once data is loaded, display the main content
    final filteredFriends = recentFriends.where((friend) {
      return friend['username']
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Friends List'),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search friends...',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.search),
              ),
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.black45,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: imagePath.isNotEmpty
                        ? _buildUserImage(imagePath)
                        : AssetImage('assets/default_avatar.png') as ImageProvider, // Fallback to default image
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Welcome, $username', // Display username
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('My Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ProfilePage(email: widget.email)),
                ).then((_) {
                  // This will run when you return from ProfilePage
                  _loadUsername(); // Refresh the image and username
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.event),
              title: Text('My Event List'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          EventListPage(email: widget.email)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.thumb_up),
              title: Text('My Pledged Gifts'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MyPledgedGiftsPage(email: widget.email)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person_add),
              title: Text('Add a Friend'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddFriendPage(email: widget.email),
                  ),
                ).then((_) {
                  fetchRecentFriends(); // Call this when returning
                });
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: filteredFriends.isEmpty
                ? const Center(child: Text('No friends found.')) // Show message if no friends
                : ListView.separated(
              padding: EdgeInsets.all(8.0),
              itemCount: filteredFriends.length,
              separatorBuilder: (context, index) => SizedBox(height: 8.0),
              itemBuilder: (context, index) {
                final friend = filteredFriends[index];
                return Card(
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Friend's Image with tap functionality
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfilePage(email: friend['email']),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage: friend['imagePath'] != null && friend['imagePath'].isNotEmpty
                                ? _buildFriendImage(friend['imagePath'])
                                : AssetImage('assets/default_avatar.png') as ImageProvider,
                          ),
                        ),
                        SizedBox(width: 16.0),
                        // Friend's Details with tap functionality
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventListPage(email: friend['email']),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend['username'] ?? 'Unknown Friend',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4.0),
                                Text(
                                  friend['phone'] ?? 'No number available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4.0),
                                // Additional Information (Optional)
                                // Row(
                                //   children: [
                                //     Icon(Icons.email, size: 16, color: Colors.grey),
                                //     SizedBox(width: 4),
                                //     Text(friend['email'] ?? 'No email'),
                                //   ],
                                // ),
                              ],
                            ),
                          ),
                        ),
                        // Optional: Add trailing icons or information
                        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventListPage(email: widget.email),
                    ),
                  );
                },
                child: Text('Create Your Own Event'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  textStyle: TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the user's profile image in the drawer, handling Base64 and file paths
  ImageProvider _buildUserImage(String imagePath) {
    if (imagePath.isEmpty) {
      return AssetImage('assets/default_avatar.png');
    }

    // Determine if imagePath is a Base64 string
    bool isBase64 = false;
    try {
      // Attempt to decode; if successful, it's Base64
      base64Decode(imagePath);
      isBase64 = true;
    } catch (e) {
      isBase64 = false;
    }

    if (isBase64) {
      try {
        Uint8List imageBytes = base64Decode(imagePath);
        return MemoryImage(imageBytes);
      } catch (e) {
        print("Error decoding Base64 user image: $e");
        return AssetImage('assets/default_avatar.png');
      }
    } else {
      // Treat imagePath as a file path
      File imageFile = File(imagePath);
      if (imageFile.existsSync()) {
        return FileImage(imageFile);
      } else {
        return AssetImage('assets/default_avatar.png');
      }
    }
  }

  /// Builds the friend's image widget, handling Base64 strings and file paths
  ImageProvider _buildFriendImage(String imagePath) {
    if (imagePath.isEmpty) {
      return AssetImage('assets/default_avatar.png');
    }

    // Determine if imagePath is a Base64 string
    bool isBase64 = false;
    try {
      // Attempt to decode; if successful, it's Base64
      base64Decode(imagePath);
      isBase64 = true;
    } catch (e) {
      isBase64 = false;
    }

    if (isBase64) {
      try {
        Uint8List imageBytes = base64Decode(imagePath);
        return MemoryImage(imageBytes);
      } catch (e) {
        print("Error decoding Base64 friend image: $e");
        return AssetImage('assets/default_avatar.png');
      }
    } else {
      // Treat imagePath as a file path
      File imageFile = File(imagePath);
      if (imageFile.existsSync()) {
        return FileImage(imageFile);
      } else {
        return AssetImage('assets/default_avatar.png');
      }
    }
  }
}
