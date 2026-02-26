// lib/features/tasks/presentation/foco_do_dia_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_view_scope.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/tasks_list_view.dart';
import 'package:sincro_app_flutter/common/parser/task_parser.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:uuid/uuid.dart';
import 'widgets/task_input_modal.dart';
import 'widgets/task_detail_modal.dart';

// --- INÃCIO DA MUDANÃ‡A: Importar o motor de numerologia ---
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';
import 'dart:async';
import 'package:sincro_app_flutter/features/tasks/services/task_action_service.dart';
import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart';
// --- FIM DA MUDANÃ‡A ---

// --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 2): Adicionado 'concluidas' ---
import 'package:sincro_app_flutter/features/tasks/models/task_view_scope.dart';
import 'package:sincro_app_flutter/common/widgets/sincro_toolbar.dart';
import 'package:sincro_app_flutter/common/widgets/mobile_filter_sheet.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';

// --- FIM DA MUDANÃ‡A ---

class FocoDoDiaScreen extends StatefulWidget {
  final UserModel? userData;
  final String? initialFilter; // NOVO PARAMETRO

  const FocoDoDiaScreen({
    super.key,
    required this.userData,
    this.initialFilter,
  });

  @override
  State<FocoDoDiaScreen> createState() => _FocoDoDiaScreenState();
}

