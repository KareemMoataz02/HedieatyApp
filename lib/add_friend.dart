import 'package:flutter/material.dart';
import 'package:hedieaty/database_helper.dart';

class AddFriendPage extends StatefulWidget {
  final String email;

  AddFriendPage({required this.email});

  @override
  _AddFriendPageState createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  List<Map<String, dynamic>> recentFriends = [];
  bool isLoading = true; // To show loading state initially

  @override
  void initState() {
    super.initState();
    fetchRecentFriends(); // Fetch recent friends when the page initializes
  }

  // Fetch recent friends from the database
  void fetchRecentFriends() async {
    int userId = await getCurrentUserId();
    final dbHelper = DatabaseHelper();
    final friends = await dbHelper.getRecentFriendsByUserId(userId);

    setState(() {
      recentFriends = friends;
      isLoading = false; // Set loading to false after data fetch
    });
  }

  // Get current user ID based on email
  Future<int> getCurrentUserId() async {
    final dbHelper = DatabaseHelper();
    var currentUser = await dbHelper.getUserByEmail(widget.email);
    return currentUser?['id'] ?? 0; // Return 0 if no user is found
  }

  // Show dialog with a message
  void showDialogMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Add friend logic (remains unchanged)
  void addFriend(String input, {required bool isEmail}) async {
    // ... Add your existing addFriend implementation here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Friend'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () {
                showAddFriendDialog();
              },
              child: Text('Add Friend by Email or Phone'),
            ),
            SizedBox(height: 16),
            Text(
              'Recent Friends:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            isLoading
                ? Center(child: CircularProgressIndicator()) // Show loading spinner
                : Expanded(
              child: recentFriends.isEmpty
                  ? Center(
                child: Text(
                  'No recent friends found. Add some to see them here!',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: recentFriends.length,
                itemBuilder: (context, index) {
                  final friend = recentFriends[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(friend['email'] ?? 'No email'),
                    subtitle: Text(friend['phone'] ?? 'No phone'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show the dialog to add a friend by email or phone
  void showAddFriendDialog() {
    TextEditingController inputController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Friend'),
          content: TextField(
            controller: inputController,
            decoration: InputDecoration(
              labelText: 'Enter Email or Phone',
              hintText: 'Email or Phone',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                String input = inputController.text.trim();
                if (_isValidEmail(input)) {
                  addFriend(input, isEmail: true);
                  Navigator.of(context).pop();
                } else {
                  showDialogMessage('Error', 'Please enter a valid email address');
                }
              },
              child: Text('Add by Email'),
            ),
            TextButton(
              onPressed: () {
                String input = inputController.text.trim();
                if (_isValidPhone(input)) {
                  addFriend(input, isEmail: false);
                  Navigator.of(context).pop();
                } else {
                  showDialogMessage('Error', 'Please enter a valid phone number');
                }
              },
              child: Text('Add by Phone'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  // Phone validation (basic validation)
  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9]{10,15}$').hasMatch(phone); // Adjust format as per requirements
  }
}
