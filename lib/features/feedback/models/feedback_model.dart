enum FeedbackType {
  bug,
  idea,
  account,
  subscription,
  tech,
  general,
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
    String typeString;
    switch (type) {
      case FeedbackType.bug:
        typeString = 'Bug';
        break;
      case FeedbackType.idea:
        typeString = 'Sugestão';
        break;
      case FeedbackType.account:
        typeString = 'Conta e Segurança';
        break;
      case FeedbackType.subscription:
        typeString = 'Assinatura e Planos';
        break;
      case FeedbackType.tech:
        typeString = 'Solução de Problemas';
        break;
      case FeedbackType.general:
        typeString =
            'Primeiros Passos'; // Mapping General/Other to Primeiros Passos as per UI
        break;
    }

    return {
      'type': typeString,
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
