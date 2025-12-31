// lib/features/journal/models/journal_entry_model.dart

class JournalEntry {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int personalDay;
  final int? mood; // Mood 1-5

  JournalEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.personalDay,
    this.mood,
  });

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      // Se não tiver updated_at ou entry_date, usa created_at
      updatedAt: DateTime.tryParse(map['updated_at'] ?? map['entry_date'] ?? '') ?? DateTime.now(),
      personalDay: map['personal_day'] ?? 0,
      mood: map['mood'] != null ? int.tryParse(map['mood'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'entry_date': createdAt.toIso8601String(), // Sync entry_date with createdAt usually
      'personal_day': personalDay,
      'mood': mood?.toString(),
    };
  }
}
