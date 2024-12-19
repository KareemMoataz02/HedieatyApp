import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import '../services/database_helper.dart';
import 'gift_details_page.dart';
import '../models/event_model.dart';
import '../models/pledged_gift_model.dart';
import '../models/user_model.dart';
import '../models/gift_model.dart'; // Import for GiftModel

class MyPledgedGiftsPage extends StatefulWidget {
  final String email; // The current user's email

  const MyPledgedGiftsPage({Key? key, required this.email}) : super(key: key);

  @override
  _MyPledgedGiftsPageState createState() => _MyPledgedGiftsPageState();
}

class _MyPledgedGiftsPageState extends State<MyPledgedGiftsPage> {
  List<Map<String, dynamic>> pledgedGifts = [];
  List<Map<String, dynamic>> giftDetails = [];
  bool isLoading = false;

  final DatabaseHelper dbHelper = DatabaseHelper();
  final UserModel userModel = UserModel();
  final EventModel eventModel = EventModel();
  final PledgeModel pledgeModel = PledgeModel();
  final GiftModel giftModel = GiftModel();

  @override
  void initState() {
    super.initState();
    _loadPledgedGifts();
  }

  Future<void> _loadPledgedGifts() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch pledged gifts for the current user
      final List<Map<String, dynamic>> pledgedGiftList =
      await pledgeModel.getPledgedGiftsByUser(widget.email);

      // Fetch gift details for each pledged gift
      List<Map<String, dynamic>> gifts = [];
      for (var pledge in pledgedGiftList) {
        final giftDetail = await giftModel.getGiftById(pledge['giftId']);
        if (giftDetail != null) {
          gifts.add(giftDetail);
        }
      }

      setState(() {
        pledgedGifts = pledgedGiftList;
        giftDetails = gifts; // Store detailed gift information
      });
    } catch (e) {
      print("Error loading pledged gifts: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _getEventDetails(int eventId) async {
    try {
      return await eventModel.getEventById(eventId);
    } catch (e) {
      print("Error fetching event details for ID $eventId: $e");
      return null;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('MMMM dd, yyyy').format(date);
    } catch (e) {
      print("Date formatting error: $e");
      return 'Invalid date';
    }
  }

  Future<String> _getEventOwnerName(String email) async {
    try {
      final user = await userModel.getUserByEmail(email);
      return user?['username'] ?? 'Unknown Owner';
    } catch (e) {
      print("Error fetching event owner name for email $email: $e");
      return 'Unknown Owner';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pledged Gifts'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pledgedGifts.isEmpty
          ? const Center(child: Text('No pledged gifts found.'))
          : ListView.builder(
        itemCount: pledgedGifts.length,
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> pledge = pledgedGifts[index];
          final Map<String, dynamic>? gift =
          giftDetails.firstWhere((g) => g['id'] == pledge['giftId']);

          if (gift == null) {
            return const ListTile(
              title: Text('Error: Gift details not found'),
            );
          }

          final int? eventId = gift['event_id'];

          if (eventId == null) {
            return const ListTile(
              title: Text('Error: Gift has no associated event'),
            );
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text(gift['name']),
              subtitle: FutureBuilder<Map<String, dynamic>?>(
                future: _getEventDetails(eventId),
                builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Text('Loading event details...');
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (snapshot.data == null) {
                    return const Text('No event details available.');
                  } else {
                    final Map<String, dynamic> event = snapshot.data!;
                    final String eventName = event['name'] ?? 'Unknown Event';
                    final String eventDeadline = event['date'] ?? '';
                    final String formattedDeadline = _formatDate(eventDeadline);

                    return FutureBuilder<String>(
                      future: _getEventOwnerName(event['email']),
                      builder: (BuildContext context, AsyncSnapshot<String> ownerSnapshot) {
                        if (ownerSnapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Loading owner name...');
                        } else if (ownerSnapshot.hasError) {
                          return Text('Error: ${ownerSnapshot.error}');
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Event: $eventName'),
                              Text('Event Date: $formattedDeadline'),
                              Text('Event Owner: ${ownerSnapshot.data}'),
                            ],
                          );
                        }
                      },
                    );
                  }
                },
              ),
              trailing: const Icon(Icons.check, color: Colors.green),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GiftDetailsPage(gift: gift),
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
