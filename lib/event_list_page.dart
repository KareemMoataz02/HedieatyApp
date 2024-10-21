import 'package:flutter/material.dart';
import 'gift_list_page.dart'; // Import GiftListPage

class EventListPage extends StatelessWidget {
  final String friendName;

  EventListPage({required this.friendName});

  final List<Map<String, dynamic>> events = [
    {'name': 'Birthday Party', 'category': 'Birthday', 'status': 'Upcoming'},
    {'name': 'Wedding', 'category': 'Wedding', 'status': 'Current'},
    {'name': 'Graduation', 'category': 'Graduation', 'status': 'Past'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$friendName\'s Events'),
      ),
      body: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(events[index]['name']!),
            subtitle: Text('${events[index]['category']} - ${events[index]['status']}'),
            onTap: () {
              // Navigate to Gift List Page when the event is tapped
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GiftListPage(friendName: friendName),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to Create Event Page
        },
        child: Icon(Icons.add),
        tooltip: 'Add Event',
      ),
    );
  }
}
