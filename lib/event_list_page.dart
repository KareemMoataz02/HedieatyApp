import 'package:flutter/material.dart';
import 'database_helper.dart'; // Assume you have a DatabaseHelper for CRUD operations
import 'gift_list_page.dart'; // Import GiftListPage
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUsername(); // Load the username when the page initializes
    _loadEvents();
  }

  // Function to fetch username associated with the email
  Future<void> _loadUsername() async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getUserByEmail(widget.email); // Assuming getUserByEmail fetches the user data
    setState(() {
      username = user?['username'] ?? 'User'; // Assign username, or 'User' if not found
    });
  }

  // Function to load events from the database
  Future<void> _loadEvents() async {
    final dbHelper = DatabaseHelper();
    final eventList = await dbHelper.getEventsByEmail(widget.email);
    setState(() {
      events = eventList;
    });
  }

  // Function to sort events based on selected criterion
  void sortEvents() {
    setState(() {
      if (sortBy == 'name') {
        events.sort((a, b) => a['name']!.compareTo(b['name']!));
      } else if (sortBy == 'category') {
        events.sort((a, b) => a['category']!.compareTo(b['category']!));
      } else if (sortBy == 'status') {
        events.sort((a, b) => a['status']!.compareTo(b['status']!));
      }
    });
  }

  // Function to show the event form (both for creating and editing)
  void showEventForm({int? index}) {
    final isEditing = index != null;
    final event = isEditing
        ? events[index!]
        : {
      'name': '',
      'category': 'Formal',
      'status': 'Upcoming',
      'deadline': DateTime.now(),
    };

    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: event['name']);
    selectedCategory = event['category'];
    selectedStatus = event['status'];
    DateTime deadline = event['deadline'] ?? DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isEditing ? 'Edit Event' : 'Add Event'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Event Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an event name';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Formal',
                      child: Text('Formal'),
                    ),
                    DropdownMenuItem(
                      value: 'Personal',
                      child: Text('Personal'),
                    ),
                    DropdownMenuItem(
                      value: 'Gathering',
                      child: Text('Gathering'),
                    ),
                  ],
                  onChanged: (newValue) {
                    setState(() {
                      selectedCategory = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(labelText: 'Status'),
                  items: ['Upcoming', 'Current', 'Past'].map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedStatus = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a status';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                Text('Deadline: ${DateFormat('yyyy-MM-dd').format(deadline)}'),
                ElevatedButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: deadline,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null && picked != deadline) {
                      setState(() {
                        deadline = picked;
                      });
                    }
                  },
                  child: Text('Select Deadline'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(isEditing ? 'Save' : 'Add'),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final dbHelper = DatabaseHelper();
                  final newEvent = {
                    'name': nameController.text,
                    'category': selectedCategory,
                    'status': selectedStatus,
                    'deadline': deadline.toIso8601String(),
                    'email': widget.email,
                  };

                  if (isEditing) {
                    await dbHelper.updateEvent(event['id'], newEvent);
                  } else {
                    await dbHelper.insertEvent(newEvent);
                  }

                  _loadEvents(); // Refresh the event list
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Function to delete an event
  void deleteEvent(int index) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.deleteEvent(events[index]['id']);
    setState(() {
      events.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Events'), // Show the username instead of email
        actions: [
          DropdownButton<String>(
            value: sortBy,
            onChanged: (String? newValue) {
              setState(() {
                sortBy = newValue!;
                sortEvents();
              });
            },
            items: <String>['name', 'category', 'status']
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
              itemCount: events.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(events[index]['name']!),
                  subtitle: Text(
                    '${events[index]['category']} - ${events[index]['status']} - Deadline: ${events[index]['deadline'] != null ? DateFormat('yyyy-MM-dd').format(DateTime.tryParse(events[index]['deadline']) ?? DateTime.now()) : 'N/A'}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GiftListPage(
                          friendName: widget.email,
                          eventName: events[index]['name']!,
                        ),
                      ),
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          showEventForm(index: index);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          deleteEvent(index);
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
                  showEventForm();
                },
                child: Text('Create New Event'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
