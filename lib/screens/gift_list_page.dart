// gift_list_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hedieaty/models/gift_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_gift_page.dart';
import '../services/database_helper.dart';
import 'gift_details_page.dart';
import '../services/image_converter.dart';
import 'package:hedieaty/services/connectivity_service.dart';
import '../services/notifications.dart';
import '../services/gift_image.dart';
import '../models/event_model.dart';
import '../models/pledged_gift_model.dart';
import '../models/user_model.dart';

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
  final userModel = UserModel();
  final eventModel = EventModel();
  final giftModel = GiftModel();
  final pledgeModel = PledgeModel();


  late StreamSubscription<bool> _connectivitySubscription;
  final ImageConverter _imageConverter = ImageConverter(); // Instantiate ImageConverter

  @override
  void initState() {
    super.initState();
    // Schedule the _initializeData to run 2 seconds after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadGifts();
        _checkOwnership();
        _getEventOwnerEmail();
      }
    });



    // Listen to connectivity changes
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
      final giftList = await giftModel.getGiftsByEventId(widget.eventId);

      // Fetch logged-in user's email
      final prefs = await SharedPreferences.getInstance();
      final loggedInEmail = prefs.getString('email') ?? '';

      // Check if each gift is pledged by the logged-in user
      final updatedGiftList = await Future.wait(giftList.map((gift) async {
        final pledges = await pledgeModel.getPledgedGiftsByUser(loggedInEmail);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load gifts.')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getEventOwnerEmail() async {
    try {
      String? eventOwnerEmail =
      await eventModel.getEventOwnerEmail(widget.eventId);
      if (eventOwnerEmail != null) {
        print('Event owner email: $eventOwnerEmail');
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

  Future<String?> getFcmTokenFromFirestore(String userId) async {
    try {
      // Retrieve the user document from Firestore using user ID
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId) // Use the user's UID
          .get();

      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        String fcmToken = userData['fcm_token'] ?? '';
        return fcmToken.isEmpty ? null : fcmToken;
      } else {
        print("User not found in Firestore.");
        return null;
      }
    } catch (e) {
      print("Error retrieving FCM token from Firestore: $e");
      return null;
    }
  }

  Future<void> _getEventOwner() async {
    try {
      final user = await userModel.getUserByEmail(eventOwner);
      userNotifications = user?['notifications'] ?? 0;
      userOwnerId = user?['id'].toString() ?? '';
      userToken = await getFcmTokenFromFirestore(userOwnerId) ?? '';
      print('User Token: $userToken');
      print('User Notifications: $userNotifications');
      print('User Owner ID: $userOwnerId');
    } catch (e) {
      print("Error in _getEventOwner: $e");
    }
  }

  Future<void> sendNotificationToGiftOwner(String userToken, String title,
      String body, String userOwnerId) async {
userNotifications = (await userModel.getNotificationStatusFromFirebase(eventOwner))!;
if (userNotifications == 1) {
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
    final loggedInEmail = prefs.getString('email'); // Get logged-in user's email
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
          SnackBar(content: Text('Cannot pledge your own gift')));
      return;
    }

    // Set isLoading true to show progress indicator during the operation
    setState(() {
      isLoading = true;
    });

    try {
        if (!isConnected) {
    ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Cannot pledge a gift while offline'))
    );
    }

      if (isPledged) {
        // Retrieve all pledges for this gift to check who pledged it
        final pledgedGifts =
        await pledgeModel.getPledgedGiftsByUser(loggedInEmail.toLowerCase());

        final isPledgedByUser = pledgedGifts.any((pledgedGift) {
          print( pledgedGift['userEmail']);
          return pledgedGift['giftId'] == currentGift['id'] &&
              pledgedGift['userEmail'] ==
                  loggedInEmail.toLowerCase(); // Ensure email is lowercase
        });

        if (!isPledgedByUser) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                Text('Only the original pledger can unpledge this gift.')),
          );
        } else {
          // Remove the pledge since it is confirmed that the current user pledged it
          await pledgeModel.removePledge(loggedInEmail, currentGift['id']);
          setState(() {
            currentGift['status'] = 'Available'; // Update the status
          });
        }
      } else {
        // Pledge the gift if it is not pledged and the device is online
        await pledgeModel.insertPledge(loggedInEmail, currentGift['id']);
        sendNotificationToGiftOwner(userToken, title, body, userOwnerId);
        setState(() {
          currentGift['status'] = 'Pledged'; // Update the status
        });
      }
    } catch (e) {
      print("Error toggling pledge: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update pledge status.')),
      );
    } finally {
      setState(() {
        isLoading = false; // Hide the progress indicator
      });
    }
  }

  // Edit the details of an existing gift
  Future<void> editGift(Map<String, dynamic> updatedGift) async {
    try {
      await giftModel.updateGift(updatedGift);
      setState(() {
        final index =
        gifts.indexWhere((gift) => gift['id'] == updatedGift['id']);
        if (index != -1) {
          gifts[index] = updatedGift;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gift updated successfully.')),
      );
    } catch (e) {
      print("Error editing gift: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit the gift.')),
      );
    }
  }

  // Delete a gift
  Future<void> deleteGift(int index) async {
    if (index < 0 || index >= gifts.length) {
      print(index);
      print("Invalid index: $index");
      return;
    }

    final EventModel eventModel = EventModel();
   try {
      final gift = gifts[index];
      print("Deleting gift: $gift"); // Debug print

      final giftId = gift['id']; // Fetch the gift ID
      final event = await eventModel.getEventById(widget.eventId); // Await the async call
      final userEmail = event?['email'];
      print("Gift ID: $giftId");
      print("User Email: $userEmail");

      // Proceed only if userEmail is not null
      if (userEmail == null) {
        print("Error: userEmail is null for gift ID $giftId");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot delete the gift due to missing user information.')),
        );
        return;
      }

      // Check if the gift has any pledges before allowing deletion
      if (gift['status'] == 'Pledged') {
        print("Gift with ID $giftId cannot be deleted because it has been pledged.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot delete the gift as it has been pledged by users.'),
          ),
        );
        return; // Prevent deletion if the gift has pledges
      }

      // Proceed with deletion if no pledges are found
      final rowsAffected = await giftModel.deleteGift(giftId);

      if (rowsAffected > 0) {
        setState(() {
          gifts.removeAt(index); // Remove from the list
        });
        print("Gift with ID $giftId deleted successfully.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gift deleted successfully.')),
        );
      } else {
        print("No gift found with ID $giftId.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No gift found to delete.')),
        );
      }
    } catch (e) {
      print("Error deleting gift: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete the gift.')),
      );
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
              if (newValue != null) {
                setState(() {
                  sortBy = newValue;
                  sortGifts();
                });
              }
            },
            underline: Container(), // Removes the underline
            icon: Icon(Icons.sort, color: Colors.white),
            dropdownColor: Colors.blue,
            items: <String>['name', 'status']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  'Sort by ${value[0].toUpperCase()}${value.substring(1)}',
                  style: TextStyle(color: Colors.white),
                ),
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
            child: gifts.isEmpty
                ? Center(child: Text('No gifts available.'))
                : ListView.builder(
              itemCount: gifts.length,
              itemBuilder: (context, index) {
                final gift = gifts[index];
                final giftStatus = gift['status'];
                final bool isPledged = giftStatus == 'Pledged';
                final String? base64Image = gift['image_path'];

                return Card(
                  margin:
                  EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    leading: GiftImage(
                      base64Image: base64Image,
                      key: Key('${gift['id']}-${base64Image ?? ''}'),
                    ),
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
                          transitionBuilder:
                              (child, animation) {
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
                        // Show Edit and Delete buttons only if the user is the owner
                        if (isOwner) ...[
                          IconButton(
                            icon: Icon(Icons.edit),
                            onPressed: () {
                              _showEditDialog(context, gift);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            onPressed: () => deleteGift(index),
                          ),
                        ],
                        IconButton(
                          icon: Icon(Icons.info),
                          onPressed: () {
                            // Navigate to GiftDetailsPage
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
                child: ElevatedButton.icon(
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
                  icon: Icon(Icons.add),
                  label: const Text('Create New Gift'),
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
    String? base64Image = gift['image_path']; // Use 'image_path'

    // Function to pick and convert image to Base64
    Future<void> _pickImage(Function setStateDialog) async {
      String? newImageData =
      await _imageConverter.pickAndCompressImageToString();

      if (newImageData != null) {
        setStateDialog(() {
          base64Image = newImageData; // Update the image data with the new Base64 string
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image.')),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // To manage state within the dialog
          builder: (context, setStateDialog) {
            // Define a Form key to manage form state
            final _formKey = GlobalKey<FormState>();

            return AlertDialog(
              title: Text('Edit Gift'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey, // Assign the Form key
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Display current image if available
                      base64Image != null && base64Image!.isNotEmpty
                          ? GiftImage(
                        base64Image: base64Image,
                        key: Key('${gift['id']}-${base64Image!}'),
                      )
                          : Container(
                        height: 100,
                        width: 100,
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8.0),
                      // Option to pick a new image
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(setStateDialog),
                        icon: Icon(Icons.photo),
                        label: Text('Change Image'),
                      ),
                      SizedBox(height: 8.0),
                      // Gift details fields with validation
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the gift name.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 8.0),
                      TextFormField(
                        controller: categoryController,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the category.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 8.0),
                      TextFormField(
                        controller: priceController,
                        decoration: InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          // Allow only numbers and decimal points
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the price.';
                          }
                          final price = double.tryParse(value.trim());
                          if (price == null) {
                            return 'Price must be a valid number.';
                          }
                          if (price < 0) {
                            return 'Price cannot be negative.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate the form fields
                    if (_formKey.currentState!.validate()) {
                      // Trimmed input values
                      String name = nameController.text.trim();
                      String category = categoryController.text.trim();
                      double priceValue = double.parse(priceController.text.trim());

                      // Validate image if changed
                      if (base64Image != null && base64Image!.isNotEmpty) {
                        try {
                          base64Decode(base64Image!);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Invalid image data.')),
                          );
                          return;
                        }
                      }

                      // Prepare the updated gift data
                      final updatedGift = {
                        ...gift,
                        'name': name,
                        'category': category,
                        'price': priceValue,
                        'image_path': base64Image ?? gift['image_path'], // Update 'image_path'
                      };

                      try {
                        // Show a loading indicator while updating
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Center(child: CircularProgressIndicator()),
                        );

                        // Update the gift in the database
                        await editGift(updatedGift);

                        // Dismiss the loading indicator
                        Navigator.pop(context);

                        // Provide success feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gift updated successfully.')),
                        );

                        // Navigate back
                        Navigator.pop(context);
                      } catch (e) {
                        // Dismiss the loading indicator if an error occurs
                        Navigator.pop(context);

                        // Display error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update gift: $e')),
                        );
                      }
                    }
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
