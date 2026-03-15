// lib/features/tasks/presentation/widgets/task_detail_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Para DeepCollectionEquality
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/models/date_picker_result.dart';
import 'package:sincro_app_flutter/common/widgets/modern/schedule_task_sheet.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
// content_data.dart import removed
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/create_goal_dialog.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/goal_selection_modal.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/common/widgets/contact_picker_modal.dart';
import 'package:sincro_app_flutter/features/journal/presentation/journal_editor_screen.dart';
import 'package:sincro_app_flutter/common/parser/parser_input_field.dart';
import 'package:sincro_app_flutter/common/parser/parser_text_controller.dart';
import 'package:sincro_app_flutter/common/parser/task_parser.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';

class TaskDetailModal extends StatefulWidget {
  final TaskModel task;
  final UserModel userData;

  final bool isNew; // NOVO
  final bool isMilestoneMode; // NOVO
  final VoidCallback? onClose; // Callback para modo embedado (Desktop)
  final Function(DateTime)? onReschedule; // NOVO: Callback para reagendamento

  const TaskDetailModal({
    super.key,
    required this.task,
    required this.userData,
    this.isNew = false, // Default false
    this.isMilestoneMode = false,
    this.onClose,
    this.onReschedule,
  });

  @override
  State<TaskDetailModal> createState() => _TaskDetailModalState();
}

class _TaskDetailModalState extends State<TaskDetailModal> {
  final SupabaseService _supabaseService = SupabaseService();
  late ParserTextEditingController _textController;
  final FocusNode _textFieldFocusNode = FocusNode();
  List<ContactModel>? _cachedContacts;
  Goal? _selectedGoal;
  List<String> _currentTags = [];
  late int _personalDay;
  bool _hasChanges = false;
  bool _isLoading = false;
  bool _isFocus = false;
  bool _isLoadingGoal = false;

  // Tags properties
  List<String> _availableTags = [];
  String? _journalTitle;

  // Parser tracking
  Set<String> _tagsInText = {};
  Set<String> _contactsInText = {};
  bool _goalInText = false;

  // Estados originais para comparação
  late String _originalText;
  late String? _originalGoalId;
  late List<String> _originalTags;
  late DateTime? _originalDateTime;
  late RecurrenceRule _originalRecurrenceRule;
  late bool _originalIsFocus;

  late List<int>? _originalReminderOffsets;
  late List<String> _originalSharedWith; // NOVO

  // Estados para data/hora/recorrência/lembrete
  late DateTime? _selectedDateTime;
  late DateTime? _selectedStartDate; // NOVO: Para tarefas Flow
  late RecurrenceRule _recurrenceRule;
  List<int>? _reminderOffsets;
  bool _hasExplicitTime = false; // Rastreia se o usuário selecionou horário explícito
  List<String> _currentSharedWith = []; // NOVO

  final TextEditingController _tagInputController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();
  final DeepCollectionEquality _listEquality = const DeepCollectionEquality();
  bool _isTagInputVisible = false; // Flag to show/hide tag input field

  @override
  void didUpdateWidget(TaskDetailModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.id != oldWidget.task.id ||
        widget.isNew != oldWidget.isNew) {
      _initializeState();
      _loadAvailableTags();
      _loadJournalTitle();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeState();
    _loadAvailableTags();
    _loadJournalTitle();
  }

  Future<void> _loadAvailableTags() async {
    if (!mounted) return;
    try {
      final tags = await _supabaseService.getTags(widget.userData.uid);
      if (mounted) {
        setState(() {
          _availableTags = tags;
        });
      }
    } catch (_) {
      // Ignore errors
    }
  }

  Future<void> _loadJournalTitle() async {
    if (!mounted) return;
    final journalId = widget.task.sourceJournalId;
    if (journalId == null || journalId.isEmpty) {
      if (_journalTitle != null) {
        setState(() => _journalTitle = null);
      }
      return;
    }
    try {
      final entry = await _supabaseService.getJournalEntryById(
          widget.userData.uid, journalId);
      if (mounted && entry != null) {
        setState(() {
          _journalTitle =
              entry.title?.isNotEmpty == true ? entry.title : 'Anotação';
        });
      }
    } catch (_) {
      // Ignore errors — fallback to default text
    }
  }

  void _initializeState() {
    _textController = ParserTextEditingController(text: widget.task.text);
    _textController.mentionEnabled = widget.task.dueDate != null;
    _currentTags = List.from(widget.task.tags);
    _isFocus = widget.task.isFocus;
    _originalIsFocus = widget.task.isFocus;

    if (widget.task.dueDate != null) {
      final date = widget.task.dueDate!.toLocal();
      final time =
          widget.task.reminderTime ?? const TimeOfDay(hour: 0, minute: 0);
      _selectedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      // Se a tarefa já tem reminderTime definido e não é meia-noite, tem horário explícito
      _hasExplicitTime = widget.task.reminderTime != null &&
          (widget.task.reminderTime!.hour != 0 || widget.task.reminderTime!.minute != 0);
    } else {
      _selectedDateTime = null;
      _hasExplicitTime = false;
    }

    // Calcula offset inicial do lembrete
    if (widget.task.reminderOffsets != null &&
        widget.task.reminderOffsets!.isNotEmpty) {
      _reminderOffsets = List.from(widget.task.reminderOffsets!);
    } else if (widget.task.reminderAt != null && widget.task.dueDate != null) {
      // Recurso de legado para tarefas antigas sem reminderOffsets
      DateTime base = widget.task.dueDate!.toLocal();
      if (widget.task.reminderTime != null) {
        base = DateTime(base.year, base.month, base.day,
            widget.task.reminderTime!.hour, widget.task.reminderTime!.minute);
      } else {
        base = DateTime(base.year, base.month, base.day);
      }
      final duration = base.difference(widget.task.reminderAt!.toLocal());
      if (!duration.isNegative) {
        _reminderOffsets = [duration.inMinutes];
      } else {
        _reminderOffsets = null;
      }
    } else {
      _reminderOffsets = null;
    }

    _recurrenceRule = RecurrenceRule(
      type: widget.task.recurrenceType,
      daysOfWeek: widget.task.recurrenceDaysOfWeek,
      endDate: widget.task.recurrenceEndDate?.toLocal(),
      recurrenceCategory: widget.task.recurrenceCategory ?? 'commitment', // ← FIX: was always defaulting to 'commitment'
    );

    _personalDay = _calculatePersonalDayForDate(
        _selectedDateTime ?? widget.task.effectiveDate);

    _originalText = widget.task.text;
    _originalGoalId = widget.task.journeyId;
    _originalTags = List.from(widget.task.tags);
    _originalSharedWith = List.from(widget.task.sharedWith);
    _currentSharedWith = List.from(widget.task.sharedWith);
    _originalDateTime = _selectedDateTime;
    _selectedStartDate = widget.task.startDate; // INICIALIZA O START DATE AQUI
    _originalRecurrenceRule = _recurrenceRule.copyWith();
    _originalReminderOffsets =
        _reminderOffsets != null ? List.from(_reminderOffsets!) : null;

    final parsedT = TaskParser.parse(widget.task.text);
    _tagsInText = parsedT.tags.map((t) => t.toLowerCase()).toSet();
    _contactsInText = parsedT.sharedWith.map((m) => m.toLowerCase()).toSet();
    _goalInText = parsedT.goals.isNotEmpty;

    // Listeners are added here, but check if controller was just replaced
    // Since we created a new controller above, we need to add the listener again.
    // NOTE: If this is called from didUpdateWidget, the old controller is garbage collected eventually?
    // Ideally we should dispose the old one if we are replacing it, OR reuse it.
    // For simplicity here (since new task = complete refresh), replacing is safer for state sync.
    _textController.addListener(_checkForChanges);

    if (widget.task.journeyId != null && widget.task.journeyId!.isNotEmpty) {
      _loadGoalDetails(widget.task.journeyId!);
    }
    // _updateVibrationInfo removed

    // Reset change flags
    _hasChanges = false;
    // But if it's 'isNew', maybe we don't want to reset if we were drafting?
    // The requirement is that switching tasks (selection) updates the view.
    // So complete reset is correct.
  }

