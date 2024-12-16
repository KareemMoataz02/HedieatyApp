// gift_image.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class GiftImage extends StatefulWidget {
  final String? base64Image;

  // Updated constructor to accept a Key
  const GiftImage({
    Key? key,
    required this.base64Image,
  }) : super(key: key);

  @override
  _GiftImageState createState() => _GiftImageState();
}

class _GiftImageState extends State<GiftImage> {
  late Future<Uint8List?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _decodeBase64Image(widget.base64Image);
  }

  @override
  void didUpdateWidget(GiftImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the Base64 image changes, reinitialize the Future
    if (oldWidget.base64Image != widget.base64Image) {
      setState(() {
        _imageFuture = _decodeBase64Image(widget.base64Image);
      });
    }
  }

  Future<Uint8List?> _decodeBase64Image(String? base64String) async {
    if (base64String == null || base64String.isEmpty) {
      return null;
    }
    try {
      return base64Decode(base64String);
    } catch (e) {
      print("Error decoding Base64 image: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 50,
            height: 50,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
          return Icon(Icons.image_not_supported, size: 50);
        } else {
          return Image.memory(
            snapshot.data!,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          );
        }
      },
    );
  }
}
