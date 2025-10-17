// lib/features/calendar/presentation/calendar_screen.dart
import 'package:flutter/material.dart';
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
  final FirestoreService _firestoreService = FirestoreService();
  final AuthRepository _authRepository = AuthRepository();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late final String _userId;

  // Mapa para os marcadores do CustomCalendar
  Map<DateTime, List<CalendarEvent>> _calendarEvents = {};
  // Mapa com os dados brutos para o painel de detalhes
  Map<DateTime, List<dynamic>> _rawEvents = {};

  bool _isLoading = true;
  int? _personalDayNumber;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _userId = _authRepository.getCurrentUser()!.uid;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchEventsForMonth(_focusedDay);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEventsForMonth(DateTime month) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final tasksFuture = _firestoreService.getTasksForCalendar(_userId, month);
    final journalFuture =
        _firestoreService.getJournalEntriesForMonth(_userId, month);

    final results = await Future.wait([tasksFuture, journalFuture]);

    final tasks = results[0] as List<TaskModel>;
    final journalEntries = results[1] as List<JournalEntry>;

    final allRawEvents = <dynamic>[...tasks, ...journalEntries];

    _rawEvents = groupBy<dynamic, DateTime>(
      allRawEvents,
      (event) {
        DateTime date;
        if (event is TaskModel) {
          date = event.dueDate ?? event.createdAt;
        } else {
          date = (event as JournalEntry).createdAt;
        }
        return DateTime.utc(date.year, date.month, date.day);
      },
    );

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

    _calendarEvents = groupBy<CalendarEvent, DateTime>(
      allCalendarEvents,
      (event) =>
          DateTime.utc(event.date.year, event.date.month, event.date.day),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_selectedDay != null) {
          _updatePersonalDay(_selectedDay!);
        }
      });
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
    ).then((_) {
      _fetchEventsForMonth(_focusedDay);
    });
  }

  void _onPageChanged(DateTime newFocusedDay) {
    if (!mounted) return;
    setState(() {
      _focusedDay = newFocusedDay;
      if (_selectedDay == null || !isSameMonth(_selectedDay, newFocusedDay)) {
        _selectedDay = newFocusedDay;
        _updatePersonalDay(newFocusedDay);
      }
    });
    _fetchEventsForMonth(newFocusedDay);
  }

  void _onToggleTask(TaskModel task, bool isCompleted) async {
    await _firestoreService.updateTaskCompletion(_userId, task.id,
        completed: isCompleted);
    _fetchEventsForMonth(_focusedDay);
  }

  void _onDeleteTask(TaskModel task) async {
    await _firestoreService.deleteTask(_userId, task.id);
    _fetchEventsForMonth(_focusedDay);
  }

  void _onDuplicateTask(TaskModel task) async {
    final duplicatedTask = task.copyWith(
      id: '',
      completed: false,
      createdAt: DateTime.now(),
    );
    await _firestoreService.addTask(_userId, duplicatedTask);
    _fetchEventsForMonth(_focusedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CustomLoadingSpinner())
            : _buildMobileLayout(),
      ),
      floatingActionButton: CalendarFab(onAddTask: () => _openAddTaskModal()),
    );
  }

  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          CalendarHeader(
            focusedDay: _focusedDay,
            onTodayButtonTap: () {
              final now = DateTime.now();
              if (!isSameMonth(_focusedDay, now)) {
                _onPageChanged(now);
              }
              _onDaySelected(now, now);
            },
            onLeftArrowTap: () => _onPageChanged(
                DateTime(_focusedDay.year, _focusedDay.month - 1)),
            onRightArrowTap: () => _onPageChanged(
                DateTime(_focusedDay.year, _focusedDay.month + 1)),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // *** CORREÇÃO FINAL APLICADA AQUI ***
                  CustomCalendar(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    onDaySelected: _onDaySelected,
                    onPageChanged: _onPageChanged,
                    events:
                        _calendarEvents, // A propriedade 'events' está correta agora
                  ),
                  const SizedBox(height: 16),
                  DayDetailPanel(
                    selectedDay: _selectedDay,
                    personalDayNumber: _personalDayNumber,
                    events: _selectedDay != null
                        ? _getRawEventsForDay(_selectedDay!)
                        : [],
                    onAddTask: () => _openAddTaskModal(),
                    onEditTask: (task) => _openAddTaskModal(task: task),
                    onDeleteTask: _onDeleteTask,
                    onDuplicateTask: _onDuplicateTask,
                    onToggleTask: _onToggleTask,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
