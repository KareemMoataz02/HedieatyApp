import 'package:flutter/material.dart';
import 'database_helper.dart';

class MyPledgedGiftsPage extends StatefulWidget {
  final String email; // This should be the current user's email

  MyPledgedGiftsPage({required this.email});

  @override
  _MyPledgedGiftsPageState createState() => _MyPledgedGiftsPageState();
}

class _MyPledgedGiftsPageState extends State<MyPledgedGiftsPage> {
  List<Map<String, dynamic>> pledgedGifts = [];
  final dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadPledgedGifts();
  }

  Future<void> _loadPledgedGifts() async {
    try {
      // Fetch only the gifts pledged by the current user
      final giftList = await dbHelper.getPledgedGiftsByUser(widget.email);
      setState(() {
        pledgedGifts = giftList;
      });
    } catch (e) {
      print("Error loading pledged gifts: $e");
    }
  }

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
              title: Text(gift['name']),
              subtitle: Text(
                'Due Date: ${gift['dueDate']}',
              ),
              trailing: Icon(
                Icons.check,
                color: Colors.green,
              ),
            ),
          );
        },
      ),
    );
  }
}
