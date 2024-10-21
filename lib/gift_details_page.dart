import 'package:flutter/material.dart';

class GiftDetailsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gift Details'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Gift Name'),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Description'),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Category'),
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Price'),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                // Upload image functionality
              },
              child: Text('Upload Image'),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status:'),
                DropdownButton<String>(
                  value: 'Available',
                  items: <String>['Available', 'Pledged']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    // Update status
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
