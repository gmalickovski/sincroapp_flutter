// lib/features/tasks/presentation/foco_do_dia_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/tasks_list_view.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:uuid/uuid.dart';
import 'widgets/task_input_modal.dart';
import 'widgets/task_detail_modal.dart';
import 'widgets/tag_selection_modal.dart';
import 'package:sincro_app_flutter/features/assistant/widgets/expanding_assistant_fab.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/assistant_panel.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';

// --- INÍCIO DA MUDANÇA: Importar o motor de numerologia ---
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/features/tasks/services/task_action_service.dart';
import 'widgets/task_filter_panel.dart';
import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart';
// --- FIM DA MUDANÇA ---

// --- INÍCIO DA MUDANÇA (Solicitação 2): Adicionado 'concluidas' ---
enum TaskViewScope { focoDoDia, todas, concluidas, atrasadas }
// --- FIM DA MUDANÇA ---

class FocoDoDiaScreen extends StatefulWidget {
  final UserModel? userData;
  const FocoDoDiaScreen({super.key, required this.userData});
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

  // --- INÍCIO DA MUDANÇA (Solicitação 1 & 3): Estados de seleção e filtro ---
  bool _isSelectionMode = false;
  Set<String> _selectedTaskIds = {};
  String? _selectedTag;
  // --- FIM DA MUDANÇA ---

  @override
  void initState() {
    super.initState();
    _userId = AuthRepository().currentUser?.id ?? '';
    if (_userId.isEmpty) {
      debugPrint("ERRO: FocoDoDiaScreen acessada sem usuário logado!");
    }
  }

