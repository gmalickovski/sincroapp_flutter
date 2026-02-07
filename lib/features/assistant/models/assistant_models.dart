// ignore_for_file: constant_identifier_names

enum AssistantActionType { schedule, create_goal, create_task, analyze_harmony, analyze_compatibility }

class AssistantAction {
  final AssistantActionType type;
  final String? title;
  final String? description; // Novo: descrição/motivação da meta
  final DateTime?
      date; // For schedule/create_task and target date for create_goal
  final DateTime? startDate; // For ranges
  final DateTime? endDate;
  final List<DateTime> suggestedDates; // Novo: datas alternativas sugeridas
  final List<String> subtasks;
  final bool isExecuting;
  final bool isExecuted;
  final bool needsUserInput;
  final Map<String, dynamic> data;

  AssistantAction({
    required this.type,
    this.title,
    this.description,
    this.date,
    this.startDate,
    this.endDate,
    this.subtasks = const [],
    this.suggestedDates = const [],
    this.isExecuting = false,
    this.isExecuted = false,
    this.needsUserInput = false,
    this.data = const {},
  });

  // Método copyWith para atualizar estado
  AssistantAction copyWith({
    AssistantActionType? type,
    String? title,
    String? description,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? subtasks,
    List<DateTime>? suggestedDates,
    bool? isExecuting,
    bool? isExecuted,
    bool? needsUserInput,
    Map<String, dynamic>? data,
  }) {
    return AssistantAction(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      subtasks: subtasks ?? this.subtasks,
      suggestedDates: suggestedDates ?? this.suggestedDates,
      isExecuting: isExecuting ?? this.isExecuting,
      isExecuted: isExecuted ?? this.isExecuted,
      needsUserInput: needsUserInput ?? this.needsUserInput,
      data: data ?? this.data,
    );
  }

  factory AssistantAction.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? '').toString();
    AssistantActionType? t;
    if (typeStr == 'schedule') t = AssistantActionType.schedule;
    if (typeStr == 'create_goal') t = AssistantActionType.create_goal;
    if (typeStr == 'create_task') t = AssistantActionType.create_task;
    if (typeStr == 'analyze_harmony') t = AssistantActionType.analyze_harmony;
    if (typeStr == 'analyze_compatibility') t = AssistantActionType.analyze_compatibility;
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      // Allow ISO 8601 (incl. time) or YYYY-MM-DD
      // Remove strict Regex to allow timestamps like "2023-10-27T10:00:00.000Z"
      return DateTime.tryParse(s);
    }

    // Support both "date" and "targetDate" keys, AND nested payload date (default for N8n)
    final payload = json['payload'] as Map<String, dynamic>?;
    final payloadDate = payload != null ? parseDate(payload['date']) : null;
    
    final parsedDate = parseDate(json['date']) ?? parseDate(json['targetDate']) ?? payloadDate;

    // Capture extra data
    final extraData = Map<String, dynamic>.from(json);

    // Parse suggestions
    List<DateTime> suggestions = [];
    if (json['suggestedDates'] is List) {
       suggestions = (json['suggestedDates'] as List)
           .map((e) => parseDate(e))
           .whereType<DateTime>() // Filter nulls
           .toList();
    } else if (payload != null && payload['suggestedDates'] is List) {
       // Also look for suggestedDates in payload
       suggestions = (payload['suggestedDates'] as List)
           .map((e) => parseDate(e))
           .whereType<DateTime>() // Filter nulls
           .toList();
    }

    return AssistantAction(
      type: t ?? AssistantActionType.create_task,
      title: (json['title'] ?? '').toString().trim().isEmpty
          ? null
          : (json['title'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim().isEmpty
          ? null
          : (json['description'] ?? '').toString().trim(),
      date: parsedDate,
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      subtasks: (json['subtasks'] is List)
          ? List<String>.from(json['subtasks'].map((e) => e.toString()))
          : const <String>[],
      suggestedDates: suggestions,
      needsUserInput: json['needsUserInput'] == true, // Parse needsUserInput flag
      data: extraData,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'date': date?.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'subtasks': subtasks,
      'suggestedDates': suggestedDates.map((e) => e.toIso8601String()).toList(),
      'isExecuting': isExecuting,
      'isExecuted': isExecuted,
      'needsUserInput': needsUserInput,
      ...data,
    };
  }
}

class AssistantAnswer {
  final String answer;
  final List<AssistantAction> actions;
  final List<Map<String, dynamic>> embeddedTasks; // NOVO: Lista de tarefas para renderizar

  AssistantAnswer({required this.answer, required this.actions, this.embeddedTasks = const []});

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) {
    final answer = (json['answer'] ?? '').toString();
    final actions = <AssistantAction>[];
    if (json['actions'] is List) {
      for (final item in (json['actions'] as List)) {
        if (item is Map) actions.add(AssistantAction.fromJson(Map.from(item)));
      }
    }
    
    // NOVO: Parsear tasks[] - buscar no nível raiz OU dentro de actions[].tasks
    final embeddedTasks = <Map<String, dynamic>>[];
    
    // 1. Tentar buscar no nível raiz primeiro
    if (json['tasks'] is List) {
      for (final item in (json['tasks'] as List)) {
        if (item is Map) embeddedTasks.add(Map<String, dynamic>.from(item));
      }
    }
    
    // 2. Se não encontrou, buscar dentro de actions[].tasks (formato N8n atual)
    if (embeddedTasks.isEmpty && json['actions'] is List) {
      for (final action in (json['actions'] as List)) {
        if (action is Map && action['tasks'] is List) {
          for (final task in (action['tasks'] as List)) {
            if (task is Map) embeddedTasks.add(Map<String, dynamic>.from(task));
          }
        }
      }
    }
    
    return AssistantAnswer(answer: answer, actions: actions, embeddedTasks: embeddedTasks);
  }
}

class AssistantMessage {
  final String id; // Unique ID
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime time;
  final List<AssistantAction> actions; // Ações sugeridas pelo assistente
  final List<Map<String, dynamic>> embeddedTasks; // NOVO: Lista de tarefas para renderizar visualmente

  AssistantMessage({
    String? id,
    required this.role,
    required this.content,
    required this.time,
    this.actions = const [],
    this.embeddedTasks = const [], // NOVO
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  bool get isUser => role == 'user';
  DateTime get timestamp => time; // Alias for compatibility if needed
  bool get hasTasks => embeddedTasks.isNotEmpty; // NOVO: Helper para verificar se tem tasks

  AssistantMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? time,
    List<AssistantAction>? actions,
    List<Map<String, dynamic>>? embeddedTasks, // NOVO
  }) {
    return AssistantMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      time: time ?? this.time,
      actions: actions ?? this.actions,
      embeddedTasks: embeddedTasks ?? this.embeddedTasks, // NOVO
    );
  }
}

class AssistantConversation {
  final String id;
  final String title;
  final DateTime createdAt;

  AssistantConversation({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory AssistantConversation.fromJson(Map<String, dynamic> json) {
    return AssistantConversation(
      id: json['id'].toString(),
      title: json['title'] ?? 'Nova Conversa',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
