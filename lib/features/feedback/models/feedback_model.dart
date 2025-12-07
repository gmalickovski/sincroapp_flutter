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
  final DateTime timestamp;

  FeedbackModel({
    required this.type,
    required this.description,
    this.userId,
    this.userEmail,
    required this.appVersion,
    required this.deviceInfo,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type == FeedbackType.bug ? 'Bug' : 'Idea',
      'description': description,
      'user_id': userId,
      'user_email': userEmail,
      'app_version': appVersion,
      'device_info': deviceInfo,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
