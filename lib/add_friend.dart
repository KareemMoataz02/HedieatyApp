import 'package:flutter/material.dart';

class AddFriendPage extends StatefulWidget {
  @override
  _AddFriendPageState createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  void addFriendByEmail() {
    String email = emailController.text;
    if (email.isNotEmpty) {
      print('Friend added by email: $email');
      emailController.clear();
    } else {
      showError('Please enter a valid email');
    }
  }

  void addFriendByPhone() {
    String phone = phoneController.text;
    if (phone.isNotEmpty) {
      print('Friend added by phone: $phone');
      phoneController.clear();
    } else {
      showError('Please enter a valid phone number');
    }
  }

  void showError(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error'),
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

  void showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Option'),
          content: Text('Choose how to add a friend:'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                showEmailInput();
              },
              child: Text('Add by Email'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                showPhoneInput();
              },
              child: Text('Add by Phone'),
            ),
          ],
        );
      },
    );
  }

  void showEmailInput() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Friend by Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter email address',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                addFriendByEmail();
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Add'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void showPhoneInput() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Friend by Phone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter phone number',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                addFriendByPhone();
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Add'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Choose how you want to add a friend:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: showAddFriendDialog,
              child: Text('Add by Email or Phone'),
            ),
            SizedBox(height: 20),
            Text(
              'Recent Friends:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: 5, // Replace with actual number of recent friends
                itemBuilder: (context, index) {
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text('Friend $index'), // Replace with friend data
                      subtitle: Text('friend${index}@example.com'), // Example email
                      trailing: Icon(Icons.person),
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
