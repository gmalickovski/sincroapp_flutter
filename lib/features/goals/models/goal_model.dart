// lib/features/goals/models/goal_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Goal {
  final String id;
  final String title;
  final String description;
  final DateTime? targetDate;
  final int progress;
  final DateTime createdAt;
  final String userId;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    this.targetDate,
    required this.progress,
    required this.createdAt,
    required this.userId,
  });

  // Constrói uma instância de Goal a partir de um documento do Firestore
  factory Goal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // *** INÍCIO DA CORREÇÃO ***
    // Função auxiliar para converter datas de forma segura,
    // aceitando tanto Timestamp (do Flutter) quanto String (da web).
    DateTime? _parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is Timestamp) {
        return dateValue.toDate(); // Converte Timestamp para DateTime
      }
      if (dateValue is String) {
        return DateTime.tryParse(
            dateValue); // Converte "AAAA-MM-DD" para DateTime
      }
      return null;
    }
    // *** FIM DA CORREÇÃO ***

    return Goal(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      // Usa a função segura para os campos de data
      targetDate: _parseDate(data['targetDate']),
      progress: (data['progress'] ?? 0).toInt(),
      // createdAt é obrigatório, mas usamos a função por segurança
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      userId: data['userId'] ?? '',
    );
  }

  // Converte a instância de Goal para um Map para salvar no Firestore
  // Ao salvar a partir do Flutter, sempre usaremos o formato correto (Timestamp)
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'progress': progress,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }
}
