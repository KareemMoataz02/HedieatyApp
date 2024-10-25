import 'package:flutter/material.dart';

class GiftDetailsPage extends StatelessWidget {
  final Map<String, String> gift;

  GiftDetailsPage({required this.gift});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(gift['name'] ?? 'Gift Details'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Center align the children
          children: [
            // Centered CircleAvatar for the gift icon
            Center(
              child: CircleAvatar(
                radius: 100, // Increased size for a larger avatar
                backgroundImage: AssetImage('Assets/gift.jpg'), // Update the image path as needed
                backgroundColor: Colors.grey[200], // Fallback color
              ),
            ),
            SizedBox(height: 16), // Space between avatar and text

            // Gift details
            Text(
              'Name: ${gift['name'] ?? 'N/A'}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Divider(), // Divider for better separation

            Text(
              'Category: ${gift['category'] ?? 'N/A'}',
              style: TextStyle(fontSize: 18),
            ),
            Divider(), // Divider for better separation

            Text(
              'Status: ${gift['status'] ?? 'N/A'}',
              style: TextStyle(fontSize: 18),
            ),
            Divider(), // Divider for better separation

            Text(
              'Price: \$${gift['price'] ?? 'N/A'}',
              style: TextStyle(fontSize: 18),
            ),
            Divider(), // Divider for better separation

            Text(
              'Event: ${gift['event'] ?? 'N/A'}',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
