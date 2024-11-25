import 'package:flutter/material.dart';
import 'package:hedieaty/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hedieaty/profile_page.dart';
import 'event_list_page.dart';
import 'gift_list_page.dart';
import 'add_gift_page.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUsername(); // Load the username when the page initializes
    fetchRecentFriends(); // Fetch recent friends from the database
  }

  // Function to fetch username associated with the email
  Future<void> _loadUsername() async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserByEmail(widget.email);
    setState(() {
      username = user?['username'] ?? 'User'; // Default 'User' if no username found
    });
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
    final friends = await dbHelper.getRecentFriendsByUserId(userId);

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
                    backgroundImage: AssetImage('Assets/logo.jpeg'),
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
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.event),
              title: Text('Event List'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          EventListPage(email: widget.email)),
                );
              },
            ),
            // ListTile(
            //   leading: Icon(Icons.card_giftcard),
            //   title: Text('Gift List'),
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => GiftListPage(
            //           friendEmail: widget.email, // Friend's email or user email
            //           eventName: event['name'],  // Event name
            //           eventId: event['id'],      // Pass the event ID to fetch related gifts
            //         ),
            //       ),
            //     );
            //   },
            // ),
            // ListTile(
            //   leading: Icon(Icons.add),
            //   title: Text('Create New Gift'),
            //   onTap: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => AddGiftPage(eventId: null,)),
            //     );
            //   },
            // ),
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
                      builder: (context) => AddFriendPage(email: widget.email)),
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
                ? Center(child: CircularProgressIndicator()) // Show loading indicator if no friends
                : ListView.builder(
              itemCount: filteredFriends.length,
              itemBuilder: (context, index) {
                final friend = filteredFriends[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: friend['imagePath'] != null
                        ? AssetImage(friend['imagePath'])
                        : AssetImage('Assets/default.png'), // Default image if none exists
                  ),
                  title: Text(friend['username'] ?? 'Unknown Friend'), // Default username
                  subtitle: Text(friend['email'] ?? 'No Email Available'), // Default email
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ProfilePage(email: friend['email']),
                    ));
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
                  // Navigate to event creation page
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
