import 'package:flutter/material.dart';

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
              child: CircleAvatar(
                radius: 80,
                backgroundImage: gift['image'] != null
                    ? NetworkImage(gift['image']) // Load from URL
                    : AssetImage('assets/gift.jpg') as ImageProvider, // Default image
                backgroundColor: Colors.grey[200],
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
            _detailText('Price', gift['price'] != null ? '\$${gift['price']}' : 'N/A'),
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
                    Text(
                      gift['description'],
                      style: TextStyle(fontSize: 16),
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
    return Row(
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
            style: TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  // Helper method to create a divider
  Widget _detailDivider() {
    return Divider(thickness: 1.0, height: 24.0);
  }
}
