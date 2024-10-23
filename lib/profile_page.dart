import 'package:flutter/material.dart';
import 'event_list_page.dart'; // Import EventListPage
import 'my_pledged_gifts_page.dart'; // Import MyPledgedGiftsPage

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = 'User'; // Initial username value
  bool notificationsEnabled = true; // Initial notification preference

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 20), // Space from the top
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the profile picture
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage('Assets/logo.jpeg'), // Replace with actual path
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          // Functionality to upload a new profile picture
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: TextFormField(
                      initialValue: username, // Display the initial username
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.start,
                      decoration: InputDecoration(
                        border: InputBorder.none, // No underline for editing
                      ),
                      onChanged: (value) {
                        setState(() {
                          // Update the username with the new value
                          username = value;
                        });
                      },
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () {
                        // Optional: Trigger additional functionality if needed
                      },
                    ),
                  ),
                  Divider(),
                  ListTile(
                    title: Text(
                      'Enable Notifications',
                      style: TextStyle(fontSize: 18),
                    ),
                    trailing: Switch(
                      value: notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          notificationsEnabled = value; // Update the notification preference
                        });
                      },
                    ),
                  ),
                  Divider(),
                  ListTile(
                    title: Text('Create New Event'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventListPage(friendName: 'Your Events'),
                        ),
                      );
                    },
                  ),
                  Divider(),
                  ListTile(
                    title: Text('My Pledged Gifts'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyPledgedGiftsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
