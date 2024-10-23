import 'package:flutter/material.dart';
import 'gift_list_page.dart'; // Import GiftListPage

class EventListPage extends StatefulWidget {
  final String friendName;

  EventListPage({required this.friendName});

  @override
  _EventListPageState createState() => _EventListPageState();
}

class _EventListPageState extends State<EventListPage> {
  // Ensure the list contains strictly Map<String, dynamic>
  List<Map<String, dynamic>> events = [
    {
      'name': 'Birthday Party',
      'category': 'Birthday',
      'status': 'Upcoming',
      'deadline': DateTime.now().add(Duration(days: 7)), // Example deadline
    },
    {
      'name': 'Wedding',
      'category': 'Wedding',
      'status': 'Current',
      'deadline': DateTime.now().add(Duration(days: 14)), // Example deadline
    },
    {
      'name': 'Graduation',
      'category': 'Graduation',
      'status': 'Past',
      'deadline': DateTime.now().subtract(Duration(days: 1)), // Example deadline
    },
  ];

  String sortBy = 'name'; // Default sorting criteria

  // Sort Events based on the selected criteria
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

  // Function to add or edit an event with a form
  void showEventForm({int? index}) {
    final isEditing = index != null;
    final event = isEditing
        ? events[index!]
        : {
      'name': '',
      'category': '',
      'status': '',
      'deadline': DateTime.now(), // Initialize with current date
    };

    final _formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: event['name']);
    final categoryController = TextEditingController(text: event['category']);
    final statusController = TextEditingController(text: event['status']);
    DateTime deadline = event['deadline'] ?? DateTime.now(); // Use DateTime for the deadline

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
                TextFormField(
                  controller: statusController,
                  decoration: InputDecoration(labelText: 'Status (Upcoming/Current/Past)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a status';
                    }
                    return null;
                  },
                ),
                // Add a Date Picker for the deadline
                SizedBox(height: 16),
                Text('Deadline: ${deadline.toLocal()}'.split(' ')[0]),
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
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() {
                    if (isEditing) {
                      // Modify the event if in edit mode
                      events[index!] = {
                        'name': nameController.text,
                        'category': categoryController.text,
                        'status': statusController.text,
                        'deadline': deadline, // Include the deadline
                      };
                    } else {
                      // Add new event
                      events.add({
                        'name': nameController.text,
                        'category': categoryController.text,
                        'status': statusController.text,
                        'deadline': deadline, // Include the deadline
                      });
                    }
                  });
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
  void deleteEvent(int index) {
    setState(() {
      events.removeAt(index); // Remove the event from the list
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
      body: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(events[index]['name']!),
            subtitle: Text(
              '${events[index]['category']} - ${events[index]['status']} - Deadline: ${events[index]['deadline'] != null ? events[index]['deadline'].toLocal() : 'N/A'}'.split(' ')[0],
            ),
            onTap: () {
              // Navigate to Gift List Page when the event is tapped
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GiftListPage(
                    friendName: widget.friendName,
                    eventName: events[index]['name']!, // Pass the event name here
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
                    showEventForm(index: index); // Edit event details
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    deleteEvent(index); // Delete event
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showEventForm(); // Add a new event
        },
        child: Icon(Icons.add),
        tooltip: 'Add Event',
      ),
    );
  }
}
