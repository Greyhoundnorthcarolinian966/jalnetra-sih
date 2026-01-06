import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class JalnetraStorageImage extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final BoxFit fit;

  const JalnetraStorageImage({
    super.key,
    required this.imagePath,
    this.width = 120,
    this.height = 80,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(imagePath).getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }

        if (!snapshot.hasData) {
          return _placeholder();
        }

        return Image.network(
          snapshot.data!,
          width: width,
          height: height,
          fit: fit,
        );
      },
    );
  }

  Widget _loading() => SizedBox(
    width: width,
    height: height,
    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );

  Widget _placeholder() => Container(
    width: width,
    height: height,
    color: Colors.black12,
    alignment: Alignment.center,
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image, color: Colors.grey),
        SizedBox(height: 4),
        Text("Image not available", style: TextStyle(fontSize: 11)),
      ],
    ),
  );
}
