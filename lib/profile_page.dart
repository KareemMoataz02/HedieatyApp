import 'package:flutter/material.dart';
import 'home_page.dart'; // Import HomePage
import 'event_list_page.dart'; // Import EventListPage
import 'gift_list_page.dart'; // Import GiftListPage
import 'gift_details_page.dart'; // Import GiftDetailsPage
import 'my_pledged_gifts_page.dart'; // Import MyPledgedGiftsPage

class ProfilePage extends StatelessWidget {
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
                CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('Assets/logo.jpeg'), // Replace with actual path
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center align text
              children: [
                Text(
                  'Welcome, User!', // Change to user's name dynamically if needed
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center align text
              children: [
                Text(
                  'Manage your gift lists and events easily.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: Text('View Friends\' Gift Lists'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => HomePage()),
                      );
                    },
                  ),
                  Divider(), // Adds a line between items
                  ListTile(
                    title: Text('View Your Events'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EventListPage(friendName: 'Your Events')),
                      );
                    },
                  ),
                  Divider(),
                  ListTile(
                    title: Text('View Your Gift List'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => GiftListPage(friendName: 'Your Gifts')),
                      );
                    },
                  ),
                  Divider(),
                  ListTile(
                    title: Text('Create New Gift'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => GiftDetailsPage()),
                      );
                    },
                  ),
                  Divider(),
                  ListTile(
                    title: Text('My Pledged Gifts'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyPledgedGiftsPage()),
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
