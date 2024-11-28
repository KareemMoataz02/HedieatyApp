import 'package:flutter/material.dart';
import 'database_helper.dart'; // Assume you have a DatabaseHelper for CRUD operations
import 'gift_list_page.dart'; // Import GiftListPage
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';


class EventListPage extends StatefulWidget {
  final String email;

  EventListPage({required this.email});

  @override
  _EventListPageState createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  List<Map<String, dynamic>> events = [];
  String sortBy = 'name';
  String? selectedCategory;
  String? selectedStatus;
  String username = ''; // To store the user's username
  bool isLoading = false; // Loading indicator for async operations
  bool isOwner = false;  // This will store whether the logged-in user is the owner


  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadEvents();
    _checkOwnership();
  }

  // Check if the logged-in user is the owner of the event
  Future<void> _checkOwnership() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedInEmail = prefs.getString('email');  // Get logged-in user's email
    if (loggedInEmail != null && loggedInEmail == widget.email) {
      setState(() {
        isOwner = true;
      });
    }
  }

  // Fetch username associated with the email
  Future<void> _loadUsername() async {
    setState(() => isLoading = true);
    try {
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getUserByEmail(widget.email);
      username = user?['username'] ?? 'User';
    } catch (e) {
      print("Error loading username: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Load events from the database
  Future<void> _loadEvents() async {
    setState(() => isLoading = true);
    try {
      final dbHelper = DatabaseHelper();
      events = await dbHelper.getEventsByEmail(widget.email);
    } catch (e) {
      print("Error loading events: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Update a specific event in the database
  Future<void> _updateEventInDb(Map<String, dynamic> updatedEvent) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.updateEvent(updatedEvent['id'], updatedEvent);
  }

// Show event form (create or edit)
  showEventForm({int? index}) {
    final isEditing = index != null;
    final event = isEditing
        ? Map<String, dynamic>.from(events[index!]) // Make a mutable copy
        : {
      'id': null,
      'name': '',
      'category': 'Formal',
      'status': 'Upcoming',
      'deadline': DateTime.now().toIso8601String(),
      'email': widget.email,
    };

    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: event['name']);
    selectedCategory = event['category'];
    selectedStatus = event['status'];
    DateTime deadline = DateTime.tryParse(event['deadline']) ?? DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Event' : 'Add Event'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Event Name'),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter an event name' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(labelText: 'Category'),
                    items: ['Formal', 'Personal', 'Gathering'].map((String category) {
                      return DropdownMenuItem(value: category, child: Text(category));
                    }).toList(),
                    onChanged: (newValue) => setState(() => selectedCategory = newValue),
                    validator: (value) => value == null ? 'Please select a category' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: InputDecoration(labelText: 'Status'),
                    items: ['Upcoming', 'Current', 'Past'].map((String status) {
                      return DropdownMenuItem(value: status, child: Text(status));
                    }).toList(),
                    onChanged: (newValue) => setState(() => selectedStatus = newValue),
                    validator: (value) => value == null ? 'Please select a status' : null,
                  ),
                  SizedBox(height: 16),
                  Text('Deadline: ${DateFormat('yyyy-MM-dd').format(deadline)}'),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: deadline,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) setState(() => deadline = picked);
                    },
                    child: Text('Select Deadline'),
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
            TextButton(
              child: Text(isEditing ? 'Save' : 'Add'),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final updatedEvent = {
                    'id': event['id'],
                    'name': nameController.text,
                    'category': selectedCategory,
                    'status': selectedStatus,
                    'deadline': deadline.toIso8601String(),
                    'email': widget.email,
                  };

                  if (isEditing) {
                    setState(() {
                      events[index] = updatedEvent; // Update locally
                    });
                    await _updateEventInDb(updatedEvent); // Update in DB
                  } else {
                    final dbHelper = DatabaseHelper();
                    final newId = await dbHelper.insertEvent(updatedEvent);
                    updatedEvent['id'] = newId;
                    setState(() {
                      events.add(updatedEvent); // Add to mutable list
                    });
                  }
                  // Close the dialog after the state update
                  Navigator.of(context).pop(); // Close the dialog
                }
              },
            ),
          ],
        );
      },
    );
  }

// Delete an event
  Future<void> deleteEvent(int index) async {
    if (index < 0 || index >= events.length) {
      print("Invalid index: $index");
      return;
    }

    final dbHelper = DatabaseHelper();
    try {
      final eventId = events[index]['id'];
      await dbHelper.deleteEvent(eventId);
      setState(() {
        // Modify the mutable events list
        events = List.from(events)..removeAt(index);
      });
      print("Event with ID $eventId deleted successfully.");
    } catch (e) {
      print("Error deleting event: $e");
    }
  }


  // Sort events based on selected criterion
  void sortEvents() {
    setState(() {
      if (sortBy == 'name') {
        events.sort((a, b) => a['name'].compareTo(b['name']));
      } else if (sortBy == 'category') {
        events.sort((a, b) => a['category'].compareTo(b['category']));
      } else if (sortBy == 'status') {
        events.sort((a, b) => a['status'].compareTo(b['status']));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Events - $username'),
        actions: [
          DropdownButton<String>(
            value: sortBy,
            onChanged: (newValue) => setState(() {
              sortBy = newValue!;
              sortEvents();
            }),
            items: ['name', 'category', 'status'].map((value) {
              return DropdownMenuItem(value: value, child: Text('Sort by $value'));
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
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return ListTile(
                  title: Text(event['name']),
                  subtitle: Text(
                    '${event['category']} - ${event['status']} - Deadline: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(event['deadline']))}',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GiftListPage(
                        friendEmail: widget.email, // Friend's email or user email
                        eventName: event['name'],  // Event name
                        eventId: event['id'],      // Pass the event ID to fetch related gifts
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOwner)
                        IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => showEventForm(index: index),
                      ),
                      if (isOwner)
                        IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => deleteEvent(index),
                      ),
                    ],
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
                onPressed: () => showEventForm(),
                child: Text('Create New Event'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
