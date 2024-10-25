import 'package:flutter/material.dart';
import 'package:hedieaty/profile_page.dart';
import 'event_list_page.dart'; // Import EventListPage
import 'gift_list_page.dart'; // Import GiftListPage
import 'add_gift_page.dart'; // Import GiftDetailsPage
import 'my_pledged_gifts_page.dart'; // Import MyPledgedGiftsPage
import 'add_friend.dart';

class HomePage extends StatefulWidget {
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

  @override
  Widget build(BuildContext context) {
    // Filter friends based on the search query
    final filteredFriends = friends.where((friend) {
      return friend['name'].toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Friends List'),
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: Icon(Icons.menu), // Three-dash menu icon
              onPressed: () {
                Scaffold.of(context).openDrawer(); // Open the drawer
              },
            );
          },
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60.0), // Adjust the height as needed
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value; // Update the search query
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
                mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                children: [
                  SizedBox(height: 10), // Space between text and avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage('Assets/logo.jpeg'), // Replace with actual image path
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
                  MaterialPageRoute(builder: (context) => ProfilePage()),
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
                    builder: (context) => GiftListPage(friendName: 'Your Gifts', eventName: 'Your Event Name'), // Add eventName here
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
              title: Text('Add a friend'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddFriendPage()),
                );
              },
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
                    // Navigate to Event List Page
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
                  // Navigate to Create Event/List Page (implement as needed)
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EventListPage(friendName: 'Create Your Own Event/List')),
                  );
                },
                child: Text('Create Your Own Event'),
              )
            ),
          ),
        ],
      ),
    );
  }
}
