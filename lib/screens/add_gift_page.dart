// add_gift_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart'; // For input formatters
import 'package:hedieaty/models/gift_model.dart';
import '../services/image_converter.dart'; // Ensure the path is correct
import '../services/database_helper.dart';

class AddGiftPage extends StatefulWidget {
  final int eventId; // Event ID to associate with the gift

  AddGiftPage({required this.eventId});

  @override
  _AddGiftPageState createState() => _AddGiftPageState();
}

class _AddGiftPageState extends State<AddGiftPage> {
  // Controllers for form fields
  final TextEditingController giftNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  String giftStatus = 'Available'; // Default gift status
  String? selectedImageBase64; // To hold the Base64 string of the selected image

  final ImageConverter _imageConverter = ImageConverter(); // Instantiate ImageConverter

  // Define a Form key to manage form state
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false; // To manage loading state

  // Function to pick an image
  Future<void> uploadImage() async {
    String? imageString = await _imageConverter.pickAndCompressImageToString();

    if (imageString != null) {
      setState(() {
        selectedImageBase64 = imageString; // Save the Base64 string
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image.')),
      );
    }
  }

  // Function to save gift to the database
  Future<void> saveGift() async {
    // Validate the form fields
    if (_formKey.currentState!.validate()) {
      // Trimmed input values
      String name = giftNameController.text.trim();
      String description = descriptionController.text.trim();
      String category = categoryController.text.trim();
      double priceValue = double.parse(priceController.text.trim());

      // Validate image if changed
      if (selectedImageBase64 == null || selectedImageBase64!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please upload an image.')),
        );
        return;
      }

      // Ensure the image is valid
      try {
        base64Decode(selectedImageBase64!);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid image data.')),
        );
        return;
      }

      // Prepare the gift data
      final Map<String, dynamic> newGift = {
        'name': name,
        'description': description,
        'category': category,
        'price': priceValue,
        'status': giftStatus,
        'event_id': widget.eventId, // Associate with the current event
        'image_path': selectedImageBase64!, // Save the Base64 image string
      };

      // Save the gift to the database
      final giftModel = GiftModel(); // Use singleton instance

      try {
        // Show a loading indicator while saving
        setState(() {
          isLoading = true;
        });

        await giftModel.insertGift(newGift);

        // Hide the loading indicator
        setState(() {
          isLoading = false;
        });

        // Provide success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gift added successfully.')),
        );

        // After saving, pop the screen and return to the previous page
        Navigator.pop(context);
      } catch (e) {
        // Hide the loading indicator
        setState(() {
          isLoading = false;
        });

        // Display error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add gift: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    giftNameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Gift'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // To prevent overflow when keyboard appears
          child: Form(
            key: _formKey, // Assign the Form key
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch to fill width
              children: [
                // Gift Name Field
                TextFormField(
                  controller: giftNameController,
                  decoration: InputDecoration(
                    labelText: 'Gift Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the gift name.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.0),

                // Description Field
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3, // Allow multiple lines
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the description.';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.0),

                // Category Field
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
                SizedBox(height: 16.0),

                // Price Field
                TextFormField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    // Allow only numbers and decimal points with up to 2 decimal places
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
                SizedBox(height: 16.0),

                // Display the selected image
                if (selectedImageBase64 != null && selectedImageBase64!.isNotEmpty)
                  Column(
                    children: [
                      Image.memory(
                        base64Decode(selectedImageBase64!),
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                      ),
                      SizedBox(height: 8.0),
                    ],
                  ),

                // Upload Image Button
                ElevatedButton.icon(
                  onPressed: uploadImage, // Call the upload function
                  icon: Icon(Icons.photo),
                  label: Text('Upload Image'),
                ),
                SizedBox(height: 16.0),

                // Gift Status Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(fontSize: 16.0),
                    ),
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

                // Save Gift Button
                ElevatedButton(
                  onPressed: saveGift,
                  child: Text('Save Gift'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: TextStyle(fontSize: 18.0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Show a loading indicator overlay when saving
      floatingActionButton: isLoading
          ? Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(child: CircularProgressIndicator()),
      )
          : null,
    );
  }
}
