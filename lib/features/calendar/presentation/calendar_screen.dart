// lib/features/calendar/presentation/calendar_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
// ATUALIZADO: Importa ParsedTask
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/features/tasks/services/task_action_service.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import '../models/event_model.dart';
import 'package:sincro_app_flutter/common/widgets/custom_calendar.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'widgets/calendar_header.dart';
import 'widgets/day_detail_panel.dart';
import 'package:sincro_app_flutter/features/assistant/widgets/expanding_assistant_fab.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/assistant_panel.dart';
import 'package:sincro_app_flutter/models/subscription_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart';

import 'package:sincro_app_flutter/common/widgets/fab_opacity_manager.dart';
import 'package:sincro_app_flutter/common/widgets/custom_month_year_picker.dart';

class CalendarScreen extends StatefulWidget {
  final UserModel userData;
  const CalendarScreen({super.key, required this.userData});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const double kTabletBreakpoint = 768.0;

  final SupabaseService _supabaseService = SupabaseService();
  final TaskActionService _taskActionService = TaskActionService();
  final AuthRepository _authRepository = AuthRepository();
  final Uuid _uuid = const Uuid();

  DateTime _focusedDay = DateTime.now();

  // --- INÍCIO DA CORREÇÃO (Para erro de tipo) ---
  // Alterado de 'DateTime? _selectedDay;' para 'late DateTime _selectedDay;'
  // Isso garante ao compilador que _selectedDay nunca será nulo
  // quando o DayDetailPanel for chamado, pois ele é inicializado no initState.
  late DateTime _selectedDay;
  // --- FIM DA CORREÇÃO ---

  late final String _userId;

  Map<DateTime, List<CalendarEvent>> _events = {}; // Chave UTC
  Map<DateTime, List<dynamic>> _rawEvents = {}; // Chave LOCAL

  int? _personalDayNumber;
  bool _isScreenLoading = true;
  final bool _isChangingMonth = false;

  final FabOpacityController _fabOpacityController = FabOpacityController();

  StreamSubscription? _tasksDueDateSubscription;
  StreamSubscription? _tasksCreatedAtSubscription;

  List<TaskModel> _currentTasksDueDate = [];
  List<TaskModel> _currentTasksCreatedAt = [];

