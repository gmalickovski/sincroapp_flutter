// lib/features/goals/models/goal_model.dart
// (Arquivo existente, código completo atualizado)

import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Métodos de (de)serialização para Firestore
  factory SubTask.fromMap(Map<String, dynamic> map, String defaultId) {
    DateTime? parsedDeadline;
    if (map['deadline'] is Timestamp) {
      parsedDeadline = (map['deadline'] as Timestamp).toDate();
    } else if (map['deadline'] is String) {
      // Tenta fazer parse de String (se vier da web ou outro formato)
      parsedDeadline = DateTime.tryParse(map['deadline']);
    }

    return SubTask(
      id: map['id'] ?? defaultId,
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      deadline: parsedDeadline,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
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
  });

  // Constrói uma instância de Goal a partir de um documento do Firestore
  factory Goal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    DateTime? _parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      }
      if (dateValue is String) {
        return DateTime.tryParse(dateValue);
      }
      return null;
    }

    List<SubTask> loadedSubTasks = [];
    if (data['subTasks'] is List) {
      try {
        List<dynamic> subTasksData = data['subTasks'] as List<dynamic>;
        loadedSubTasks = subTasksData.map((taskData) {
          final taskMap = taskData as Map<String, dynamic>;
          return SubTask.fromMap(
              taskMap, FirebaseFirestore.instance.collection('temp').doc().id);
        }).toList();
      } catch (e) {
        print("Erro ao carregar subTasks da meta ${doc.id}: $e");
        loadedSubTasks =
            []; // Falha ao carregar, retorna lista vazia por segurança
      }
    }

    return Goal(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      targetDate: _parseDate(data['targetDate']),
      // Usa o progresso salvo ou calcula se não existir/for zero? (Decisão de design)
      // Por ora, vamos usar o valor salvo. O cálculo pode ser feito na UI se necessário.
      progress: (data['progress'] ?? 0).toInt(),
      createdAt: _parseDate(data['createdAt']) ??
          DateTime.now(), // Usa now() como fallback
      userId: data['userId'] ?? '',
      category: data['category'] as String?,
      subTasks: loadedSubTasks,
    );
  }

  // Converte a instância de Goal para um Map para salvar no Firestore
  Map<String, dynamic> toFirestore() {
    // Calcula o progresso atual baseado nas subtarefas
    final completedCount = subTasks.where((task) => task.isCompleted).length;
    final currentProgress = subTasks.isNotEmpty
        ? (completedCount / subTasks.length * 100).round()
        : 0;

    return {
      'title': title,
      'description': description,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'progress': currentProgress, // Salva o progresso calculado
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'category': category,
      'subTasks': subTasks.map((task) => task.toMap()).toList(),
    };
  }

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
      ];
}
