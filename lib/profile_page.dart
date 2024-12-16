import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'event_list_page.dart';
import 'image_converter.dart';
import 'my_pledged_gifts_page.dart';

class ProfilePage extends HookWidget {
  final String email; // Email of the user to display profile for

  const ProfilePage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    // State variables using hooks
    final isEditable = useState(false); // Determines if the profile is editable
    final username = useState('User');
    final phone = useState('N/A'); // Removed edit capability for phone
    final imagePath = useState('');
    final notificationsEnabled = useState(false);
    final loggedInEmail = useState<String?>(''); // Track the logged-in user's email
    final recentFriends = useState<List<Map<String, dynamic>>>([]); // Track recent friends

    final imageConverter = ImageConverter(); // Instantiate ImageConverter

    // Initialize profile data
    Future<void> _initializeProfile() async {
      final dbHelper = DatabaseHelper();
      try {
        // Fetch logged-in email from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        loggedInEmail.value = prefs.getString('email');

        // Load profile data
        final user = await dbHelper.getUserByEmail(email);
        if (user != null) {
          username.value = user['username'] ?? 'User';
          phone.value = user['phone'] ?? 'N/A';
          imagePath.value = user['imagePath'] ?? '';
          notificationsEnabled.value = user['notifications'] == 1;
        }

        // Allow editing only if the logged-in user matches the profile email
        isEditable.value = (loggedInEmail.value?.toLowerCase() == email.toLowerCase());

        // Fetch recent friends
        final friends = await dbHelper.getAcceptedFriendsByUserId(user?['id'] ?? 0);
        recentFriends.value = friends;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }

    // Update user data (only username and notifications are editable)
    Future<void> _updateUserData(String field, dynamic value) async {
      try {
        final dbHelper = DatabaseHelper();
        final user = await dbHelper.getUserByEmail(email);

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
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }

    // Update profile image using ImageConverter
    Future<void> _updateProfileImage() async {
      final imageString = await imageConverter.pickAndCompressImageToString();

      if (imageString != null) {
        final dbHelper = DatabaseHelper();
        final user = await dbHelper.getUserByEmail(email);

        if (user != null) {
          await dbHelper.updateUser(user['id'], {'imagePath': imageString});
          imagePath.value = imageString; // Update UI with the new Base64 image string
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Profile picture updated')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture')),
        );
      }
    }

    // Fetch profile data when the widget is first built
    useEffect(() {
      _initializeProfile();
      return null; // No cleanup needed
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.deepPurple,
        elevation: 4.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 20),
            _buildProfilePicture(isEditable.value, imagePath, _updateProfileImage),
            SizedBox(height: 20),
            _buildProfileDetails(
              isEditable.value,
              username,
              phone,
              _updateUserData,
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventListPage(email: email),
                ),
              ),
            ),
            SizedBox(height: 20),
            _buildSettings(
              isEditable.value,
              notificationsEnabled,
                  (newValue) => _updateUserData('notifications', newValue ? 1 : 0),
              isEditable.value
                  ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyPledgedGiftsPage(email: email),
                ),
              )
                  : () {},
            ),
            SizedBox(height: 20),
            _buildRecentFriends(context, recentFriends.value),
          ],
        ),
      ),
    );
  }

  /// Builds the profile picture section with an optional edit button
  Widget _buildProfilePicture(
      bool isEditable,
      ValueNotifier<String> imagePath,
      Future<void> Function() updateProfileImage,
      ) {
    final imageConverter = ImageConverter(); // Ensure ImageConverter is available if needed

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 70,
            backgroundImage: imagePath.value.isNotEmpty
                ? (imagePath.value.startsWith('http') || imagePath.value.startsWith('https'))
                ? NetworkImage(imagePath.value)
                : (imagePath.value.length > 100
                ? MemoryImage(base64Decode(imagePath.value))
                : FileImage(File(imagePath.value)) as ImageProvider)
                : AssetImage('assets/logo.jpeg') as ImageProvider,
          ),
          if (isEditable)
            Positioned(
              bottom: 0,
              right: 0,
              child: InkWell(
                onTap: updateProfileImage,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the profile details section (username and phone)
  Widget _buildProfileDetails(
      bool isEditable,
      ValueNotifier<String> username,
      ValueNotifier<String> phone,
      Function(String, String) updateUser,
      VoidCallback navigateToEventsPage,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: isEditable
              ? TextFormField(
            initialValue: username.value,
            decoration: InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => username.value = value,
          )
              : Text(
            username.value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          trailing: isEditable
              ? IconButton(
            icon: Icon(Icons.save, color: Colors.green),
            onPressed: () => updateUser('username', username.value),
          )
              : null,
        ),
        SizedBox(height: 10),
        // Phone (Read-only)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Phone: ${phone.value}',
            style: TextStyle(fontSize: 18),
          ),
        ),
        SizedBox(height: 10),
        // View Events Button
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: navigateToEventsPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple, // Background color of the button
              foregroundColor: Colors.white, // Text color of the button
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Text(
              'View Events',
              style: TextStyle(fontSize: 16), // Font size only
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the settings section with optional "My Pledged Gifts" and notifications toggle
  Widget _buildSettings(
      bool isEditable,
      ValueNotifier<bool> notificationsEnabled,
      Function(bool) updateNotifications,
      VoidCallback onPledgedGiftsNavigate,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "My Pledged Gifts" button shown only if the user is the profile owner
        if (isEditable)
          ElevatedButton(
            onPressed: onPledgedGiftsNavigate,
            child: Text('My Pledged Gifts'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white, // Text color of the button
              padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
              textStyle: TextStyle(fontSize: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        if (isEditable) SizedBox(height: 10.0),
        // Notifications Switch shown only if the user is the profile owner
        if (isEditable)
          SwitchListTile(
            title: Text('Enable Notifications'),
            value: notificationsEnabled.value,
            onChanged: (value) {
              notificationsEnabled.value = value;
              updateNotifications(value);
            },
            secondary: Icon(Icons.notifications),
          ),
      ],
    );
  }

  /// Builds the recent friends section (non-routable)
  Widget _buildRecentFriends(BuildContext context, List<Map<String, dynamic>> friends) {
    if (friends.isEmpty) {
      return const Center(child: Text('No recent friends found.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Friends',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        ListView.separated(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: friends.length,
          separatorBuilder: (context, index) => SizedBox(height: 8.0),
          itemBuilder: (context, index) {
            final friend = friends[index];
            return Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Friend's Image (Non-tappable)
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: friend['imagePath'] != null && friend['imagePath'].isNotEmpty
                          ? (friend['imagePath'].startsWith('http') || friend['imagePath'].startsWith('https'))
                          ? NetworkImage(friend['imagePath'])
                          : (friend['imagePath'].length > 100
                          ? MemoryImage(base64Decode(friend['imagePath']))
                          : FileImage(File(friend['imagePath'])) as ImageProvider)
                          : AssetImage('assets/default_avatar.png') as ImageProvider,
                    ),
                    SizedBox(width: 16.0),
                    // Friend's Details (Non-tappable)
                    Expanded(
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
                        ],
                      ),
                    ),
                    // Trailing icon for visual cue (optional)
                    Icon(Icons.person, size: 20, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
