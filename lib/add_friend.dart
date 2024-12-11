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
  List<Map<String, dynamic>> friendRequests = [];

  @override
  void initState() {
    super.initState();
    fetchRecentFriends();
    fetchFriendRequests();
  }

  Future<int> getCurrentUserId() async {
    final dbHelper = DatabaseHelper();
    var currentUser = await dbHelper.getUserByEmail(widget.email);
    return currentUser?['id'] ?? 0;
  }

  void sendFriendRequest(String input, {required bool isEmail}) async {
    if (input.isEmpty) {
      showDialogMessage('Error', 'Please enter a valid email or phone number');
      return;
    }

    final dbHelper = DatabaseHelper();
    var user = isEmail
        ? await dbHelper.getUserByEmail(input)
        : await dbHelper.getUserByPhone(input);

    if (user != null) {
      int userId = await getCurrentUserId();
      int friendId = user['id'];

      if (userId == friendId) {
        showDialogMessage('Error', 'You cannot add yourself as a friend');
        return;
      }

      bool existingFriend = await dbHelper.checkIfFriendExists(userId, friendId);
      if (existingFriend) {
        showDialogMessage('Error', 'You already added this user');
      } else {
        await dbHelper.sendFriendRequest(userId, friendId);
        fetchFriendRequests();
        showDialogMessage('Success', 'Friend request sent');
      }
    } else {
      showDialogMessage('Error', 'No user found with this information');
    }
  }

  void fetchRecentFriends() async {
    int userId = await getCurrentUserId();
    final dbHelper = DatabaseHelper();
    final friends = await dbHelper.getAcceptedFriendsByUserId(userId);
    setState(() {
      recentFriends = friends;
    });
  }

  void fetchFriendRequests() async {
    int userId = await getCurrentUserId();
    final dbHelper = DatabaseHelper();
    final requests = await dbHelper.getFriendRequests(userId);

    setState(() {
      friendRequests = requests.map((request) {
        return {
          ...request,
          'username': request['username'] ?? 'Unknown',
          'email': request['email'] ?? 'No email available',
          'imagePath': request['imagePath'] ?? '',
          'id': request['user_id']?? '',
        };
      }).toList();
    });
  }

  void updateFriendRequest(int friendId, String status) async {
    final dbHelper = DatabaseHelper();
    int userId = await getCurrentUserId(); // Get the current user's ID.

    try {
      // Update the friend request status in the database.
      await dbHelper.updateFriendRequestStatus(userId, friendId, status);

      if (status == 'accepted') {
        // Refresh the recent friends list.
        fetchRecentFriends();

        // Show success message for accepting the request.
        showDialogMessage('Success', 'Friend request accepted.');
      } else if (status == 'declined') {
        // Show success message for declining the request.
        showDialogMessage('Success', 'Friend request declined.');
      }

      // Refresh the friend requests list.
      fetchFriendRequests();
    } catch (error) {
      // Handle any errors that occur during the process.
      showDialogMessage('Error', 'An error occurred while updating the friend request. Please try again.');
      print('Error updating friend request: $error');
    }
  }


  void showDialogMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void showAddFriendDialog() {
    TextEditingController inputController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Friend'),
        content: TextField(
          controller: inputController,
          decoration: InputDecoration(labelText: 'Enter Email or Phone', hintText: 'Email or Phone'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              String input = inputController.text.trim();
              if (_isValidEmail(input)) {
                sendFriendRequest(input, isEmail: true);
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
                sendFriendRequest(input, isEmail: false);
                Navigator.of(context).pop();
              } else {
                showDialogMessage('Error', 'Please enter a valid phone number');
              }
            },
            child: Text('Add by Phone'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Friend')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: showAddFriendDialog,
              child: Text('Add Friend by Email or Phone'),
            ),
            SizedBox(height: 16),
            Text('Recent Friends:'),
            Expanded(
              child: ListView.builder(
                itemCount: recentFriends.length,
                itemBuilder: (context, index) {
                  final friend = recentFriends[index];
                  return ListTile(
                    title: Text(friend['email'] ?? 'No email'),
                    subtitle: Text(friend['phone'] ?? 'No phone'),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Text('Friend Requests:'),
            Expanded(
              child: ListView.builder(
                itemCount: friendRequests.length,
                itemBuilder: (context, index) {
                  final request = friendRequests[index];
                  return ListTile(
                    title: Text(request['email'] ?? 'Unknown'),
                    subtitle: Text('Request Pending'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check),
                          onPressed: () => updateFriendRequest(request['id'], 'accepted'),
                        ),
                        IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () => updateFriendRequest(request['id'], 'declined'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
