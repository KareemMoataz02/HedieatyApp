import 'package:flutter/material.dart';
import 'add_gift_page.dart';
import 'gift_details_page.dart';
import 'database_helper.dart';

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
  final dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  // Load gifts from the database for the given event
  Future<void> _loadGifts() async {
    setState(() {
      isLoading = true;
    });
    try {
      final giftList = await dbHelper.getGiftsByEventId(widget.eventId);
      setState(() {
        gifts = giftList.map((gift) => Map<String, dynamic>.from(gift)).toList();
      });
    } catch (e) {
      print("Error loading gifts: $e");
    } finally {
      setState(() {
        isLoading = false;
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
    setState(() {
      isLoading = true;
    });

    final currentGift = gifts[index];
    final isPledged = currentGift['status'] == 'Pledged';
    final updatedStatus = isPledged ? 'Available' : 'Pledged';

    try {
      // Update the gift status in the database first
      if (!isPledged) {
        await dbHelper.insertPledge(widget.friendEmail, currentGift['id']);
      } else {
        await dbHelper.removePledge(widget.friendEmail, currentGift['id']);
      }

      // Then update the UI
      setState(() {
        gifts[index]['status'] = updatedStatus;
      });
    } catch (e) {
      print("Error toggling pledge: $e");
      // Roll back UI update in case of error
      setState(() {
        gifts[index]['status'] = isPledged ? 'Available' : 'Pledged';
      });
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update pledge status')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Edit the details of an existing gift
  Future<void> editGift(Map<String, dynamic> updatedGift) async {
    try {
      await dbHelper.updateGift(updatedGift);
      setState(() {
        final index = gifts.indexWhere((gift) => gift['id'] == updatedGift['id']);
        if (index != -1) {
          gifts[index] = updatedGift;
        }
      });
    } catch (e) {
      print("Error editing gift: $e");
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
                return ListTile(
                  title: Text(gifts[index]['name']),
                  subtitle: Text('${gifts[index]['category']} - ${gifts[index]['status']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: IconButton(
                          key: ValueKey(gifts[index]['status']),
                          icon: Icon(
                            gifts[index]['status'] == 'Pledged' ? Icons.thumb_down : Icons.thumb_up,
                            color: gifts[index]['status'] == 'Pledged' ? Colors.red : Colors.green,
                          ),
                          onPressed: () {
                            togglePledge(index);
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () {
                          _showEditDialog(context, gifts[index]);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.info),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GiftDetailsPage(gift: gifts[index]),
                            ),
                          );
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddGiftPage(eventId: widget.eventId),
                    ),
                  ).then((_) {
                    _loadGifts();
                  });
                },
                child: Text('Create New Gift'),
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
        SnackBar(
          content: Text('Cannot edit this gift as it is already pledged.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final TextEditingController nameController = TextEditingController(text: gift['name']);
    final TextEditingController categoryController = TextEditingController(text: gift['category']);
    final TextEditingController priceController = TextEditingController(text: gift['price'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Gift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  'price': double.tryParse(priceController.text) ?? gift['price'],
                };
                editGift(updatedGift);
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
