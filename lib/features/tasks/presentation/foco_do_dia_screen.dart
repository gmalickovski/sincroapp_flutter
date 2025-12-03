// lib/features/tasks/presentation/foco_do_dia_screen.dart
import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/tasks_list_view.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/common/widgets/custom_recurrence_picker_modal.dart';
import 'package:uuid/uuid.dart';
import 'widgets/task_input_modal.dart';
import 'widgets/task_detail_modal.dart';
import 'widgets/tag_selection_modal.dart';
import 'package:sincro_app_flutter/features/assistant/widgets/expanding_assistant_fab.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/assistant_panel.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';

// --- INÍCIO DA MUDANÇA: Importar o motor de numerologia ---
import 'package:sincro_app_flutter/services/numerology_engine.dart';
// --- FIM DA MUDANÇA ---

// --- INÍCIO DA MUDANÇA (Solicitação 2): Adicionado 'concluidas' ---
enum TaskFilterType { focoDoDia, todas, vibracao, concluidas, atrasadas }
// --- FIM DA MUDANÇA ---

class FocoDoDiaScreen extends StatefulWidget {
  final UserModel? userData;
  const FocoDoDiaScreen({super.key, required this.userData});
  @override
  State<FocoDoDiaScreen> createState() => _FocoDoDiaScreenState();
}