  void _openAddTaskModal() {
    if (widget.userData == null || _userId.isEmpty) {
      _showErrorSnackbar('Erro: Não foi possível obter dados do usuário.');
      return;
    }

    // --- INÍCIO DA MUDANÇA (Solicitação 1): Cancela seleção ao abrir modal ---
    if (_isSelectionMode) {
      _clearSelection();
    }
    // --- FIM DA MUDANÇA ---

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData!,
        userId: _userId,
        // NÃO passa initialDueDate para que o pill de data não apareça
        // O modal vai calcular a vibração para "hoje" mas não mostra o pill
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

  // --- INÍCIO DA MUDANÇA: Função helper para calcular o Dia Pessoal ---
  /// Calcula o Dia Pessoal para uma data específica.
  /// Retorna null se os dados do usuário não estiverem disponíveis ou a data for nula.
  int? _calculatePersonalDay(DateTime? date) {
    if (widget.userData == null ||
        widget.userData!.dataNasc.isEmpty ||
        widget.userData!.nomeAnalise.isEmpty ||
        date == null) {
      return null; // Retorna nulo se não pode calcular
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
  // --- FIM DA MUDANÇA ---

  void _createSingleTask(ParsedTask parsedTask, {String? recurrenceId}) {
    // Garante que a data seja convertida para UTC
    DateTime? finalDueDateUtc;
    DateTime dateForPersonalDay;

    if (parsedTask.dueDate != null) {
      // Se tem data específica, usa ela
      final dateLocal = parsedTask.dueDate!.toLocal();
      finalDueDateUtc =
          DateTime.utc(dateLocal.year, dateLocal.month, dateLocal.day);
      dateForPersonalDay = finalDueDateUtc;
    } else {
      // Se não tem data específica, usa a data atual (não a de amanhã)
      final now = DateTime.now().toLocal();
      dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
      // NÃO define finalDueDateUtc - deixa null para tarefas sem data específica
    }

    // Calcula o dia pessoal usando a data determinada
    final int? finalPersonalDay = _calculatePersonalDay(dateForPersonalDay);

    final newTask = TaskModel(
      id: '',
      text: parsedTask.cleanText,
      createdAt: DateTime.now().toUtc(),
      dueDate: finalDueDateUtc,
      // --- INÍCIO DA MUDANÇA: Campos de Meta/Jornada (Já estavam corretos) ---
      journeyId: parsedTask.journeyId,
      journeyTitle: parsedTask.journeyTitle,
      // --- FIM DA MUDANÇA ---
      tags: parsedTask.tags,
      reminderTime: parsedTask.reminderTime,
      reminderAt: parsedTask.reminderAt,
      recurrenceType: parsedTask.recurrenceRule.type,
      recurrenceDaysOfWeek: parsedTask.recurrenceRule.daysOfWeek,
      recurrenceEndDate: parsedTask.recurrenceRule.endDate?.toUtc(),
      recurrenceId: recurrenceId,
      // --- INÍCIO DA MUDANÇA: Salvar o Dia Pessoal calculado ---
      personalDay: finalPersonalDay,
      // --- FIM DA MUDANÇA ---
    );

    _supabaseService.addTask(_userId, newTask).catchError((error) {
      _showErrorSnackbar("Erro ao salvar tarefa: $error");
    });
  }

  void _createRecurringTasks(ParsedTask parsedTask) {
    final String recurrenceId = _uuid.v4();
    final List<DateTime> dates = _calculateRecurrenceDates(
        parsedTask.recurrenceRule, parsedTask.dueDate);

    if (dates.isEmpty) {
      _showErrorSnackbar(
          "Nenhuma data futura encontrada para esta recorrência.");
      return;
    }

    // --- INÍCIO DA MUDANÇA: Usar o loop 'for' (do código comentado) ---
    // Isso garante que cada tarefa passe por _createSingleTask,
    // que agora calcula e salva o Dia Pessoal corretamente.
    // O Batch Write foi removido pois não tínhamos como injetar o cálculo do Dia Pessoal.
    for (final date in dates) {
      final taskForDate = parsedTask.copyWith(
        dueDate: date,
      );
      // Chamando _createSingleTask, que agora lida com o Dia Pessoal
      _createSingleTask(taskForDate, recurrenceId: recurrenceId);
    }

    // Sugestão para o usuário aguardar a criação
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Criando tarefas recorrentes...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  //
  // --- Nenhuma mudança nas funções de cálculo de recorrência ---
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
  // --- Fim das funções de cálculo de recorrência ---
  //

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _handleTaskTap(TaskModel task) {
    // --- INÍCIO DA MUDANÇA (Solicitação 1): Trava clique normal em modo de seleção ---
    if (_isSelectionMode) return;
    // --- FIM DA MUDANÇA ---

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
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  // Note: date comparisons now use explicit local-date logic where needed.

  // --- INÍCIO DA MUDANÇA (Solicitação 1): Métodos de gerenciamento de seleção ---

  /// Alterna o modo de seleção.
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTaskIds.clear();
      }
    });
  }

  /// Limpa a seleção e sai do modo de seleção.
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

  /// Seleciona todas as tarefas visíveis atualmente.
  void _selectAll(List<TaskModel> tasksToShow) {
    setState(() {
      if (_selectedTaskIds.length == tasksToShow.length) {
        // Se todos já estão selecionados, limpa
        _selectedTaskIds.clear();
      } else {
        // Senão, seleciona todos
        _selectedTaskIds = tasksToShow.map((t) => t.id).toSet();
      }
    });
  }

  /// Exibe um diálogo de confirmação e exclui as tarefas selecionadas.
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
            'Você tem certeza que deseja excluir permanentemente $count ${count == 1 ? 'tarefa' : 'tarefas'}?',
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
                    '$count ${count == 1 ? 'tarefa excluída' : 'tarefas excluídas'}.'),
                backgroundColor: Colors.green),
          );
          _clearSelection();
        }
      } catch (e) {
        _showErrorSnackbar("Erro ao excluir tarefas: $e");
      }
    }
  }
  // --- FIM DA MUDANÇA ---

  // --- INÍCIO DA MUDANÇA (Solicitação 2 & 3): Lógica de filtro atualizada ---
  List<TaskModel> _filterTasks(List<TaskModel> allTasks, int? userPersonalDay) {
    List<TaskModel> filteredTasks;

    // 1. SCOPE FILTERING (O que ver?)
    switch (_currentScope) {
      case TaskViewScope.focoDoDia:
        filteredTasks = _taskActionService.calculateFocusTasks(allTasks, userPersonalDay);
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
                if (widget.userData?.nomeAnalise.isNotEmpty == true && widget.userData?.dataNasc.isNotEmpty == true) {
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
      filteredTasks = filteredTasks.where((task) => task.tags.contains(_selectedTag)).toList();
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
  // --- FIM DA MUDANÇA ---

  // --- INÍCIO DA MUDANÇA (Swipe Actions) ---
  // Swipe Left: Excluir Tarefa
  Future<bool?> _handleSwipeLeft(TaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Excluir Tarefa?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Tem certeza que deseja excluir esta tarefa? Esta ação não pode ser desfeita.',
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
              content: Text('Tarefa excluída com sucesso'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return true; // Confirma a exclusão visual
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
      // Lógica de remoção visual baseada no filtro
      if (_currentScope == TaskViewScope.focoDoDia) {
        // Se estava no Foco do Dia (Hoje), e mudou a data (para Amanhã), remove.
        // Se era Atrasada e veio para Hoje, mantém (mas a lista deve atualizar via stream).
        // Como o reschedule sempre joga para o futuro (exceto atrasada -> hoje),
        // vamos simplificar: se a nova data NÃO é hoje, removemos da lista de "Hoje".
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
  // --- FIM DA MUDANÇA ---

  @override
  Widget build(BuildContext context) {
    if (widget.userData == null || _userId.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Erro: Dados do usuário não disponíveis.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 4.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [


                  Expanded(
                    child: StreamBuilder<List<TaskModel>>(
                      stream: _supabaseService.getTasksStream(_userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: _buildHeader(isMobile: isMobile, availableTags: []),
                              ),
                              const Expanded(child: Center(child: CustomLoadingSpinner())),
                            ],
                          );
                        }
                        if (snapshot.hasError) {
                          debugPrint(
                              "Erro no Stream de Tarefas: ${snapshot.error}");
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: _buildHeader(isMobile: isMobile, availableTags: []),
                              ),
                              Expanded(
                                child: Center(
                                    child: Text(
                                        'Erro ao carregar tarefas: ${snapshot.error}')),
                              ),
                            ],
                          );
                        }

                        final allTasks = snapshot.data ?? [];

                        // --- INÍCIO DA MUDANÇA (Solicitação 3): Extração de Tags ---
                        // Extrai tags dinamicamente da lista de tarefas pendentes
                        final allTags = allTasks
                            .where((task) => !task.completed)
                            .expand((task) => task.tags)
                            .toSet()
                            .toList();
                        allTags.sort(); // Ordena alfabeticamente

                        int? personalDay;
                        if (widget.userData?.nomeAnalise.isNotEmpty == true && widget.userData?.dataNasc.isNotEmpty == true) {
                             final engine = NumerologyEngine(
                                  nomeCompleto: widget.userData!.nomeAnalise,
                                  dataNascimento: widget.userData!.dataNasc,
                               );
                             personalDay = engine.calculatePersonalDayForDate(DateTime.now());
                        }
                        final tasksToShow = _filterTasks(allTasks, personalDay);
                        // --- FIM DA MUDANÇA ---

                        // Lógica de mensagens de "lista vazia" (atualizada)
                        String emptyMsg = 'Tudo limpo por aqui!';
                        String emptySubMsg = 'Nenhuma tarefa encontrada.';

                        if (_currentScope == TaskViewScope.focoDoDia &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Foco do dia concluído!';
                          emptySubMsg =
                              'Você não tem tarefas pendentes para hoje.';
                        } else if (_currentScope == TaskViewScope.todas &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Caixa de entrada vazia!';
                          emptySubMsg = 'Você não tem nenhuma tarefa pendente.';
                        } else if (_currentScope ==
                                TaskViewScope.concluidas &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Nenhuma tarefa concluída.';
                          emptySubMsg = 'Complete tarefas para vê-las aqui.';
                        } else if (_currentScope == TaskViewScope.atrasadas &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Nenhuma tarefa atrasada.';
                          emptySubMsg = 'Parabéns! Você está em dia com suas tarefas.';
                        }


                        // Se um filtro de tag estiver ativo e a lista vazia
                        if (_selectedTag != null &&
                            tasksToShow.isEmpty &&
                            _currentScope != TaskViewScope.concluidas) {
                          emptyMsg = 'Nenhuma tarefa encontrada.';
                          emptySubMsg =
                              'Não há tarefas pendentes com a tag "$_selectedTag".';
                        }

                        return Column(
                          children: [
                             // Header (título e filtros principais) - Moved inside to access allTags
                             Padding(
                               padding: const EdgeInsets.symmetric(horizontal: 8.0),
                               child: _buildHeader(isMobile: isMobile, availableTags: allTags),
                             ),


                            // 2. Controles de Seleção (nova UI)
                            // Sempre mostrar os controles de seleção, independente do filtro
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: _buildSelectionControls(tasksToShow),
                            ),
                            // --- FIM DA MUDANÇA ---

                            Expanded(
                              child: TasksListView(
                                tasks: tasksToShow,
                                userData: widget.userData,
                                emptyListMessage: emptyMsg,
                                emptyListSubMessage: emptySubMsg,
                                // --- INÍCIO DA MUDANÇA (Solicitação 1): Passa parâmetros ---
                                selectionMode: _isSelectionMode,
                                selectedTaskIds: _selectedTaskIds,
                                onTaskSelected:
                                    _onTaskSelected, // A tela de Foco *passa* a função
                                onTaskTap: (task) {
                                  // Lógica de toque principal
                                  if (_isSelectionMode) {
                                    _onTaskSelected(task.id,
                                        !_selectedTaskIds.contains(task.id));
                                  } else {
                                    _handleTaskTap(task); // Abre detalhes
                                  }
                                },
                                // --- FIM DA MUDANÇA ---
                                onToggle: (task, isCompleted) {
                                  // Desabilita o toggle de conclusão durante o modo de seleção
                                  if (_isSelectionMode) return;

                                  _supabaseService.updateTaskFields(
                                    _userId,
                                    task.id,
                                    {
                                      'completed': isCompleted,
                                      'completedAt': isCompleted ? DateTime.now() : null,
                                    },
                                  ).then((_) {
                                    if (task.journeyId != null &&
                                        task.journeyId!.isNotEmpty) {
                                      _supabaseService.updateGoalProgress(
                                          _userId, task.journeyId!);
                                    }
                                  }).catchError((error) {
                                    _showErrorSnackbar(
                                        "Erro ao atualizar tarefa: $error");
                                  });
                                },
                                // Callbacks de Swipe
                                onSwipeLeft: _handleSwipeLeft,
                                onSwipeRight: _handleSwipeRight,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // --- INÍCIO DA MUDANÇA (Solicitação 1): Esconde FAB em modo de seleção ---
      floatingActionButton: _isSelectionMode
          ? null
          : (widget.userData != null &&
                  widget.userData!.subscription.isActive &&
                  widget.userData!.subscription.plan ==
                      SubscriptionPlan.premium)
              ? ExpandingAssistantFab(
                  onPrimary: _openAddTaskModal,
                  primaryIcon: Icons.add_task,
                  primaryTooltip: 'Nova Tarefa',
                  onOpenAssistant: (message) =>
                      AssistantPanel.show(context, widget.userData!, initialMessage: message),
                )
              : FloatingActionButton(
                  onPressed: _openAddTaskModal,
                  backgroundColor: AppColors.primary,
                  tooltip: 'Adicionar Tarefa',
                  heroTag: 'foco_fab',
                  child: const Icon(Icons.add, color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
      // --- FIM DA MUDANÇA ---
    );
  }

  // _buildHeader (original) MODIFICADO para (Solicitação 1 e 3)
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

  Widget _buildHeader({required bool isMobile, required List<String> availableTags}) {
    final double titleFontSize = isMobile ? 28 : 32;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tarefas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold)),
            
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
                    color: _isFilterActive ? AppColors.primary : AppColors.secondaryText,
                  ),
                  tooltip: 'Filtros',
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: _isFilterActive ? AppColors.primary : AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (_isFilterActive) 
           Padding(
             padding: const EdgeInsets.only(bottom: 16),
             child: Wrap(
               spacing: 8,
               children: [
                 ActionChip(
                   avatar: const Icon(Icons.clear, size: 16, color: Colors.white),
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
                     Chip(label: Text(_getScopeLabel(_currentScope)), backgroundColor: AppColors.cardBackground, side: BorderSide.none),
                  if (_selectedDate != null)
                     Chip(label: Text(DateFormat('dd/MM').format(_selectedDate!)), backgroundColor: AppColors.cardBackground, side: BorderSide.none),
                  if (_selectedVibrationNumber != null)
                     Chip(label: Text('Dia Pessoal $_selectedVibrationNumber'), backgroundColor: AppColors.cardBackground, side: BorderSide.none),
                  if (_selectedTag != null)
                     Chip(label: Text('#$_selectedTag'), backgroundColor: AppColors.cardBackground, side: BorderSide.none),
               ],
             ),
           ),

         const Divider(color: AppColors.border, height: 1),
       ],
     );
   }
   
   String _getScopeLabel(TaskViewScope type) {
     switch (type) {
       case TaskViewScope.focoDoDia: return 'Foco do Dia';
       case TaskViewScope.todas: return 'Todas';
       case TaskViewScope.concluidas: return 'Concluídas';
       case TaskViewScope.atrasadas: return 'Atrasadas';
     }
   }


  // --- INÍCIO DA MUDANÇA (Solicitação 1 & 3): Widgets de UI refatorados ---



  /// Constrói o botão de seleção de tarefas
  Widget _buildSelectionButton() {
    return IconButton(
      onPressed: _toggleSelectionMode,
      icon: Icon(
          _isSelectionMode ? Icons.close : Icons.checklist_rounded, 
          color: _isSelectionMode ? Colors.white : AppColors.secondaryText
      ),
      tooltip: _isSelectionMode ? 'Cancelar Seleção' : 'Selecionar Tarefas',
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(8),
           side: BorderSide(color: _isSelectionMode ? Colors.white : AppColors.border),
        ),
      ),
    );
  }

  /// (Solicitação 1 - Nova UI) Constrói os controles de seleção
  Widget _buildSelectionControls(List<TaskModel> tasksToShow) {
    // Se estiver no modo de seleção
    if (_isSelectionMode) {
      final int count = _selectedTaskIds.length;
      final bool allSelected =
          tasksToShow.isNotEmpty && count == tasksToShow.length;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween, // Garante separação
          children: [
            // Botão Excluir (Lado Esquerdo)
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

            // Controles do Lado Direito
            Flexible(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.end, // Alinha controles à direita
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: tasksToShow.isEmpty
                        ? null
                        : (value) => _selectAll(tasksToShow),
                    visualDensity: VisualDensity.compact, // Reduz o padding
                    checkColor: Colors.white,
                    activeColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border, width: 2),
                  ),
                  // Envolve o InkWell/Texto em Flexible
                  Flexible(
                    child: InkWell(
                      onTap: tasksToShow.isEmpty
                          ? null
                          : () => _selectAll(tasksToShow),
                      child: const Text(
                        'Selecionar Todas',
                        style: TextStyle(color: AppColors.secondaryText),
                        overflow: TextOverflow
                            .ellipsis, // Corta o texto se for muito longo
                        softWrap: false,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: _clearSelection,
                    tooltip: 'Cancelar seleção',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Modo Padrão (Botão para ativar seleção)
    // Não mostrar o botão se não houver tarefas para selecionar
    if (tasksToShow.isEmpty) {
      return const SizedBox(height: 8); // Apenas padding
    }

    // The selection toggle was moved to the header next to the filters.
    // Keep a small spacer here so layout remains consistent.
    return const SizedBox(height: 8);
  }
}
bool isSameDay(DateTime? a, DateTime? b) { if (a == null || b == null) return false; return a.year == b.year && a.month == b.month && a.day == b.day; }
