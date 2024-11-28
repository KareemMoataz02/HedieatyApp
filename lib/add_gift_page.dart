import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'database_helper.dart';

class AddGiftPage extends StatefulWidget {
  final int eventId; // Event ID to associate with the gift

  AddGiftPage({required this.eventId});

  @override
  _AddGiftPageState createState() => _AddGiftPageState();
}

class _AddGiftPageState extends State<AddGiftPage> {
  final TextEditingController giftNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  String giftStatus = 'Available'; // Default gift status
  File? selectedImage; // To hold the selected image file

  // Function to pick an image
  Future<void> uploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImage = File(image.path); // Save the image file
      });
    }
  }

  // Function to save gift to the database
  void saveGift() async {
    final String name = giftNameController.text;
    final String description = descriptionController.text;
    final String category = categoryController.text;
    final String price = priceController.text;

    if (name.isEmpty || description.isEmpty || category.isEmpty || price.isEmpty) {
      // Show an error if any field is empty
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all the fields.')),
      );
      return;
    }

    // Convert price to double
    final double priceValue = double.tryParse(price) ?? 0.0;

    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please upload an image.')),
      );
      return;
    }

    // Save the gift to the database, including the image path
    final dbHelper = DatabaseHelper();
    await dbHelper.insertGift({
      'name': name,
      'description': description,
      'category': category,
      'price': priceValue,
      'status': giftStatus,
      'event_id': widget.eventId, // Associate with the current event
      'image_path': selectedImage!.path, // Save the image file path
    });

    // After saving, pop the screen and return to the previous page
    Navigator.pop(context);
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
            SizedBox(height: 16.0),

            // Display the selected image
            if (selectedImage != null)
              Image.file(
                selectedImage!,
                height: 150,
                width: 150,
                fit: BoxFit.cover,
              ),

            SizedBox(height: 16.0),

            // Upload Image Button
            ElevatedButton(
              onPressed: uploadImage, // Call the upload function
              child: Text('Upload Image'),
            ),
            SizedBox(height: 16.0),

            // Gift status Dropdown
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
                      giftStatus = newValue!;
                    });
                  },
                ),
              ],
            ),

            SizedBox(height: 24.0),

            // Save Button
            ElevatedButton(
              onPressed: saveGift,
              child: Text('Save Gift'),
            ),
          ],
        ),
      ),
    );
  }
}
