import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import '../services/database_helper.dart';
import 'gift_details_page.dart';
import '../models/event_model.dart';
import '../models/pledged_gift_model.dart';
import '../models/user_model.dart'; // Ensure this imports your DatabaseHelper

class MyPledgedGiftsPage extends StatefulWidget {
  final String email; // This should be the current user's email

  MyPledgedGiftsPage({required this.email});

  @override
  _MyPledgedGiftsPageState createState() => _MyPledgedGiftsPageState();
}

class _MyPledgedGiftsPageState extends State<MyPledgedGiftsPage> {
  List<Map<String, dynamic>> pledgedGifts = [];
  final dbHelper = DatabaseHelper();
  final userModel = UserModel();
  final  eventModel = EventModel();
  final pledgeModel = PledgeModel();

  @override
  void initState() {
    super.initState();
    _loadPledgedGifts();
  }

  Future<void> _loadPledgedGifts() async {
    try {
      // Fetch gifts pledged by the current user using their email
      final giftList = await pledgeModel.getPledgedGiftsByUser(widget.email);
      print('Pledged gifts: $giftList'); // Debugging line
      setState(() {
        pledgedGifts = giftList;
      });
    } catch (e) {
      print("Error loading pledged gifts: $e");
    }
  }

  // Function to get event details by event ID
  Future<Map<String, dynamic>?> _getEventDetails(int eventId) async {
    final event = await eventModel.getEventById(eventId);
    return event; // Return event details or null if no event found
  }

  // Function to format the deadline
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final formattedDate = DateFormat('MMMM dd, yyyy').format(date);
      return formattedDate;
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Function to get event owner name
  Future<String> _getEventOwnerName(String email) async {
    final user = await userModel.getUserByEmail(email);
    return user?['username'] ?? 'Unknown Owner';
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
          final int eventId = gift['event_id']; // Get the event ID for each gift

          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text(gift['name']),
              subtitle: FutureBuilder<Map<String, dynamic>?>(  // Fetch event details
                future: _getEventDetails(eventId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text('Loading...');
                  } else if (snapshot.hasError) {
                    return Text('Error fetching event');
                  } else if (!snapshot.hasData || snapshot.data == null) {
                    return Text('No event details');
                  } else {
                    final event = snapshot.data!;
                    final eventName = event['name'] ?? 'Unknown Event';
                    final eventDeadline = event['deadline'] ?? '';
                    final formattedDeadline = _formatDate(eventDeadline);

                    // Fetching the event owner name asynchronously
                    return FutureBuilder<String>(
                      future: _getEventOwnerName(event['email']),
                      builder: (context, ownerSnapshot) {
                        if (ownerSnapshot.connectionState == ConnectionState.waiting) {
                          return Text('Loading owner...');
                        } else if (ownerSnapshot.hasError) {
                          return Text('Error fetching owner');
                        } else {
                          final eventOwnerName = ownerSnapshot.data ?? 'Unknown Owner';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Event: $eventName'),
                              Text('Due Date: $formattedDeadline'),
                              Text('Event Owner: $eventOwnerName'),
                            ],
                          );
                        }
                      },
                    );
                  }
                },
              ),
              trailing: Icon(
                Icons.check,
                color: Colors.green,
              ),
              onTap: () {
                // Navigate to GiftDetailsPage with the selected gift
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GiftDetailsPage(gift: gift), // Pass the gift details here
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
