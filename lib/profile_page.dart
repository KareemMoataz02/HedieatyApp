import 'dart:io';
import 'package:flutter/material.dart';
import 'database_helper.dart'; // Your DatabaseHelper class
import 'event_list_page.dart';
import 'my_pledged_gifts_page.dart';

class ProfilePage extends StatefulWidget {
  final String email;

  ProfilePage({required this.email});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = 'User';
  String phone = 'N/A';
  String imagePath = '';
  bool notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByEmail(widget.email);

      if (user != null) {
        setState(() {
          username = user['username'] ?? 'User';
          phone = user['phone'] ?? 'N/A';
          imagePath = user['imagePath'] ?? '';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e')),
      );
    }
  }

  Future<void> _updateUserData(String field, String value) async {
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByEmail(widget.email);

      if (user != null) {
        final updatedRows = await dbHelper.updateUser(user['id'], {field: value});
        if (updatedRows > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$field updated successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update $field')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user data: $e')),
      );
    }
  }

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
            SizedBox(height: 20),
            _buildProfilePicture(),
            SizedBox(height: 20),
            _buildProfileDetails(),
            SizedBox(height: 20),
            _buildSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: imagePath.isNotEmpty
                ? FileImage(File(imagePath))
                : AssetImage('assets/logo.jpeg') as ImageProvider,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: _updateProfilePicture,
            ),
          ),
        ],
      ),
    );
  }

  void _updateProfilePicture() {
    // Implement functionality to update profile picture
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Profile picture update coming soon!')),
    );
  }

  Widget _buildProfileDetails() {
    return Column(
      children: [
        ListTile(
          title: TextFormField(
            key: Key(username),
            initialValue: username,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.start,
            decoration: InputDecoration(border: InputBorder.none),
            onChanged: (value) => username = value,
          ),
          trailing: IconButton(
            icon: Icon(Icons.save),
            onPressed: () => _updateUserData('username', username),
          ),
        ),
        Divider(),
        ListTile(
          title: Text(
            'Phone: $phone',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildSettings() {
    return Expanded(
      child: ListView(
        children: [
          ListTile(
            title: Text('Enable Notifications'),
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  notificationsEnabled = value;
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
    );
  }
}
