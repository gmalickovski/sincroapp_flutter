import 'dart:async'; // Necessário para StreamSubscription
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';
// --- MUDANÇA (TAREFA 3): Import removido ---
// import 'package:sincro_app_flutter/features/journal/presentation/journal_editor_screen.dart';
// --- FIM MUDANÇA ---
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart'; // Import correto
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
// --- MUDANÇA (TAREFA 3): Import removido ---
// import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
// --- FIM MUDANÇA ---
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import '../models/event_model.dart';
import 'package:sincro_app_flutter/common/widgets/custom_calendar.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'widgets/calendar_header.dart';
import 'widgets/day_detail_panel.dart';

// --- INÍCIO DA MUDANÇA: Importar o TaskDetailModal ---
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart';
// --- FIM DA MUDANÇA ---

class CalendarScreen extends StatefulWidget {
  final UserModel userData;
  const CalendarScreen({super.key, required this.userData});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const double kTabletBreakpoint = 768.0;

  final FirestoreService _firestoreService = FirestoreService();
  final AuthRepository _authRepository = AuthRepository();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late final String _userId;

  Map<DateTime, List<CalendarEvent>> _events = {}; // Chave UTC
  Map<DateTime, List<dynamic>> _rawEvents = {}; // Chave LOCAL

  int? _personalDayNumber;
  bool _isScreenLoading = true;
  bool _isChangingMonth = false;

  StreamSubscription? _tasksDueDateSubscription;
  StreamSubscription? _tasksCreatedAtSubscription;
  // --- MUDANÇA (TAREFA 3): Stream removida ---
  // StreamSubscription? _journalSubscription;
  // --- FIM MUDANÇA ---