class _FocoDoDiaScreenState extends State<FocoDoDiaScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TaskActionService _taskActionService = TaskActionService();
  late final String _userId;
  final Uuid _uuid = const Uuid();

  // Filtro ativo: 'foco' (default), 'tarefas', 'agendamentos', 'concluidas', 'atrasadas', null (todas)
  String? _activeFilter = 'foco';
  DateTime? _selectedDate; // Single date (when start==end)
  DateTime? _startDateFilter; // Range start
  DateTime? _endDateFilter; // Range end
  int? _selectedVibrationNumber;
  final List<int> _vibrationNumbers = List.generate(9, (i) => i + 1) + [11, 22];

  // Stream to prevent rebuilds
  late Stream<List<TaskModel>> _tasksStream;

  // Filter Data
  String? _selectedGoalId;
  String? _selectedContactId;
  String? _selectedSort;
  List<Goal> _availableGoals = [];
  List<ContactModel> _availableContacts = [];
  StreamSubscription<List<Goal>>? _goalsSubscription;

  // --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 1 & 3): Estados de seleÃ§Ã£o e filtro ---
  bool _isSelectionMode = false;
  Set<String> _selectedTaskIds = {};
  String? _selectedTag;
  String _searchQuery = '';
  // --- FIM DA MUDANÃ‡A ---

  // Desktop Split View State
  TaskModel? _selectedTaskDesktop;
  bool _isCreatingTaskDesktop = false;

  // Global Keys for Desktop Filter Popups
  final GlobalKey _dateFilterKey = GlobalKey();
  final GlobalKey _vibrationFilterKey = GlobalKey();
  final GlobalKey _tagFilterKey = GlobalKey();
  final GlobalKey _goalFilterKey = GlobalKey();
  final GlobalKey _contactFilterKey = GlobalKey();
  final GlobalKey _sortFilterKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _userId = AuthRepository().currentUser?.id ?? '';
    if (_userId.isNotEmpty) {
      _tasksStream = _supabaseService.getTasksStream(_userId);
      _goalsSubscription =
          _supabaseService.getGoalsStream(_userId).listen((goals) {
        if (mounted) setState(() => _availableGoals = goals);
      });
      _fetchContacts();
    }
    if (_userId.isEmpty) {
      debugPrint("ERRO: FocoDoDiaScreen acessada sem usuÃ¡rio logado!");
    }

    // Configurar filtro inicial baseado no parametro
    if (widget.initialFilter == 'overdue') {
      _activeFilter = 'atrasadas';
    } else if (widget.initialFilter == 'today') {
      _activeFilter = 'foco';
    }
  }

  Future<void> _fetchContacts() async {
    try {
      final users = await _supabaseService.getUserContacts(_userId);
      if (mounted) {
        setState(() {
          _availableContacts =
              users.map((u) => ContactModel.fromUserModel(u)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
    }
  }

  @override
  void dispose() {
    _goalsSubscription?.cancel();
    super.dispose();
  }

  void _openAddTaskModal() {
    if (widget.userData == null || _userId.isEmpty) {
      _showErrorSnackbar('Erro: NÃ£o foi possÃ­vel obter dados do usuÃ¡rio.');
      return;
    }

    // --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 1): Cancela seleÃ§Ã£o ao abrir modal ---
    if (_isSelectionMode) {
      _clearSelection();
    }
    // --- FIM DA MUDANÃ‡A ---

    if (MediaQuery.of(context).size.width > 900 &&
        MediaQuery.of(context).size.width >
            MediaQuery.of(context).size.height) {
      setState(() {
        _isCreatingTaskDesktop = true;
        _selectedTaskDesktop = null;
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData!,
        userId: _userId,
        // NÃƒO passa initialDueDate para que o pill de data nÃ£o apareÃ§a
        // O modal vai calcular a vibraÃ§Ã£o para "hoje" mas nÃ£o mostra o pill
        onAddTask: (ParsedTask parsedTask) {
          if (parsedTask.recurrenceRule.type == RecurrenceType.none) {
            _createSingleTask(parsedTask);
          } else {
            _createRecurringTasks(parsedTask);
          }
        },
      ),
    );
  }

  // --- INÃCIO DA MUDANÃ‡A: FunÃ§Ã£o helper para calcular o Dia Pessoal ---
  /// Calcula o Dia Pessoal para uma data especÃ­fica.
  /// Retorna null se os dados do usuÃ¡rio nÃ£o estiverem disponÃ­veis ou a data for nula.
  int? _calculatePersonalDay(DateTime? date) {
    if (widget.userData == null ||
        widget.userData!.dataNasc.isEmpty ||
        widget.userData!.nomeAnalise.isEmpty ||
        date == null) {
      return null; // Retorna nulo se nÃ£o pode calcular
    }

    final engine = NumerologyEngine(
      nomeCompleto: widget.userData!.nomeAnalise,
      dataNascimento: widget.userData!.dataNasc,
    );

    try {
      // Garante que estamos usando UTC
      final dateUtc = date.toUtc();
      final day = engine.calculatePersonalDayForDate(dateUtc);
      return (day > 0) ? day : null;
    } catch (e) {
      return null;
    }
  }
  // --- FIM DA MUDANÃ‡A ---

  void _createSingleTask(ParsedTask parsedTask, {String? recurrenceId}) {
    // Garante que a data seja convertida para UTC
    DateTime? finalDueDateUtc;
    DateTime dateForPersonalDay;

    if (parsedTask.dueDate != null) {
      // Se tem data especÃ­fica, usa ela
      final dateLocal = parsedTask.dueDate!.toLocal();
      finalDueDateUtc =
          DateTime.utc(dateLocal.year, dateLocal.month, dateLocal.day);
      dateForPersonalDay = finalDueDateUtc;
    } else {
      // Se nÃ£o tem data especÃ­fica, usa a data atual (nÃ£o a de amanhÃ£)
      final now = DateTime.now().toLocal();
      dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
      // NÃƒO define finalDueDateUtc - deixa null para tarefas sem data especÃ­fica
    }

    // Calcula o dia pessoal usando a data determinada
    final int? finalPersonalDay = _calculatePersonalDay(dateForPersonalDay);

    final newTask = TaskModel(
      id: '',
      text: parsedTask.cleanText,
      createdAt: DateTime.now().toUtc(),
      dueDate: finalDueDateUtc,
      // --- INÃCIO DA MUDANÃ‡A: Campos de Meta/Jornada (JÃ¡ estavam corretos) ---
      journeyId: parsedTask.journeyId,
      journeyTitle: parsedTask.journeyTitle,
      // --- FIM DA MUDANÃ‡A ---
      tags: parsedTask.tags,
      reminderTime: parsedTask.reminderTime,
      reminderAt: parsedTask.reminderAt,
      recurrenceType: parsedTask.recurrenceRule.type,
      recurrenceDaysOfWeek: parsedTask.recurrenceRule.daysOfWeek,
      recurrenceEndDate: parsedTask.recurrenceRule.endDate?.toUtc(),
      recurrenceId: recurrenceId,
      // --- INÃCIO DA MUDANÃ‡A: Salvar o Dia Pessoal calculado ---
      personalDay: finalPersonalDay,
      // --- FIM DA MUDANÃ‡A ---
    );

    _supabaseService.addTask(_userId, newTask).catchError((error) {
      _showErrorSnackbar("Erro ao salvar tarefa: $error");
    });
  }

  void _createRecurringTasks(ParsedTask parsedTask) {
    // GeraÃ§Ã£o de ID Ãºnico para agrupar (se necessÃ¡rio no futuro)
    final String recurrenceId = _uuid.v4();

    // A logica antiga gerava 100+ tarefas.
    // A nova lÃ³gica cria APENAS A PRIMEIRA e deixa o backend (n8n) criar a prÃ³xima ao concluir.

    // Usa a data definida ou 'Hoje'
    final firstDate = parsedTask.dueDate ?? DateTime.now();

    final taskForFirstDate = parsedTask.copyWith(
      dueDate: firstDate,
    );

    // Cria apenas uma tarefa
    _createSingleTask(taskForFirstDate, recurrenceId: recurrenceId);

    // Feedback visual simples
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarefa recorrente criada!'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  //
  // --- Nenhuma mudanÃ§a nas funÃ§Ãµes de cÃ¡lculo de recorrÃªncia ---
  //
  List<DateTime> _calculateRecurrenceDates(
      RecurrenceRule rule, DateTime? startDate) {
    final List<DateTime> dates = [];
    DateTime currentDate = (startDate ?? DateTime.now()).toLocal();
    currentDate =
        DateTime(currentDate.year, currentDate.month, currentDate.day);

    final DateTime safetyLimit =
        DateTime.now().add(const Duration(days: 365 * 2));
    final DateTime loopEndDate = (rule.endDate?.toLocal() ?? safetyLimit);
    final DateTime finalEndDate = DateTime(
        loopEndDate.year, loopEndDate.month, loopEndDate.day, 23, 59, 59);

    int iterations = 0;
    const int maxIterations = 100;

    if (rule.type != RecurrenceType.none &&
        _doesDateMatchRule(rule, currentDate, startDate)) {
      dates.add(currentDate);
      iterations++;
    }

    DateTime nextDate = _getNextDate(rule, currentDate);

    while (nextDate.isBefore(finalEndDate) && iterations < maxIterations) {
      if (_doesDateMatchRule(rule, nextDate, startDate)) {
        dates.add(nextDate);
        iterations++;
      }
      nextDate = _getNextDate(rule, nextDate);
      if (iterations > maxIterations + 5) {
        break;
      }
    }
    return dates;
  }

  bool _doesDateMatchRule(
      RecurrenceRule rule, DateTime date, DateTime? ruleStartDate) {
    switch (rule.type) {
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        return rule.daysOfWeek.contains(date.weekday);
      case RecurrenceType.monthly:
        return date.day == (ruleStartDate?.day ?? date.day);
      case RecurrenceType.none:
        return false;
    }
  }

  DateTime _getNextDate(RecurrenceRule rule, DateTime currentDate) {
    switch (rule.type) {
      case RecurrenceType.daily:
      case RecurrenceType.weekly:
        return currentDate.add(const Duration(days: 1));
      case RecurrenceType.monthly:
        int nextMonth = currentDate.month + 1;
        int nextYear = currentDate.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        int daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        int nextDay = currentDate.day > daysInNextMonth
            ? daysInNextMonth
            : currentDate.day;
        return DateTime(nextYear, nextMonth, nextDay);
      case RecurrenceType.none:
        return DateTime.now().add(const Duration(days: 365 * 10));
    }
  }
  // --- Fim das funÃ§Ãµes de cÃ¡lculo de recorrÃªncia ---
  //

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _handleTaskTap(TaskModel task) {
    // --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 1): Trava clique normal em modo de seleÃ§Ã£o ---
    if (_isSelectionMode) return;
    // --- FIM DA MUDANÃ‡A ---

    if (widget.userData == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    bool isDesktopLayout = screenWidth > 600;

    if (isDesktopLayout) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return TaskDetailModal(
            task: task,
            userData: widget.userData!,
            onReschedule: (date) => _rescheduleTaskToDate(task, date),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => TaskDetailModal(
          task: task,
          userData: widget.userData!,
          onReschedule: (date) => _rescheduleTaskToDate(task, date),
        ),
      );
    }
  }

  // Note: date comparisons now use explicit local-date logic where needed.

  // --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 1): MÃ©todos de gerenciamento de seleÃ§Ã£o ---

  /// Alterna o modo de seleÃ§Ã£o.
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTaskIds.clear();
      }
    });
  }

  /// Limpa a seleÃ§Ã£o e sai do modo de seleÃ§Ã£o.
  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedTaskIds.clear();
    });
  }

  /// Seleciona ou deseleciona uma tarefa.
  void _onTaskSelected(String taskId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedTaskIds.add(taskId);
      } else {
        _selectedTaskIds.remove(taskId);
      }
    });
  }

  /// Seleciona todas as tarefas visÃ­veis atualmente.
  void _selectAll(List<TaskModel> tasksToShow) {
    setState(() {
      if (_selectedTaskIds.length == tasksToShow.length) {
        // Se todos jÃ¡ estÃ£o selecionados, limpa
        _selectedTaskIds.clear();
      } else {
        // SenÃ£o, seleciona todos
        _selectedTaskIds = tasksToShow.map((t) => t.id).toSet();
      }
    });
  }

  /// Exibe um diÃ¡logo de confirmaÃ§Ã£o e exclui as tarefas selecionadas.
  Future<void> _deleteSelectedTasks() async {
    final count = _selectedTaskIds.length;
    if (count == 0) return;

    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir Tarefas',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'VocÃª tem certeza que deseja excluir permanentemente $count ${count == 1 ? 'tarefa' : 'tarefas'}?',
            style: const TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _supabaseService.deleteTasks(_userId, _selectedTaskIds.toList());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '$count ${count == 1 ? 'tarefa excluÃ­da' : 'tarefas excluÃ­das'}.'),
                backgroundColor: Colors.green),
          );
          _clearSelection();
          setState(() {
            _tasksStream = _supabaseService.getTasksStream(_userId);
          });
        }
      } catch (e) {
        _showErrorSnackbar("Erro ao excluir tarefas: $e");
      }
    }
  }
  // --- FIM DA MUDANÃ‡A ---

  // --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 2 & 3): LÃ³gica de filtro atualizada ---
  List<TaskModel> _filterTasks(List<TaskModel> allTasks, int? userPersonalDay) {
    // 0. SEARCH FILTERING
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      allTasks =
          allTasks.where((t) => t.text.toLowerCase().contains(query)).toList();
    }

    List<TaskModel> filteredTasks;

    // 1. VIEW FILTER (standalone toggles)
    switch (_activeFilter) {
      case 'foco':
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final tomorrowStart = todayStart.add(const Duration(days: 1));
        filteredTasks = allTasks.where((task) {
          if (task.completed) return false;
          // Tarefas sem data marcadas como foco
          if (!task.hasDeadline && task.isFocus) return true;
          // Tarefas atrasadas (com data)
          if (task.isOverdue) return true;
          // Tarefas agendadas para hoje
          if (task.hasDeadline) {
            final taskDateLocal = task.dueDate!.toLocal();
            final taskDateOnly = DateTime(taskDateLocal.year, taskDateLocal.month, taskDateLocal.day);
            return !taskDateOnly.isBefore(todayStart) && taskDateOnly.isBefore(tomorrowStart);
          }
          return false;
        }).toList();
        break;
      case 'tarefas':
        filteredTasks = allTasks.where((task) => !task.completed && !task.hasDeadline).toList();
        break;
      case 'agendamentos':
        filteredTasks = allTasks.where((task) => !task.completed && task.hasDeadline).toList();
        break;
      case 'concluidas':
        filteredTasks = allTasks.where((task) => task.completed).toList();
        break;
      case 'atrasadas':
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        filteredTasks = allTasks.where((task) {
          if (task.completed) return false;
          if (!task.hasDeadline) return false;
          final taskDateLocal = task.dueDate!.toLocal();
          final taskDateOnly = DateTime(taskDateLocal.year, taskDateLocal.month, taskDateLocal.day);
          return taskDateOnly.isBefore(todayStart);
        }).toList();
        break;
      default:
        filteredTasks = allTasks.where((task) => !task.completed).toList();
        break;
    }

    // 2. REFINEMENT FILTERING (Refinar por...)

    // Date Filter (supports single date and range) — usa effectiveDate
    if (_startDateFilter != null || _endDateFilter != null || _selectedDate != null) {
      filteredTasks = filteredTasks.where((task) {
        final effectiveLocal = task.effectiveDate.toLocal();
        final taskDate = DateTime(effectiveLocal.year, effectiveLocal.month, effectiveLocal.day);
        if (_startDateFilter != null && _endDateFilter != null) {
          final start = DateTime(_startDateFilter!.year, _startDateFilter!.month, _startDateFilter!.day);
          final end = DateTime(_endDateFilter!.year, _endDateFilter!.month, _endDateFilter!.day);
          return !taskDate.isBefore(start) && !taskDate.isAfter(end);
        } else if (_selectedDate != null) {
          return isSameDay(effectiveLocal, _selectedDate!);
        }
        return true;
      }).toList();
    }

    // Vibration Filter — usa effectiveDate para calcular dia pessoal
    if (_selectedVibrationNumber != null) {
      if (widget.userData != null) {
        filteredTasks = filteredTasks.where((task) {
          // Usa personalDay salvo, ou calcula a partir de effectiveDate
          int? pd = task.personalDay;

          if (pd == null &&
              widget.userData?.nomeAnalise.isNotEmpty == true &&
              widget.userData?.dataNasc.isNotEmpty == true) {
            final engine = NumerologyEngine(
              nomeCompleto: widget.userData!.nomeAnalise,
              dataNascimento: widget.userData!.dataNasc,
            );
            // Calcula PD pela data efetiva (dueDate ?? createdAt)
            final effectiveLocal = task.effectiveDate.toLocal();
            final dateForCalc = DateTime.utc(effectiveLocal.year, effectiveLocal.month, effectiveLocal.day);
            pd = engine.calculatePersonalDayForDate(dateForCalc);
          }
          return pd == _selectedVibrationNumber;
        }).toList();
      }
    }

    // Tag Filter
    if (_selectedTag != null) {
      filteredTasks = filteredTasks
          .where((task) => task.tags.contains(_selectedTag))
          .toList();
    }

    // Goal Filter (New)
    if (_selectedGoalId != null) {
      if (_selectedGoalId == 'all') {
        filteredTasks = filteredTasks
            .where((task) =>
                (task.journeyId != null && task.journeyId!.isNotEmpty) ||
                (task.goalId != null && task.goalId!.isNotEmpty))
            .toList();
      } else {
        filteredTasks = filteredTasks
            .where((task) =>
                task.journeyId == _selectedGoalId ||
                task.goalId == _selectedGoalId)
            .toList();
      }
    }

    // Contact Filter (New)
    if (_selectedContactId != null) {
      if (_selectedContactId == 'all') {
        filteredTasks =
            filteredTasks.where((task) => task.sharedWith.isNotEmpty).toList();
      } else {
        final contact = _availableContacts.firstWhere(
            (c) => c.userId == _selectedContactId,
            orElse: () => ContactModel(
                userId: '',
                username: '',
                displayName: '',
                photoUrl: '',
                status: ''));

        if (contact.username.isNotEmpty) {
          filteredTasks = filteredTasks
              .where((task) => task.sharedWith.contains(contact.username))
              .toList();
        }
      }
    }

    // Sorting
    filteredTasks.sort((a, b) {
      if (_selectedSort == 'alpha_asc') {
        return a.text.toLowerCase().compareTo(b.text.toLowerCase());
      } else if (_selectedSort == 'alpha_desc') {
        return b.text.toLowerCase().compareTo(a.text.toLowerCase());
      } else if (_selectedSort == 'date_desc') {
        final aDate = a.dueDate ?? a.createdAt;
        final bDate = b.dueDate ?? b.createdAt;
        return bDate.compareTo(aDate);
      } else if (_selectedSort == 'date_asc') {
        final aDate = a.dueDate ?? a.createdAt;
        final bDate = b.dueDate ?? b.createdAt;
        return aDate.compareTo(bDate);
      } else {
        // Default sort (by Due Date)
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      }
    });

    return filteredTasks;
  }
  // --- FIM DA MUDANÃ‡A ---

  // --- INÃCIO DA MUDANÃ‡A (Swipe Actions) ---
  // Swipe Left: Excluir Tarefa
  Future<bool?> _handleSwipeLeft(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir Tarefa?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Tem certeza que deseja excluir esta tarefa? Esta aÃ§Ã£o nÃ£o pode ser desfeita.',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.deleteTask(_userId, task.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarefa excluÃ­da com sucesso'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return true; // Confirma a exclusÃ£o visual
      } catch (e) {
        debugPrint("Erro ao excluir tarefa: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir tarefa: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  // Swipe Right: Reagendar (com deadline) ou Toggle Foco (sem deadline)
  Future<bool?> _handleSwipeRight(TaskModel task) async {
    if (widget.userData == null) return false;

    // Tarefas sem data: toggle foco
    if (!task.hasDeadline) {
      try {
        await _supabaseService.updateTaskFields(
          _userId, task.id, {'is_focus': !task.isFocus},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(task.isFocus ? 'Foco removido' : 'Em foco ⚡'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (_) {}
      return false;
    }

    // Tarefas com data: reagendar
    final newDate = await _taskActionService.rescheduleTask(
      context,
      task,
      widget.userData!,
    );

    if (newDate != null) {
      if (_activeFilter == 'foco') {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final newDateOnly = DateTime(newDate.year, newDate.month, newDate.day);
        if (!newDateOnly.isAtSameMomentAs(today)) return true;
      } else if (_activeFilter == 'atrasadas') {
        return true;
      }
    }
    return false;
  }
  // --- FIM DA MUDANÃ‡A ---

  @override
  Widget build(BuildContext context) {
    if (widget.userData == null || _userId.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Erro: Dados do usuÃ¡rio nÃ£o disponÃ­veis.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 900 && size.width > size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: _buildTaskListContent(isMobile: !isDesktop),
      ),

      // Esconde FAB em modo de seleÃ§Ã£o e Desktop
      floatingActionButton: (_isSelectionMode || isDesktop)
          ? null
          : FloatingActionButton(
              onPressed: _openAddTaskModal,
              backgroundColor: AppColors.primary,
              tooltip: 'Adicionar Tarefa',
              heroTag: 'foco_fab',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  // _buildHeader (original) MODIFICADO para (SolicitaÃ§Ã£o 1 e 3)
  final GlobalKey _filterButtonKey = GlobalKey();

  // Removed duplicate _selectedDate

  bool get _isFilterActive {
    return _activeFilter != null ||
        _selectedDate != null ||
        _startDateFilter != null ||
        _endDateFilter != null ||
        _selectedVibrationNumber != null ||
        _selectedTag != null ||
        _selectedGoalId != null ||
        _selectedContactId != null ||
        _searchQuery.isNotEmpty;
  }



  void _showDesktopDateFilter() {
    showSmartPopup(
      context: _dateFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 340,
        child: MobileFilterSheet(
          type: MobileFilterType.date,
          selectedDate: _selectedDate,
          selectedStartDate: _startDateFilter,
          selectedEndDate: _endDateFilter,
          userData: widget.userData,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _selectedDate = result['date'];
          _startDateFilter = result['startDate'];
          _endDateFilter = result['endDate'];
          _clearSelection();
        });
      }
    });
  }

  void _showDesktopVibrationFilter() {
    showSmartPopup(
      context: _vibrationFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 320,
        child: MobileFilterSheet(
          type: MobileFilterType.vibration,
          selectedVibration: _selectedVibrationNumber,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map && result.containsKey('vibration')) {
        setState(() {
          _selectedVibrationNumber = result['vibration'];
          _clearSelection();
        });
      }
    });
  }

  void _showDesktopTagFilter(List<String> availableTags) {
    showSmartPopup(
      context: _tagFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 320,
        child: MobileFilterSheet(
          type: MobileFilterType.tag,
          availableTags: availableTags,
          selectedTag: _selectedTag,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map && result.containsKey('tag')) {
        setState(() {
          _selectedTag = result['tag'];
          _clearSelection();
        });
      }
    });
  }

  void _showDesktopGoalFilter() {
    showSmartPopup(
      context: _goalFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 320,
        child: MobileFilterSheet(
          type: MobileFilterType.goal,
          goals: _availableGoals,
          selectedOption: _selectedGoalId,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map && result.containsKey('goalId')) {
        setState(() {
          _selectedGoalId = result['goalId'];
          _clearSelection();
        });
      }
    });
  }

  void _showDesktopContactFilter() {
    showSmartPopup(
      context: _contactFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 320,
        child: MobileFilterSheet(
          type: MobileFilterType.contact,
          contacts: _availableContacts,
          selectedOption: _selectedContactId,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map && result.containsKey('contactId')) {
        setState(() {
          _selectedContactId = result['contactId'];
          _clearSelection();
        });
      }
    });
  }

  void _showDesktopSortFilter() {
    showSmartPopup(
      context: _sortFilterKey.currentContext!,
      builder: (context) => SizedBox(
        width: 320,
        child: MobileFilterSheet(
          type: MobileFilterType.sort,
          selectedOption: _selectedSort,
          isDesktop: true,
        ),
      ),
    ).then((result) {
      if (result != null && result is Map && result.containsKey('value')) {
        setState(() {
          _selectedSort = result['value'];
          _clearSelection();
        });
      }
    });
  }

  // --- SincroToolbar Integration ---

  Widget _buildToolbar(
      bool isDesktop, List<String> allTags, List<TaskModel> tasksToShow) {
    return SincroToolbar(
      title: "Tarefas",
      forceDesktop: isDesktop,
      filters: _buildFilterItems(isDesktop, allTags),
      isSelectionMode: _isSelectionMode,
      isAllSelected: tasksToShow.isNotEmpty &&
          _selectedTaskIds.length == tasksToShow.length,
      selectedCount: _selectedTaskIds.length,
      hasActiveFilters: _isFilterActive,
      onSearchChanged: (val) => setState(() => _searchQuery = val),
      onToggleSelectionMode: _toggleSelectionMode,
      onToggleSelectAll: () => _selectAll(tasksToShow),
      onDeleteSelected: _deleteSelectedTasks,
      onClearFilters: () {
        setState(() {
          _activeFilter = null;
          _selectedDate = null;
          _startDateFilter = null;
          _endDateFilter = null;
          _selectedVibrationNumber = null;
          _selectedTag = null;
          _selectedGoalId = null;
          _selectedContactId = null;
          _selectedSort = null;
          _searchQuery = '';
          _selectedTaskIds.clear();
        });
      },
    );
  }

  List<SincroFilterItem> _buildFilterItems(
      bool isDesktop, List<String> availableTags) {
    // Standalone view filters
    void _setFilter(String? filter) {
      setState(() {
        _activeFilter = (_activeFilter == filter) ? null : filter;
        _clearSelection();
      });
    }

    final focoItem = SincroFilterItem(
      label: 'Foco',
      icon: Icons.bolt,
      isSelected: _activeFilter == 'foco',
      activeColor: const Color(0xFFFF6D3F),
      onTap: () => _setFilter('foco'),
    );

    final tarefasItem = SincroFilterItem(
      label: 'Tarefas',
      icon: Icons.inbox_outlined,
      isSelected: _activeFilter == 'tarefas',
      activeColor: Colors.amber,
      onTap: () => _setFilter('tarefas'),
    );

    final agendamentoItem = SincroFilterItem(
      label: 'Agendamentos',
      icon: Icons.event_available,
      isSelected: _activeFilter == 'agendamentos',
      activeColor: Colors.amber,
      onTap: () => _setFilter('agendamentos'),
    );

    final concluidasItem = SincroFilterItem(
      label: 'Concluídas',
      icon: Icons.check_circle_outline,
      isSelected: _activeFilter == 'concluidas',
      activeColor: const Color(0xFF22C55E),
      onTap: () => _setFilter('concluidas'),
    );

    final atrasadasItem = SincroFilterItem(
      label: 'Atrasadas',
      icon: Icons.warning_amber_rounded,
      isSelected: _activeFilter == 'atrasadas',
      activeColor: const Color(0xFFEF5350),
      onTap: () => _setFilter('atrasadas'),
    );

    // 2. Date Filter (with rich label like Journal)
    String dateLabel = 'Data';
    bool isDateActive = _startDateFilter != null || _endDateFilter != null || _selectedDate != null;
    if (isDateActive) {
      if (_startDateFilter != null && _endDateFilter != null) {
        if (isSameDay(_startDateFilter!, _endDateFilter!)) {
          dateLabel = 'Dia ${DateFormat('dd/MM').format(_startDateFilter!)}';
        } else {
          final isFullMonth = _startDateFilter!.day == 1 &&
              _endDateFilter!.day == DateTime(_endDateFilter!.year, _endDateFilter!.month + 1, 0).day;
          final isFullYear = _startDateFilter!.month == 1 &&
              _startDateFilter!.day == 1 &&
              _endDateFilter!.month == 12 &&
              _endDateFilter!.day == 31;
          if (isFullYear) {
            dateLabel = 'Ano ${_startDateFilter!.year}';
          } else if (isFullMonth) {
            dateLabel = 'Mês ${DateFormat('MMM', 'pt_BR').format(_startDateFilter!)}';
          } else {
            dateLabel = '${DateFormat('dd/MM').format(_startDateFilter!)} - ${DateFormat('dd/MM').format(_endDateFilter!)}';
          }
        }
      } else if (_startDateFilter != null) {
        dateLabel = 'A partir de ${DateFormat('dd/MM').format(_startDateFilter!)}';
      } else if (_selectedDate != null) {
        dateLabel = 'Dia ${DateFormat('dd/MM').format(_selectedDate!)}';
      }
    }
    final dateItem = SincroFilterItem(
      key: _dateFilterKey,
      label: dateLabel,
      icon: Icons.calendar_today,
      isSelected: isDateActive,
      onTap: () {
        if (isDesktop) {
          _showDesktopDateFilter();
        } else {
          _showMobileDateFilter();
        }
      },
    );

    // 3. Vibration Filter
    // Calculate color if selected
    Color? vibrationColor;
    if (_selectedVibrationNumber != null) {
      vibrationColor =
          getColorsForVibration(_selectedVibrationNumber!).background;
    }

    final vibrationItem = SincroFilterItem(
      key: _vibrationFilterKey,
      label: _selectedVibrationNumber != null
          ? 'Vibração $_selectedVibrationNumber'
          : 'Vibração',
      icon: Icons.waves, // Updated icon
      isSelected: _selectedVibrationNumber != null,
      activeColor: vibrationColor,
      onTap: () {
        if (isDesktop) {
          _showDesktopVibrationFilter();
        } else {
          _showMobileVibrationFilter();
        }
      },
    );

    // 4. Tag Filter
    final tagItem = SincroFilterItem(
      key: _tagFilterKey,
      label: _selectedTag != null ? '#$_selectedTag' : 'Tag',
      icon: Icons.label_outline,
      isSelected: _selectedTag != null,
      activeColor:
          _selectedTag != null ? Colors.purple : null, // Requested Pink/Purple
      onTap: () {
        if (isDesktop) {
          _showDesktopTagFilter(availableTags);
        } else {
          _showMobileTagFilter(availableTags);
        }
      },
    );

    // 5. Goal Filter (New)
    String goalLabel = 'Meta';
    if (_selectedGoalId == 'all') {
      goalLabel = 'Qualquer Meta';
    } else if (_selectedGoalId != null) {
      final goal = _availableGoals.firstWhere((g) => g.id == _selectedGoalId,
          orElse: () => Goal(
              id: '',
              userId: '',
              title: 'Meta',
              description: '',
              createdAt: DateTime.now(),
              progress: 0));
      if (goal.id.isNotEmpty) {
        goalLabel = goal.title;
      }
    }

    final goalItem = SincroFilterItem(
      key: _goalFilterKey,
      label: goalLabel,
      icon: Icons.flag_outlined,
      isSelected: _selectedGoalId != null,
      activeColor:
          _selectedGoalId != null ? Colors.cyan : null, // Requested Cyan
      onTap: () {
        if (isDesktop) {
          _showDesktopGoalFilter();
        } else {
          _showMobileGoalFilter();
        }
      },
    );

    // 6. Contact Filter (New)
    String contactLabel = 'Contato';
    if (_selectedContactId == 'all') {
      contactLabel = 'Qualquer Contato';
    } else if (_selectedContactId != null) {
      final contact = _availableContacts.firstWhere(
          (c) => c.userId == _selectedContactId,
          orElse: () => ContactModel(
              userId: '',
              username: '',
              displayName: '',
              photoUrl: '',
              status: ''));
      if (contact.userId.isNotEmpty) {
        contactLabel = contact.displayName.isNotEmpty
            ? contact.displayName
            : contact.username;
      }
    }

    final contactItem = SincroFilterItem(
      key: _contactFilterKey,
      label: contactLabel,
      icon: Icons.person_outline,
      isSelected: _selectedContactId != null,
      activeColor:
          _selectedContactId != null ? Colors.blue : null, // Requested Blue
      onTap: () {
        if (isDesktop) {
          _showDesktopContactFilter();
        } else {
          _showMobileContactFilter();
        }
      },
    );

    // 7. Sort Filter (New)
    String sortLabel = 'Ordenar';
    if (_selectedSort == 'date_desc') sortLabel = 'Mais recentes';
    if (_selectedSort == 'date_asc') sortLabel = 'Mais antigas';
    if (_selectedSort == 'alpha_asc') sortLabel = 'A-Z';
    if (_selectedSort == 'alpha_desc') sortLabel = 'Z-A';

    final sortItem = SincroFilterItem(
      key: _sortFilterKey,
      label: sortLabel,
      icon: Icons.sort,
      isSelected: _selectedSort != null,
      activeColor: _selectedSort != null ? AppColors.primary : null,
      onTap: () {
        if (isDesktop) {
          _showDesktopSortFilter();
        } else {
          _showMobileSortFilter();
        }
      },
    );

    return [
      focoItem,
      tarefasItem,
      agendamentoItem,
      concluidasItem,
      atrasadasItem,
      goalItem,
      tagItem,
      contactItem,
      vibrationItem,
      sortItem,
      dateItem,
    ];
  }



  void _showMobileDateFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.date,
        selectedDate: _selectedDate,
        selectedStartDate: _startDateFilter,
        selectedEndDate: _endDateFilter,
        userData: widget.userData,
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _selectedDate = result['date'];
          _startDateFilter = result['startDate'];
          _endDateFilter = result['endDate'];
          _clearSelection();
        });
      }
    });
  }

  void _showMobileVibrationFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.vibration,
        userData: widget.userData,
        selectedVibration: _selectedVibrationNumber,
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _selectedVibrationNumber = result['vibration'] as int?;
          _clearSelection();
        });
      }
    });
  }

  void _showMobileTagFilter(List<String> availableTags) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.tag,
        availableTags: availableTags,
        selectedTag: _selectedTag,
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _selectedTag = result['tag'] as String?;
          _clearSelection();
        });
      }
    });
  }

  void _showMobileGoalFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.goal,
        goals: _availableGoals,
        selectedOption: _selectedGoalId,
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _selectedGoalId =
              result['goalId'] as String?; // Assuming 'goalId' is returned key
          _clearSelection();
        });
      }
    });
  }

  void _showMobileContactFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.contact,
        contacts: _availableContacts,
        selectedOption: _selectedContactId,
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _selectedContactId = result['contactId']
              as String?; // Assuming 'contactId' is returned key
          _clearSelection();
        });
      }
    });
  }

  void _showMobileSortFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MobileFilterSheet(
        type: MobileFilterType.sort,
        selectedOption: _selectedSort,
      ),
    ).then((result) {
      if (result != null && result is Map) {
        setState(() {
          _selectedSort = result['value'] as String?;
          _clearSelection();
        });
      }
    });
  }

  // --- SPLIT VIEW HELPERS ---

  Widget _buildTaskListContent({required bool isMobile}) {
    return StreamBuilder<List<TaskModel>>(
      stream: _tasksStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Erro ao carregar tarefas: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoadingSpinner());
        }

        final tasks = snapshot.data ?? [];
        final allTags = tasks.expand((t) => t.tags).toSet().toList();
        // Calculate personal day if needed for Foco do Dia
        int? userPersonalDay;
        if (_activeFilter == 'foco') {
          userPersonalDay = _calculatePersonalDay(DateTime.now());
        }
        final tasksToShow = _filterTasks(tasks, userPersonalDay);

        // Empty state logic
        String emptyMsg = 'Tudo limpo por aqui!';
        String emptySubMsg = 'Você não tem tarefas pendentes.';

        if (_activeFilter == 'foco' && tasksToShow.isEmpty) {
          emptyMsg = 'Foco do dia concluído!';
          emptySubMsg = 'Você não tem tarefas pendentes para hoje.';
        } else if (_activeFilter == 'tarefas' && tasksToShow.isEmpty) {
          emptyMsg = 'Nenhuma tarefa sem data.';
          emptySubMsg = 'Todas as tarefas possuem agendamento.';
        } else if (_activeFilter == 'agendamentos' && tasksToShow.isEmpty) {
          emptyMsg = 'Sem agendamentos.';
          emptySubMsg = 'Nenhuma tarefa agendada encontrada.';
        } else if (_activeFilter == 'concluidas' && tasksToShow.isEmpty) {
          emptyMsg = 'Nenhuma tarefa concluída.';
          emptySubMsg = 'Complete tarefas para vê-las aqui.';
        } else if (_activeFilter == 'atrasadas' && tasksToShow.isEmpty) {
          emptyMsg = 'Nenhuma tarefa atrasada.';
          emptySubMsg = 'Parabéns! Você está em dia com suas tarefas.';
        }

        // Se um filtro de tag estiver ativo e a lista vazia
        if (_selectedTag != null &&
            tasksToShow.isEmpty &&
            _activeFilter != 'concluidas') {
          emptyMsg = 'Nenhuma tarefa encontrada.';
          emptySubMsg = 'Não há tarefas pendentes com a tag "$_selectedTag".';
        }

        return Column(
          children: [
            if (isMobile) ...[
              _buildToolbar(false, allTags, tasksToShow),
              Expanded(
                child: TasksListView(
                  tasks: tasksToShow,
                  userData: widget.userData,
                  emptyListMessage: emptyMsg,
                  emptyListSubMessage: emptySubMsg,
                  selectionMode: _isSelectionMode,
                  selectedTaskIds: _selectedTaskIds,
                  activeTaskId: _selectedTaskDesktop?.id,
                  onTaskSelected: _onTaskSelected,
                  onTaskTap: (task) {
                    if (_isSelectionMode) {
                      _onTaskSelected(
                          task.id, !_selectedTaskIds.contains(task.id));
                    } else {
                      if (MediaQuery.of(context).size.width > 900 &&
                          MediaQuery.of(context).size.width >
                              MediaQuery.of(context).size.height) {
                        setState(() {
                          _selectedTaskDesktop = task;
                          _isCreatingTaskDesktop = false;
                        });
                      } else {
                        _handleTaskTap(task);
                      }
                    }
                  },
                  onToggle: (task, isCompleted) {
                    if (_isSelectionMode) return;
                    _supabaseService.updateTaskFields(_userId, task.id, {
                      'completed': isCompleted,
                      'completedAt': isCompleted ? DateTime.now() : null,
                    }).then((_) {
                      if (task.journeyId != null &&
                          task.journeyId!.isNotEmpty) {
                        _supabaseService.updateGoalProgress(
                            _userId, task.journeyId!);
                      }
                    });
                  },
                  onSwipeLeft: _handleSwipeLeft,
                  onSwipeRight: _handleSwipeRight,
                  onRefresh: () async {
                    setState(() {});
                  },
                  onRescheduleDate: _rescheduleTaskToDate,
                ),
              ),
            ] else ...[
              Expanded(
                child: Row(
                  children: [
                    // List Pane (60%)
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.only(
                            left: 0.0, top: 0.0, bottom: 24.0, right: 0.0),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildToolbar(true, allTags, tasksToShow),
                            ),
                            Expanded(
                              child: TasksListView(
                                tasks: tasksToShow,
                                userData: widget.userData!,
                                emptyListMessage: emptyMsg,
                                emptyListSubMessage: emptySubMsg,
                                onRefresh: () async {
                                  setState(() {});
                                },
                                selectionMode: _isSelectionMode,
                                selectedTaskIds: _selectedTaskIds,
                                activeTaskId: _selectedTaskDesktop?.id,
                                onTaskSelected: _onTaskSelected,
                                onTaskTap: (task) {
                                  if (_isSelectionMode) {
                                    _onTaskSelected(task.id,
                                        !_selectedTaskIds.contains(task.id));
                                  } else {
                                    if (MediaQuery.of(context).size.width >
                                            900 &&
                                        MediaQuery.of(context).size.width >
                                            MediaQuery.of(context)
                                                .size
                                                .height) {
                                      setState(() {
                                        _selectedTaskDesktop = task;
                                        _isCreatingTaskDesktop = false;
                                      });
                                    } else {
                                      _handleTaskTap(task);
                                    }
                                  }
                                },
                                onToggle: (task, isCompleted) {
                                  if (_isSelectionMode) return;
                                  _supabaseService
                                      .updateTaskFields(_userId, task.id, {
                                    'completed': isCompleted,
                                    'completedAt':
                                        isCompleted ? DateTime.now() : null,
                                  }).then((_) {
                                    if (task.journeyId != null &&
                                        task.journeyId!.isNotEmpty) {
                                      _supabaseService.updateGoalProgress(
                                          _userId, task.journeyId!);
                                    }
                                  });
                                },
                                onSwipeLeft: _handleSwipeLeft,
                                onSwipeRight: _handleSwipeRight,
                                onRescheduleDate: _rescheduleTaskToDate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Detail/Input Pane (40%)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.only(
                            left: 0.0, top: 24.0, bottom: 24.0, right: 40.0),
                        child: _buildDesktopRightPane(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDesktopRightPane() {
    if (_isCreatingTaskDesktop) {
      // Cria uma tarefa "em branco" para o formulário
      final emptyTask = TaskModel(
        id: '',
        text: '',
        completed: false,
        createdAt: DateTime.now(),
      );

      return TaskDetailModal(
        task: emptyTask,
        userData: widget.userData!,
        isNew: true, // Indica modo de criação
        onClose: () {
          setState(() {
            _isCreatingTaskDesktop = false;
          });
        },
      );
    }

    if (_selectedTaskDesktop != null) {
      return TaskDetailModal(
        task: _selectedTaskDesktop!,
        userData: widget.userData!,
        onClose: () {
          setState(() {
            _selectedTaskDesktop = null;
          });
        },
        onReschedule: (date) =>
            _rescheduleTaskToDate(_selectedTaskDesktop!, date),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt_rounded,
              size: 64, color: AppColors.tertiaryText.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Selecione uma tarefa ou crie uma nova',
            style: TextStyle(
                color: AppColors.tertiaryText.withValues(alpha: 0.7),
                fontSize: 18),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openAddTaskModal,
            icon: const Icon(Icons.add),
            label: const Text('Nova Tarefa'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _rescheduleTaskToDate(TaskModel task, DateTime date) async {
    DateTime newDate = date;
    if (task.dueDate != null) {
      final old = task.dueDate!.toLocal();
      newDate = DateTime(date.year, date.month, date.day, old.hour, old.minute);
    } else {
      newDate = DateTime(date.year, date.month, date.day);
    }

    await _supabaseService.updateTaskFields(_userId, task.id, {
      'dueDate': newDate.toUtc().toIso8601String(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Tarefa reagendada com sucesso"),
          duration: Duration(seconds: 1)));
    }
  }
} // End of State class
