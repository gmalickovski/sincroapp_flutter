// lib/features/goals/models/goal_model.dart

// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
// --- CORREÇÃO AQUI ---
import 'package:meta/meta.dart'; // Importa o pacote para @immutable
// --- FIM DA CORREÇÃO ---

// --- CLASSE NOVA ADICIONADA ---
// Modelo para as Subtarefas (Marcos) que a IA irá sugerir
@immutable // Agora esta anotação será reconhecida
class SubTask extends Equatable {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? deadline; // Data sugerida pela IA

  const SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.deadline,
  });

  // Construtor de cópia
  SubTask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? deadline,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      deadline: deadline ?? this.deadline,
    );
  }

  // Métodos de (de)serialização
  factory SubTask.fromMap(Map<String, dynamic> map, String defaultId) {
    DateTime? parsedDeadline;
    if (map['deadline'] is String) {
      // Tenta fazer parse de String (ISO 8601 do Supabase)
      parsedDeadline = DateTime.tryParse(map['deadline']);
    } else if (map['deadline'] is DateTime) {
      parsedDeadline = map['deadline'];
    }

    return SubTask(
      id: map['id'] ?? defaultId,
      title: map['title'] ?? '',
      isCompleted: map['is_completed'] ?? map['isCompleted'] ?? false,
      deadline: parsedDeadline,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'is_completed': isCompleted,
      'deadline': deadline?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, title, isCompleted, deadline];
}
// --- FIM DA NOVA CLASSE ---

// Classe 'Goal' agora estende Equatable e inclui 'subTasks'
// Não precisa de @immutable aqui se ela tiver métodos que a modificam (como copyWith)
// mas os campos finais garantem imutabilidade interna.
class Goal extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime? targetDate;
  final int progress;
  final DateTime createdAt;
  final String userId;
  final String? category;
  final List<SubTask> subTasks;
  final String? imageUrl; // Added: Optional image URL

  const Goal({
    required this.id,
    required this.title,
    required this.description,
    this.targetDate,
    required this.progress,
    required this.createdAt,
    required this.userId,
    this.category,
    this.subTasks = const [],
    this.imageUrl,
  });

  // Constrói uma instância de Goal a partir de um Map
  factory Goal.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is String) {
        return DateTime.tryParse(dateValue);
      }
      return null;
    }

    List<SubTask> loadedSubTasks = [];
    final subTasksRaw = data['sub_tasks'] ?? data['subTasks'];
    if (subTasksRaw is List) {
      try {
        List<dynamic> subTasksData = subTasksRaw;
        loadedSubTasks = subTasksData.map((taskData) {
          final taskMap = taskData as Map<String, dynamic>;
          // Usando um ID temporário se não vier
          return SubTask.fromMap(
              taskMap, DateTime.now().millisecondsSinceEpoch.toString());
        }).toList();
      } catch (e) {
        loadedSubTasks = [];
      }
    }

    return Goal(
      id: data['id'] ?? '', // ID deve vir no map
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      targetDate: parseDate(data['target_date'] ?? data['targetDate']),
      progress: (data['progress'] ?? 0).toInt(),
      createdAt:
          parseDate(data['created_at'] ?? data['createdAt']) ?? DateTime.now(),
      userId: data['user_id'] ?? data['userId'] ?? '',
      category: data['category'] as String?,
      subTasks: loadedSubTasks,
      imageUrl: (data['image_url'] ?? data['imageUrl']) as String?,
    );
  }

  // Converte a instância de Goal para um Map
  Map<String, dynamic> toMap() {
    // Calcula o progresso atual baseado nas subtarefas
    final completedCount = subTasks.where((task) => task.isCompleted).length;
    final currentProgress = subTasks.isNotEmpty
        ? (completedCount / subTasks.length * 100).round()
        : 0;

    return {
      'title': title,
      'description': description,
      'target_date': targetDate?.toIso8601String(),
      'progress': currentProgress,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
      'category': category,
      'sub_tasks': subTasks.map((task) => task.toMap()).toList(),
      'image_url': imageUrl,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  // Construtor de cópia
  Goal copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? targetDate,
    int?
        progress, // Mantém a opção de passar o progresso, embora calculemos no toFirestore
    DateTime? createdAt,
    String? userId,
    String? category,
    List<SubTask>? subTasks,
    String? imageUrl,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDate: targetDate ?? this.targetDate,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      subTasks: subTasks ?? this.subTasks,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        targetDate,
        progress,
        createdAt,
        userId,
        category,
        subTasks,
        imageUrl,
      ];
}