  List<TaskModel> _currentTasksDueDate = [];
  List<TaskModel> _currentTasksCreatedAt = [];
  // --- MUDANÇA (TAREFA 3): Lista removida ---
  // List<JournalEntry> _currentJournalEntries = [];
  // --- FIM MUDANÇA ---

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _userId = _authRepository.getCurrentUser()!.uid;
    _initializeStreams(_focusedDay, isInitialLoad: true);
  }

  @override
  void dispose() {
    _tasksDueDateSubscription?.cancel();
    _tasksCreatedAtSubscription?.cancel();
    // --- MUDANÇA (TAREFA 3): Cancelamento removido ---
    // _journalSubscription?.cancel();
    // --- FIM MUDANÇA ---
    super.dispose();
  }

  // initializeStreams
  Future<void> _initializeStreams(DateTime month,
      {bool isInitialLoad = false}) async {
    if (mounted) {
      setState(() {
        if (isInitialLoad) _isScreenLoading = true;
        _isChangingMonth = true;
        // Limpa dados antigos imediatamente
        _events = {};
        _rawEvents = {};
        _currentTasksDueDate = [];
        _currentTasksCreatedAt = [];
        // --- MUDANÇA (TAREFA 3): Limpeza removida ---
        // _currentJournalEntries = [];
        // --- FIM MUDANÇA ---
      });
    }

    // Cancela subscriptions anteriores
    await _tasksDueDateSubscription?.cancel();
    await _tasksCreatedAtSubscription?.cancel();
    // --- MUDANÇA (TAREFA 3): Cancelamento removido ---
    // await _journalSubscription?.cancel();
    // --- FIM MUDANÇA ---

    final monthUtc = DateTime.utc(month.year, month.month);

    // Inicia stream de Tasks (DueDate)
    _tasksDueDateSubscription = _firestoreService
        .getTasksDueDateStreamForMonth(_userId, monthUtc)
        .listen(_onTasksDueDateUpdated, onError: (e, s) {
      print("Erro no stream de tasks (dueDate): $e\n$s");
      _onTasksDueDateUpdated([]); // Trata erro como lista vazia
    });

    // Inicia stream de Tasks (CreatedAt)
    _tasksCreatedAtSubscription = _firestoreService
        .getTasksCreatedAtStreamForMonth(_userId, monthUtc)
        .listen(_onTasksCreatedAtUpdated, onError: (e, s) {
      print("Erro no stream de tasks (createdAt): $e\n$s");
      _onTasksCreatedAtUpdated([]); // Trata erro como lista vazia
    });

    // --- MUDANÇA (TAREFA 3): Stream do Journal removida ---
    // // Inicia stream de Journal
    // _journalSubscription = _firestoreService
    //     .getJournalEntriesStreamForMonth(_userId, monthUtc)
    //     .listen(_onJournalUpdated, onError: (e, s) {
    //   print("Erro no stream de journal: $e\n$s");
    //   _onJournalUpdated([]); // Trata erro como lista vazia
    // });
    // --- FIM MUDANÇA ---

    // Atualiza o dia pessoal após o primeiro carregamento
    if (isInitialLoad && mounted && _selectedDay != null) {
      _updatePersonalDay(_selectedDay!);
    }

    // Desliga o loading inicial (o _processEvents vai desligar o _isChangingMonth)
    if (isInitialLoad && mounted) {
      setState(() => _isScreenLoading = false);
    }
  }

  // Handlers de update dos streams
  void _onTasksDueDateUpdated(List<TaskModel> tasks) {
    _currentTasksDueDate = tasks;
    _processEvents();
  }

  void _onTasksCreatedAtUpdated(List<TaskModel> tasks) {
    _currentTasksCreatedAt = tasks;
    _processEvents();
  }

  // --- MUDANÇA (TAREFA 3): Método removido ---
  // void _onJournalUpdated(List<JournalEntry> entries) {
  //   _currentJournalEntries = entries;
  //   _processEvents();
  // }
  // --- FIM MUDANÇA ---

  // Processa e combina os eventos
  void _processEvents() {
    // Mapas temporários
    Map<DateTime, List<CalendarEvent>> newEvents = {};
    Map<DateTime, List<dynamic>> newRawEvents = {};

    try {
      // --- LÓGICA DE COMBINAÇÃO (baseada no seu getTasksForCalendar) ---
      final tasksMap = <String, TaskModel>{};
      for (var task in _currentTasksDueDate) {
        tasksMap[task.id] = task;
      }
      for (var task in _currentTasksCreatedAt) {
        if (!tasksMap.containsKey(task.id)) {
          tasksMap[task.id] = task;
        }
      }
      final allTasks = tasksMap.values.toList();
      // --- FIM DA LÓGICA DE COMBINAÇÃO ---

      // --- MUDANÇA (TAREFA 3): Lista de Journal removida ---
      final allRawData = <dynamic>[...allTasks]; //, ..._currentJournalEntries];
      // --- FIM MUDANÇA ---

      // Agrupa por LOCAL para newRawEvents (Painel)
      newRawEvents = groupBy<dynamic, DateTime>(allRawData, (event) {
        DateTime localDate;
        if (event is TaskModel) {
          localDate = event.dueDate ?? event.createdAt;
        } else {
          // --- MUDANÇA (TAREFA 3): Lógica do Journal removida ---
          // localDate = (event as JournalEntry).createdAt;
          // Como fallback, mas não deve acontecer
          localDate = DateTime.now();
          // --- FIM MUDANÇA ---
        }
        return DateTime(localDate.year, localDate.month, localDate.day);
      });

      // Mapeia para CalendarEvent
      final allCalendarEvents = allRawData
          .map((event) {
            DateTime eventDate;
            EventType eventType;
            String title;
            if (event is TaskModel) {
              eventDate = event.dueDate ?? event.createdAt;
              eventType = (event.journeyId?.isNotEmpty ?? false)
                  ? EventType.goalTask
                  : EventType.task;
              title = event.text;
              // --- MUDANÇA (TAREFA 3): Bloco else if removido ---
              // } else if (event is JournalEntry) {
              //   eventDate = event.createdAt;
              //   eventType = EventType.journal;
              //   title = event.content.length > 20
              //       ? '${event.content.substring(0, 17)}...'
              //       : event.content;
              // --- FIM MUDANÇA ---
            } else {
              return null;
            }
            return CalendarEvent(
                title: title, date: eventDate, type: eventType);
          })
          .whereType<CalendarEvent>()
          .toList();

      // Agrupa por UTC para newEvents (Marcadores)
      newEvents =
          groupBy<CalendarEvent, DateTime>(allCalendarEvents, (calendarEvent) {
        final localDate = calendarEvent.date;
        return DateTime.utc(localDate.year, localDate.month, localDate.day);
      });
    } catch (e, stackTrace) {
      print("Erro em _processEvents: $e\n$stackTrace");
      newRawEvents = {};
      newEvents = {}; // Limpa em caso de erro
    } finally {
      // Atualiza o estado com os novos dados e desliga os loadings
      if (mounted) {
        setState(() {
          _events = newEvents;
          _rawEvents = newRawEvents;
          _isChangingMonth = false;
          _isScreenLoading = false; // Garante que o loading inicial saia
        });
      }
    }
  }

  // _updatePersonalDay (inalterado)
  void _updatePersonalDay(DateTime date) {
    if (widget.userData.dataNasc.isNotEmpty) {
      final engine = NumerologyEngine(
          nomeCompleto: widget.userData.nomeAnalise,
          dataNascimento: widget.userData.dataNasc);
      if (mounted) {
        final dayForCalc = DateTime(date.year, date.month, date.day);
        final newNumber = engine.calculatePersonalDayForDate(dayForCalc);
        if (newNumber != _personalDayNumber) {
          setState(() => _personalDayNumber = newNumber);
        }
      }
    } else {
      if (mounted && _personalDayNumber != null) {
        setState(() => _personalDayNumber = null);
      }
    }
  }

  // _onDaySelected (inalterado)
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final selectedLocalMidnight =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    if (!isSameDay(_selectedDay, selectedLocalMidnight)) {
      if (mounted) {
        setState(() {
          _selectedDay = selectedLocalMidnight;
          _focusedDay =
              DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
        });
        _updatePersonalDay(selectedLocalMidnight);
      }
    }
  }

  // _getRawEventsForDay (inalterado)
  List<dynamic> _getRawEventsForDay(DateTime day) {
    final localMidnightKey = DateTime(day.year, day.month, day.day);
    return _rawEvents[localMidnightKey] ?? [];
  }

  // _openAddTaskModal (inalterado)
  void _openAddTaskModal({TaskModel? task}) async {
    final preselectedDateMidnight = _selectedDay != null
        ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
        : null;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData, // Já é não nulo aqui
        preselectedDate: task == null ? preselectedDateMidnight : null,
        taskToEdit: task,
      ),
    );
  }

  // --- MUDANÇA (TAREFA 3): Método removido ---
  // // _openJournalEditor (inalterado)
  // void _openJournalEditor(JournalEntry entry) async {
  //   await Navigator.of(context).push<bool>(MaterialPageRoute(
  //     builder: (context) => JournalEditorScreen(
  //       userData: widget.userData,
  //       entry: entry,
  //     ),
  //     fullscreenDialog: true,
  //   ));
  // }
  // --- FIM MUDANÇA ---

  // _onPageChanged (inalterado)
  void _onPageChanged(DateTime newFocusedDay) {
    if (!mounted) return;
    final localMidnightFocusedDay =
        DateTime(newFocusedDay.year, newFocusedDay.month, newFocusedDay.day);
    if (localMidnightFocusedDay.year != _focusedDay.year ||
        localMidnightFocusedDay.month != _focusedDay.month) {
      setState(() {
        _focusedDay = localMidnightFocusedDay;
        _isChangingMonth = true;
        _selectedDay = null; // Desseleciona o dia ao mudar de mês
        _personalDayNumber = null;
      });
      _initializeStreams(localMidnightFocusedDay);
    } else {
      // Se apenas focou em outro dia do mesmo mês, atualiza _focusedDay
      if (!isSameDay(_focusedDay, localMidnightFocusedDay)) {
        setState(() {
          _focusedDay = localMidnightFocusedDay;
        });
      }
    }
  }

  // --- Handlers ---

  // _onToggleTask (inalterado)
  void _onToggleTask(TaskModel task, bool isCompleted) async {
    try {
      await _firestoreService.updateTaskCompletion(_userId, task.id,
          completed: isCompleted);
      // Opcional: Atualizar progresso da meta se necessário (pode ser feito na tela de detalhes tbm)
      if (task.journeyId != null && task.journeyId!.isNotEmpty) {
        _firestoreService.updateGoalProgress(_userId, task.journeyId!);
      }
    } catch (e) {
      print("Erro ao atualizar conclusão: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro ao atualizar tarefa: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  // --- INÍCIO DA MUDANÇA: Implementar _handleTaskTap ---
  // Abre o modal de detalhes da tarefa
  void _handleTaskTap(TaskModel task) {
    print("Calendário: Tarefa tocada: ${task.id} - ${task.text}");

    // Abre o modal de detalhes/edição
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return TaskDetailModal(
          task: task,
          userData: widget.userData, // Passa os dados do usuário
        );
      },
    );
  }
  // --- FIM DA MUDANÇA ---

  // --- Funções _onDeleteTask e _onDuplicateTask foram REMOVIDAS ---

  // _isSameMonth (inalterado)
  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isScreenLoading
            ? const Center(
                child: CustomLoadingSpinner()) // <-- CORRIGIDO AQUI (sem size)
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
      floatingActionButton: (_isScreenLoading || _isChangingMonth)
          ? null
          : FloatingActionButton(
              onPressed: _openAddTaskModal,
              backgroundColor: AppColors.primary,
              tooltip: 'Nova Tarefa',
              heroTag: 'calendar_fab',
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  // --- BUILD LAYOUTS ---

  Widget _buildMobileLayout(
      BuildContext context, Map<DateTime, List<CalendarEvent>> eventsMapUtc) {
    final orientation = MediaQuery.of(context).orientation;

    void _handleTodayTap() {
      // ... (código inalterado) ...
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!_isSameMonth(_focusedDay, today)) {
        // Se não estiver no mês atual, navega para o mês e depois seleciona
        _onPageChanged(
            today); // Isso já vai chamar _onDaySelected indiretamente? Não, precisa chamar depois
        // A _onPageChanged pode levar um tempo para atualizar o stream,
        // então selecionamos o dia imediatamente para a UI responder rápido.
        _onDaySelected(today, today);
      } else {
        // Se já está no mês certo, apenas seleciona o dia
        _onDaySelected(today, today);
      }
    }

    if (orientation == Orientation.landscape) {
      // Layout Paisagem
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
                          // ... (inalterado) ...
                          focusedDay: _focusedDay,
                          onTodayButtonTap: _handleTodayTap,
                          onLeftArrowTap: () => _onPageChanged(DateTime(
                              _focusedDay.year, _focusedDay.month - 1)),
                          onRightArrowTap: () => _onPageChanged(DateTime(
                              _focusedDay.year, _focusedDay.month + 1)),
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomCalendar(
                              // ... (inalterado) ...
                              focusedDay: _focusedDay,
                              selectedDay: _selectedDay,
                              onDaySelected: _onDaySelected,
                              onPageChanged: _onPageChanged,
                              isDesktop: false, // É mobile landscape
                              events: eventsMapUtc, // Usa mapa UTC
                              personalDayNumber: _personalDayNumber,
                            ),
                            if (_isChangingMonth)
                              Positioned.fill(
                                child: Container(
                                  color: AppColors.background.withOpacity(0.5),
                                  child: const Center(
                                    child:
                                        CustomLoadingSpinner(), // <-- CORRIGIDO AQUI (sem size)
                                  ),
                                ),
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
            child: DayDetailPanel(
              // Chamada Atualizada
              selectedDay: _selectedDay,
              personalDayNumber: _personalDayNumber,
              events: _selectedDay != null
                  ? _getRawEventsForDay(_selectedDay!)
                  : [],
              isDesktop: false,
              onAddTask: _openAddTaskModal,
              onToggleTask: _onToggleTask,
              onTaskTap: _handleTaskTap, // Passa o novo handler
              // --- MUDANÇA (TAREFA 3): Callback removido ---
              // onJournalTap: _openJournalEditor,
              // --- FIM MUDANÇA ---
              // Callbacks removidos
            ),
          ),
        ],
      );
    } else {
      // Layout Retrato
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                CalendarHeader(
                  // ... (inalterado) ...
                  focusedDay: _focusedDay,
                  onTodayButtonTap: _handleTodayTap,
                  onLeftArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month - 1)),
                  onRightArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month + 1)),
                ),
                const SizedBox(height: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomCalendar(
                      // ... (inalterado) ...
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      onDaySelected: _onDaySelected,
                      onPageChanged: _onPageChanged,
                      isDesktop: false, // É mobile portrait
                      events: eventsMapUtc, // Usa mapa UTC
                      personalDayNumber: _personalDayNumber,
                    ),
                    if (_isChangingMonth)
                      Positioned.fill(
                        child: Container(
                          color: AppColors.background.withOpacity(0.5),
                          child: const Center(
                            child:
                                CustomLoadingSpinner(), // <-- CORRIGIDO AQUI (sem size)
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.15,
              maxChildSize: 0.9,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return DayDetailPanel(
                  // Chamada Atualizada
                  selectedDay: _selectedDay,
                  personalDayNumber: _personalDayNumber,
                  events: _selectedDay != null
                      ? _getRawEventsForDay(_selectedDay!)
                      : [],
                  isDesktop: false,
                  onAddTask: _openAddTaskModal,
                  onToggleTask: _onToggleTask,
                  onTaskTap: _handleTaskTap, // Passa o novo handler
                  // --- MUDANÇA (TAREFA 3): Callback removido ---
                  // onJournalTap: _openJournalEditor,
                  // --- FIM MUDANÇA ---
                  scrollController: scrollController,
                  // Callbacks removidos
                );
              },
            ),
          ),
        ],
      );
    }
  }

  Widget _buildWideLayout(
      BuildContext context, Map<DateTime, List<CalendarEvent>> eventsMapUtc) {
    void _handleTodayTap() {
      // ... (código inalterado) ...
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!_isSameMonth(_focusedDay, today)) {
        _onPageChanged(today);
        _onDaySelected(today, today); // Seleciona imediatamente
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
                  // ... (inalterado) ...
                  focusedDay: _focusedDay,
                  onTodayButtonTap: _handleTodayTap,
                  onLeftArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month - 1)),
                  onRightArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month + 1)),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomCalendar(
                          // ... (inalterado) ...
                          focusedDay: _focusedDay,
                          selectedDay: _selectedDay,
                          onDaySelected: _onDaySelected,
                          onPageChanged: _onPageChanged,
                          isDesktop: true, // É Desktop
                          calendarWidth:
                              constraints.maxWidth, // Passa a largura
                          events: eventsMapUtc, // Usa mapa UTC
                          personalDayNumber: _personalDayNumber,
                        ),
                        if (_isChangingMonth)
                          Positioned.fill(
                            child: Container(
                              color: AppColors.background.withOpacity(0.5),
                              child: const Center(
                                child:
                                    CustomLoadingSpinner(), // <-- CORRIGIDO AQUI (sem size)
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 24, 24),
            child: DayDetailPanel(
              // Chamada Atualizada
              selectedDay: _selectedDay,
              personalDayNumber: _personalDayNumber,
              events: _selectedDay != null
                  ? _getRawEventsForDay(_selectedDay!)
                  : [],
              isDesktop: true,
              onAddTask: _openAddTaskModal,
              onToggleTask: _onToggleTask,
              onTaskTap: _handleTaskTap, // Passa o novo handler
              // --- MUDANÇA (TAREFA 3): Callback removido ---
              // onJournalTap: _openJournalEditor,
              // --- FIM MUDANÇA ---
              // Callbacks removidos
            ),
          ),
        ),
      ],
    );
  }
} // Fim _CalendarScreenState
