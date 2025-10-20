// lib/features/calendar/presentation/calendar_screen.dart

import 'dart:async'; // Necessário para StreamSubscription
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';
import 'package:sincro_app_flutter/features/journal/presentation/journal_editor_screen.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import '../models/event_model.dart';
import 'package:sincro_app_flutter/common/widgets/custom_calendar.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'widgets/calendar_header.dart';
import 'widgets/day_detail_panel.dart';

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

  // Chaves UTC para marcadores (_events), Chaves LOCAIS para painel (_rawEvents)
  Map<DateTime, List<CalendarEvent>> _events = {}; // Chave UTC
  Map<DateTime, List<dynamic>> _rawEvents = {}; // Chave LOCAL

  int? _personalDayNumber;
  bool _isScreenLoading = true;
  bool _isChangingMonth = false;

  // Variáveis para gerenciar os streams
  StreamSubscription? _tasksDueDateSubscription;
  StreamSubscription? _tasksCreatedAtSubscription;
  StreamSubscription? _journalSubscription;

  // Listas para armazenar os dados dos streams
  List<TaskModel> _currentTasksDueDate = [];
  List<TaskModel> _currentTasksCreatedAt = [];
  List<JournalEntry> _currentJournalEntries = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _userId = _authRepository.getCurrentUser()!.uid;

    // Trocamos _loadInitialData por _initializeStreams
    _initializeStreams(_focusedDay, isInitialLoad: true);
  }

  @override
  void dispose() {
    // Limpar as inscrições dos streams para evitar memory leaks
    _tasksDueDateSubscription?.cancel();
    _tasksCreatedAtSubscription?.cancel();
    _journalSubscription?.cancel();
    super.dispose();
  }

  /// Inicia os listeners dos streams para o mês fornecido.
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
        _currentJournalEntries = [];
      });
    }

    // Cancela subscriptions anteriores
    await _tasksDueDateSubscription?.cancel();
    await _tasksCreatedAtSubscription?.cancel();
    await _journalSubscription?.cancel();

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

    // Inicia stream de Journal
    _journalSubscription = _firestoreService
        .getJournalEntriesStreamForMonth(_userId, monthUtc)
        .listen(_onJournalUpdated, onError: (e, s) {
      print("Erro no stream de journal: $e\n$s");
      _onJournalUpdated([]); // Trata erro como lista vazia
    });

    // Atualiza o dia pessoal após o primeiro carregamento
    if (isInitialLoad && mounted && _selectedDay != null) {
      _updatePersonalDay(_selectedDay!);
    }

    // Desliga o loading inicial (o _processEvents vai desligar o _isChangingMonth)
    if (isInitialLoad && mounted) {
      setState(() => _isScreenLoading = false);
    }
  }

  // Chamado quando o stream de Tasks (DueDate) entrega novos dados
  void _onTasksDueDateUpdated(List<TaskModel> tasks) {
    _currentTasksDueDate = tasks;
    _processEvents(); // Processa os dados combinados
  }

  // Chamado quando o stream de Tasks (CreatedAt) entrega novos dados
  void _onTasksCreatedAtUpdated(List<TaskModel> tasks) {
    _currentTasksCreatedAt = tasks;
    _processEvents(); // Processa os dados combinados
  }

  // Chamado quando o stream de Journal entrega novos dados
  void _onJournalUpdated(List<JournalEntry> entries) {
    _currentJournalEntries = entries;
    _processEvents(); // Processa os dados combinados
  }

  /// Processa os dados e atualiza a UI.
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

      final allRawData = <dynamic>[...allTasks, ..._currentJournalEntries];

      // Agrupa por LOCAL para newRawEvents (Painel)
      newRawEvents = groupBy<dynamic, DateTime>(allRawData, (event) {
        DateTime localDate;
        if (event is TaskModel) {
          localDate = event.dueDate ?? event.createdAt;
        } else {
          localDate = (event as JournalEntry).createdAt;
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
            } else if (event is JournalEntry) {
              eventDate = event.createdAt;
              eventType = EventType.journal;
              title = event.content.length > 20
                  ? '${event.content.substring(0, 17)}...'
                  : event.content;
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

  // Calcula dia pessoal (sem alterações)
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

  // Seleciona dia (sem alterações)
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

  // Busca eventos para o painel (USA CHAVE LOCAL)
  List<dynamic> _getRawEventsForDay(DateTime day) {
    final localMidnightKey = DateTime(day.year, day.month, day.day);
    return _rawEvents[localMidnightKey] ?? [];
  }

  // Abre modal de tarefa (sem alterações)
  void _openAddTaskModal({TaskModel? task}) async {
    final preselectedDateMidnight = _selectedDay != null
        ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
        : null;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData,
        preselectedDate: task == null ? preselectedDateMidnight : null,
        taskToEdit: task,
      ),
    );
  }

  // Abre editor de diário (sem alterações)
  void _openJournalEditor(JournalEntry entry) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (context) => JournalEditorScreen(
        userData: widget.userData,
        entry: entry,
      ),
      fullscreenDialog: true,
    ));
  }

  // Muda página/mês (sem alterações)
  void _onPageChanged(DateTime newFocusedDay) {
    if (!mounted) return;
    final localMidnightFocusedDay =
        DateTime(newFocusedDay.year, newFocusedDay.month, newFocusedDay.day);
    if (localMidnightFocusedDay.year != _focusedDay.year ||
        localMidnightFocusedDay.month != _focusedDay.month) {
      setState(() {
        _focusedDay = localMidnightFocusedDay;
        _isChangingMonth = true;
        _selectedDay = null;
        _personalDayNumber = null;
      });
      _initializeStreams(localMidnightFocusedDay);
    } else {
      if (!isSameDay(_focusedDay, localMidnightFocusedDay)) {
        setState(() {
          _focusedDay = localMidnightFocusedDay;
        });
      }
    }
  }

  // --- Handlers ---

  // (onToggleTask e onDuplicateTask sem alterações)
  void _onToggleTask(TaskModel task, bool isCompleted) async {
    try {
      await _firestoreService.updateTaskCompletion(_userId, task.id,
          completed: isCompleted);
      if (mounted) {
        if (_selectedDay != null) {
          final dayKey = DateTime(
              _selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
          final dayEvents = _rawEvents[dayKey];
          if (dayEvents != null) {
            final taskIndex =
                dayEvents.indexWhere((e) => e is TaskModel && e.id == task.id);
            if (taskIndex != -1) {
              final newRawEvents =
                  Map<DateTime, List<dynamic>>.from(_rawEvents);
              final newList = List<dynamic>.from(dayEvents);
              newList[taskIndex] = task.copyWith(completed: isCompleted);
              newRawEvents[dayKey] = newList;
              setState(() {
                _rawEvents = newRawEvents;
              });
            }
          }
        }
      }
    } catch (e) {
      print("Erro ao atualizar conclusão: $e");
    }
  }

  // --- INÍCIO DA CORREÇÃO ---
  void _onDeleteTask(TaskModel task) async {
    // MUDANÇA: Implementa um diálogo de confirmação funcional
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Usamos dialogContext para fechar o dialog
        return AlertDialog(
          backgroundColor: AppColors.cardBackground, // Estilizando o dialog
          title: const Text(
            'Confirmar Exclusão',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Você tem certeza que deseja excluir esta tarefa?',
            style: TextStyle(color: AppColors.secondaryText),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // Retorna false
              },
            ),
            TextButton(
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Retorna true
              },
            ),
          ],
        );
      },
    );

    // Se o usuário confirmou (retornou true)
    if (confirmed == true && mounted) {
      try {
        await _firestoreService.deleteTask(_userId, task.id);

        // O Stream já cuidará da atualização, mas podemos mostrar um SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarefa excluída.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print("Erro ao deletar: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir tarefa: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  // --- FIM DA CORREÇÃO ---

  void _onDuplicateTask(TaskModel task) async {
    final duplicatedTask =
        task.copyWith(id: '', completed: false, createdAt: DateTime.now());
    try {
      await _firestoreService.addTask(_userId, duplicatedTask);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarefa duplicada.'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Erro ao duplicar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao duplicar tarefa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // --- FIM Handlers ---

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isScreenLoading
            ? const Center(child: CustomLoadingSpinner())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWideLayout =
                      constraints.maxWidth >= kTabletBreakpoint;
                  return isWideLayout
                      ? _buildWideLayout(
                          context, _events) // Passa _events (UTC)
                      : _buildMobileLayout(
                          context, _events); // Passa _events (UTC)
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
  // (Layouts idênticos ao seu código original, apenas
  //  com a função _handleTodayTap implementada)

  Widget _buildMobileLayout(
      BuildContext context, Map<DateTime, List<CalendarEvent>> eventsMapUtc) {
    final orientation = MediaQuery.of(context).orientation;

    void _handleTodayTap() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!_isSameMonth(_focusedDay, today)) {
        _onPageChanged(today);
      }
      _onDaySelected(today, today);
    }

    if (orientation == Orientation.landscape) {
      // Layout Paisagem (Estrutura como antes)
      return Row(
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CalendarHeader(
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
                        focusedDay: _focusedDay,
                        selectedDay: _selectedDay,
                        onDaySelected: _onDaySelected,
                        onPageChanged: _onPageChanged,
                        isDesktop: false,
                        events: eventsMapUtc, // Usa mapa UTC
                        personalDayNumber: _personalDayNumber,
                      ),
                      if (_isChangingMonth)
                        Positioned.fill(
                          child: Container(/* Loading */),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(/* ... */),
          Expanded(
            flex: 4,
            child: DayDetailPanel(
              selectedDay: _selectedDay,
              personalDayNumber: _personalDayNumber,
              events: _selectedDay != null
                  ? _getRawEventsForDay(_selectedDay!)
                  : [],
              onAddTask: _openAddTaskModal,
              onEditTask: (task) => _openAddTaskModal(task: task),
              onDeleteTask: _onDeleteTask,
              onDuplicateTask: _onDuplicateTask,
              onToggleTask: _onToggleTask,
              onJournalTap: _openJournalEditor,
            ),
          ),
        ],
      );
    } else {
      // Retrato (Estrutura como antes)
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                CalendarHeader(
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
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      onDaySelected: _onDaySelected,
                      onPageChanged: _onPageChanged,
                      isDesktop: false,
                      events: eventsMapUtc, // Usa mapa UTC
                      personalDayNumber: _personalDayNumber,
                    ),
                    if (_isChangingMonth)
                      Positioned.fill(
                        child: Container(/* Loading */),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: DayDetailPanel(
              selectedDay: _selectedDay,
              personalDayNumber: _personalDayNumber,
              events: _selectedDay != null
                  ? _getRawEventsForDay(_selectedDay!)
                  : [],
              onAddTask: _openAddTaskModal,
              onEditTask: (task) => _openAddTaskModal(task: task),
              onDeleteTask: _onDeleteTask,
              onDuplicateTask: _onDuplicateTask,
              onToggleTask: _onToggleTask,
              onJournalTap: _openJournalEditor,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildWideLayout(
      BuildContext context, Map<DateTime, List<CalendarEvent>> eventsMapUtc) {
    void _handleTodayTap() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (!_isSameMonth(_focusedDay, today)) {
        _onPageChanged(today);
      }
      _onDaySelected(today, today);
    }

    // Estrutura como antes
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
                          focusedDay: _focusedDay,
                          selectedDay: _selectedDay,
                          onDaySelected: _onDaySelected,
                          onPageChanged: _onPageChanged,
                          isDesktop: true,
                          calendarWidth: constraints.maxWidth,
                          events: eventsMapUtc, // Usa mapa UTC
                          personalDayNumber: _personalDayNumber,
                        ),
                        if (_isChangingMonth)
                          Positioned.fill(
                            child: Container(/* Loading */),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(/* ... */),
        Expanded(
          flex: 1,
          child: DayDetailPanel(
            selectedDay: _selectedDay,
            personalDayNumber: _personalDayNumber,
            events:
                _selectedDay != null ? _getRawEventsForDay(_selectedDay!) : [],
            isDesktop: true,
            onAddTask: _openAddTaskModal,
            onEditTask: (task) => _openAddTaskModal(task: task),
            onDeleteTask: _onDeleteTask,
            onDuplicateTask: _onDuplicateTask,
            onToggleTask: _onToggleTask,
            onJournalTap: _openJournalEditor,
          ),
        ),
      ],
    );
  }
} // Fim _CalendarScreenState
