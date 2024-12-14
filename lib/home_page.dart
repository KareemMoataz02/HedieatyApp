import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hedieaty/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hedieaty/profile_page.dart';
import 'event_list_page.dart';
import 'my_pledged_gifts_page.dart';
import 'add_friend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';

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
  String imagePath = '' ;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    fetchRecentFriends();
  }

  // Function to fetch username associated with the email
  Future<void> _loadUsername() async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserByEmail(widget.email);
    setState(() {
      username = user?['username'] ?? 'User';
      imagePath = user?['imagePath'] ?? '';
    });
  }

  Future<String?> _loadFriendImage(String email) async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserByEmail(email);
    return user?['imagePath']; // Return the image path or null if not found
  }


  // Function to fetch current user ID from the database
  Future<int> getCurrentUserId() async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserByEmail(widget.email);
    return user?['id'] ?? 0; // Return the userId (default to 0 if not found)
  }

  // Function to load recent friends from the database
  void fetchRecentFriends() async {
    int userId = await getCurrentUserId(); // Ensure the correct userId is fetched
    final dbHelper = DatabaseHelper();

    // Fetch the recent friends from the database
    final friends = await dbHelper.getAcceptedFriendsByUserId(userId);

    setState(() {
      recentFriends = friends;
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
                        ? FileImage(File(imagePath)) // Load from file if path is not empty
                        : AssetImage('assets/default_avatar.png') as ImageProvider, // Fallback to default image
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Welcome, $username', // Display user email
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
                  _loadUsername();  // Refresh the image and username
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
                  }
                );
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
                ? const Center(child: CircularProgressIndicator()) // Show loading indicator if no friends
                : ListView.builder(
              itemCount: filteredFriends.length,
              itemBuilder: (context, index) {
                final friend = filteredFriends[index];
                return ListTile(
                  leading: FutureBuilder<String?>(
                    future: _loadFriendImage(friend['email']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircleAvatar(
                          radius: 30,
                          child: CircularProgressIndicator(), // Show loading indicator
                        );
                      } else if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                        return CircleAvatar(
                          radius: 30,
                          backgroundImage: AssetImage('Assets/default.png'), // Default image
                        );
                      } else {
                        return CircleAvatar(
                          radius: 30,
                          backgroundImage: FileImage(File(snapshot.data!)), // Use the loaded image path
                        );
                      }
                    },
                  ),
                  title: Text(
                    friend['username'] ?? 'Unknown Friend',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ), // Bold username
                  subtitle: Text(
                    friend['phone'] ?? 'No number available',
                    style: TextStyle(fontSize: 16),
                  ), // Subtitle with better font size
                  onTap: () {
                    // Navigate to EventListPage when the ListTile body is tapped
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventListPage(email: friend['email']),
                      ),
                    );
                  },
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
