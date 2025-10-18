// lib/features/calendar/presentation/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/journal/presentation/journal_editor_screen.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';
import '../models/event_model.dart';
import 'package:sincro_app_flutter/common/widgets/custom_calendar.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';

import 'widgets/calendar_header.dart';
import 'widgets/day_detail_panel.dart';
import 'widgets/calendar_fab.dart';

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

  Map<DateTime, List<CalendarEvent>> _events = {};
  Map<DateTime, List<dynamic>> _rawEvents = {};
  int? _personalDayNumber;

  // --- INÍCIO DA CORREÇÃO (Gerenciamento de Loading) ---

  // Controla o loading inicial da tela inteira
  bool _isScreenLoading = true;
  // Controla o loading ao trocar de mês (sobre o calendário)
  bool _isChangingMonth = false;

  // --- FIM DA CORREÇÃO ---

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _userId = _authRepository.getCurrentUser()!.uid;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // _isScreenLoading já é true por padrão
    await _fetchEventsForMonth(_focusedDay);
    if (mounted && _selectedDay != null) {
      _updatePersonalDay(_selectedDay!);
    }
    if (mounted) {
      // Desativa o loading de tela cheia
      setState(() => _isScreenLoading = false);
    }
  }

  Future<void> _fetchEventsForMonth(DateTime month) async {
    if (!mounted) return;

    // --- INÍCIO DA CORREÇÃO ---
    // REMOVIDO: setState(() => _isLoading = true);
    // Esta linha era a causa da "piscada" em todas as ações.
    // --- FIM DA CORREÇÃO ---

    final tasksFuture = _firestoreService.getTasksForCalendar(_userId, month);
    final journalFuture =
        _firestoreService.getJournalEntriesForMonth(_userId, month);
    final results = await Future.wait([tasksFuture, journalFuture]);

    final tasks = results[0] as List<TaskModel>;
    final journalEntries = results[1] as List<JournalEntry>;
    final allRawEvents = <dynamic>[...tasks, ...journalEntries];

    _rawEvents = groupBy<dynamic, DateTime>(allRawEvents, (event) {
      DateTime date;
      if (event is TaskModel) {
        date = event.dueDate ?? event.createdAt;
      } else {
        date = (event as JournalEntry).createdAt;
      }
      return DateTime.utc(date.year, date.month, date.day);
    });

    final allCalendarEvents = allRawEvents
        .map((event) {
          if (event is TaskModel) {
            return CalendarEvent(
              title: event.text,
              date: event.dueDate ?? event.createdAt,
              type: event.journeyId != null && event.journeyId!.isNotEmpty
                  ? EventType.goalTask
                  : EventType.task,
            );
          } else if (event is JournalEntry) {
            return CalendarEvent(
              title: event.content,
              date: event.createdAt,
              type: EventType.journal,
            );
          }
          return null;
        })
        .whereType<CalendarEvent>()
        .toList();

    _events = groupBy<CalendarEvent, DateTime>(
      allCalendarEvents,
      (event) =>
          DateTime.utc(event.date.year, event.date.month, event.date.day),
    );

    if (mounted) {
      // --- INÍCIO DA CORREÇÃO ---
      // Apenas atualiza o estado com os novos dados
      // e desliga o loading de troca de mês.
      setState(() {
        _isChangingMonth = false;
      });
      // --- FIM DA CORREÇÃO ---
    }
  }

  void _updatePersonalDay(DateTime date) {
    if (widget.userData.dataNasc.isNotEmpty) {
      final engine = NumerologyEngine(
          nomeCompleto: widget.userData.nomeAnalise,
          dataNascimento: widget.userData.dataNasc);
      if (mounted) {
        setState(() =>
            _personalDayNumber = engine.calculatePersonalDayForDate(date));
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      if (mounted) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        _updatePersonalDay(selectedDay);
      }
    }
  }

  List<dynamic> _getRawEventsForDay(DateTime day) {
    return _rawEvents[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void _openAddTaskModal({TaskModel? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData,
        preselectedDate: task == null ? _selectedDay : null,
        taskToEdit: task,
      ),
      // _fetchEventsForMonth agora apenas atualiza os dados, sem "piscar"
    ).then((_) => _fetchEventsForMonth(_focusedDay));
  }

  void _openNewJournalEntry() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (context) => JournalEditorScreen(userData: widget.userData),
          fullscreenDialog: true,
        ))
        .then((_) => _fetchEventsForMonth(_focusedDay));
  }

  void _openJournalEditor(JournalEntry entry) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (context) => JournalEditorScreen(
            userData: widget.userData,
            entry: entry,
          ),
          fullscreenDialog: true,
        ))
        .then((_) => _fetchEventsForMonth(_focusedDay));
  }

  void _onPageChanged(DateTime newFocusedDay) {
    if (mounted) {
      // --- INÍCIO DA CORREÇÃO ---
      // Ativa o loading de troca de mês
      setState(() {
        _focusedDay = newFocusedDay;
        _isChangingMonth = true;
      });
      // Busca os eventos. O próprio _fetchEventsForMonth vai
      // desligar o _isChangingMonth e chamar setState.
      _fetchEventsForMonth(newFocusedDay);
      // --- FIM DA CORREÇÃO ---
    }
  }

  void _onToggleTask(TaskModel task, bool isCompleted) async {
    await _firestoreService.updateTaskCompletion(_userId, task.id,
        completed: isCompleted);
    // Apenas atualiza os dados, sem "piscar"
    _fetchEventsForMonth(_focusedDay);
  }

  void _onDeleteTask(TaskModel task) async {
    await _firestoreService.deleteTask(_userId, task.id);
    // Apenas atualiza os dados, sem "piscar"
    _fetchEventsForMonth(_focusedDay);
  }

  void _onDuplicateTask(TaskModel task) async {
    final duplicatedTask =
        task.copyWith(id: '', completed: false, createdAt: DateTime.now());
    await _firestoreService.addTask(_userId, duplicatedTask);
    // Apenas atualiza os dados, sem "piscar"
    _fetchEventsForMonth(_focusedDay);
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // --- INÍCIO DA CORREÇÃO ---
        // Usa a nova variável _isScreenLoading para o loading inicial
        child: _isScreenLoading
            ? const Center(child: CustomLoadingSpinner())
            : LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= kTabletBreakpoint) {
                    return _buildWideLayout(context);
                  } else {
                    return _buildMobileLayout(context);
                  }
                },
              ),
        // --- FIM DA CORREÇÃO ---
      ),
      floatingActionButton: CalendarFab(
        onAddTask: () => _openAddTaskModal(),
        onAddJournalEntry: _openNewJournalEntry,
      ),
    );
  }

  // Layout padrão para mobile (vertical)
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              CalendarHeader(
                focusedDay: _focusedDay,
                onTodayButtonTap: () {
                  final now = DateTime.now();
                  if (!_isSameMonth(_focusedDay, now)) {
                    _onPageChanged(now);
                  }
                  _onDaySelected(now, now);
                },
                onLeftArrowTap: () => _onPageChanged(
                    DateTime(_focusedDay.year, _focusedDay.month - 1)),
                onRightArrowTap: () => _onPageChanged(
                    DateTime(_focusedDay.year, _focusedDay.month + 1)),
              ),
              const SizedBox(height: 8),
              // --- INÍCIO DA CORREÇÃO ---
              // Envolve o calendário em um Stack para mostrar o loading
              Stack(
                alignment: Alignment.center,
                children: [
                  CustomCalendar(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    onDaySelected: _onDaySelected,
                    onPageChanged: _onPageChanged,
                    isDesktop: false,
                    events: _events,
                    personalDayNumber: _personalDayNumber,
                  ),
                  // Mostra o spinner sobre o calendário se _isChangingMonth for true
                  if (_isChangingMonth)
                    Container(
                      height: 300, // Altura aproximada do calendário
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Center(child: CustomLoadingSpinner()),
                    ),
                ],
              ),
              // --- FIM DA CORREÇÃO ---
            ],
          ),
        ),
        Expanded(
          child: DayDetailPanel(
            selectedDay: _selectedDay,
            personalDayNumber: _personalDayNumber,
            events:
                _selectedDay != null ? _getRawEventsForDay(_selectedDay!) : [],
            onAddTask: () => _openAddTaskModal(),
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

  // Novo layout para telas largas (horizontal/split-view)
  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        // Painel Esquerdo (Calendário)
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                CalendarHeader(
                  focusedDay: _focusedDay,
                  onTodayButtonTap: () {
                    final now = DateTime.now();
                    if (!_isSameMonth(_focusedDay, now)) {
                      _onPageChanged(now);
                    }
                    _onDaySelected(now, now);
                  },
                  onLeftArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month - 1)),
                  onRightArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month + 1)),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // --- INÍCIO DA CORREÇÃO ---
                    // Envolve o calendário em um Stack para mostrar o loading
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
                          events: _events,
                          personalDayNumber: _personalDayNumber,
                        ),
                        // Mostra o spinner sobre o calendário se _isChangingMonth for true
                        if (_isChangingMonth)
                          Container(
                            // Altura dinâmica baseada na largura (aprox. 6 linhas)
                            height: (constraints.maxWidth / 7) * 6,
                            decoration: BoxDecoration(
                              color: AppColors.background.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Center(child: CustomLoadingSpinner()),
                          ),
                      ],
                    );
                    // --- FIM DA CORREÇÃO ---
                  },
                ),
              ],
            ),
          ),
        ),
        // Divisor visual
        VerticalDivider(
            width: 1, thickness: 1, color: AppColors.border.withOpacity(0.5)),
        // Painel Direito (Detalhes do Dia)
        Expanded(
          flex: 1,
          child: DayDetailPanel(
            selectedDay: _selectedDay,
            personalDayNumber: _personalDayNumber,
            events:
                _selectedDay != null ? _getRawEventsForDay(_selectedDay!) : [],
            onAddTask: () => _openAddTaskModal(),
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
