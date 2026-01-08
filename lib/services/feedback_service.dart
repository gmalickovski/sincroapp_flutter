import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:image_picker/image_picker.dart'; // For XFile
import '../features/feedback/models/feedback_model.dart';

class FeedbackService {
  // final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1'); // Removed
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> sendFeedback({
    required FeedbackModel feedback,
    XFile? attachment,
  }) async {
    try {
      // 1. Gather Metadata
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfoPlugin = DeviceInfoPlugin();
      String deviceData = '';

      if (kIsWeb) {
         deviceData = 'Web Browser';
      } else if (!kIsWeb && Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        deviceData = 'Android ${androidInfo.version.release} (${androidInfo.model})';
      } else if (!kIsWeb && Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        deviceData = 'iOS ${iosInfo.systemVersion} (${iosInfo.name})';
      } else {
        deviceData = 'Desktop/Other';
      }

      String? attachmentUrl;
      
      // 2. Upload Attachment
      if (attachment != null) {
        // Fallback for user ID if null
        final uid = feedback.userId ?? 'anonymous';
        attachmentUrl = await _uploadFile(attachment, uid);
      }

      // 3. Update Feedback Model with gathered data
      final fullFeedback = FeedbackModel(
        type: feedback.type,
        description: feedback.description,
        userId: feedback.userId,
        userEmail: feedback.userEmail,
        appVersion: '${packageInfo.version} (${packageInfo.buildNumber})',
        deviceInfo: deviceData,
        attachmentUrl: attachmentUrl,
        timestamp: feedback.timestamp,
      );

      // 4. Call Supabase Edge Function
      await _supabase.functions.invoke(
        'feedback-proxy',
        body: fullFeedback.toJson(),
      );

    } catch (e) {
      if (kDebugMode) print('Error sending feedback: $e');
      rethrow;
    }
  }

  Future<String> _uploadFile(XFile file, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_feedback_${file.name}';
      final path = '$userId/$fileName';
      
      // Universal Upload (Web & Mobile) - Reads into memory (acceptable for feedback images)
      final bytes = await file.readAsBytes();
      
      // Upload using Supabase Storage
      // Assuming 'feedback-attachments' bucket exists and is public or has appropriate policies
      await _supabase.storage.from('feedback-attachments').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'), // Adjust if needed
          );

      // Get Public URL
      return _supabase.storage.from('feedback-attachments').getPublicUrl(path);
    } catch (e) {
      if (kDebugMode) print('Error uploading file: $e');
      // If upload fails, we swallow it for now to allow feedback to be sent without image? 
      // Or throw? Let's throw to match previous behavior but maybe log it.
      throw Exception('Falha ao enviar imagem. Verifique se o bucket de armazenamento existe.');
    }
  }
}
