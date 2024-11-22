import 'package:flutter/material.dart';
import 'database_helper.dart'; // Assume you have a DatabaseHelper for CRUD operations
import 'gift_list_page.dart'; // Import GiftListPage
import 'package:intl/intl.dart';

class EventListPage extends StatefulWidget {
  final String friendName;

  EventListPage({required this.friendName});

  @override
  _EventListPageState createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  List<Map<String, dynamic>> events = []; // Empty list initially
  String sortBy = 'name'; // Default sorting criteria

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // Load events from the database
  Future<void> _loadEvents() async {
    final dbHelper = DatabaseHelper();
    final eventList = await dbHelper.getAllEvents(); // Get all events from DB
    setState(() {
      events = eventList;
    });
  }

  // Sort events based on selected criteria
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

  // Function to create or edit an event
  void showEventForm({int? index}) {
    final isEditing = index != null;
    final event = isEditing
        ? events[index!]
        : {
      'name': '',
      'category': '',
      'status': '',
      'deadline': DateTime.now(), // Default deadline is current date
    };

    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: event['name']);
    final categoryController = TextEditingController(text: event['category']);
    final statusController = TextEditingController(text: event['status']);
    DateTime deadline = event['deadline'] ?? DateTime.now(); // Default deadline

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
                TextFormField(
                  controller: categoryController,
                  decoration: InputDecoration(labelText: 'Category'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a category';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: statusController.text.isNotEmpty ? statusController.text : null,
                  decoration: InputDecoration(labelText: 'Status'),
                  items: ['Upcoming', 'Current', 'Past'].map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      statusController.text = newValue!;
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
                Text('Deadline: ${DateFormat('yyyy-mm-dd').format(deadline)}'),
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
                    'category': categoryController.text,
                    'status': statusController.text,
                    'deadline': deadline.toIso8601String(), // Save the deadline as string
                  };

                  if (isEditing) {
                    await dbHelper.updateEvent(event['id'], newEvent); // Update event in DB
                  } else {
                    await dbHelper.insertEvent(newEvent); // Insert new event into DB
                  }

                  _loadEvents(); // Refresh the event list after add/edit
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
    await dbHelper.deleteEvent(events[index]['id']); // Delete event from DB
    setState(() {
      events.removeAt(index); // Remove event from the list
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.friendName}\'s Events'),
        actions: [
          DropdownButton<String>(
            value: sortBy,
            onChanged: (String? newValue) {
              setState(() {
                sortBy = newValue!;
                sortEvents();
              });
            },
            items: <String>['name', 'category', 'status'].map<DropdownMenuItem<String>>((String value) {
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
                    '${events[index]['category']} - ${events[index]['status']} - Deadline: ${events[index]['deadline'] != null ?
                    DateFormat('yyyy-MM-dd').format(DateTime.tryParse(events[index]['deadline']) ?? DateTime.now()) : 'N/A'}',
                ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GiftListPage(
                          friendName: widget.friendName,
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
                  showEventForm(); // Open the form to create a new event
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

