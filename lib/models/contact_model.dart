// lib/models/contact_model.dart

import 'package:sincro_app_flutter/models/user_model.dart';

/// Modelo simplificado de contato para compartilhamento
/// 
/// Representa um usuário que pode ser adicionado como colaborador
class ContactModel {
  final String userId;
  final String username;
  final String displayName; // Nome completo para exibição
  final String status; // 'active', 'blocked', 'pending'

  ContactModel({
    required this.userId,
    required this.username,
    required this.displayName,
    this.status = 'active',
  });

  /// Cria ContactModel a partir de UserModel
  factory ContactModel.fromUserModel(UserModel user) {
    final fullName = '${user.primeiroNome} ${user.sobrenome}'.trim();
    
    return ContactModel(
      userId: user.uid,
      username: user.username ?? '',
      displayName: fullName.isNotEmpty ? fullName : user.email,
    );
  }

  /// Iniciais do nome para avatar
  String get initials {
    if (displayName.isEmpty) return '?';
    
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName[0].toUpperCase();
  }

  /// Para comparação e remoção de duplicatas
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  /// Para serialização (se necessário)
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'displayName': displayName,
        'status': status,
      };

  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
        userId: json['userId'],
        username: json['username'],
        displayName: json['displayName'],
        status: json['status'] ?? 'active',
      );
}
