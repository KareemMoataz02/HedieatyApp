import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageConverter {
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the gallery, compresses it, and converts it to a Base64 string
  Future<String?> pickAndCompressImageToString() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return null;

      // Read image as bytes
      var imageBytes = await File(pickedFile.path).readAsBytes();

      // Decode image bytes into an image object
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Resize the image to reduce size (optional)
      img.Image resizedImage = img.copyResize(image, width: 800); // Adjust width as needed

      // Compress the image (JPEG with quality of 80)
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 80);

      // Convert the compressed image to Base64 string
      String imageString = base64Encode(compressedBytes);
      return imageString;
    } catch (e) {
      print("Error during image picking/compression: $e");
      return null;
    }
  }

  /// Converts a Base64 string to Uint8List for displaying as an image
  Uint8List? stringToImage(String base64String) {
    try {
      Uint8List bytes = base64Decode(base64String);
      return bytes;
    } catch (e) {
      print("Error converting string to image: $e");
      return null;
    }
  }
}
