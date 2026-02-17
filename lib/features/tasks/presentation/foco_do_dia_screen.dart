// lib/features/tasks/presentation/foco_do_dia_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
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
import 'package:sincro_app_flutter/features/tasks/services/task_action_service.dart';
import 'widgets/task_filter_panel.dart';
import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart';
// --- FIM DA MUDANÃ‡A ---

// --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 2): Adicionado 'concluidas' ---
enum TaskViewScope { focoDoDia, todas, concluidas, atrasadas }
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

  TaskViewScope _currentScope = TaskViewScope.todas;
  DateTime? _selectedDate; // NOVO: Filtro de data
  int? _selectedVibrationNumber;
  final List<int> _vibrationNumbers = List.generate(9, (i) => i + 1) + [11, 22];

  // Stream to prevent rebuilds
  late Stream<List<TaskModel>> _tasksStream;

  // --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 1 & 3): Estados de seleÃ§Ã£o e filtro ---
  bool _isSelectionMode = false;
  Set<String> _selectedTaskIds = {};
  String? _selectedTag;
  // --- FIM DA MUDANÃ‡A ---

  // Desktop Split View State
  TaskModel? _selectedTaskDesktop;
  bool _isCreatingTaskDesktop = false;

  @override
  void initState() {
    super.initState();
    _userId = AuthRepository().currentUser?.id ?? '';
    if (_userId.isNotEmpty) {
      _tasksStream = _supabaseService.getTasksStream(_userId);
    }
    if (_userId.isEmpty) {
      debugPrint("ERRO: FocoDoDiaScreen acessada sem usuÃ¡rio logado!");
    }

    // Configurar filtro inicial baseado no parametro
    if (widget.initialFilter == 'overdue') {
      _currentScope = TaskViewScope.atrasadas;
    } else if (widget.initialFilter == 'today') {
      _currentScope = TaskViewScope.focoDoDia;
    }
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

    if (MediaQuery.of(context).size.width > 900) {
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskDetailModal(
            task: task,
            userData: widget.userData!,
            onReschedule: (date) => _rescheduleTaskToDate(task, date),
          ),
          fullscreenDialog: true,
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
        }
      } catch (e) {
        _showErrorSnackbar("Erro ao excluir tarefas: $e");
      }
    }
  }
  // --- FIM DA MUDANÃ‡A ---

  // --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 2 & 3): LÃ³gica de filtro atualizada ---
  List<TaskModel> _filterTasks(List<TaskModel> allTasks, int? userPersonalDay) {
    List<TaskModel> filteredTasks;

    // 1. SCOPE FILTERING (O que ver?)
    switch (_currentScope) {
      case TaskViewScope.focoDoDia:
        filteredTasks =
            _taskActionService.calculateFocusTasks(allTasks, userPersonalDay);
        break;
      case TaskViewScope.concluidas:
        filteredTasks = allTasks.where((task) => task.completed).toList();
        break;
      case TaskViewScope.atrasadas:
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        filteredTasks = allTasks.where((task) {
          if (task.completed) return false;
          if (task.dueDate == null) return false;
          return task.dueDate!.isBefore(todayStart);
        }).toList();
        break;
      case TaskViewScope.todas:
      default:
        // 'Todas' excludes completed by default unless explicitly asked?
        // Usually 'Todas' means 'Active Tasks'.
        // If users want completed, they go to 'Concluidas'.
        filteredTasks = allTasks.where((task) => !task.completed).toList();
        break;
    }

    // 2. REFINEMENT FILTERING (Refinar por...)

    // Date Filter
    if (_selectedDate != null) {
      filteredTasks = filteredTasks.where((task) {
        if (task.dueDate == null) return false;
        return isSameDay(task.dueDate!, _selectedDate!);
      }).toList();
    }

    // Vibration Filter
    if (_selectedVibrationNumber != null) {
      // Assuming vibration calculation happens or is stored
      // For now, filtering by date's vibration if applicable or task property?
      // TaskModel doesn't have vibration?
      // Usually vibration implies filtering tasks that MATCH a date with that vibration?
      // Or filtering users who matched?
      // Let's assume the previous logic: Filter tasks falling on dates that have this personal day.
      if (widget.userData != null) {
        filteredTasks = filteredTasks.where((task) {
          if (task.dueDate == null) return false;
          // Calculate PD for the task date
          // This acts as "Tasks that are good for vibration X"
          // Reusing helper if possible or simple calc
          // Calculate PD for the task date
          // This acts as "Tasks that are good for vibration X"
          // Reusing helper if possible or simple calc
          int? pd;
          if (widget.userData?.nomeAnalise.isNotEmpty == true &&
              widget.userData?.dataNasc.isNotEmpty == true) {
            final engine = NumerologyEngine(
              nomeCompleto: widget.userData!.nomeAnalise,
              dataNascimento: widget.userData!.dataNasc,
            );
            pd = engine.calculatePersonalDayForDate(task.dueDate!);
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

    // Sorting (Default: by Date)
    filteredTasks.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
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

  // Swipe Right: Reagendar (Usando TaskActionService)
  Future<bool?> _handleSwipeRight(TaskModel task) async {
    if (widget.userData == null) return false;

    final newDate = await _taskActionService.rescheduleTask(
      context,
      task,
      widget.userData!,
    );

    if (newDate != null) {
      // LÃ³gica de remoÃ§Ã£o visual baseada no filtro
      if (_currentScope == TaskViewScope.focoDoDia) {
        // Se estava no Foco do Dia (Hoje), e mudou a data (para AmanhÃ£), remove.
        // Se era Atrasada e veio para Hoje, mantÃ©m (mas a lista deve atualizar via stream).
        // Como o reschedule sempre joga para o futuro (exceto atrasada -> hoje),
        // vamos simplificar: se a nova data NÃƒO Ã© hoje, removemos da lista de "Hoje".
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final newDateOnly = DateTime(newDate.year, newDate.month, newDate.day);

        if (!newDateOnly.isAtSameMomentAs(today)) {
          return true; // Remove visualmente
        }
      } else if (_currentScope == TaskViewScope.atrasadas) {
        // Se estava em Atrasadas e foi reagendada (para Hoje ou Futuro), sai da lista de Atrasadas.
        return true;
      }
    }
    return false; // Deixa o StreamBuilder atualizar
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

    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
    return _currentScope != TaskViewScope.todas ||
        _selectedDate != null ||
        _selectedVibrationNumber != null ||
        _selectedTag != null;
  }

  void _openFilterUI(List<String> availableTags) {
    showSmartPopup(
      context: _filterButtonKey.currentContext!,
      builder: (context) => TaskFilterPanel(
        initialScope: _currentScope,
        initialDate: _selectedDate,
        initialVibration: _selectedVibrationNumber,
        initialTag: _selectedTag,
        availableTags: availableTags,
        userData: widget.userData,
        onApply: (scope, date, vibration, tag) {
          setState(() {
            _currentScope = scope;
            _selectedDate = date;
            _selectedVibrationNumber = vibration;
            _selectedTag = tag;
            _clearSelection();
          });
          Navigator.pop(context);
        },
        onClearInPanel: () {
          setState(() {
            _currentScope = TaskViewScope.todas;
            _selectedDate = null;
            _selectedVibrationNumber = null;
            _selectedTag = null;
          });
        },
      ),
    );
  }

  Widget _buildHeader(
      {required bool isMobile, required List<String> availableTags}) {
    final double titleFontSize = isMobile ? 28 : 32;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title + Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tarefas',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold)),
                ],
              ),

              // Buttons Row: Selection + Filters
              Row(
                children: [
                  _buildSelectionButton(),
                  const SizedBox(width: 8),
                  IconButton(
                    key: _filterButtonKey,
                    onPressed: () => _openFilterUI(availableTags),
                    icon: Icon(
                      Icons.filter_alt_outlined,
                      color: _isFilterActive
                          ? AppColors.primary
                          : AppColors.secondaryText,
                    ),
                    tooltip: 'Filtros',
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                            color: _isFilterActive
                                ? AppColors.primary
                                : AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_isFilterActive)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar:
                      const Icon(Icons.clear, size: 16, color: Colors.white),
                  label: const Text('Limpar Filtros'),
                  labelStyle: const TextStyle(color: Colors.white),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  onPressed: () {
                    setState(() {
                      _currentScope = TaskViewScope.todas;
                      _selectedDate = null;
                      _selectedVibrationNumber = null;
                      _selectedTag = null;
                    });
                  },
                  side: BorderSide.none,
                ),
                // Show what is active
                if (_currentScope != TaskViewScope.todas)
                  Chip(
                      label: Text(_getScopeLabel(_currentScope)),
                      backgroundColor: AppColors.cardBackground,
                      side: BorderSide.none),
                if (_selectedDate != null)
                  Chip(
                      label: Text(DateFormat('dd/MM').format(_selectedDate!)),
                      backgroundColor: AppColors.cardBackground,
                      side: BorderSide.none),
                if (_selectedVibrationNumber != null)
                  Chip(
                      label: Text('Dia Pessoal $_selectedVibrationNumber'),
                      backgroundColor: AppColors.cardBackground,
                      side: BorderSide.none),
                if (_selectedTag != null)
                  Chip(
                      label: Text('#$_selectedTag'),
                      backgroundColor: AppColors.cardBackground,
                      side: BorderSide.none),
              ],
            ),
          ),
        const Divider(color: AppColors.border, height: 1),
      ],
    );
  }

  String _getScopeLabel(TaskViewScope type) {
    switch (type) {
      case TaskViewScope.focoDoDia:
        return 'Foco do Dia';
      case TaskViewScope.todas:
        return 'Todas';
      case TaskViewScope.concluidas:
        return 'ConcluÃ­das';
      case TaskViewScope.atrasadas:
        return 'Atrasadas';
    }
  }

  // --- INÃCIO DA MUDANÃ‡A (SolicitaÃ§Ã£o 1 & 3): Widgets de UI refatorados ---

  /// ConstrÃ³i o botÃ£o de seleÃ§Ã£o de tarefas
  Widget _buildSelectionButton() {
    return IconButton(
      onPressed: _toggleSelectionMode,
      icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist_rounded,
          color: _isSelectionMode ? Colors.white : AppColors.secondaryText),
      tooltip: _isSelectionMode ? 'Cancelar SeleÃ§Ã£o' : 'Selecionar Tarefas',
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: _isSelectionMode ? Colors.white : AppColors.border),
        ),
      ),
    );
  }

  /// (SolicitaÃ§Ã£o 1 - Nova UI) ConstrÃ³i os controles de seleÃ§Ã£o
  Widget _buildSelectionControls(List<TaskModel> tasksToShow) {
    // Se estiver no modo de seleÃ§Ã£o
    if (_isSelectionMode) {
      final int count = _selectedTaskIds.length;
      final bool allSelected =
          tasksToShow.isNotEmpty && count == tasksToShow.length;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            // 1. Selecionar Todas (Primeiro, Esquerda)
            Transform.scale(
              scale: 0.9,
              child: Checkbox(
                value: allSelected,
                onChanged: tasksToShow.isEmpty
                    ? null
                    : (value) => _selectAll(tasksToShow),
                visualDensity: VisualDensity.compact,
                checkColor: Colors.white,
                activeColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border, width: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            InkWell(
              onTap: tasksToShow.isEmpty ? null : () => _selectAll(tasksToShow),
              child: const Text(
                'Selecionar Todas',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),

            const SizedBox(width: 16),

            // 2. Excluir (Segundo, Logo apÃ³s)
            TextButton.icon(
              icon: Icon(Icons.delete_outline_rounded,
                  color: count > 0 ? Colors.redAccent : AppColors.tertiaryText),
              label: Text('Excluir ($count)',
                  style: TextStyle(
                      color: count > 0
                          ? Colors.redAccent
                          : AppColors.tertiaryText)),
              onPressed: count > 0 ? _deleteSelectedTasks : null,
            ),

            const Spacer(),

            // 3. Fechar (Direita)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: _clearSelection,
              tooltip: 'Cancelar seleÃ§Ã£o',
            ),
          ],
        ),
      );
    }

    // Modo PadrÃ£o (BotÃ£o para ativar seleÃ§Ã£o)
    // NÃ£o mostrar o botÃ£o se nÃ£o houver tarefas para selecionar
    if (tasksToShow.isEmpty) {
      return const SizedBox(height: 8); // Apenas padding
    }

    // The selection toggle was moved to the header next to the filters.
    // Keep a small spacer here so layout remains consistent.
    return const SizedBox(height: 8);
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
        if (_currentScope == TaskViewScope.focoDoDia) {
          userPersonalDay = _calculatePersonalDay(DateTime.now());
        }
        final tasksToShow = _filterTasks(tasks, userPersonalDay);

        // Empty state logic
        String emptyMsg = 'Tudo limpo por aqui!';
        String emptySubMsg = 'VocÃª nÃ£o tem tarefas pendentes.';

        if (_currentScope == TaskViewScope.focoDoDia && tasksToShow.isEmpty) {
          emptyMsg = 'Foco do dia concluÃ­do!';
          emptySubMsg = 'VocÃª nÃ£o tem tarefas pendentes para hoje.';
        } else if (_currentScope == TaskViewScope.todas &&
            tasksToShow.isEmpty) {
          emptyMsg = 'Caixa de entrada vazia!';
          emptySubMsg = 'VocÃª nÃ£o tem nenhuma tarefa pendente.';
        } else if (_currentScope == TaskViewScope.concluidas &&
            tasksToShow.isEmpty) {
          emptyMsg = 'Nenhuma tarefa concluÃ­da.';
          emptySubMsg = 'Complete tarefas para vÃª-las aqui.';
        } else if (_currentScope == TaskViewScope.atrasadas &&
            tasksToShow.isEmpty) {
          emptyMsg = 'Nenhuma tarefa atrasada.';
          emptySubMsg = 'ParabÃ©ns! VocÃª estÃ¡ em dia com suas tarefas.';
        }

        // Se um filtro de tag estiver ativo e a lista vazia
        if (_selectedTag != null &&
            tasksToShow.isEmpty &&
            _currentScope != TaskViewScope.concluidas) {
          emptyMsg = 'Nenhuma tarefa encontrada.';
          emptySubMsg = 'NÃ£o hÃ¡ tarefas pendentes com a tag "$_selectedTag".';
        }

        return Column(
          children: [
            if (isMobile) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildHeader(isMobile: isMobile, availableTags: allTags),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSelectionControls(tasksToShow),
              ),
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
                      if (MediaQuery.of(context).size.width > 900) {
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
                            left: 24.0, top: 0.0, bottom: 24.0, right: 12.0),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildHeader(
                                  isMobile: false, availableTags: allTags),
                            ),
                            if (_isSelectionMode)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: _buildSelectionControls(tasksToShow),
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
                                        900) {
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
                            left: 12.0, top: 24.0, bottom: 24.0, right: 24.0),
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
              size: 64, color: AppColors.tertiaryText.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Selecione uma tarefa ou crie uma nova',
            style: TextStyle(
                color: AppColors.tertiaryText.withOpacity(0.7), fontSize: 18),
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
