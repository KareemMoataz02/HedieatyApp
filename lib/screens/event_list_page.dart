// event_list_page.dart

import 'package:flutter/material.dart';
import 'package:hedieaty/models/event_model.dart';
import 'gift_list_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class EventListPage extends StatefulWidget {
  final String email;

  const EventListPage({Key? key, required this.email}) : super(key: key);

  @override
  _EventListPageState createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  List<Map<String, dynamic>> events = [];
  String sortBy = 'name';
  int? userId;
  String username = ''; // To store the user's username
  bool isLoading = false; // Loading indicator for async operations
  bool isOwner = false; // Indicates if the logged-in user is the owner

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvents();
    });
    _checkOwnership();
    _loadUsername();
  }

  /// Checks if the logged-in user is the owner of the event list.
  Future<void> _checkOwnership() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInEmail = prefs.getString('email'); // Get logged-in user's email
    if (loggedInEmail != null && loggedInEmail.toLowerCase() == widget.email.toLowerCase()) {
      setState(() {
        isOwner = true;
      });
    }
  }

  /// Fetches the username associated with the email.
  Future<void> _loadUsername() async {
    setState(() => isLoading = true);
    try {
      final userModel = UserModel();
      final user = await userModel.getUserByEmail(widget.email);
      setState(() {
        username = (user?['username'] as String?) ?? 'User';
        userId = user?['id'] as int?;
      });
    } catch (e) {
      print("Error loading username: $e");
      setState(() {
        username = 'User';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Loads events from the local database and syncs with Firebase if online.
  Future<void> _loadEvents() async {
    setState(() => isLoading = true);
    try {
      final eventModel = EventModel();
      final fetchedEvents =
      await eventModel.getEventsByEmail(widget.email.toLowerCase());
      setState(() {
        events = fetchedEvents;
      });
      sortEvents(); // Sort events after loading
    } catch (e) {
      print("Error loading events: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load events. Please try again.')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Updates a specific event in the database.
  Future<void> _updateEventInDb(Map<String, dynamic> updatedEvent) async {
    if (updatedEvent['id'] is! int) {
      print("Invalid event ID. Cannot update.");
      return;
    }
    final eventModel = EventModel();
    await eventModel.updateEvent(updatedEvent['id'] as int, updatedEvent);
  }

  /// Displays the event form for creating or editing an event.
  void showEventForm({int? index}) {
    final isEditing = index != null;
    final event = isEditing
        ? Map<String, dynamic>.from(events[index])
        : {
      'id': null,
      'name': '',
      'category': 'Formal',
      'status': 'Upcoming',
      'date': DateTime.now().toIso8601String(),
      'location': '',
      'description': '',
      'email': widget.email,
      'user_id': userId,
    };

    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
        text: event['name'] != null ? event['name'] as String : '');
    final locationController = TextEditingController(
        text: event['location'] != null ? event['location'] as String : '');
    final descriptionController = TextEditingController(
        text: event['description'] != null ? event['description'] as String : '');
    String? formSelectedCategory =
    event['category'] != null ? event['category'] as String : 'Formal';
    String? formSelectedStatus =
    event['status'] != null ? event['status'] as String : 'Upcoming';
    DateTime eventDate = DateTime.tryParse(
        event['date'] != null ? event['date'] as String : '') ??
        DateTime.now();

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder( // To manage state within the dialog
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text(isEditing ? 'Edit Event' : 'Add Event'),
                content: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Event Name
                        TextFormField(
                          key:const Key('event_name_field'),
                          controller: nameController,
                          decoration: InputDecoration(labelText: 'Event Name'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter an event name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                        // Category
                        DropdownButtonFormField<String>(
                          key:const Key('event_category_field'),
                          value: formSelectedCategory,
                          decoration: InputDecoration(labelText: 'Category'),
                          items: ['Formal', 'Personal', 'Gathering']
                              .map((String category) {
                            return DropdownMenuItem(
                                value: category, child: Text(category));
                          }).toList(),
                          onChanged: (newValue) =>
                              setStateDialog(() =>
                              formSelectedCategory = newValue),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                        // Status
                        DropdownButtonFormField<String>(
                          key: const Key('event_status_field'),
                          value: formSelectedStatus,
                          decoration: InputDecoration(labelText: 'Status'),
                          items: ['Upcoming', 'Current', 'Past']
                              .map((String status) {
                            return DropdownMenuItem(
                                value: status, child: Text(status));
                          }).toList(),
                          onChanged: (newValue) =>
                              setStateDialog(() =>
                              formSelectedStatus = newValue),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please select a status';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 10),
                        // Date
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  'Date: ${DateFormat('yyyy-MM-dd').format(eventDate)}'),
                            ),
                            IconButton(
                              key: const Key('event_date_field'),
                              icon: Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: eventDate.isBefore(DateTime.now())
                                      ? DateTime.now()
                                      : eventDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2101),
                                );
                                if (picked != null) {
                                  setStateDialog(() => eventDate = picked);
                                }
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        // Location
                        TextFormField(
                          key: const Key('event_locate_field'),
                          controller: locationController,
                          decoration: InputDecoration(labelText: 'Location'),
                          // Assuming location is optional; no validator
                        ),
                        SizedBox(height: 10),
                        // Description
                        TextFormField(
                          key: const Key('event_description_field'),
                          controller: descriptionController,
                          decoration: InputDecoration(labelText: 'Description'),
                          maxLines: 3,
                          // Assuming description is optional; no validator
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  ElevatedButton(
                    child: Text(isEditing ? 'Save' : 'Add'),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        // Ensure the selected date is not before today
                        if (eventDate.isBefore(DateTime.now())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Date cannot be in the past.')),
                          );
                          return;
                        }

                        final updatedEvent = {
                          'id': event['id'] as int?,
                          'name': nameController.text.trim(),
                          'category': formSelectedCategory,
                          'status': formSelectedStatus,
                          'date': eventDate.toIso8601String(),
                          'location': locationController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'email': widget.email,
                          'user_id': userId,
                        };
                        if (isEditing) {
                          // Update locally
                          setState(() {
                            events[index!] = updatedEvent;
                          });
                          // Update in DB
                          await _updateEventInDb(updatedEvent);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Event updated successfully.')),
                          );
                        } else {
                          // Insert into DB
                          final eventModel = EventModel();
                          final newId = await eventModel.insertEvent(updatedEvent);
                          updatedEvent['id'] = newId;
                          setState(() {
                            events.add(updatedEvent);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Event added successfully.')),
                          );
                        }
                        Navigator.of(context).pop(); // Close the dialog
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
    );
  }


        /// Deletes an event from the database and updates the UI.
        Future<void> deleteEvent(int index) async {
      if (index < 0 || index >= events.length) {
        print("Invalid index: $index");
        return;
      }

      final event = events[index];
      final eventId = event['id'] as int?;
      if (eventId == null) {
        print("Event ID is null. Cannot delete.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid event ID. Cannot delete.')),
        );
        return;
      }

      final eventModel = EventModel();
      try {
        final rowsAffected = await eventModel.deleteEvent(eventId);
        if (rowsAffected > 0) {
          setState(() {
            events.removeAt(index);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Event deleted successfully.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to delete event. Please try again.')),
          );
        }
      } catch (e) {
        print("Error deleting event: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting event. Please try again.')),
        );
      }
    }

    /// Sorts the events based on the selected criterion.
    void sortEvents() {
      setState(() {
        if (sortBy == 'name') {
          events.sort((a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase()));
        } else if (sortBy == 'category') {
          events.sort((a, b) => (a['category'] as String).toLowerCase().compareTo(
              (b['category'] as String).toLowerCase()));
        } else if (sortBy == 'status') {
          events.sort((a, b) => (a['status'] as String).toLowerCase().compareTo(
              (b['status'] as String).toLowerCase()));
        }
        // Add more sorting criteria if needed
      });
    }

    /// Confirms with the user before deleting an event.
    void _confirmDelete(int index) {
      final eventName = events[index]['name'] as String? ?? 'this event';
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Delete Event'),
            content: Text(
                'Are you sure you want to delete the event "$eventName"?'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: Text('Delete'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.of(context).pop(); // Close the confirmation dialog
                  await deleteEvent(index);
                },
              ),
            ],
          );
        },
      );
    }

    /// Navigates to the GiftListPage with the relevant event details.
    void navigateToGiftListPage(String eventName, int eventId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GiftListPage(
            friendEmail: widget.email, // Friend's email or user email
            eventName: eventName, // Event name
            eventId: eventId, // Pass the event ID to fetch related gifts
          ),
        ),
      );
    }

    /// Builds the subtitle widget for each event tile.
    Widget buildEventSubtitle(DateTime? eventDate, String category, String status,
        String location, String description) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 5),
          Text(
            'Category: $category | Status: $status',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 2),
          Text(
            'Date: ${eventDate != null ? DateFormat('yyyy-MM-dd').format(eventDate) : 'N/A'}',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 2),
          if (location.isNotEmpty)
            Text(
              'Location: $location',
              style: TextStyle(fontSize: 14),
            ),
          if (description.isNotEmpty)
            Text(
              'Description: $description',
              style: TextStyle(fontSize: 14),
            ),
        ],
      );
    }

    /// Builds the action buttons (edit and delete) for each event tile.
    Widget buildActionButtons(int index) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner)
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue),
              onPressed: () => showEventForm(index: index),
            ),
          if (isOwner)
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(index),
            ),
        ],
      );
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Events - $username'),
          actions: [
            // Sort Dropdown
            DropdownButton<String>(
              value: sortBy,
              underline: Container(),
              // Removes the underline
              icon: Icon(Icons.sort, color: Colors.white),
              dropdownColor: Colors.blue,
              items: [
                DropdownMenuItem(
                  value: 'name',
                  child: Text('Sort by Name',
                      style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'category',
                  child: Text('Sort by Category',
                      style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'status',
                  child: Text('Sort by Status',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    sortBy = newValue;
                    sortEvents();
                  });
                }
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: isLoading
                      ? Center(child: CircularProgressIndicator())
                      : events.isEmpty
                      ? Center(child: Text('No events found.'))
                      : RefreshIndicator(
                    onRefresh: _loadEvents,
                    child: ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        // Safely retrieve and cast all necessary fields
                        final String eventName =
                            event['name'] as String? ?? 'No Name';
                        final String category =
                            event['category'] as String? ?? 'N/A';
                        final String status =
                            event['status'] as String? ?? 'N/A';
                        final String dateStr =
                            event['date'] as String? ?? '';
                        final String location =
                            event['location'] as String? ?? '';
                        final String description =
                            event['description'] as String? ?? '';
                        final int? eventId = event['id'] as int?;

                        // Parse dates safely
                        DateTime? eventDate;
                        try {
                          eventDate = DateTime.parse(dateStr);
                        } catch (e) {
                          print("Error parsing event date: $e");
                        }

                        return Card(
                          margin: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          elevation: 3,
                          child: ListTile(
                            title: Text(
                              eventName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            subtitle: buildEventSubtitle(eventDate,
                                category, status, location, description),
                            isThreeLine:
                            true, // Allows multiple lines in subtitle
                            onTap: () {
                              if (eventId != null) {
                                navigateToGiftListPage(
                                    eventName, eventId);
                              } else {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Invalid event ID.')),
                                );
                              }
                            },
                            trailing: buildActionButtons(index),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (isOwner)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50, // Fixed height for better UI consistency
                      child: ElevatedButton(
                        onPressed: () => showEventForm(),
                        child: Text(
                          'Create New Event',
                          style: TextStyle(fontSize: 16.0),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Show a loading indicator overlay when saving or performing other operations
            if (isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      );
    }
  }
