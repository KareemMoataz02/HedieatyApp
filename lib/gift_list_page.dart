import 'package:flutter/material.dart';

class GiftListPage extends StatefulWidget {
  final String friendName;
  final String eventName; // New field to hold the event name

  GiftListPage({required this.friendName, required this.eventName});

  @override
  _GiftListPageState createState() => _GiftListPageState();
}

class _GiftListPageState extends State<GiftListPage> {
  // List of gifts with an additional field for the event
  List<Map<String, String>> gifts = [
    {'name': 'Watch', 'category': 'Electronics', 'status': 'Available', 'event': ''},
    {'name': 'Book', 'category': 'Books', 'status': 'Pledged', 'event': 'Birthday Party'},
    {'name': 'Perfume', 'category': 'Beauty', 'status': 'Available', 'event': ''},
    {'name': 'T-shirt', 'category': 'Clothing', 'status': 'Pledged', 'event': 'Graduation'},
    {'name': 'Smartphone', 'category': 'Electronics', 'status': 'Available', 'event': ''},
    {'name': 'Headphones', 'category': 'Electronics', 'status': 'Pledged', 'event': 'Wedding'},
    {'name': 'Chocolate', 'category': 'Food', 'status': 'Available', 'event': ''},
    {'name': 'Camera', 'category': 'Electronics', 'status': 'Pledged', 'event': 'Graduation'},
    {'name': 'Shoes', 'category': 'Clothing', 'status': 'Available', 'event': ''},
    {'name': 'Board Game', 'category': 'Toys', 'status': 'Pledged', 'event': 'Birthday Party'},
  ];

  String sortBy = 'name'; // Default sorting criteria

  void sortGifts() {
    setState(() {
      if (sortBy == 'name') {
        gifts.sort((a, b) => a['name']!.compareTo(b['name']!));
      } else if (sortBy == 'status') {
        gifts.sort((a, b) => a['status']!.compareTo(b['status']!));
      }
    });
  }

  void togglePledge(int index) {
    setState(() {
      if (gifts[index]['status'] == 'Available') {
        gifts[index]['status'] = 'Pledged';
        gifts[index]['event'] = widget.eventName; // Assign the event name
      } else {
        gifts[index]['status'] = 'Available';
        gifts[index]['event'] = ''; // Clear the event name
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.friendName}\'s Gift List for ${widget.eventName}'), // Show event name
        actions: [
          DropdownButton<String>(
            value: sortBy,
            onChanged: (String? newValue) {
              setState(() {
                sortBy = newValue!;
                sortGifts();
              });
            },
            items: <String>['name', 'status'].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text('Sort by $value'),
              );
            }).toList(),
          ),
        ],
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
                  icon: Icon(Icons.thumb_up),
                  onPressed: () {
                    togglePledge(index); // Toggle pledge/unpledge status
                  },
                  color: gifts[index]['status'] == 'Pledged' ? Colors.green : Colors.grey,
                ),
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    // Navigate to Edit Gift Page (implement as needed)
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    // Delete gift functionality (implement as needed)
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to Create Gift Page (implement as needed)
        },
        child: Icon(Icons.add),
        tooltip: 'Add Gift',
      ),
    );
  }
}
