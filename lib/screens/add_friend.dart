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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        refreshData();
      }
    });
  }

  Future<void> refreshData() async {
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
    } else if (userId == user?['id']) {
      showDialogMessage('Error', 'You can\'t send a friend request to yourself');
    } else {
      showDialogMessage('Error', 'No user found with this information');
    }
  }

  Future<void> updateFriendRequest(int friendId, String status) async {
    final friendModel = FriendModel();
    final userModel = UserModel();
    final notificationsHelper = NotificationsHelper();
    final dbHelper = DatabaseHelper();
    bool connected = await dbHelper.isConnectedToInternet();
    int userId = await getCurrentUserId();

    try {
      await friendModel.updateFriendRequestStatus(userId, friendId, status);
      showDialogMessage('Success', status == 'accepted' ? 'Friend request accepted' : 'Friend request declined');

      String? friendEmail = await userModel.getEmailById(friendId);
      if (friendEmail == null) return;

      var friend = await userModel.getUserByEmail(friendEmail);
      if (friend == null) return;

      int? friendNotificationStatus = await userModel.getNotificationStatusFromFirebase(friendEmail);
      friendNotificationStatus ??= 0;
      String? friendToken = await userModel.getFcmTokenFromFirebase(friendEmail);

      if (friendToken != null && friendToken.isNotEmpty && friendNotificationStatus == 1 && connected) {
        String notificationTitle = 'Friend Request Update';
        String notificationBody = status == 'accepted'
            ? 'Your friend request was accepted by ${friend['username']}.'
            : 'Your friend request was declined by ${friend['username']}.';

        await notificationsHelper.sendNotifications(
          fcmToken: friendToken,
          title: notificationTitle,
          body: notificationBody,
          userId: friendId.toString(),
          type: 'friend_request',
        );
      }

      refreshData();
    } catch (error, stackTrace) {
      showDialogMessage('Error', 'An error occurred while updating the friend request. Please try again.');
      print('Error updating friend request: $error\n$stackTrace');
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
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: Theme.of(context).colorScheme.primary))),
        ],
      ),
    );
  }

  void showAddFriendDialog() {
    TextEditingController inputController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Friend', style: Theme.of(context).textTheme.titleLarge),
        content: TextField(
          controller: inputController,
          decoration: InputDecoration(
            labelText: 'Enter Email or Phone',
            hintText: 'Email or Phone',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
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
            child: Text('Add by Email', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          TextButton(
            onPressed: () {
              String input = inputController.text.trim();
              if (_isValidPhone(input)) {
                sendFriendRequest(input, isEmail: false);
                Navigator.of(context).pop();
              } else {
                showDialogMessage('Error', 'Please enter a valid phone number +20**********');
              }
            },
            child: Text('Add by Phone', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String email) => RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  bool _isValidPhone(String phone) => RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phone);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Friend', style: Theme.of(context).textTheme.titleLarge),
        elevation: 4.0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: showAddFriendDialog,
              icon: Icon(Icons.person_add),
              label: Text('Add Friend by Email or Phone'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            SizedBox(height: 16),
            Divider(),
            Text('Recent Friends:', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: recentFriends.length,
                itemBuilder: (context, index) {
                  final friend = recentFriends[index];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text(friend['email'] ?? 'No email'),
                      subtitle: Text(friend['phone'] ?? 'No phone'),
                    ),
                  );
                },
              ),
            ),
            Divider(),
            Text('Friend Requests:', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: friendRequests.length,
                itemBuilder: (context, index) {
                  final request = friendRequests[index];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text(request['email'] ?? 'Unknown'),
                      subtitle: Text('Request Pending'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () => updateFriendRequest(request['id'], 'accepted'),
                          ),
                          IconButton(
                            icon: Icon(Icons.clear, color: Colors.red),
                            onPressed: () => updateFriendRequest(request['id'], 'declined'),
                          ),
                        ],
                      ),
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
