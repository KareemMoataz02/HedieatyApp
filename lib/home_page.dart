import 'package:flutter/material.dart';
import 'event_list_page.dart'; // Import EventListPage

class HomePage extends StatelessWidget {
  final List<Map<String, dynamic>> friends = [
    {'name': 'Alice', 'profilePic': 'Assets/female.png', 'events': 1},
    {'name': 'Bob', 'profilePic': 'Assets/male.png', 'events': 0},
    {'name': 'Charlie', 'profilePic': 'Assets/male.png', 'events': 2},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends List'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: friends.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: AssetImage(friends[index]['profilePic']),
            ),
            title: Text(friends[index]['name']),
            subtitle: Text(
              friends[index]['events'] > 0
                  ? 'Upcoming Events: ${friends[index]['events']}'
                  : 'No Upcoming Events',
            ),
            onTap: () {
              // Navigate to Event List Page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventListPage(friendName: friends[index]['name']),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to Create Event/List Page
        },
        child: Icon(Icons.add),
        tooltip: 'Create Your Own Event/List',
      ),
    );
  }
}
