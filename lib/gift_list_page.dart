import 'package:flutter/material.dart';

class GiftListPage extends StatelessWidget {
  final String friendName;

  GiftListPage({required this.friendName});

  final List<Map<String, String>> gifts = [
    {'name': 'Watch', 'category': 'Electronics', 'status': 'Available'},
    {'name': 'Book', 'category': 'Books', 'status': 'Pledged'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$friendName\'s Gift List'),
      ),
      body: ListView.builder(
        itemCount: gifts.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(gifts[index]['name']!),
            subtitle: Text('${gifts[index]['category']} - ${gifts[index]['status']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    // Navigate to Edit Gift Page
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    // Delete gift functionality
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to Create Gift Page
        },
        child: Icon(Icons.add),
        tooltip: 'Add Gift',
      ),
    );
  }
}
