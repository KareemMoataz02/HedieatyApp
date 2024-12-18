import 'package:flutter/material.dart';
import 'package:hedieaty/services/database_helper.dart';
import 'package:hedieaty/models/friend_model.dart';
import '../models/user_model.dart';
import '../services/notifications.dart';

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
    // Schedule the _initializeData to run 2 seconds after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {

        if (mounted) {
          refreshData();
        }
      });
    }



  Future<void>  refreshData() async {
    await fetchRecentFriends();
    await fetchFriendRequests();
  }

  Future<int> getCurrentUserId() async {
    final userModel = UserModel();
    var currentUser = await userModel.getUserByEmail(widget.email);
    return currentUser?['id'] ?? 0;
  }

  void sendFriendRequest(String input, {required bool isEmail}) async {
    if (input.isEmpty) {
      showDialogMessage('Error', 'Please enter a valid email or phone number');
      return;
    }

    final dbHelper = DatabaseHelper();
    final userModel = UserModel();
    final friendModel = FriendModel();

    var user = isEmail ? await userModel.getUserByEmail(input) : await userModel.getUserByPhone(input);
    int userId = await getCurrentUserId();

    if (user != null && userId != user['id']) {
      int friendId = user['id'];
      bool existingFriend = await friendModel.checkIfFriendExists(userId, friendId);
      if (existingFriend) {
        showDialogMessage('Error', 'You already added this user');
      } else {
        await friendModel.sendFriendRequest(userId, friendId);
        showDialogMessage('Success', 'Friend request sent');
        refreshData();
      }
    }
    else if( userId == user?['id']) {
      showDialogMessage(
          'Error', 'You can\'t send a friend request to yourself');
    }
    else {
      showDialogMessage('Error', 'No user found with this information');
    }
  }

  Future<void> updateFriendRequest(int friendId, String status) async {
    final friendModel = FriendModel();
    final userModel = UserModel();
    final notificationsHelper = NotificationsHelper(); // Assuming NotificationsHelper exists
    int userId = await getCurrentUserId();

    try {
      // Update the friend request status
      await friendModel.updateFriendRequestStatus(userId, friendId, status);

      // Show a dialog message indicating success
      showDialogMessage('Success', status == 'accepted' ? 'Friend request accepted' : 'Friend request declined');

      // Send a notification to the friend about the status update
      var friendEmail = await userModel.getEmailById(friendId); // Assume this returns friend details
      var friend = await userModel.getUserByEmail(friendEmail!);
      var friendNotificationStatus = await userModel.getNotificationStatusFromFirebase(friendEmail);
      String friendToken = friend?['fcm_token']; // Assuming friend details include their FCM token

      if(friendNotificationStatus == 1) {
        // Prepare the notification details
        String notificationTitle = 'Friend Request Update';
        String notificationBody = status == 'accepted'
            ? 'Your friend request was accepted by ${friend?['username']}.'
            : 'Your friend request was declined by ${friend?['username']}.';

        // Send the notification using NotificationsHelper
        await notificationsHelper.sendNotifications(
          fcmToken: friendToken,
          title: notificationTitle,
          body: notificationBody,
          userId: friendId.toString(),
          type: 'friend_request',
        );

        print('Notification sent successfully to $friendEmail.');
      }
      // Refresh data after updating the friend request
      refreshData();
    } catch (error) {
      // Show an error message in case of failure
      showDialogMessage('Error', 'An error occurred while updating the friend request. Please try again.');
      print('Error updating friend request: $error');
    }
  }


  Future<void> fetchRecentFriends() async {
    int userId = await getCurrentUserId();
    final friendModel = FriendModel();
    var friends = await friendModel.getAcceptedFriendsByUserId(userId);
    setState(() => recentFriends = friends);
  }

  Future<void> fetchFriendRequests() async {
    int userId = await getCurrentUserId();
    final friendModel = FriendModel();
    var requests = await friendModel.getFriendRequests(userId);
    setState(() => friendRequests = requests.map((request) => {
      ...request,
      'username': request['username'] ?? 'Unknown',
      'email': request['email'] ?? 'No email available',
      'imagePath': request['imagePath'] ?? '',
      'id': request['user_id'] ?? '',
    }).toList());
  }

  void showDialogMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK')),
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
        content: TextField(controller: inputController, decoration: InputDecoration(labelText: 'Enter Email or Phone', hintText: 'Email or Phone')),
        actions: [
          TextButton(onPressed: () {
            String input = inputController.text.trim();
            if (_isValidEmail(input)) {
              sendFriendRequest(input, isEmail: true);
              Navigator.of(context).pop();
            } else {
              showDialogMessage('Error', 'Please enter a valid email address');
            }
          }, child: Text('Add by Email')),
          TextButton(onPressed: () {
            String input = inputController.text.trim();
            if (_isValidPhone(input)) {
              sendFriendRequest(input, isEmail: false);
              Navigator.of(context).pop();
            } else {
              showDialogMessage('Error', 'Please enter a valid phone number +20**********');
            }
          }, child: Text('Add by Phone')),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
        ],
      ),
    );
  }

  bool _isValidEmail(String email) => RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);

  bool _isValidPhone(String phone) => RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phone);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Friend')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(onPressed: showAddFriendDialog, child: Text('Add Friend by Email or Phone')),
            SizedBox(height: 16),
            Text('Recent Friends:'),
            Expanded(
              child: ListView.builder(
                itemCount: recentFriends.length,
                itemBuilder: (context, index) {
                  final friend = recentFriends[index];
                  return ListTile(title: Text(friend['email'] ?? 'No email'), subtitle: Text(friend['phone'] ?? 'No phone'));
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
                        IconButton(icon: Icon(Icons.check), onPressed: () => updateFriendRequest(request['id'], 'accepted')),
                        IconButton(icon: Icon(Icons.clear), onPressed: () => updateFriendRequest(request['id'], 'declined')),
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
