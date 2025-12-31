import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  /// Uploads a goal image to Firebase Storage using raw bytes.
  /// Returns the download URL of the uploaded image.
  /// 
  /// [fileBytes] is the image data.
  /// [fileName] is the original filename (used for extension and metadata).
  /// [userId] is required to organize files by user.
  Future<String> uploadGoalImage({
    required Uint8List fileBytes,
    required String fileName,
    required String userId,
  }) async {
    try {
      // Create a unique filename
      final String fileExtension = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final String uniqueName = '${_uuid.v4()}.$fileExtension';
      
      // Define the path: users/{userId}/goals/{uniqueName}
      final Reference ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('goals')
          .child(uniqueName);

      // Upload metadata context
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/$fileExtension',
        customMetadata: {
          'userId': userId,
          'originalName': fileName,
        },
      );

      // Upload task
      final UploadTask uploadTask = ref.putData(fileBytes, metadata);

      // Wait for completion
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Deletes an image from storage given its URL.
  Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Ignore if file not found or already deleted
      print('Error deleting image: $e');
    }
  }
}