  @override
  void dispose() {
    _textController.removeListener(_checkForChanges);
    _textController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _loadGoalDetails(String goalId) async {
    if (!mounted) return;
    setState(() => _isLoadingGoal = true);
    try {
      final goal =
          await _supabaseService.getGoalById(widget.userData.uid, goalId);
      if (mounted) {
        setState(() {
          _selectedGoal = goal;
          // Limpa contatos ao carregar meta
          for (final username in _currentSharedWith) {
            _removeParserTextFromInput('@', username);
          }
          _currentSharedWith.clear();
          _isLoadingGoal = false;
          _updateParserFlags();
          _checkForChanges();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGoal = false);
      }
    }
  }

  int _calculatePersonalDayForDate(DateTime date) {
    final localDate = date.toLocal();
    if (widget.userData.dataNasc.isNotEmpty &&
        widget.userData.nomeAnalise.isNotEmpty) {
      try {
        final engine = NumerologyEngine(
            nomeCompleto: widget.userData.nomeAnalise,
            dataNascimento: widget.userData.dataNasc);
        return engine.calculatePersonalDayForDate(localDate);
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  void _checkForChanges() {
    final currentParsed = TaskParser.parse(_textController.text);
    bool parsedChanged = false;

    // 1. Tags Sync
    final currentTextTags = currentParsed.tags.map((t) => t.toLowerCase()).toSet();
    final tagsToRemove = _tagsInText.where((t) => !currentTextTags.contains(t)).toList();
    for (var t in tagsToRemove) {
      _currentTags.removeWhere((st) => st.toLowerCase() == t);
      parsedChanged = true;
    }
    _tagsInText = _currentTags
        .map((st) => st.toLowerCase())
        .where((t) => currentTextTags.contains(t))
        .toSet();

    // 2. Mentions Sync
    final currentTextMentions = currentParsed.sharedWith.map((m) => m.toLowerCase()).toSet();
    final mentionsToRemove = _contactsInText.where((m) => !currentTextMentions.contains(m)).toList();
    for (var m in mentionsToRemove) {
      _currentSharedWith.removeWhere((sm) => sm.toLowerCase() == m);
      parsedChanged = true;
    }
    _contactsInText = _currentSharedWith
        .map((sm) => sm.toLowerCase())
        .where((m) => currentTextMentions.contains(m))
        .toSet();

    // 3. Goal Sync
    final currentTextGoals = currentParsed.goals.map((g) => TaskParser.normalizeParserKey(g, ParserKeyType.goal)).toSet();
    if (_selectedGoal != null) {
      final normalizedGoalTitle = TaskParser.normalizeParserKey(_selectedGoal!.title, ParserKeyType.goal);
      if (_goalInText) {
        bool found = currentTextGoals.any((gText) => normalizedGoalTitle.contains(gText) || gText.contains(normalizedGoalTitle));
        if (!found) {
          _selectedGoal = null;
          _goalInText = false;
          parsedChanged = true;
        }
      } else {
        bool found = currentTextGoals.any((gText) => normalizedGoalTitle.contains(gText) || gText.contains(normalizedGoalTitle));
        if (found) {
          _goalInText = true;
        }
      }
    } else {
      _goalInText = false;
    }

    if (parsedChanged) {
      _updateParserFlags();
      // Wait for next frame if we are currently building, else setState normally
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }

    final currentGoalId = _selectedGoal?.id;
    bool textChanged = _textController.text != _originalText;
    // Fix: Don't flag goal changes while still loading the goal details
    bool goalChanged = !_isLoadingGoal && (currentGoalId != _originalGoalId);
    bool tagsChanged =
        !_listEquality.equals(_currentTags..sort(), _originalTags..sort());
    bool dateTimeChanged =
        !_compareDateTimes(_selectedDateTime, _originalDateTime) ||
        !_compareDateTimes(_selectedStartDate, widget.task.startDate); // VERIFICA START DATE
    bool recurrenceChanged = _recurrenceRule != _originalRecurrenceRule;
    bool reminderChanged = !_listEquality.equals(
        (_reminderOffsets != null ? List<int>.from(_reminderOffsets!) : <int>[])
          ..sort(),
        (_originalReminderOffsets != null
            ? List<int>.from(_originalReminderOffsets!)
            : <int>[])
          ..sort());
    bool sharedWithChanged = !_listEquality.equals(
        _currentSharedWith..sort(), _originalSharedWith..sort()); // NOVO

    bool focusChanged = _isFocus != _originalIsFocus;

    bool changes = textChanged ||
        goalChanged ||
        tagsChanged ||
        dateTimeChanged ||
        recurrenceChanged ||
        reminderChanged ||
        sharedWithChanged ||
        focusChanged;

    if (changes != _hasChanges && mounted) {
      setState(() {
        _hasChanges = changes;
      });
    }
  }

  bool _compareDateTimes(DateTime? dt1, DateTime? dt2) {
    if (dt1 == null && dt2 == null) return true;
    if (dt1 == null || dt2 == null) return false;
    final localDt1 = dt1.toLocal();
    final localDt2 = dt2.toLocal();
    return localDt1.year == localDt2.year &&
        localDt1.month == localDt2.month &&
        localDt1.day == localDt2.day &&
        localDt1.hour == localDt2.hour &&
        localDt1.minute == localDt2.minute;
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  Future<List<ParserSuggestion>> _onSearchForParser(
      ParserKeyType type, String query) async {
    // REGRA: Meta e contatos são mutuamente exclusivos
    if (type == ParserKeyType.mention && _selectedGoal != null) return [];
    if (type == ParserKeyType.goal && _currentSharedWith.isNotEmpty) return [];
    // REGRA: Menção de contato só funciona com due date
    if (type == ParserKeyType.mention && _selectedDateTime == null) return [];

    final normalizedQuery =
        TaskParser.normalizeParserKey(query, type).toLowerCase();

    if (type == ParserKeyType.mention) {
      if (_cachedContacts == null) {
        try {
          _cachedContacts =
              await _supabaseService.getContacts(widget.userData.uid);
        } catch (e) {
          debugPrint("Erro ao carregar contatos para parser: $e");
          return [];
        }
      }
      return (_cachedContacts ?? [])
          .where((c) => c.status == 'active' && c.username.isNotEmpty)
          .where((c) {
        final uname =
            TaskParser.normalizeParserKey(c.username, type).toLowerCase();
        return uname.contains(normalizedQuery);
      }).map((c) {
        final normalizedLabel = TaskParser.normalizeParserKey(c.username, type);
        return ParserSuggestion(
          id: c.userId,
          label: normalizedLabel,
          type: type,
          description: c.displayName,
        );
      }).toList();
    } else if (type == ParserKeyType.tag) {
      final userTags = await _supabaseService.getTags(widget.userData.uid);
      return userTags.where((t) {
        final tNorm = TaskParser.normalizeParserKey(t, type).toLowerCase();
        return tNorm.contains(normalizedQuery);
      }).map((t) {
        final normalizedLabel = TaskParser.normalizeParserKey(t, type);
        return ParserSuggestion(
          id: t,
          label: normalizedLabel,
          type: type,
        );
      }).toList();
    } else if (type == ParserKeyType.goal) {
      try {
        final goalsStream = _supabaseService.getGoalStream(widget.userData.uid);
        final goalsList = await goalsStream.first;
        return goalsList.where((g) {
          final gNorm =
              TaskParser.normalizeParserKey(g.title, type).toLowerCase();
          return gNorm.contains(normalizedQuery);
        }).map((g) {
          final normalizedLabel = TaskParser.normalizeParserKey(g.title, type);
          return ParserSuggestion(
            id: g.id,
            label: normalizedLabel,
            type: type,
            description: g.title,
          );
        }).toList();
      } catch (e) {
        debugPrint("Error fetching goals for parser: $e");
        return [];
      }
    }
    return [];
  }

  void _onSuggestionSelected(ParserKeyType type, ParserSuggestion suggestion) {
    setState(() {
      if (type == ParserKeyType.mention &&
          !_currentSharedWith.contains(suggestion.label)) {
        _currentSharedWith.add(suggestion.label);
      } else if (type == ParserKeyType.tag &&
          !_currentTags.contains(suggestion.label)) {
        _currentTags.add(suggestion.label);
      } else if (type == ParserKeyType.goal) {
        // Load goal details, limpa contatos no callback _loadGoalDetails
        _loadGoalDetails(suggestion.id);
      }
      _updateParserFlags();
      _checkForChanges();
    });
  }

  /// Remove uma menção do parser do texto (ex: @username, #tag, !meta)
  void _removeParserTextFromInput(String triggerChar, String value) {
    final text = _textController.text;
    final pattern = '$triggerChar$value';
    final newText = text.replaceAll('$pattern ', '').replaceAll(pattern, '');
    final cleaned = newText.replaceAll(RegExp(r'  +'), ' ').trim();
    _textController.text = cleaned;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: cleaned.length),
    );
  }

  /// Atualiza os flags mentionEnabled e goalEnabled do controller
  /// baseado no estado atual de data, meta e contatos.
  void _updateParserFlags() {
    // Menção habilitada somente se: tem due date E não tem meta selecionada
    _textController.mentionEnabled =
        _selectedDateTime != null && _selectedGoal == null;
    // Meta habilitada somente se: não tem contatos compartilhados
    _textController.goalEnabled = _currentSharedWith.isEmpty;
  }

  Future<void> _duplicateTask() async {
    if (_isLoading || !mounted) return;
    setState(() => _isLoading = true);

    final dateForCalc = _selectedDateTime ?? DateTime.now();
    int? personalDayForDuplicated = _calculatePersonalDayForDate(dateForCalc);
    if (personalDayForDuplicated == 0) personalDayForDuplicated = null;

    DateTime? finalDueDate;
    // TimeOfDay? finalReminderTime; // Não precisamos separar
    if (_selectedDateTime != null) {
      finalDueDate = _selectedDateTime!.toUtc();
    }

    // Calcula reminderAt para a nova tarefa
    DateTime? reminderAt;
    if (finalDueDate != null &&
        _reminderOffsets != null &&
        _reminderOffsets!.isNotEmpty) {
      // finalDueDate já é UTC e contém a hora completa se definida
      reminderAt =
          finalDueDate.subtract(Duration(minutes: _reminderOffsets!.first));
    }

    final duplicatedTask = TaskModel(
      id: '',
      text: _textController.text.trim(),
      completed: false,
      createdAt: DateTime.now().toUtc(),
      dueDate: finalDueDate?.toUtc(),
      tags: List.from(_currentTags),
      journeyId: _selectedGoal?.id,
      journeyTitle: _selectedGoal?.title,
      personalDay: personalDayForDuplicated,
      recurrenceType: _recurrenceRule.type,
      recurrenceDaysOfWeek: _recurrenceRule.daysOfWeek,
      recurrenceEndDate: _recurrenceRule.endDate?.toUtc(),
      // reminderTime: finalReminderTime, // Removido
      reminderAt: reminderAt, // Usa o reminderAt calculado
      recurrenceId: null,
    );

    final messenger = ScaffoldMessenger.of(context);
    // _handleClose(); // REMOVED: Moved to after success

    try {
      await _supabaseService.addTask(widget.userData.uid, duplicatedTask);
      if (duplicatedTask.journeyId != null &&
          duplicatedTask.journeyId!.isNotEmpty) {
        await _supabaseService.updateGoalProgress(
            widget.userData.uid, duplicatedTask.journeyId!);
      }
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Tarefa duplicada.'),
              backgroundColor: AppColors.primary),
        );
        _handleClose(); // Close after success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
              content: Text('Erro ao duplicar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    if (_isLoading || !mounted) return;

    final bool isRecurrentTask =
        widget.task.recurrenceType != RecurrenceType.none ||
        widget.task.recurrenceCategory == 'commitment_instance' ||
        widget.task.recurrenceCategory == 'flow' ||
        widget.task.recurrenceCategory == 'flow_instance';

    if (isRecurrentTask) {
      await _deleteRecurrentTask();
    } else {
      await _deleteSingleTask();
    }
  }

  /// Exclusão simples para tarefas normais (sem recorrência).
  Future<void> _deleteSingleTask() async {
    final messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir Tarefa?',
            style: TextStyle(fontFamily: 'Poppins', color: AppColors.primaryText, fontWeight: FontWeight.bold)),
        content: const Text('Esta ação não pode ser desfeita.',
            style: TextStyle(fontFamily: 'Poppins', color: AppColors.secondaryText)),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.secondaryText, fontFamily: 'Poppins')),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
              ),
              child: const Text('Excluir',
                  style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            )),
          ]),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _supabaseService.deleteTask(widget.userData.uid, widget.task.id);
      if (widget.task.journeyId != null && widget.task.journeyId!.isNotEmpty) {
        await _supabaseService.updateGoalProgress(widget.userData.uid, widget.task.journeyId!);
      }
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Tarefa excluída.'), backgroundColor: Colors.orange),
        );
        _handleClose();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// Exclusão de tarefas RECORRENTES — opção de excluir só esta ou toda a recorrência.
  Future<void> _deleteRecurrentTask() async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir Recorrência',
            style: TextStyle(color: AppColors.primaryText, fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
        content: const Text('Como deseja excluir esta tarefa recorrente?',
            style: TextStyle(color: AppColors.secondaryText, fontFamily: 'Poppins')),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Excluir só este
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('only_this'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
                child: const Text('Excluir só este',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              ),
              const SizedBox(height: 10),
              // Excluir toda a recorrência
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop('all'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                child: const Text('Excluir toda a recorrência',
                    style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              ),
              const SizedBox(height: 10),
              // Cancelar
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppColors.secondaryText, fontFamily: 'Poppins')),
              ),
            ],
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    try {
      if (choice == 'only_this') {
        await _supabaseService.deleteTask(widget.userData.uid, widget.task.id);
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Agendamento excluído.'), backgroundColor: Colors.orange),
          );
          _handleClose();
        }
      } else if (choice == 'all') {
        final templateId = widget.task.recurrenceId ?? widget.task.id;
        await _supabaseService.deleteTaskRecurrence(widget.userData.uid, templateId);
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Recorrência excluída por completo.'), backgroundColor: Colors.orange),
          );
          _handleClose();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_isLoading || !mounted) return;
    if (!_hasChanges) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Nenhuma alteração detectada.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2)),
        );
      }
      return;
    }

    final newText = _textController.text.trim();
    if (newText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("O texto da tarefa não pode estar vazio."),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Calcula personal day com a data âncora certa (startDate pra flow, dueDate pra commitment, ou _selectedDateTime se ambos faltam, senão effectiveDate)
    int? newPersonalDay = widget.task.personalDay;
    if (widget.isNew || !_compareDateTimes(_selectedDateTime, _originalDateTime) || !_compareDateTimes(_selectedStartDate, widget.task.startDate)) {
      final dateForCalc = _selectedStartDate ?? _selectedDateTime ?? widget.task.effectiveDate;
      newPersonalDay = _calculatePersonalDayForDate(dateForCalc);
      if (newPersonalDay == 0) newPersonalDay = null;
    }

    DateTime? finalDueDateUtc;
    if (_selectedDateTime != null) {
      if (_hasExplicitTime) {
        // Com horário: converte para UTC
        finalDueDateUtc = _selectedDateTime!.toUtc();
      } else {
        // Sem horário: Local midnight convertido para UTC
        finalDueDateUtc = DateTime(
          _selectedDateTime!.year,
          _selectedDateTime!.month,
          _selectedDateTime!.day,
        ).toUtc();
      }
    }

    DateTime? finalStartDateUtc;
    if (_selectedStartDate != null) {
      if (_hasExplicitTime) { // Se horário estivesse em flow... o flow tipicamente ignora, mas mantemos local
         finalStartDateUtc = _selectedStartDate!.toUtc();
      } else {
         finalStartDateUtc = DateTime(_selectedStartDate!.year, _selectedStartDate!.month, _selectedStartDate!.day).toUtc();
      }
    } else if (_recurrenceRule.recurrenceCategory == 'flow') {
      // Fallback: tarefas flow sempre precisam de start_date
      final now = DateTime.now();
      finalStartDateUtc = DateTime(now.year, now.month, now.day).toUtc();
    }

    DateTime? reminderAt;
    if (finalDueDateUtc != null &&
        _reminderOffsets != null &&
        _reminderOffsets!.isNotEmpty) {
      DateTime base =
          _selectedDateTime!.toLocal(); // Usa selecionada com hora (se houver)
      // Calcula usando o primeiro lembrete apenas para manter compatibilidade com antigos campos se necessário
      reminderAt =
          base.subtract(Duration(minutes: _reminderOffsets!.first)).toUtc();
    }

    final Map<String, dynamic> updates = {
      'text': newText,
      'dueDate': finalDueDateUtc?.toIso8601String(), // Se for explicitDue
      'start_date': finalStartDateUtc?.toIso8601String(), // Se for Flow
      'reminder_offsets': _reminderOffsets,
      'reminder_at': reminderAt?.toIso8601String(), // Envia data calculada
      'tags': _currentTags,
      'journeyId': _selectedGoal?.id,
      'journeyTitle': _selectedGoal?.title,
      'personalDay': newPersonalDay,
      'recurrenceType': _recurrenceRule.type != RecurrenceType.none
          ? _recurrenceRule.type.toString()
          : null,
      'recurrenceDaysOfWeek': _recurrenceRule.daysOfWeek,
      'recurrenceEndDate': _recurrenceRule.endDate?.toUtc(),
      // Só persiste category quando há recorrência ativa (evita default 'commitment' em tarefas normais)
      'recurrenceCategory': _recurrenceRule.type != RecurrenceType.none
          ? _recurrenceRule.recurrenceCategory
          : null,
      'sharedWith': _currentSharedWith, // NOVO
      'is_focus': _isFocus,
    };

    String? originalGoalId = _originalGoalId;
    String? currentGoalId = _selectedGoal?.id;
    final messenger = ScaffoldMessenger.of(context);

    // _handleClose(); // REMOVED: Moved to after success

    try {
      if (widget.isNew) {
        // --- LOGICA DE CRIAÇÃO ---
        final newTask = widget.task.copyWith(
          text: newText,
          dueDate: finalDueDateUtc, // copyWith handles Object? so we pass directly
          startDate: finalStartDateUtc, // NOVO: Para Rituaos
          tags: _currentTags,
          journeyId: _selectedGoal?.id,
          journeyTitle: _selectedGoal?.title,
          personalDay: newPersonalDay,
          recurrenceType: _recurrenceRule.type,
          recurrenceDaysOfWeek: _recurrenceRule.daysOfWeek,
          recurrenceEndDate: _recurrenceRule.endDate?.toUtc(),
          // Só persiste category quando há recorrência ativa
          recurrenceCategory: _recurrenceRule.type != RecurrenceType.none
              ? _recurrenceRule.recurrenceCategory
              : null,
          sharedWith: _currentSharedWith,
          reminderAt: reminderAt,
          reminderOffsets: _reminderOffsets,
        );

        await _supabaseService.addTask(widget.userData.uid, newTask);

        // Se houver meta vinculada, atualizar progresso
        if (_selectedGoal?.id != null) {
          await _supabaseService.updateGoalProgress(
              widget.userData.uid, _selectedGoal!.id);
        }

        if (_selectedGoal?.id != null) {
          await _supabaseService.updateGoalProgress(
              widget.userData.uid, _selectedGoal!.id);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Tarefa criada.'), backgroundColor: Colors.green),
          );
          _handleClose(); // Close after success
        }
      } else {
        // --- LOGICA DE ATUALIZAÇÃO (existente) ---
        await _supabaseService.updateTaskFields(
            widget.userData.uid, widget.task.id, updates);

        bool goalChanged = originalGoalId != currentGoalId;
        if (goalChanged) {
          if (originalGoalId != null && originalGoalId.isNotEmpty) {
            await _supabaseService.updateGoalProgress(
                widget.userData.uid, originalGoalId);
          }
        }
        if (currentGoalId != null && currentGoalId.isNotEmpty) {
          await _supabaseService.updateGoalProgress(
              widget.userData.uid, currentGoalId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Tarefa atualizada.'),
                backgroundColor: Colors.green),
          );
          _handleClose(); // Close after success
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false); // Re-enable UI on error
        messenger.showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDateAndTimeRecurrence() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    final DateTime initialPickerDate =
        _selectedStartDate?.toLocal() ?? _selectedDateTime?.toLocal() ?? DateTime.now();

    Future<DatePickerResult?> resultFuture;

    final bool isMidnight = _selectedDateTime != null &&
        _selectedDateTime!.hour == 0 &&
        _selectedDateTime!.minute == 0;

    resultFuture = ScheduleTaskSheet.show(
      context,
      initialDate: initialPickerDate,
      initialTime: (_selectedDateTime != null && !isMidnight)
          ? TimeOfDay.fromDateTime(_selectedDateTime!.toLocal())
          : null,
      initialRecurrence: _recurrenceRule,
      initialReminderOffsets: _reminderOffsets,
      goalDeadline: _selectedGoal?.targetDate,
      userData: widget.userData,
    );

    final DatePickerResult? result = await resultFuture;

    if (result != null && mounted) {
      bool dateTimeChanged = !_compareDateTimes(
          result.dateTime?.toLocal(), _selectedDateTime?.toLocal());
      bool startDateChanged = !_compareDateTimes(
          result.startDate?.toLocal(), _selectedStartDate?.toLocal());

      bool recurrenceChanged = result.recurrenceRule != _recurrenceRule;
      final newOffsets = result.reminderOffsets;
      bool reminderChanged =
          !_listEquality.equals(newOffsets?..sort(), _reminderOffsets?..sort());

      if (dateTimeChanged || startDateChanged || recurrenceChanged || reminderChanged) {
        setState(() {
          _selectedDateTime = result.dateTime?.toLocal();
          _selectedStartDate = result.startDate?.toLocal();
          _hasExplicitTime = result.hasTime; // Rastreia se o usuário selecionou horário
          _textController.mentionEnabled = _selectedDateTime != null; // Se Flow (startDate sem dueDate), mention desabilita
          _recurrenceRule = result.recurrenceRule;
          _reminderOffsets = newOffsets; // Atualiza offset

          // Limpa contatos e @menções quando data muda ou é removida
          if (dateTimeChanged || startDateChanged) {
            for (final username in _currentSharedWith) {
              _removeParserTextFromInput('@', username);
            }
            _currentSharedWith.clear();
          }

          if (_selectedDateTime != null || _selectedStartDate != null) {
            final measureDate = _selectedStartDate ?? _selectedDateTime!;
            _personalDay = _calculatePersonalDayForDate(measureDate);
            // Quando define data, desativa foco (botão vai sumir)
            _isFocus = false;
          } else {
            _personalDay = _calculatePersonalDayForDate(DateTime.now());
          }
          _updateParserFlags();
          _checkForChanges();
        });
      }
    }
  }

  void _addTag() {
    final String tagText = _tagInputController.text
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .toLowerCase();
    final forbiddenChars = RegExp(r'[/#@]');

    if (tagText.isNotEmpty &&
        !forbiddenChars.hasMatch(tagText) &&
        !_currentTags.contains(tagText)) {
      if (_currentTags.length < 5) {
        if (mounted) {
          setState(() {
            _currentTags.add(tagText);
            _tagInputController.clear();
            _checkForChanges();
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Limite de 5 tags atingido.'),
                duration: Duration(seconds: 2)),
          );
        }
        _tagInputController.clear();
      }
    } else if (tagText.isNotEmpty && forbiddenChars.hasMatch(tagText)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tags não podem conter / # @'),
              duration: Duration(seconds: 2)),
        );
      }
      _tagInputController.clear();
    } else {
      _tagInputController.clear();
    }
    if (mounted && _currentTags.length < 5) {
      _tagFocusNode.requestFocus();
    } else if (mounted) {
      _tagFocusNode.unfocus();
    }
  }

  void _removeTag(String tagToRemove) {
    if (mounted) {
      _removeParserTextFromInput('#', tagToRemove);
      setState(() {
        _currentTags.remove(tagToRemove);
        _checkForChanges();
      });
    }
  }

  void _selectGoal() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GoalSelectionModal(
          userId: widget.userData.uid,
        );
      },
    );

    if (result == null) return;

    if (result is Goal) {
      setState(() {
        _selectedGoal = result;
        // Limpa contatos ao selecionar meta (Exclusividade)
        for (final username in _currentSharedWith) {
          _removeParserTextFromInput('@', username);
        }
        _currentSharedWith = [];
        _updateParserFlags();
        _checkForChanges();
      });
    } else if (result == '_CREATE_NEW_GOAL_') {
      _openCreateGoalWidget();
    }
  }

  // Opens the dialog/bottom sheet to create a new goal
  void _openCreateGoalWidget() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    bool? result;

    if (isMobile) {
      result = await CreateGoalDialog.showAsBottomSheet(
        context,
        userData: widget.userData,
      );
    } else {
      result = await showDialog<bool>(
        context: context,
        builder: (context) => CreateGoalDialog(userData: widget.userData),
      );
    }

    if (result == true && mounted) {
      // Refresh or handle new goal
      // Simplification: logic to reload goals usually happens via stream in GoalSelectionModal
    }
  }

  void _confirmDelete() {
    // Calls _deleteTask directly — it already has its own confirmation dialog
    _deleteTask();
  }

  Widget _buildBottomActions() {
    // Para nova tarefa: mostra ação somente quando tem texto digitado
    // Para tarefa existente: mostra ação somente quando há alterações
    final bool showActionButtons = widget.isNew
        ? _textController.text.trim().isNotEmpty
        : _hasChanges;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: showActionButtons
          ? Row(
              key: const ValueKey('actionButtons'),
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _handleClose,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.cardBackground,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.normal)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                            (states) => AppColors.primary),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                            (states) => Colors.white),
                        elevation:
                            WidgetStateProperty.resolveWith<double>((states) => 0),
                        padding: WidgetStateProperty.resolveWith<EdgeInsetsGeometry>(
                            (states) => const EdgeInsets.symmetric(vertical: 12)),
                        shape:
                            WidgetStateProperty.resolveWith<OutlinedBorder>((states) {
                          return RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side:
                                  const BorderSide(color: AppColors.primary, width: 2));
                        }),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              widget.isMilestoneMode
                                  ? (widget.isNew ? 'Criar Marco' : 'Salvar Marco')
                                  : (widget.isNew ? 'Criar Tarefa' : 'Salvar Tarefa'),
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              key: const ValueKey('closeButton'),
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _handleClose,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Fechar',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.normal)),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime dateForPersonalDay = widget.task.effectiveDate;
    if (_selectedDateTime != null && !widget.isMilestoneMode) {
      dateForPersonalDay = _selectedDateTime!;
    } else if (widget.isMilestoneMode && widget.task.dueDate != null) {
      dateForPersonalDay = widget.task.dueDate!;
    }

    final int currentPersonalDay = _calculatePersonalDayForDate(dateForPersonalDay);

    if (currentPersonalDay != _personalDay && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _personalDay = currentPersonalDay;
            // _updateVibrationInfo removed
          });
        }
      });
    }
    final bool showGoal = _currentSharedWith.isEmpty && !widget.isMilestoneMode;
    final bool showContact = _selectedGoal == null && _selectedDateTime != null && !widget.isMilestoneMode;

    Widget contentBody = GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ParserInputField(
                controller: _textController,
                focusNode: _textFieldFocusNode,
                disabledTriggers: [
                  if (_currentSharedWith.isNotEmpty) ParserKeyType.goal,
                  if (_selectedGoal != null) ParserKeyType.mention,
                  if (_selectedDateTime == null) ParserKeyType.mention,
                ],
                onSubmitted: (_) {},
                hintText: 'Digite aqui sua tarefa...',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryText,
                    fontSize: 16,
                    height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Digite aqui sua tarefa...',
                  hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.secondaryText.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                  filled: false,
                  fillColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSearch: _onSearchForParser,
                onSuggestionSelected: _onSuggestionSelected,
              ),
            ),
            const Divider(color: AppColors.border, height: 16),
            _buildDetailRow(
              icon: Icons.calendar_month_outlined,
              iconColor: (_selectedDateTime != null ||
                      _recurrenceRule.type != RecurrenceType.none)
                  ? Colors.amber
                  : AppColors.secondaryText,
              valueWidget: _buildDateTimeRecurrenceSummaryWidget(),
              onTap: _selectDateAndTimeRecurrence,
              valueColor: (_selectedDateTime != null ||
                      _recurrenceRule.type != RecurrenceType.none)
                  ? AppColors.primaryText
                  : AppColors.secondaryText,
              trailingAction: (_selectedDateTime != null ||
                      _recurrenceRule.type != RecurrenceType.none)
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Remover agendamento',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: _subtleHoverStyle(),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _selectedDateTime = null;
                            _textController.mentionEnabled = false;
                            _recurrenceRule = RecurrenceRule();
                            _reminderOffsets = null;
                            // Remove @menções do texto antes de limpar contatos
                            for (final username in _currentSharedWith) {
                              _removeParserTextFromInput('@', username);
                            }
                            _currentSharedWith.clear();
                            _personalDay =
                                _calculatePersonalDayForDate(DateTime.now());
                            // Quando remove data, reseta foco para desativado
                            _isFocus = false;
                            _checkForChanges();
                          });
                        }
                      },
                    )
                  : null,
            ),

            if (showGoal || showContact)
              const Divider(color: AppColors.border, height: 16),
            if (showGoal) ...[
              _buildDetailRow(
                icon: Icons.flag_outlined,
                iconColor: _selectedGoal != null
                    ? Colors.cyan
                    : AppColors.secondaryText,
                valueWidget: _isLoadingGoal
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: CustomLoadingSpinner(size: 20))
                    : null,
                value: _isLoadingGoal
                    ? null
                    : (_selectedGoal?.title ?? 'Adicionar à jornada'),
                onTap: _selectGoal,
                valueColor: _selectedGoal != null
                    ? AppColors.primaryText
                    : AppColors.secondaryText,
                trailingAction: _selectedGoal != null
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Desvincular meta',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: _subtleHoverStyle(),
                        onPressed: () {
                          if (mounted) {
                            if (_selectedGoal != null) {
                              final goalKey = TaskParser.normalizeParserKey(
                                  _selectedGoal!.title, ParserKeyType.goal);
                              _removeParserTextFromInput('!', goalKey);
                            }
                            setState(() {
                              _selectedGoal = null;
                              _updateParserFlags();
                              _checkForChanges();
                            });
                          }
                        },
                      )
                    : null,
              ),

            ],
            if (showGoal && showContact)
              const Divider(color: AppColors.border, height: 16),
            if (showContact) ...[
              _buildSharedWithSection(),
            ],
            const Divider(color: AppColors.border, height: 16),
            if (widget.task.sourceJournalId != null &&
                widget.task.sourceJournalId!.isNotEmpty) ...[
              _buildDetailRow(
                icon: Icons.auto_stories_outlined,
                iconColor: AppColors.journalMarker,
                valueColor: AppColors.journalMarker,
                valueWidget: Wrap(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.auto_stories,
                          size: 14, color: Colors.white),
                      label: Text(
                        _journalTitle ?? 'Anotação',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor:
                          AppColors.journalMarker.withValues(alpha: 0.85),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () {
                        _navigateToJournal(widget.task.sourceJournalId!);
                      },
                    ),
                  ],
                ),
                onTap: null,
              ),
              const Divider(color: AppColors.border, height: 16),
            ],
            _buildTagsSection(),
          ],
        ),
      ),
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isEmbedded = widget.onClose != null;

    final Widget header = Padding(
      padding:
          const EdgeInsets.only(top: 16.0, left: 16.0, right: 8.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: vibration pill
          if (currentPersonalDay > 0)
            VibrationPill(
              vibrationNumber: currentPersonalDay,
              type: VibrationPillType.standard,
            )
          else
            const SizedBox.shrink(),
          // Right side: focus + delete + duplicate buttons (only for existing tasks)
          if (!widget.isNew)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botão Foco do dia — só aparece quando não há dueDate
                if (_selectedDateTime == null)
                  Tooltip(
                    message: _isFocus ? 'Remover do Foco do dia' : 'Foco do dia',
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () {
                            if (mounted) {
                              setState(() {
                                _isFocus = !_isFocus;
                                _checkForChanges();
                              });
                            }
                          },
                          customBorder: const CircleBorder(),
                          hoverColor: Colors.amber.withValues(alpha: 0.15),
                          splashColor: Colors.amber.withValues(alpha: 0.25),
                          child: Center(
                            child: Icon(
                              Icons.bolt,
                              color: _isFocus
                                  ? Colors.amber
                                  : AppColors.secondaryText.withValues(alpha: 0.4),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Tooltip(
                  message: 'Excluir Tarefa',
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _confirmDelete(),
                        customBorder: const CircleBorder(),
                        hoverColor: AppColors.primary.withValues(alpha: 0.1),
                        splashColor: AppColors.primary.withValues(alpha: 0.2),
                        child: const Center(
                          child: Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Duplicar Tarefa',
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => _duplicateTask(),
                        customBorder: const CircleBorder(),
                        hoverColor: AppColors.primary.withValues(alpha: 0.1),
                        splashColor: AppColors.primary.withValues(alpha: 0.2),
                        child: const Center(
                          child: Icon(Icons.copy_outlined,
                              color: AppColors.secondaryText, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    if (isMobile) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            Flexible(child: contentBody),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildBottomActions(),
            ),
          ],
        ),
      );
    }

    // Desktop Embedded View (Novo Layout)
    if (isEmbedded) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.0),
          border: (widget.task.isOverdue && !widget.task.completed)
              ? Border.all(color: const Color(0xFFEF5350), width: 1.0)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: Scaffold(
            backgroundColor: AppColors.cardBackground,
            body: Column(
              children: [
                header,
                Expanded(child: contentBody),
              ],
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildBottomActions(),
            ),
          ),
        ),
      );
    }

    // Desktop Dialog View
    final vibrationColor = getColorsForVibration(currentPersonalDay).background;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: Container(
            decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                    color: vibrationColor.withValues(alpha: 0.6), width: 1.5)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header,
                Flexible(child: contentBody),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildBottomActions(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconText(
      IconData icon, String text, Color textColor, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
                fontFamily: 'Poppins', color: textColor, fontSize: 15),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  String _getShortRecurrenceText(RecurrenceRule rule) {
    switch (rule.type) {
      case RecurrenceType.daily:
        return 'Diariamente';
      case RecurrenceType.weekly:
        if (rule.daysOfWeek.length == 7) return 'Diariamente';
        return 'Semanalmente';
      case RecurrenceType.monthly:
        return 'Mensalmente';
      case RecurrenceType.none:
        return '';
    }
  }

  String _getReminderText(List<int> offsets) {
    if (offsets.isEmpty) return "Sem lembrete";
    if (offsets.length > 1) return "${offsets.length} lembretes";
    final offsetMins = offsets.first;
    if (offsetMins == 0) return "No horário";
    if (offsetMins < 60) return "$offsetMins min antes";
    final offsetHours = offsetMins ~/ 60;
    if (offsetHours < 24) return "${offsetHours}h antes";
    return "${offsetHours ~/ 24} dias antes";
  }

  Widget _buildDateTimeRecurrenceSummaryWidget() {
    final bool hasDateTime = _selectedDateTime != null;
    final bool hasRecurrence = _recurrenceRule.type != RecurrenceType.none;
    final bool hasReminder =
        _reminderOffsets != null && _reminderOffsets!.isNotEmpty;

    final Color color = (hasDateTime || hasRecurrence || hasReminder)
        ? AppColors.primaryText
        : AppColors.secondaryText;

    // COR: Laranja/Amber se tiver data
    final Color iconColor = (hasDateTime || hasRecurrence || hasReminder)
        ? Colors.amber
        : AppColors.tertiaryText;

    // When no dueDate and no startDate and no recurrence: show placeholder
    if (!hasDateTime && !hasRecurrence && _selectedStartDate == null) {
      return _buildIconText(
        Icons.calendar_today_outlined,
        'Adicionar agendamento',
        AppColors.tertiaryText,
        AppColors.tertiaryText,
      );
    }

    List<Widget> children = [];

    if (hasDateTime || _selectedStartDate != null) {
      final dateToUse = _selectedStartDate ?? _selectedDateTime!;
      final bool isOverdue = dateToUse.isBefore(DateTime.now()) &&
          !widget.task.completed &&
          !_isSameDay(
              DateTime(dateToUse.year, dateToUse.month,
                  dateToUse.day),
              DateTime(DateTime.now().year, DateTime.now().month,
                  DateTime.now().day));

      children.add(_buildIconText(
        Icons.calendar_today_outlined,
        _formatDateLabel(dateToUse),
        isOverdue ? Colors.redAccent : color,
        isOverdue ? Colors.redAccent : iconColor,
      ));
      if (_hasExplicitTime && dateToUse.hour != 0 || dateToUse.minute != 0) {
        children.add(_buildIconText(
          Icons.alarm,
          DateFormat.Hm('pt_BR').format(dateToUse),
          color,
          iconColor,
        ));
      }
    }

    if (hasRecurrence) {
      children.add(_buildIconText(
        Icons.repeat,
        _getShortRecurrenceText(_recurrenceRule),
        color,
        iconColor,
      ));
    }

    if (hasReminder) {
      children.add(_buildIconText(
        Icons.notifications_active_outlined,
        _getReminderText(_reminderOffsets!),
        AppColors.primary,
        AppColors.primary,
      ));
    }

    // Single-line row: earlier items keep natural size, last item truncates if needed
    if (children.length == 1) return children[0];
    final List<Widget> rowChildren = [];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) rowChildren.add(const SizedBox(width: 12));
      rowChildren.add(
        i < children.length - 1 ? children[i] : Flexible(child: children[i]),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: rowChildren);
  }

  /// Formats a date as "Hoje", "Amanhã", or the date string.
  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    // Mostra "Iniciando" para qualquer tarefa com recorrência ativa
    // (commitment template, flow, ou instâncias de ambos)
    final bool isRecurringContext = _recurrenceRule.type != RecurrenceType.none ||
        _selectedStartDate != null ||
        widget.task.recurrenceCategory == 'commitment_instance' ||
        widget.task.recurrenceCategory == 'flow' ||
        widget.task.recurrenceCategory == 'flow_instance';
    String prefix = isRecurringContext ? 'Iniciando ' : '';

    if (_isSameDay(dateOnly, today)) return '${prefix}Hoje';
    if (_isSameDay(dateOnly, tomorrow)) return '${prefix}Amanhã';
    if (date.year == now.year) {
      return prefix + DateFormat('EEE, dd/MM', 'pt_BR').format(date);
    }
    return prefix + DateFormat('dd/MM/yy', 'pt_BR').format(date);
  }

  Widget _buildDetailRow({
    required IconData icon,
    String? value,
    Widget? valueWidget,
    VoidCallback? onTap,
    Color valueColor = AppColors.primaryText,
    Color? iconColor, // Adicionado parâmetro opcional para cor do ícone
    Widget? trailingAction,
  }) {
    assert(value != null || valueWidget != null,
        'Provide either value or valueWidget');

    Widget rowContent = Row(
      children: [
        Icon(icon, color: iconColor ?? AppColors.secondaryText, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: valueWidget ??
              Text(
                value!,
                style: TextStyle(
                    fontFamily: 'Poppins', color: valueColor, fontSize: 15),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
        ),
        const SizedBox(width: 8),
        if (trailingAction != null)
          trailingAction
        else if (onTap != null)
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.secondaryText,
            size: 24,
          ),
      ],
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: rowContent,
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: rowContent,
      );
    }
  }

  Widget _buildTagsSection() {
    // Build sorted tag list: selected tags first, then unselected available tags
    final List<String> sortedTags = [
      ..._currentTags, // selected tags first
      ..._availableTags
          .where((t) => !_currentTags.contains(t)), // then the rest
    ];
    // Also include any current tags not in availableTags (e.g. newly created)
    final List<String> extraTags =
        _currentTags.where((t) => !_availableTags.contains(t)).toList();
    final List<String> allTags = [
      ...sortedTags,
      ...extraTags.where((t) => !sortedTags.contains(t)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: Icon + "Tags" label + "Criar" button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              const Icon(Icons.label_outline,
                  color: AppColors.secondaryText, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tags',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryText,
                    fontSize: 15,
                  ),
                ),
              ),
              // Toggle "Criar" button
              if (_currentTags.length < 5)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isTagInputVisible = !_isTagInputVisible;
                      if (!_isTagInputVisible) {
                        _tagInputController.clear();
                      }
                    });
                  },
                  icon: Icon(
                    _isTagInputVisible
                        ? Icons.close_rounded
                        : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isTagInputVisible ? 'Cancelar' : 'Criar',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                    ),
                  ),
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    minimumSize: WidgetStateProperty.all(Size.zero),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    overlayColor: WidgetStateProperty.all(Colors.transparent),
                    splashFactory: NoSplash.splashFactory,
                    foregroundColor:
                        WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) {
                        return AppColors.primary;
                      }
                      return AppColors.secondaryText;
                    }),
                  ),
                ),
            ],
          ),
        ),

        // Expandable input field (hidden by default, revealed by "Criar")
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _isTagInputVisible
              ? Padding(
                  padding: const EdgeInsets.only(
                      left: 34, right: 4, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagInputController,
                          focusNode: _tagFocusNode,
                          autofillHints: const [],
                          autofocus: true,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.primaryText,
                              fontSize: 14),
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(
                                RegExp(r'\s')), // no spaces
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) => newValue.copyWith(
                                text: newValue.text.toLowerCase(),
                              ),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: 'nome-da-tag',
                            hintStyle: TextStyle(
                                fontFamily: 'Poppins',
                                color: AppColors.secondaryText
                                    .withValues(alpha: 0.5)),
                            filled: false,
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color:
                                      AppColors.border.withValues(alpha: 0.5),
                                  width: 1),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color:
                                      AppColors.border.withValues(alpha: 0.5),
                                  width: 1),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.primary, width: 1.5),
                            ),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                          enabled: _currentTags.length < 5,
                          onChanged: (_) =>
                              setState(() {}), // rebuild to show/hide confirm
                          onSubmitted: (_) {
                            _addTag();
                            setState(() => _isTagInputVisible = false);
                          },
                        ),
                      ),
                      // Confirm button: only visible when there is text
                      if (_tagInputController.text.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.check_rounded, size: 22),
                          onPressed: () {
                            _addTag();
                            setState(() => _isTagInputVisible = false);
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          style: _subtleHoverStyle(),
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Tag chips cloud (always visible)
        if (allTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 34, right: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: allTags.map((tag) {
                    final bool isSelected = _currentTags.contains(tag);
                    return _buildTagChip(tag, isSelected);
                  }).toList(),
                ),
              ),
            ),
          ),
        if (allTags.isEmpty && !_isTagInputVisible)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 34),
            child: Text(
              'Nenhuma tag disponível',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.secondaryText.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTagChip(String tag, bool isSelected) {
    return ChoiceChip(
      label: Text(tag),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          if (_currentTags.length < 5) {
            setState(() {
              _currentTags.add(tag);
              _checkForChanges();
            });
          }
        } else {
          _removeTag(tag);
        }
      },
      selectedColor: Colors.purple,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.secondaryText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontFamily: 'Poppins',
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : AppColors.border,
        ),
      ),
    );
  }

  bool _isLoadingShared = false;

  /// Lightweight hover: only changes icon/text color, no background or border.
  ButtonStyle _subtleHoverStyle() {
    return ButtonStyle(
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.hovered)) {
          return AppColors.primary;
        }
        return AppColors.secondaryText;
      }),
    );
  }

  // ... (inside State class)

  void _openContactPicker() async {
    if (_isLoadingShared) return;
    setState(() => _isLoadingShared = true);

    try {
      final contacts = await _supabaseService.getContacts(widget.userData.uid);

      if (!mounted) return;
      setState(() => _isLoadingShared = false);

      await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return ContactPickerModal(
            preSelectedUsernames: _currentSharedWith,
            currentDate: _selectedDateTime ?? DateTime.now(),
            initialContacts: contacts, // PASS PRE-LOADED DATA
            onSelectionChanged: (selectedUsernames) {
              setState(() {
                _currentSharedWith = selectedUsernames;
                _updateParserFlags();
                _checkForChanges();
              });
            },
            onDateChanged: (newDate) {},
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingShared = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao carregar contatos.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ...

  Widget _buildSharedWithSection() {
    return _buildDetailRow(
      icon: Icons.people_outline_rounded,
      iconColor: _currentSharedWith.isNotEmpty
          ? Colors.lightBlueAccent
          : AppColors.secondaryText,
      valueWidget: _isLoadingShared
          ? const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.secondaryText)),
            )
          : (_currentSharedWith.isEmpty
              ? const Text('Adicionar pessoas',
                  style:
                      TextStyle(color: AppColors.secondaryText, fontSize: 15))
              : Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _currentSharedWith.map((username) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 10,
                        child: Text(username[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
                      ),
                      label: Text(username),
                      labelStyle: const TextStyle(fontSize: 12),
                      backgroundColor: AppColors.cardBackground,
                      side: const BorderSide(color: AppColors.border),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () {
                        _removeParserTextFromInput('@', username);
                        setState(() {
                          _currentSharedWith.remove(username);
                          _updateParserFlags();
                          _checkForChanges();
                        });
                      },
                    );
                  }).toList(),
                )),
      onTap: (_selectedGoal != null || _isLoadingShared)
          ? null
          : _openContactPicker,
      valueColor: _selectedGoal != null
          ? AppColors.tertiaryText
          : (_currentSharedWith.isNotEmpty
              ? AppColors.primaryText
              : AppColors.secondaryText),
      trailingAction: _selectedGoal != null
          ? null
          : (_isLoadingShared
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.secondaryText))
              : null),
    );
  }

  void _navigateToJournal(String journalId) async {
    if (!mounted) return;
    try {
      final entry = await _supabaseService.getJournalEntryById(
          widget.userData.uid, journalId);
      if (entry != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JournalEditorScreen(
              userData: widget.userData,
              entry: entry,
            ),
            fullscreenDialog:
                true, // Also fullscreen on mobile as defined in other parts
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Anotação não encontrada'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao buscar anotação: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
} // End of _TaskDetailModalState
