import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:image_picker/image_picker.dart'; // For XFile
import '../features/feedback/models/feedback_model.dart';

class FeedbackService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
        attachmentUrl = await _uploadFile(attachment, feedback.userId ?? 'anonymous');
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

      // 4. Call Cloud Function
      final callable = _functions.httpsCallable('submitFeedback');
      await callable.call(fullFeedback.toJson());

    } catch (e) {
      print('Error sending feedback: $e');
      rethrow;
    }
  }

  Future<String> _uploadFile(XFile file, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_feedback.jpg';
      final ref = _storage.ref().child('feedback_uploads/$userId/$fileName');
      
      UploadTask uploadTask;

      if (kIsWeb) {
        // Web: Read bytes and upload using putData
        final bytes = await file.readAsBytes();
        final metadata = SettableMetadata(contentType: 'image/jpeg'); // Assuming JPEG or similar
        uploadTask = ref.putData(bytes, metadata);
      } else {
        // Mobile: Use putFile with standard File
        uploadTask = ref.putFile(File(file.path));
      }
      
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      throw Exception('Falha ao enviar imagem.');
    }
  }
}
