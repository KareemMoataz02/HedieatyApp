import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_gift_page.dart';
import 'gift_details_page.dart';
import 'database_helper.dart';
import 'package:hedieaty/connectivity_service.dart';
import 'package:hedieaty/notifications.dart';

class GiftListPage extends StatefulWidget {
  final String friendEmail;
  final String eventName;
  final int eventId;

  GiftListPage({
    required this.friendEmail,
    required this.eventName,
    required this.eventId,
  });

  @override
  _GiftListPageState createState() => _GiftListPageState();
}

class _GiftListPageState extends State<GiftListPage> {
  List<Map<String, dynamic>> gifts = [];
  String sortBy = 'name';
  bool isLoading = false;
  bool isOwner = false;
  bool isConnected = false;
  String eventOwner = 'Event Owner';
  String userToken = 'User Token';
  String title = "Pledge Notification";
  String body = "A Friend Has Pledged Your Gift";
  int userNotifications = 0;
  String userOwnerId = '';


  final dbHelper = DatabaseHelper();
  late StreamSubscription<bool> _connectivitySubscription;
  @override
  void initState() {
    super.initState();
    _loadGifts();
    _checkOwnership(); //
    _getEventOwnerEmail();

    // Use the singleton instance of ConnectivityService directly
    _connectivitySubscription =
        ConnectivityService().connectionStatusStream.listen((isConnected) {
      setState(() {
        this.isConnected = isConnected;
      });
    });
  }

