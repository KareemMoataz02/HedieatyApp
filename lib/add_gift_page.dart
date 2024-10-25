import 'package:flutter/material.dart';

class AddGiftPage extends StatefulWidget {
  @override
  _AddGiftPageState createState() => _AddGiftPageState();
}

class _AddGiftPageState extends State<AddGiftPage> {
  final TextEditingController giftNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController eventController = TextEditingController();

  String giftStatus = 'Available'; // Default gift status

  // Function to upload an image
  void uploadImage() {
    // Logic for image upload can be implemented here
    // This can use packages like image_picker or file_picker
    print('Upload Image functionality goes here');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Gift'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: giftNameController,
              decoration: InputDecoration(labelText: 'Gift Name'),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
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
            TextField(
              controller: eventController,
              decoration: InputDecoration(labelText: 'Event'),
            ),

            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: uploadImage, // Call the upload function
              child: Text('Upload Image'),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Status:'),
                DropdownButton<String>(
                  value: giftStatus,
                  items: <String>['Available', 'Pledged']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      giftStatus = newValue!; // Update the status
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
