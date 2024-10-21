import 'package:flutter/material.dart';

class CreateEventPage extends StatelessWidget {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _eventCategoryController = TextEditingController();
  final TextEditingController _eventStatusController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Event'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _eventNameController,
              decoration: InputDecoration(labelText: 'Event Name'),
            ),
            TextField(
              controller: _eventCategoryController,
              decoration: InputDecoration(labelText: 'Event Category'),
            ),
            TextField(
              controller: _eventStatusController,
              decoration: InputDecoration(labelText: 'Event Status'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Logic to save the new event
                // You can add logic to add the new event to the list
                Navigator.pop(context); // Navigate back after saving
              },
              child: Text('Create Event'),
            ),
          ],
        ),
      ),
    );
  }
}
