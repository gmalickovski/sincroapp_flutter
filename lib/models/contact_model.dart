// lib/models/contact_model.dart

import 'package:sincro_app_flutter/models/user_model.dart';

/// Modelo simplificado de contato para compartilhamento
///
/// Representa um usuário que pode ser adicionado como colaborador
class ContactModel {
  final String userId;
  final String username;
  final String displayName; // Nome completo para exibição
  final String? photoUrl; // NOVO: URL da foto
  final String status; // 'active', 'blocked', 'pending'

  ContactModel({
    required this.userId,
    required this.username,
    required this.displayName,
    this.photoUrl,
    this.status = 'active',
  });

  /// Cria ContactModel a partir de UserModel
  factory ContactModel.fromUserModel(UserModel user) {
    final firstName = user.primeiroNome.trim();
    final lastName = user.sobrenome.trim();

    // Check if firstName already ends with lastName to avoid duplication
    // e.g. firstName="João Silva", lastName="Silva" -> fullName="João Silva"
    String fullName;
    if (firstName.toLowerCase().endsWith(lastName.toLowerCase())) {
      fullName = firstName;
    } else {
      fullName = '$firstName $lastName'.trim();
    }

    return ContactModel(
      userId: user.uid,
      username: user.username ?? '',
      displayName: fullName.isNotEmpty ? fullName : user.email,
      photoUrl: user.photoUrl,
    );
  }

  /// Iniciais do nome para avatar
  String get initials {
    if (displayName.isEmpty) return '?';

    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName[0].toUpperCase();
  }

  // Separation logic remains same...

  /// Para serialização (se necessário)
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'status': status,
      };

  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
        userId: json['userId'],
        username: json['username'],
        displayName: json['displayName'],
        photoUrl: json['photoUrl'],
        status: json['status'] ?? 'active',
      );
}
