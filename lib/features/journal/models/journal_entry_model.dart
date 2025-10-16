// lib/features/journal/models/journal_entry_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntry {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int personalDay;
  final int? mood; // Mood pode ser nulo

  JournalEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.personalDay,
    this.mood,
  });

  // Método factory para criar uma instância a partir de um DocumentSnapshot do Firestore
  factory JournalEntry.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return JournalEntry(
      id: doc.id,
      content: data['content'] ?? '',
      // Timestamps do Firestore precisam ser convertidos para DateTime
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      personalDay: data['personalDay'] ?? 0,
      mood: data['mood'] as int?,
    );
  }

  // Método para converter a instância para um Map, útil para salvar no Firestore
  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'personalDay': personalDay,
      'mood': mood,
    };
  }
}
