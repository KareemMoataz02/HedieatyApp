import 'package:flutter/material.dart';
import 'home_page.dart';


class LoginPage extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add CircleAvatar with gift image
            CircleAvatar(
              radius: 100, // Adjust the size of the icon
              backgroundImage: AssetImage('Assets/gift.jpg'), // Image path
            ),
            SizedBox(height: 20), // Space between the icon and text fields
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Logic to handle login validation
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                );
              },
              child: Text('Login'),
            ),
            TextButton(
              onPressed: () {
                // Open SignUp Dialog
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SignUpDialog(); // Call the SignUp dialog here
                  },
                );
              },
              child: Text('Don\'t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}


class SignUpDialog extends StatefulWidget {
  @override
  _SignUpDialogState createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<SignUpDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sign Up'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: 'Username'),
          ),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            // Logic to handle sign up
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
          child: Text('Sign Up'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog
          },
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
