import 'package:flutter/material.dart';
import 'add_gift_page.dart'; // Import AddGiftPage
import 'gift_details_page.dart'; // Import GiftDetailsPage

class GiftListPage extends StatefulWidget {
  final String friendName;
  final String eventName;

  GiftListPage({required this.friendName, required this.eventName});

  @override
  _GiftListPageState createState() => _GiftListPageState();
}

class _GiftListPageState extends State<GiftListPage> {
  List<Map<String, String>> gifts = [
    {'name': 'Watch', 'category': 'Electronics', 'status': 'Available', 'event': ''},
    {'name': 'Book', 'category': 'Books', 'status': 'Pledged', 'event': 'Birthday Party'},
    {'name': 'Perfume', 'category': 'Beauty', 'status': 'Available', 'event': ''},
    {'name': 'T-shirt', 'category': 'Clothing', 'status': 'Pledged', 'event': 'Graduation'},
    {'name': 'Smartphone', 'category': 'Electronics', 'status': 'Available', 'event': ''},
    {'name': 'Headphones', 'category': 'Electronics', 'status': 'Pledged', 'event': 'Wedding'},
    {'name': 'Chocolate', 'category': 'Food', 'status': 'Available', 'event': ''},
    {'name': 'Shoes', 'category': 'Clothing', 'status': 'Available', 'event': ''},
    {'name': 'Board Game', 'category': 'Toys', 'status': 'Pledged', 'event': 'Birthday Party'},
  ];

  String sortBy = 'name';

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
        gifts[index]['event'] = widget.eventName;
      } else {
        gifts[index]['status'] = 'Available';
        gifts[index]['event'] = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gift List'),
        actions: [
          DropdownButton<String>(
            value: sortBy,
            onChanged: (String? newValue) {
              setState(() {
                sortBy = newValue!;
                sortGifts();
              });
            },
            items: <String>['name', 'status']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text('Sort by $value'),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
                          togglePledge(index);
                        },
                        color: gifts[index]['status'] == 'Pledged' ? Colors.green : Colors.grey,
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          // Implement edit functionality as needed
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.info),
                        onPressed: () {
                          // Navigate to GiftDetailsPage
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GiftDetailsPage(gift: gifts[index]),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddGiftPage(),
                    ),
                  );
                },
                child: Text('Create Gift'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