class _FocoDoDiaScreenState extends State<FocoDoDiaScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late final String _userId;
  final Uuid _uuid = const Uuid();

  TaskFilterType _selectedFilter = TaskFilterType.focoDoDia;
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
    _userId = AuthRepository().getCurrentUser()?.uid ?? '';
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
      recurrenceType: parsedTask.recurrenceRule.type,
      recurrenceDaysOfWeek: parsedTask.recurrenceRule.daysOfWeek,
      recurrenceEndDate: parsedTask.recurrenceRule.endDate?.toUtc(),
      recurrenceId: recurrenceId,
      // --- INÍCIO DA MUDANÇA: Salvar o Dia Pessoal calculado ---
      personalDay: finalPersonalDay,
      // --- FIM DA MUDANÇA ---
    );

    _firestoreService.addTask(_userId, newTask).catchError((error) {
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
        await _firestoreService.deleteTasks(_userId, _selectedTaskIds.toList());
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
  List<TaskModel> _filterTasks(List<TaskModel> allTasks) {
    List<TaskModel> baseTasks;

    // 1. Filtro Principal (Foco, Todas, Vibração, Concluídas)
    switch (_selectedFilter) {
      case TaskFilterType.focoDoDia:
        // Show only tasks for TODAY (local date) and that match today's
        // personal day. If user data is missing (can't compute personal day),
        // fall back to date-only matching.
        final nowLocal = DateTime.now().toLocal();
        final todayLocal =
            DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

        final int? todayPersonal = _calculatePersonalDay(todayLocal);

        DateTime? localDateOnly(DateTime? d) {
          if (d == null) return null;
          final dl = d.toLocal();
          return DateTime(dl.year, dl.month, dl.day);
        }

        baseTasks = allTasks.where((task) {
          if (task.completed) return false;

          // --- INÍCIO DA MUDANÇA (Solicitação 2): Incluir Atrasadas no Foco do Dia ---
          if (task.isOverdue) return true;
          // --- FIM DA MUDANÇA ---

          final DateTime taskDate = task.dueDate ?? task.createdAt;
          final taskDateOnly = localDateOnly(taskDate);
          if (taskDateOnly == null) return false;

          // Date must match local today
          if (!(taskDateOnly.year == todayLocal.year &&
              taskDateOnly.month == todayLocal.month &&
              taskDateOnly.day == todayLocal.day)) {
            return false;
          }

          // If we can compute today's personal day, require task's personal day
          // to match. Use saved value if available, otherwise compute from date.
          if (todayPersonal == null) {
            return true; // fallback to date-only
          }

          final int taskPersonal =
              task.personalDay ?? _calculatePersonalDay(taskDateOnly) ?? -1;
          return taskPersonal == todayPersonal;
        }).toList();
        break;

      case TaskFilterType.vibracao:
        if (_selectedVibrationNumber == null) {
          baseTasks = [];
        } else {
          baseTasks = allTasks.where((task) {
            return !task.completed && // <-- Apenas pendentes
                task.personalDay == _selectedVibrationNumber;
          }).toList();
        }
        break;

      case TaskFilterType.concluidas:
        // Novo filtro: mostra apenas tarefas concluídas
        baseTasks = allTasks.where((task) => task.completed).toList();

        // Ordena tarefas concluídas por data de conclusão/criação
        baseTasks.sort((a, b) {
          final aDate = a.completedAt ?? a.createdAt;
          final bDate = b.completedAt ?? b.createdAt;
          return bDate.compareTo(aDate); // Mais recentes primeiro
        });
        // --- FIM DA CORREÇÃO ---
        break;

      case TaskFilterType.atrasadas:
        baseTasks = allTasks.where((task) => !task.completed && task.isOverdue).toList();
        break;

      case TaskFilterType.todas:
        // Filtro "Todas" agora significa "Todas as Pendentes"
        baseTasks = allTasks.where((task) => !task.completed).toList();
        break;
    }

    // 2. Filtro Secundário (Tag)
    // Não aplica filtro de tag se estivermos vendo as concluídas
    if (_selectedTag != null && _selectedFilter != TaskFilterType.concluidas) {
      baseTasks =
          baseTasks.where((task) => task.tags.contains(_selectedTag!)).toList();
    }

    return baseTasks;
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
        await _firestoreService.deleteTask(_userId, task.id);
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

  // Swipe Right: Reagendar para Amanhã
  Future<bool?> _handleSwipeRight(TaskModel task) async {
    try {
      // Calcula a data de amanhã
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final tomorrowUtc = tomorrow.toUtc();

      // Atualiza a tarefa
      await _firestoreService.updateTask(
        _userId,
        task.id,
        dueDate: tomorrowUtc,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarefa adiada para amanhã! 📅'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Se o filtro for "Foco do Dia" ou "Atrasadas", a tarefa deve sair da lista
      // Se for "Todas", ela apenas muda a data, mas continua na lista (talvez reordenada)
      // Para UX consistente, vamos retornar true se ela não pertencer mais ao filtro atual
      if (_selectedFilter == TaskFilterType.focoDoDia ||
          _selectedFilter == TaskFilterType.atrasadas) {
        return true;
      }
      return false; // Mantém na lista (Stream atualizará os dados)
    } catch (e) {
      debugPrint("Erro ao reagendar tarefa: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reagendar tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
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
                  // Header (título e filtros principais)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _buildHeader(isMobile: isMobile),
                  ),

                  Expanded(
                    child: StreamBuilder<List<TaskModel>>(
                      stream: _firestoreService.getTasksStream(_userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(child: CustomLoadingSpinner());
                        }
                        if (snapshot.hasError) {
                          debugPrint(
                              "Erro no Stream de Tarefas: ${snapshot.error}");
                          return Center(
                              child: Text(
                                  'Erro ao carregar tarefas: ${snapshot.error}'));
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

                        final tasksToShow = _filterTasks(allTasks);
                        // --- FIM DA MUDANÇA ---

                        // Lógica de mensagens de "lista vazia" (atualizada)
                        String emptyMsg = 'Tudo limpo por aqui!';
                        String emptySubMsg = 'Nenhuma tarefa encontrada.';

                        if (_selectedFilter == TaskFilterType.focoDoDia &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Foco do dia concluído!';
                          emptySubMsg =
                              'Você não tem tarefas pendentes para hoje.';
                        } else if (_selectedFilter == TaskFilterType.vibracao &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Nenhuma tarefa encontrada.';
                          emptySubMsg = _selectedVibrationNumber != null
                              ? 'Não há tarefas pendentes para o dia pessoal $_selectedVibrationNumber.'
                              : 'Selecione um número de dia pessoal acima.';
                        } else if (_selectedFilter == TaskFilterType.todas &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Caixa de entrada vazia!';
                          emptySubMsg = 'Você não tem nenhuma tarefa pendente.';
                        } else if (_selectedFilter ==
                                TaskFilterType.concluidas &&
                            tasksToShow.isEmpty) {
                          emptyMsg = 'Nenhuma tarefa concluída.';
                          emptySubMsg = 'Complete tarefas para vê-las aqui.';
                        }

                        // Se um filtro de tag estiver ativo e a lista vazia
                        if (_selectedTag != null &&
                            tasksToShow.isEmpty &&
                            _selectedFilter != TaskFilterType.concluidas) {
                          emptyMsg = 'Nenhuma tarefa encontrada.';
                          emptySubMsg =
                              'Não há tarefas pendentes com a tag "$_selectedTag".';
                        }

                        return Column(
                          children: [
                            // --- INÍCIO DA MUDANÇA (Solicitação 1 & 3): Barras Dinâmicas ---
                            // 1. Filtros de Tag (só aparece se não estiver selecionando)
                            if (!_isSelectionMode)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: _buildTagFilters(allTags,
                                    isMobile: isMobile),
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

                                  _firestoreService
                                      .updateTaskCompletion(
                                    _userId,
                                    task.id,
                                    completed: isCompleted,
                                  )
                                      .then((_) {
                                    if (task.journeyId != null &&
                                        task.journeyId!.isNotEmpty) {
                                      _firestoreService.updateGoalProgress(
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
                ),
      // --- FIM DA MUDANÇA ---
    );
  }

  // _buildHeader (original) MODIFICADO para (Solicitação 1 e 3)
  Widget _buildHeader({required bool isMobile}) {
    final double titleFontSize = isMobile ? 28 : 32;
    // --- INÍCIO DA CORREÇÃO (Problema 2) ---
    // Padronizando o espaçamento
    const double chipSpacing = 8.0;
    // --- FIM DA CORREÇÃO ---

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          // --- INÍCIO DA MUDANÇA (Solicitação 1): Botão de Seleção REMOVIDO ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tarefas',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold)),
              // O botão de seleção foi MOVIDO para _buildSelectionControls
            ],
          ),
          // --- FIM DA MUDANÇA ---
          const SizedBox(height: 16),

          // Linha 1: Filtros principais
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // --- INÍCIO DA CORREÇÃO (Problema 2) ---
                // 'Wrap' removido, 'Row' agora contém os filhos diretamente
                // com espaçamento consistente
                // --- FIM DA CORREÇÃO ---
                ...TaskFilterType.values.map((filterType) {
                  String label;
                  late IconData icon;
                  switch (filterType) {
                    case TaskFilterType.focoDoDia:
                      label = 'Foco do Dia';
                      icon = Icons.star_border_rounded;
                      break;
                    case TaskFilterType.todas:
                      label = 'Todas';
                      icon = Icons.inbox_rounded;
                      break;
                    case TaskFilterType.vibracao:
                      label = 'Dia Pessoal';
                      icon = Icons.wb_sunny_rounded;
                      break;
                    case TaskFilterType.concluidas:
                      label = 'Concluídas';
                      icon = Icons.check_circle_outline_rounded;
                      break;
                    case TaskFilterType.atrasadas:
                      label = 'Atrasadas';
                      icon = Icons.warning_amber_rounded;
                      break;
                  }

                  final isSelected = _selectedFilter == filterType;

                  return Padding(
                    padding: const EdgeInsets.only(
                        right: chipSpacing), // Espaçamento
                    child: ChoiceChip(
                      label: Text(label,
                          style: const TextStyle(
                              fontSize: 14)), // Consistent text size
                      avatar: Icon(
                        icon,
                        size: 16, // Smaller icon size
                        color:
                            isSelected ? Colors.white : AppColors.secondaryText,
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            // --- INÍCIO DA MUDANÇA (Solicitação 1) ---
                            // Cancela o modo de seleção ao trocar de filtro
                            _clearSelection();
                            // --- FIM DA MUDANÇA ---
                            _selectedFilter = filterType;
                            if (filterType != TaskFilterType.vibracao) {
                              _selectedVibrationNumber = null;
                            }
                            _selectedTag = null;
                          });
                        }
                      },
                      backgroundColor: AppColors.cardBackground,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.secondaryText,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal),
                      showCheckmark: false,
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6), // Reduced padding
                    ),
                  );
                }),

                // --- INÍCIO DA CORREÇÃO (Problema 2) ---
                // SizedBox(width: 12) removido
                // --- FIM DA CORREÇÃO ---

                // Tag filter (opens modal) - keep visible regardless of selection mode
                Padding(
                  padding: const EdgeInsets.only(right: chipSpacing),
                  child: ChoiceChip(
                    label: Text(_selectedTag ?? 'Tags',
                        style: const TextStyle(fontSize: 14)),
                    avatar: const Icon(Icons.label_outline, size: 16),
                    selected: _selectedTag != null,
                    onSelected: (selected) async {
                      final selectedTag = await showModalBottomSheet<String?>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => TagSelectionModal(userId: _userId),
                      );
                      if (selectedTag != null) {
                        setState(() {
                          _selectedTag = selectedTag;
                          _clearSelection();
                        });
                      }
                    },
                    backgroundColor: AppColors.cardBackground,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        color: _selectedTag != null
                            ? Colors.white
                            : AppColors.secondaryText,
                        fontWeight: _selectedTag != null
                            ? FontWeight.bold
                            : FontWeight.normal),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    // --- INÍCIO DA CORREÇÃO (Problema 1) ---
                    // Adicionado 'side' para corresponder aos outros chips
                    side: BorderSide.none,
                    // --- FIM DA CORREÇÃO ---
                  ),
                ),
              ],
            ),
          ),
          // --- FIM DA MUDANÇA (Solicitação 3) ---

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Visibility(
              visible: _selectedFilter == TaskFilterType.vibracao,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: (_selectedFilter == TaskFilterType.vibracao)
                    // --- INÍCIO DA MUDANÇA (Solicitação 3): Rolagem Horizontal ---
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          children: _vibrationNumbers.map((number) {
                            final isSelected =
                                _selectedVibrationNumber == number;
                            final colors = getColorsForVibration(number);

                            return Padding(
                              padding: const EdgeInsets.only(
                                  right: chipSpacing), // Espaçamento
                              child: ChoiceChip(
                                label: Text('$number'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    // --- INÍCIO DA MUDANÇA (Solicitação 1) ---
                                    _clearSelection(); // Cancela seleção
                                    // --- FIM DA MUDANÇA ---
                                    if (!selected) {
                                      _selectedVibrationNumber = null;
                                    } else {
                                      _selectedVibrationNumber = number;
                                    }
                                  });
                                },
                                backgroundColor:
                                    colors.background.withValues(alpha: 0.2),
                                selectedColor: colors.background,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? colors.text
                                      : colors.background
                                          .withValues(alpha: 0.9),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                shape: StadiumBorder(
                                    side: BorderSide(
                                        color: colors.background
                                            .withValues(alpha: 0.5))),
                                showCheckmark: false,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    // --- FIM DA MUDANÇA (Solicitação 3) ---
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
        ],
      ),
    );
  }

  // --- INÍCIO DA MUDANÇA (Solicitação 1 & 3): Widgets de UI refatorados ---

  /// (Solicitação 3) Constrói a barra de filtro de tags e controles
  Widget _buildTagFilters(List<String> allTags, {required bool isMobile}) {
    // Always show the selection button in the tasks header, regardless of filter
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          // Pequeno padding esquerdo para alinhar visualmente com os itens da lista
          padding: const EdgeInsets.only(left: 8.0),
          child: _buildSelectionButton(),
        ),
      ),
    );
  }

  /// Constrói o botão de seleção de tarefas
  Widget _buildSelectionButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.check_box_outline_blank_rounded,
          color: AppColors.secondaryText, size: 20),
      label: const Text('Selecionar Tarefas',
          style: TextStyle(
              color: AppColors.secondaryText, fontWeight: FontWeight.normal)),
      onPressed: _toggleSelectionMode,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.secondaryText,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
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
