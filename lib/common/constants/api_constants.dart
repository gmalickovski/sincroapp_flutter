import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kReleaseMode) {
      return 'https://sincroapp.com.br';
    }
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else {
      // Android Emulator uses 10.0.2.2 to access localhost
      return 'http://10.0.2.2:3000';
    }
  }

  // Webhook Endpoints
  static String get resetPassword => '$baseUrl/api/auth/reset-password';
  static String get deleteUser => '$baseUrl/api/auth/delete-user';
  static String get signupNotify => '$baseUrl/api/auth/signup-notify';
}
