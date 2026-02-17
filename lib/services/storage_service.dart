import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();
  final String _bucketName = 'images'; // Bucket name in Supabase

  /// Uploads a goal image to Supabase Storage using raw bytes.
  /// Returns the public URL of the uploaded image.
  Future<String> uploadGoalImage({
    required Uint8List fileBytes,
    required String fileName,
    required String userId,
  }) async {
    try {
      // Create a unique filename
      final String fileExtension =
          fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final String uniqueName = '${_uuid.v4()}.$fileExtension';

      // Define path: users/{userId}/goals/{uniqueName}
      final String path = 'users/$userId/goals/$uniqueName';

      // Upload to Supabase
      await _supabase.storage.from(_bucketName).uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExtension',
              upsert: true,
            ),
          );

      // Get Public URL
      final String publicUrl =
          _supabase.storage.from(_bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image to Supabase: $e');
    }
  }

  /// Deletes an image from storage given its URL.
  /// Note: This parsing logic assumes standard Supabase URL structure.
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extract path from URL roughly (after /object/public/images/)
      // This generic parsing is tricky, so ideally we store path.
      // But for now, we try to parse standard Supabase URLs.
      final Uri uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      // Ex: /storage/v1/object/public/images/users/...
      // We need 'users/...' part if bucket is images.

      if (segments.contains('public')) {
        final publicIndex = segments.indexOf('public');
        if (publicIndex + 1 < segments.length) {
          // buffer bucket name
          final pathSegments =
              segments.sublist(publicIndex + 2); // skip bucket name
          final path = pathSegments.join('/');
          await _supabase.storage.from(_bucketName).remove([path]);
        }
      }
    } catch (e) {
      // Ignore if file not found or parsing fails
      print('Error deleting image: $e');
    }
  }
}