  // initState, dispose, _initializeStreams, _onTasksDueDateUpdated,
  // _onTasksCreatedAtUpdated, _processEvents, _updatePersonalDay,
  // _onDaySelected, _getRawEventsForDay
  // (Seu código original, sem alterações)
  // --- (Código omitido para brevidade) ---
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    // Esta linha satisfaz o 'late' de _selectedDay
    _selectedDay = DateTime(now.year, now.month, now.day);
    // Garante que userId seja pego com segurança
    _userId = _authRepository.currentUser?.id ?? '';
    if (_userId.isEmpty) {
      debugPrint("ERRO GRAVE: CalendarScreen iniciada sem userId!");
      // Idealmente, tratar esse caso (ex: mostrar erro, impedir build)
      _isScreenLoading = false; // Impede loading infinito
    } else {
      _initializeStreams(_focusedDay, isInitialLoad: true);
    }
  }

  @override
  void dispose() {
    _tasksDueDateSubscription?.cancel();
    _tasksCreatedAtSubscription?.cancel();
    _fabOpacityController.dispose();
    super.dispose();
  }

  // --- Estado de Expansão do Calendário (Mobile) ---
  bool _isCalendarExpanded = true;

  void _toggleCalendar() {
    setState(() {
      _isCalendarExpanded = !_isCalendarExpanded;
    });
  }

  // Abre o seletor customizado de Mês/Ano
  Future<void> _showMonthYearPicker() async {
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext builderContext) {
        return CustomMonthYearPicker(
          initialDate: _focusedDay,
          firstDate: DateTime(2020),
          lastDate: DateTime(2101),
        );
      },
    );
    if (picked != null && mounted) {
      final newFocusedDay = DateTime(picked.year, picked.month, 1);
      _onPageChanged(newFocusedDay);
    }
  }

  void _initializeStreams(DateTime month, {bool isInitialLoad = false}) {
    _tasksDueDateSubscription?.cancel();
    _tasksCreatedAtSubscription?.cancel();

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    // Stream de tarefas por data de vencimento (para o mês atual)
    _tasksDueDateSubscription = _supabaseService
        .getTasksStreamForRange(_userId, startOfMonth, endOfMonth)
        .listen((tasks) {
      _currentTasksDueDate = tasks;
      _processEvents();
    });

    // Stream de tarefas por data de criação (para mostrar no dia que foi criada, se quiser)
    // Ou apenas mantemos o dueDate. Por simplificação, vamos focar no dueDate.
    // Mas se o app usa createdAt para algo, podemos manter.
    // Vou manter simplificado para dueDate por enquanto, mas inicializar a lista.
    _currentTasksCreatedAt = []; 
    _processEvents();
    
    // --- INÍCIO DA CORREÇÃO (Vibração) ---
    // Atualiza o dia pessoal ao inicializar streams (troca de mês/load)
    _updatePersonalDay(_selectedDay);
    // --- FIM DA CORREÇÃO ---

    if (isInitialLoad) {
      setState(() {
        _isScreenLoading = false;
      });
    }
  }

  void _processEvents() {
    final newEvents = <DateTime, List<CalendarEvent>>{};
    final newRawEvents = <DateTime, List<dynamic>>{};

    // Processar tarefas
    for (var task in _currentTasksDueDate) {
      if (task.dueDate != null) {
        // --- INÍCIO DA CORREÇÃO (Marcadores) ---
        // Usa UTC para chave do mapa de eventos (compatível com CustomCalendar)
        final dateUtc = DateTime.utc(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        // Usa Local para chave do mapa de raw events (compatível com DayDetailPanel)
        final dateLocal = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        
        // Determina o tipo de evento para o marcador
        EventType eventType = EventType.task;
        if (task.journeyId != null && task.journeyId!.isNotEmpty) {
          eventType = EventType.goalTask;
        } else if (task.reminderTime != null) {
          eventType = EventType.scheduledTask;
        }

        // Adicionar ao map de eventos do calendário (para bolinhas)
        if (newEvents[dateUtc] == null) newEvents[dateUtc] = [];
        newEvents[dateUtc]!.add(CalendarEvent(
          title: task.text,
          date: task.dueDate!,
          type: eventType,
          isCompleted: task.completed,
        ));

        // Adicionar ao map de raw events (para lista de detalhes)
        if (newRawEvents[dateLocal] == null) newRawEvents[dateLocal] = [];
        newRawEvents[dateLocal]!.add(task);
        // --- FIM DA CORREÇÃO ---
      }
    }

    if (mounted) {
      setState(() {
        _events = newEvents;
        _rawEvents = newRawEvents;
      });
    }
  }

  // --- INÍCIO DA CORREÇÃO (Vibração) ---
  void _updatePersonalDay(DateTime date) {
    if (widget.userData.nomeAnalise.isEmpty || widget.userData.dataNasc.isEmpty) {
      return;
    }

    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );

    try {
      // Calcula para o dia selecionado (em UTC para garantir consistência)
      final dateUtc = DateTime.utc(date.year, date.month, date.day);
      final day = engine.calculatePersonalDayForDate(dateUtc);
      
      if (_personalDayNumber != day) {
        setState(() {
          _personalDayNumber = day;
        });
      }
    } catch (e) {
      debugPrint('Erro ao calcular dia pessoal: $e');
    }
  }
  // --- FIM DA CORREÇÃO ---

  List<dynamic> _getRawEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _rawEvents[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      // --- INÍCIO DA CORREÇÃO (Vibração) ---
      _updatePersonalDay(selectedDay);
      // --- FIM DA CORREÇÃO ---
    }
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _initializeStreams(focusedDay);
    setState(() {}); // Atualiza UI
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

    void _openAddTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userId: _userId,
        userData: widget.userData,
        initialDueDate: _selectedDay,
        onAddTask: (parsedTask) {
          if (parsedTask.recurrenceRule.type == RecurrenceType.none) {
            _createSingleTask(parsedTask);
          } else {
            _createRecurringTasks(parsedTask);
          }
        },
      ),
    );
  }

  // --- MÉTODOS DE CRIAÇÃO DE TAREFA (Copiados de FocoDoDiaScreen) ---

  int? _calculatePersonalDay(DateTime? date) {
    if (widget.userData.dataNasc.isEmpty ||
        widget.userData.nomeAnalise.isEmpty ||
        date == null) {
      return null;
    }

    final engine = NumerologyEngine(
      nomeCompleto: widget.userData.nomeAnalise,
      dataNascimento: widget.userData.dataNasc,
    );

    try {
      final dateUtc = date.toUtc();
      final day = engine.calculatePersonalDayForDate(dateUtc);
      return (day > 0) ? day : null;
    } catch (e) {
      return null;
    }
  }

  void _createSingleTask(ParsedTask parsedTask, {String? recurrenceId}) {
    DateTime? finalDueDateUtc;
    DateTime dateForPersonalDay;

    if (parsedTask.dueDate != null) {
      final dateLocal = parsedTask.dueDate!.toLocal();
      finalDueDateUtc =
          DateTime.utc(dateLocal.year, dateLocal.month, dateLocal.day);
      dateForPersonalDay = finalDueDateUtc;
    } else {
      final now = DateTime.now().toLocal();
      dateForPersonalDay = DateTime.utc(now.year, now.month, now.day);
    }

    final int? finalPersonalDay = _calculatePersonalDay(dateForPersonalDay);

    final newTask = TaskModel(
      id: '',
      text: parsedTask.cleanText,
      createdAt: DateTime.now().toUtc(),
      dueDate: finalDueDateUtc,
      journeyId: parsedTask.journeyId,
      journeyTitle: parsedTask.journeyTitle,
      tags: parsedTask.tags,
      reminderTime: parsedTask.reminderTime,
      reminderAt: parsedTask.reminderAt,
      recurrenceType: parsedTask.recurrenceRule.type,
      recurrenceDaysOfWeek: parsedTask.recurrenceRule.daysOfWeek,
      recurrenceEndDate: parsedTask.recurrenceRule.endDate?.toUtc(),
      recurrenceId: recurrenceId,
      personalDay: finalPersonalDay,
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

    for (final date in dates) {
      final taskForDate = parsedTask.copyWith(
        dueDate: date,
      );
      _createSingleTask(taskForDate, recurrenceId: recurrenceId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Criando tarefas recorrentes...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

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

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }    
  
  Future<void> _onToggleTask(TaskModel task, bool newValue) async {
    try {
      await _supabaseService.updateTaskCompletion(
        _userId,
        task.id,
        completed: newValue,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar tarefa: $e')),
      );
    }
  }

  // --- Swipe Actions ---
  Future<bool?> _handleDeleteTask(TaskModel task) async {
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
        return true;
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

  Future<bool?> _handleRescheduleTask(TaskModel task) async {
    final newDate = await _taskActionService.rescheduleTask(
      context,
      task,
      widget.userData,
    );

    // Se a data mudou, precisamos atualizar a UI.
    // O stream de tarefas já deve cuidar disso, mas podemos retornar true
    // se quisermos remover visualmente da lista do dia atual (se a nova data for diferente).
    if (newDate != null) {
       final now = DateTime.now();
       final today = DateTime(now.year, now.month, now.day);
       final newDateOnly = DateTime(newDate.year, newDate.month, newDate.day);
       
       // Se a nova data não for a mesma do dia selecionado, remove visualmente
       if (!newDateOnly.isAtSameMomentAs(_selectedDay)) {
          return true;
       }
    }
    return false;
  }

  void _handleTaskTap(TaskModel task) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailModal(
        task: task,
        userData: widget.userData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Adiciona verificação de _userId no início do build
    if (_userId.isEmpty && !_isScreenLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text("Erro: Usuário não identificado.",
              style: TextStyle(color: Colors.red)),
        ),
      );
    }



    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false, // Prevent body resizing (and sheet moving up) when keyboard opens
      body: ScreenInteractionListener(
        controller: _fabOpacityController,
        child: SafeArea(
          bottom: false, // Prevent SafeArea from reacting to keyboard/bottom insets
          child: _isScreenLoading
              ? const Center(child: CustomLoadingSpinner())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWideLayout =
                        constraints.maxWidth >= kTabletBreakpoint;
                    return isWideLayout
                        ? _buildWideLayout(context, _events)
                        : _buildMobileLayout(context, _events);
                  },
                ),
        ),
      ),
      floatingActionButton: TransparentFabWrapper(
        controller: _fabOpacityController,
        child: (widget.userData.subscription.isActive &&
                widget.userData.subscription.plan == SubscriptionPlan.premium)
            ? ExpandingAssistantFab(
                onPrimary: _openAddTaskModal,
                primaryIcon: Icons.edit_calendar, // Ícone de agendamento
                primaryTooltip: 'Nova Tarefa',
                onOpenAssistant: (message) {
                  AssistantPanel.show(context, widget.userData, initialMessage: message);
                },
              )
            : FloatingActionButton(
                onPressed: _openAddTaskModal,
                backgroundColor: AppColors.primary,
                tooltip: 'Nova Tarefa',
                heroTag: 'calendar_fab',
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildMobileLayout(
      BuildContext context, Map<DateTime, List<CalendarEvent>> eventsMapUtc) {
    final orientation = MediaQuery.of(context).orientation;

    void handleTodayTap() {

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!_isSameMonth(_focusedDay, today)) {
        _onPageChanged(today);
        _onDaySelected(today, today);
      } else {
        _onDaySelected(today, today);
      }
    }

    if (orientation == Orientation.landscape) {
      return Row(
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        CalendarHeader(
                          focusedDay: _focusedDay,
                          onTodayButtonTap: handleTodayTap,
                          onLeftArrowTap: () => _onPageChanged(DateTime(
                              _focusedDay.year, _focusedDay.month - 1)),
                          onRightArrowTap: () => _onPageChanged(DateTime(
                              _focusedDay.year, _focusedDay.month + 1)),
                          isCompact: true,
                          isDesktop: false,
                          onMonthYearTap: _showMonthYearPicker,
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            CustomCalendar(
                              focusedDay: _focusedDay,
                              selectedDay: _selectedDay,
                              onDaySelected: _onDaySelected,
                              onPageChanged: _onPageChanged,
                              isDesktop: false,
                              events: eventsMapUtc,
                              personalDayNumber: _personalDayNumber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(
              width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            flex: 4,
            // --- INÍCIO DA CORREÇÃO (Para erro de tipo) ---
            // _selectedDay agora é um 'DateTime' não-nulo,
            // então podemos passá-lo diretamente.
            child: DayDetailPanel(
              selectedDay: _selectedDay,
              personalDayNumber: _personalDayNumber,
              events: _getRawEventsForDay(_selectedDay),
              isDesktop: false,
              onAddTask: _openAddTaskModal,
              onToggleTask: _onToggleTask,
              onTaskTap: _handleTaskTap,
              // Callbacks de Swipe
              onDeleteTask: _handleDeleteTask,
              onRescheduleTask: _handleRescheduleTask,
            ),
            // --- FIM DA CORREÇÃO ---
          ),
        ],
      );
    } else {
      // --- Layout Mobile Novo (Sem sobreposição) ---
      return Column(
        children: [
          // 1. Calendário (Animado)
          AnimatedCrossFade(
            firstChild: Container(
             color: AppColors.background, // Fundo correto (não scaffoldBackground)
             padding: const EdgeInsets.only(bottom: 8.0), // Espaço pro painel não colar
             child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CalendarHeader(
                          focusedDay: _focusedDay,
                          onTodayButtonTap: handleTodayTap,
                          onLeftArrowTap: () => _onPageChanged(
                              DateTime(_focusedDay.year, _focusedDay.month - 1)),
                          onRightArrowTap: () => _onPageChanged(
                              DateTime(_focusedDay.year, _focusedDay.month + 1)),
                          isCompact: true,
                          onMonthYearTap: _showMonthYearPicker,
                        ),
                        // Removido SizedBox(height: 8) fixo
                        CustomCalendar(
                          focusedDay: _focusedDay,
                          selectedDay: _selectedDay,
                          onDaySelected: _onDaySelected,
                          onPageChanged: _onPageChanged,
                          isDesktop: false,
                          events: eventsMapUtc,
                          personalDayNumber: _personalDayNumber,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0), // Estado colapsado
            crossFadeState: _isCalendarExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),

          // 2. Painel de Detalhes (Ocupa o resto)
          Expanded(
            child: GestureDetector(
              // Gesto na *área do cabeçalho* é tratado dentro do painel se necessário, 
              // mas podemos adicionar detecção global de swipe vertical
              onVerticalDragEnd: (details) {
                // Swipe rápido para cima = fechar calendário
                if (details.primaryVelocity! < -500 && _isCalendarExpanded) {
                  _toggleCalendar();
                }
                // Swipe rápido para baixo = abrir calendário (se estiver no topo da lista)
                // Isso é complexo pois conflita com scroll da lista. 
                // Melhor deixar apenas o botão por enquanto ou swipe apenas no header
                else if (details.primaryVelocity! > 500 && !_isCalendarExpanded) {
                  _toggleCalendar();
                }
              },
              child: DayDetailPanel(
                selectedDay: _selectedDay,
                personalDayNumber: _personalDayNumber,
                events: _getRawEventsForDay(_selectedDay),
                isDesktop: false,
                onAddTask: _openAddTaskModal,
                onToggleTask: _onToggleTask,
                onTaskTap: _handleTaskTap,
                // Callbacks de Swipe
                onDeleteTask: _handleDeleteTask,
                onRescheduleTask: _handleRescheduleTask,
                // Controle de Expansão
                onToggleCalendar: _toggleCalendar,
                isCalendarExpanded: _isCalendarExpanded,
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildWideLayout(
      BuildContext context, Map<DateTime, List<CalendarEvent>> eventsMapUtc) {
    void handleTodayTap() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!_isSameMonth(_focusedDay, today)) {
        _onPageChanged(today);
        _onDaySelected(today, today);
      } else {
        _onDaySelected(today, today);
      }
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                CalendarHeader(
                  focusedDay: _focusedDay,
                  onTodayButtonTap: handleTodayTap,
                  onLeftArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month - 1)),
                  onRightArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month + 1)),
                  isDesktop: true,
                  onMonthYearTap: _showMonthYearPicker, // Abre seletor de mês/ano
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        CustomCalendar(
                          focusedDay: _focusedDay,
                          selectedDay: _selectedDay,
                          onDaySelected: _onDaySelected,
                          onPageChanged: _onPageChanged,
                          isDesktop: true,
                          calendarWidth: constraints.maxWidth,
                          events: eventsMapUtc,
                          personalDayNumber: _personalDayNumber,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: DayDetailPanel(
                  selectedDay: _selectedDay,
                  personalDayNumber: _personalDayNumber,
                  events: _getRawEventsForDay(_selectedDay),
                  isDesktop: true,
                  onAddTask: _openAddTaskModal,
                  onToggleTask: _onToggleTask,
                  onTaskTap: _handleTaskTap,
                  // Callbacks de Swipe
                  onDeleteTask: _handleDeleteTask,
                  onRescheduleTask: _handleRescheduleTask,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
} // Fim _CalendarScreenState
