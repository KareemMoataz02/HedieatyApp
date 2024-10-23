import 'package:flutter/material.dart';

class MyPledgedGiftsPage extends StatelessWidget {
  // Sample data for pledged gifts (replace with your actual data source)
  final List<Map<String, dynamic>> pledgedGifts = [
    {
      'giftName': 'Birthday Gift',
      'friendName': 'Alice',
      'dueDate': '2024-12-01',
      'status': 'Pending',
    },
    {
      'giftName': 'Wedding Gift',
      'friendName': 'Bob',
      'dueDate': '2024-10-15',
      'status': 'Completed',
    },
    {
      'giftName': 'Graduation Gift',
      'friendName': 'Charlie',
      'dueDate': '2024-11-30',
      'status': 'Pending',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Pledged Gifts'),
      ),
      body: pledgedGifts.isEmpty
          ? Center(child: Text('No pledged gifts found.'))
          : ListView.builder(
        itemCount: pledgedGifts.length,
        itemBuilder: (context, index) {
          final gift = pledgedGifts[index];
          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text(gift['giftName']),
              subtitle: Text('Pledged to: ${gift['friendName']}\nDue Date: ${gift['dueDate']}'),
              trailing: gift['status'] == 'Pending'
                  ? IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: () {
                  // Functionality to edit the pledge
                },
              )
                  : Icon(Icons.check, color: Colors.green),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Functionality to add a new pledged gift
        },
        child: Icon(Icons.add),
        tooltip: 'Add Pledged Gift',
      ),
    );
  }
}
