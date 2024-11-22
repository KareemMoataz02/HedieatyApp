import 'package:flutter/material.dart';
import 'package:hedieaty/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hedieaty/profile_page.dart';
import 'event_list_page.dart';
import 'gift_list_page.dart';
import 'add_gift_page.dart';
import 'my_pledged_gifts_page.dart';
import 'add_friend.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

class HomePage extends StatefulWidget {
  final String email; // Property to store email

  HomePage({required this.email}); // Constructor to accept email

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> friends = [
    {'name': 'Alice', 'profilePic': 'Assets/female.png', 'events': 1},
    {'name': 'Bob', 'profilePic': 'Assets/male.png', 'events': 0},
    {'name': 'Harbor', 'profilePic': 'Assets/male.png', 'events': 2},
    {'name': 'Jenny', 'profilePic': 'Assets/female.png', 'events': 2},
    {'name': 'Sam', 'profilePic': 'Assets/male.png', 'events': 2},
  ];

  String searchQuery = '';


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
    final filteredFriends = friends.where((friend) {
      return friend['name'].toLowerCase().contains(searchQuery.toLowerCase());
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
                    radius:40,
                    backgroundImage: AssetImage('Assets/logo.jpeg'),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Welcome, ${widget.email}', // Display user email
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
                  MaterialPageRoute(builder: (context) => ProfilePage(email: widget.email)),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.event),
              title: Text('Event List'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EventListPage(friendName: 'Your Events')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.card_giftcard),
              title: Text('Gift List'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GiftListPage(friendName: 'Your Gifts', eventName: 'Your Event Name'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.add),
              title: Text('Create New Gift'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddGiftPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.thumb_up),
              title: Text('My Pledged Gifts'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyPledgedGiftsPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person_add),
              title: Text('Add a Friend'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddFriendPage(email: widget.email)),
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
            child: ListView.builder(
              itemCount: filteredFriends.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: AssetImage(filteredFriends[index]['profilePic']),
                  ),
                  title: Text(filteredFriends[index]['name']),
                  subtitle: Text(
                    filteredFriends[index]['events'] > 0
                        ? 'Upcoming Events: ${filteredFriends[index]['events']}'
                        : 'No Upcoming Events',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventListPage(friendName: filteredFriends[index]['name']),
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
                    MaterialPageRoute(builder: (context) => EventListPage(friendName: 'Create Your Own Event/List')),
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