  @override
  void dispose() {
    // Cancel the connectivity subscription to avoid memory leaks
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Load gifts with the correct pledged status
  Future<void> _loadGifts() async {
    setState(() {
      isLoading = true;
    });
    try {
      final dbHelper = DatabaseHelper();
      final giftList = await dbHelper.getGiftsByEventId(widget.eventId);

      // Fetch logged-in user's email
      final prefs = await SharedPreferences.getInstance();
      final loggedInEmail = prefs.getString('email') ?? '';

      // Check if each gift is pledged by the logged-in user
      final updatedGiftList = await Future.wait(giftList.map((gift) async {
        final pledges = await dbHelper.getPledgedGiftsByUser(loggedInEmail);
        final isPledgedByUser =
            pledges.any((pledgedGift) => pledgedGift['id'] == gift['id']);
        return {
          ...gift,
          'status': isPledgedByUser
              ? 'Pledged'
              : gift['status'] ?? 'Available', // Ensure a default status
        };
      }));

      setState(() {
        gifts = updatedGiftList;
      });
    } catch (e) {
      print("Error loading gifts: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getEventOwnerEmail() async {
    try {
      String? eventOwnerEmail = await dbHelper.getEventOwnerEmail(widget.eventId);
      if (eventOwnerEmail != null) {
        print('Event owner email: $eventOwnerEmail');
        // If you need to do something with the email in your state, like displaying it
        setState(() {
          this.eventOwner = eventOwnerEmail;
          _getEventOwner();
        });
      } else {
        print("No owner found for this event.");
      }
    } catch (e) {
      print("Failed to fetch event owner email: $e");
    }
  }

  Future<void> _getEventOwner() async {
    try {
      final user = await dbHelper.getUserByEmail(eventOwner);
      // Check if user is not null and if the user map contains the 'fcm_token' and 'notifications' keys
      userToken = user?['fcm_token'] ?? ''; // Provide a default value or handle null separately
      userNotifications = user?['notifications'] ?? 0; // Ensure default false if null
      userOwnerId = user!['id'].toString();
      print('Aana user Token');
      print(userToken);
      print(userNotifications);
      print(userOwnerId);
    } catch (e) {
      print("Error in _getEventOwner: $e");
    }
  }


  Future<void> sendNotificationToGiftOwner(String userToken, String title, String body, String userOwnerId) async {
    if (userNotifications == 1 ) {
      var notificationsHelper = NotificationsHelper();
      await notificationsHelper.sendNotifications(
        fcmToken: userToken,
        title: title,
        body: body,
        userId: userOwnerId,
        type: "pledge",
      );
    }
  }

  // Check if the logged-in user is the owner of the event
  Future<void> _checkOwnership() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInEmail =
        prefs.getString('email'); // Get logged-in user's email
    if (loggedInEmail != null && loggedInEmail == widget.friendEmail) {
      setState(() {
        isOwner = true;
      });
    }
  }

  // Sort the gifts based on selected criteria
  void sortGifts() {
    setState(() {
      if (sortBy == 'name') {
        gifts.sort((a, b) => a['name'].compareTo(b['name']));
      } else if (sortBy == 'status') {
        gifts.sort((a, b) => a['status'].compareTo(b['status']));
      }
    });
  }

// Toggle the pledge status (Available/Pledged) of a gift
  Future<void> togglePledge(int index) async {
    final currentGift = gifts[index];
    final isPledged = currentGift['status'] == 'Pledged';
    final dbHelper = DatabaseHelper();

    // Get the logged-in user's email
    final prefs = await SharedPreferences.getInstance();
    final loggedInEmail = prefs.getString('email') ?? '';

    if (isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Can not pledge your own gift')));
      return;
    }

    // Set isLoading true to show progress indicator during the operation
    setState(() {
      isLoading = true;
    });

    try {
      if (isPledged) {
        // Retrieve all pledges for this gift to check who pledged it
        final pledgedGifts =
            await dbHelper.getPledgedGiftsByUser(loggedInEmail.toLowerCase());

        print("PLEDGEDD MENYYY");
        print(pledgedGifts);

        final isPledgedByUser = pledgedGifts.any((pledgedGift) {
          print('Checking pledged gift: ${pledgedGift}');
          print('Current gift ID: ${currentGift['id']}');
          print('Pledged gift ID: ${pledgedGift['id']}');
          print('Pledged gift userEmail: ${pledgedGift['userEmail']}');

          return pledgedGift['id'] == currentGift['id'] &&
              pledgedGift['userEmail'] == loggedInEmail.toLowerCase();
        });

        if (!isPledgedByUser) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Only the original pledger can unpledge this gift.')),
          );
        } else {
          // Remove the pledge since it is confirmed that the current user pledged it
          await dbHelper.removePledge(loggedInEmail, currentGift['id']);
          setState(() {
            currentGift['status'] =
                'Available'; // Update the status of the gift to Available
          });
        }
      } else if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot Pledge a gift while offline')),
        );
      } else {
        // Pledge the gift if it is not pledged and the device is online
        await dbHelper.insertPledge(loggedInEmail, currentGift['id']);
        sendNotificationToGiftOwner(userToken, title, body, userOwnerId);
        setState(() {
          currentGift['status'] =
              'Pledged'; // Update the status of the gift to Pledged
        });
      }
    } catch (e) {
      print("Error toggling pledge: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update pledge status.')),
      );
    } finally {
      setState(() {
        isLoading =
            false; // Ensure isLoading is set to false to hide the progress indicator
      });
    }
  }

  // Edit the details of an existing gift
  Future<void> editGift(Map<String, dynamic> updatedGift) async {
    try {
      await dbHelper.updateGift(updatedGift);
      setState(() {
        final index =
            gifts.indexWhere((gift) => gift['id'] == updatedGift['id']);
        if (index != -1) {
          gifts[index] = updatedGift;
        }
      });
    } catch (e) {
      print("Error editing gift: $e");
    }
  }

  // Delete an event
  Future<void> deleteGift(int index) async {
    if (index < 0 || index >= gifts.length) {
      print("Invalid index: $index");
      return;
    }

    final dbHelper = DatabaseHelper();
    try {
      final giftId = gifts[index]['id']; // Fetch the gift ID

      // Check if the gift has any pledges before allowing deletion
      final pledgedGifts =
          await dbHelper.getPledgedGiftsByUser(gifts[index]['userEmail']);

      if (pledgedGifts.isNotEmpty) {
        print(
            "Gift with ID $giftId cannot be deleted because it has been pledged.");
        return; // Prevent deletion if the gift has pledges
      }

      // Proceed with deletion if no pledges are found
      final rowsAffected = await dbHelper.deleteGift(giftId);

      if (rowsAffected > 0) {
        setState(() {
          gifts.removeAt(index); // Remove from the list
        });
        print("Gift with ID $giftId deleted successfully.");
      } else {
        print("No gift found with ID $giftId.");
      }
    } catch (e) {
      print("Error deleting gift: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gift List for ${widget.eventName}'),
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
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: gifts.length,
                    itemBuilder: (context, index) {
                      final gift = gifts[index];
                      final giftStatus = gift['status'];
                      final bool isPledged = giftStatus == 'Pledged';

                      return Card(
                        margin:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          title: Text(
                            gift['name'],
                            style: isPledged
                                ? TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey)
                                : TextStyle(),
                          ),
                          subtitle: Text(
                            '${gift['category']} - ${gift['status']}',
                            style: isPledged
                                ? TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey)
                                : TextStyle(),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                      scale: animation, child: child);
                                },
                                child: IconButton(
                                  key: ValueKey(gift['status']),
                                  icon: Icon(
                                    isPledged
                                        ? Icons.thumb_down
                                        : Icons.thumb_up,
                                    color:
                                        isPledged ? Colors.red : Colors.green,
                                  ),
                                  onPressed: () {
                                    togglePledge(index);
                                  },
                                ),
                              ),
                              // Show Edit button only if the logged-in user is the owner
                              if (isOwner)
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () {
                                    _showEditDialog(context, gift);
                                  },
                                ),
                              if (isOwner)
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () => deleteGift(index),
                                ),
                              IconButton(
                                icon: Icon(Icons.info),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          GiftDetailsPage(gift: gift),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (isOwner)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddGiftPage(eventId: widget.eventId),
                            ),
                          ).then((_) {
                            _loadGifts();
                          });
                        },
                        child: const Text('Create New Gift'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

// Show a dialog to edit the gift details
  void _showEditDialog(BuildContext context, Map<String, dynamic> gift) {
    if (gift['status'] != 'Available') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit this gift as it is already pledged.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final TextEditingController nameController =
        TextEditingController(text: gift['name']);
    final TextEditingController categoryController =
        TextEditingController(text: gift['category']);
    final TextEditingController priceController =
        TextEditingController(text: gift['price'].toString());
    String imagePath =
        gift['imagePath'] ?? ''; // Default image path if no image exists.

    // Function to pick an image from the gallery or camera
    Future<void> _pickImage() async {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
          source: ImageSource
              .gallery); // You can change to ImageSource.camera for using camera.

      if (pickedFile != null) {
        imagePath = pickedFile
            .path; // Update the image path with the new image selected.
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Gift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Option to pick a new image
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Change Image'),
              ),

              // Gift details fields
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: categoryController,
                decoration: InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedGift = {
                  ...gift,
                  'name': nameController.text,
                  'category': categoryController.text,
                  'price':
                      double.tryParse(priceController.text) ?? gift['price'],
                  'imagePath': imagePath, // Include the updated image path
                };
                editGift(
                    updatedGift); // Assuming editGift updates the gift in your database
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
