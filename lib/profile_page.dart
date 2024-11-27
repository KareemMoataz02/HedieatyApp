import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'database_helper.dart';
import 'event_list_page.dart';
import 'my_pledged_gifts_page.dart';

class ProfilePage extends HookWidget {
  final String email; // Email of the user to display profile for

  const ProfilePage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final isEditable = useState(false); // Hook to determine if the profile is editable
    final username = useState('User');
    final phone = useState('N/A');
    final imagePath = useState('');
    final notificationsEnabled = useState(false);
    final loggedInEmail = useState<String?>(''); // Track the logged-in user's email

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
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }

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

    Future<void> _updateProfileImage() async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final dbHelper = DatabaseHelper();
        final user = await dbHelper.getUserByEmail(email);

        if (user != null) {
          await dbHelper.updateUser(user['id'], {'imagePath': image.path});
          imagePath.value = image.path; // Update UI with the new image path
        }
      }
    }

    useEffect(() {
      _initializeProfile();
      return null; // No cleanup needed
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Padding(
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
                  () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyPledgedGiftsPage(email: email),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicture(
      bool isEditable,
      ValueNotifier<String> imagePath,
      Future<void> Function() updateProfileImage,
      ) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 70,
            backgroundImage: imagePath.value.isNotEmpty
                ? FileImage(File(imagePath.value))
                : AssetImage('assets/logo.jpeg') as ImageProvider,
          ),
          if (isEditable)
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: updateProfileImage,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails(
      bool isEditable,
      ValueNotifier<String> username,
      ValueNotifier<String> phone,
      Function(String, String) updateUser,
      VoidCallback navigateToEventsPage,
      ) {
    return Column(
      children: [
        ListTile(
          title: isEditable
              ? TextFormField(
            initialValue: username.value,
            decoration: InputDecoration(labelText: 'Username'),
            onChanged: (value) => username.value = value,
          )
              : Text(username.value, style: TextStyle(fontSize: 24)),
          trailing: isEditable
              ? IconButton(
            icon: Icon(Icons.save),
            onPressed: () => updateUser('username', username.value),
          )
              : null,
        ),
        ListTile(
          title: Text('Phone: ${phone.value}'),
        ),
        ElevatedButton(
          onPressed: navigateToEventsPage,
          child: Text('View Events'),
        ),
      ],
    );
  }

  Widget _buildSettings(
      bool isEditable,
      ValueNotifier<bool> notificationsEnabled,
      Function(bool) updateNotifications,
      VoidCallback onPledgedGiftsNavigate,
      ) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPledgedGiftsNavigate,
          child: Text('My Pledged Gifts'),
        ),
        if (isEditable)
          SwitchListTile(
            title: Text('Enable Notifications'),
            value: notificationsEnabled.value,
            onChanged: (value) {
              notificationsEnabled.value = value;
              updateNotifications(value);
            },
          ),
   ]);
  }
}
