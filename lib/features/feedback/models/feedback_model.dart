enum FeedbackType {
  bug,
  idea,
}

class FeedbackModel {
  final FeedbackType type;
  final String description;
  final String? userId;
  final String? userEmail;
  final String appVersion;
  final String deviceInfo;
  final String? attachmentUrl;
  final DateTime timestamp;

  FeedbackModel({
    required this.type,
    required this.description,
    required this.userId,
    required this.userEmail,
    required this.appVersion,
    required this.deviceInfo,
    this.attachmentUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last, // 'bug' or 'idea'
      'description': description,
      'user_id': userId,
      'user_email': userEmail,
      'app_version': appVersion,
      'device_info': deviceInfo,
      'attachment_url': attachmentUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
