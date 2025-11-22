// ignore_for_file: constant_identifier_names

enum AssistantActionType { schedule, create_goal, create_task, analyze_harmony }

class AssistantAction {
  final AssistantActionType type;
  final String? title;
  final String? description; // Novo: descrição/motivação da meta
  final DateTime?
      date; // For schedule/create_task and target date for create_goal
  final DateTime? startDate; // For ranges
  final DateTime? endDate;
  final List<String> subtasks;
  final bool isExecuting; // Novo: indica se está sendo executado
  final bool isExecuted; // Novo: indica se já foi executado
  final bool needsUserInput; // Novo: indica se precisa de input do usuário (formulário)
  final Map<String, dynamic> data; // Novo: dados extras

  AssistantAction({
    required this.type,
    this.title,
    this.description,
    this.date,
    this.startDate,
    this.endDate,
    this.subtasks = const [],
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
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      // Accept YYYY-MM-DD
      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (regex.hasMatch(s)) return DateTime.tryParse(s);
      return null;
    }

    // Support both "date" and "targetDate" keys
    final parsedDate = parseDate(json['date']) ?? parseDate(json['targetDate']);
    
    // Capture extra data
    final extraData = Map<String, dynamic>.from(json);

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
      needsUserInput: json['needsUserInput'] == true, // Parse needsUserInput flag
      data: extraData,
    );
  }
}

class AssistantAnswer {
  final String answer;
  final List<AssistantAction> actions;

  AssistantAnswer({required this.answer, required this.actions});

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) {
    final answer = (json['answer'] ?? '').toString();
    final actions = <AssistantAction>[];
    if (json['actions'] is List) {
      for (final item in (json['actions'] as List)) {
        if (item is Map) actions.add(AssistantAction.fromJson(Map.from(item)));
      }
    }
    return AssistantAnswer(answer: answer, actions: actions);
  }
}

class AssistantMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime time;
  final List<AssistantAction> actions; // Novo: ações sugeridas pelo assistente

  AssistantMessage({
    required this.role,
    required this.content,
    required this.time,
    this.actions = const [],
  });

  AssistantMessage copyWith({
    String? role,
    String? content,
    DateTime? time,
    List<AssistantAction>? actions,
  }) {
    return AssistantMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      time: time ?? this.time,
      actions: actions ?? this.actions,
    );
  }
}
