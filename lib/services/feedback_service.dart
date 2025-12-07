import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../features/feedback/models/feedback_model.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

class FeedbackService {
  Future<void> sendFeedback({
    required FeedbackModel feedback,
    File? attachment,
  }) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      String deviceData = '';

      if (kIsWeb) {
         deviceData = 'Web Browser';
      } else if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        deviceData = '${androidInfo.manufacturer} ${androidInfo.model} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        deviceData = '${iosInfo.name} ${iosInfo.systemName} ${iosInfo.systemVersion}';
      } else {
        deviceData = 'Desktop/Other';
      }

      final payload = {
        'type': feedback.type == FeedbackType.bug ? 'Bug' : 'Idea',
        'description': feedback.description,
        'userId': feedback.userId,
        'userEmail': feedback.userEmail,
        'appVersion': '${packageInfo.version} (${packageInfo.buildNumber})',
        'deviceInfo': deviceData,
        // Attachment would need to be uploaded to Firebase Storage first, 
        // then the URL sent here. For MVP/Text-only, we skip the file for now or handle it later.
      };

      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      await functions.httpsCallable('submitFeedback').call(payload);

    } catch (e) {
      print('Erro ao enviar feedback: $e');
      rethrow;
    }
  }
}
