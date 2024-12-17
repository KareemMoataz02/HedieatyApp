// gift_details_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../services/gift_image.dart'; // Import the GiftImage widget

class GiftDetailsPage extends StatelessWidget {
  final Map<String, dynamic> gift;

  GiftDetailsPage({required this.gift});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(gift['name'] ?? 'Gift Details'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gift image or placeholder
            Center(
              child: ClipOval(
                child: SizedBox(
                  width: 160, // Desired width
                  height: 160, // Desired height
                  child: gift['image_path'] != null && gift['image_path'].isNotEmpty
                      ? GiftImage(base64Image: gift['image_path'])
                      : Image.asset(
                    'assets/gift_placeholder.png', // Ensure you have this asset
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),

            // Gift details
            _detailText('Name', gift['name']),
            _detailDivider(),
            _detailText('Category', gift['category']),
            _detailDivider(),
            _detailText('Status', gift['status']),
            _detailDivider(),
            _detailText(
                'Price', gift['price'] != null ? '\$${gift['price']}' : 'N/A'),
            _detailDivider(),

            // Optional description
            if (gift['description'] != null && gift['description'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    // Center the description text
                    Center(
                      child: Text(
                        gift['description'],
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center, // Ensures text is centered
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to display detail text
  Widget _detailText(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0), // Add vertical padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to create a divider
  Widget _detailDivider() {
    return Divider(thickness: 1.0, height: 24.0);
  }
}
