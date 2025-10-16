// lib/features/calendar/presentation/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
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

  Map<DateTime, List<CalendarEvent>> _events = {};
  bool _isLoading = true;
  int? _personalDayNumber;

  final ScrollController _calendarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _userId = _authRepository.getCurrentUser()!.uid;
    _loadInitialData();
  }

  @override
  void dispose() {
    _calendarScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _fetchEventsForMonth(_focusedDay);
    if (_selectedDay != null) {
      _updatePersonalDay(_selectedDay!);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEventsForMonth(DateTime month) async {
    if (!mounted) return;
    final tasks = await _firestoreService.getTasksForCalendar(_userId, month);
    final List<CalendarEvent> fetchedEvents = [];
    for (final task in tasks) {
      final DateTime eventDate = task.dueDate ?? task.createdAt;
      final eventType = task.journeyId != null && task.journeyId!.isNotEmpty
          ? EventType.goalTask
          : EventType.task;
      final event = CalendarEvent(
        title: task.text,
        type: eventType,
        date: eventDate,
      );
      fetchedEvents.add(event);
    }
    final groupedEvents = groupBy(
        fetchedEvents,
        (event) =>
            DateTime.utc(event.date.year, event.date.month, event.date.day));
    if (mounted) {
      setState(() {
        _events = groupedEvents;
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
      }
      _updatePersonalDay(selectedDay);
    }
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void _openAddTaskModalForSelectedDay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData,
        preselectedDate: _selectedDay,
      ),
    );
  }

  void _onPageChanged({bool? isNext, DateTime? newFocusedDay}) {
    final pageDay = newFocusedDay ??
        (isNext == true
            ? DateTime(_focusedDay.year, _focusedDay.month + 1)
            : DateTime(_focusedDay.year, _focusedDay.month - 1));

    setState(() => _focusedDay = pageDay);
    _fetchEventsForMonth(pageDay);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: _isLoading
              ? const Center(child: CustomLoadingSpinner())
              : isDesktop
                  ? _buildDesktopLayout(constraints)
                  : _buildMobileLayout(),
          floatingActionButton: isDesktop
              ? null
              : CalendarFab(onAddTask: _openAddTaskModalForSelectedDay),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          CalendarHeader(
            focusedDay: _focusedDay,
            onTodayButtonTap: () {
              final now = DateTime.now();
              if (isSameDay(_focusedDay, now)) return;
              setState(() {
                _focusedDay = now;
                _selectedDay = now;
              });
              _fetchEventsForMonth(_focusedDay);
              _updatePersonalDay(_focusedDay);
            },
            onLeftArrowTap: () => _onPageChanged(isNext: false),
            onRightArrowTap: () => _onPageChanged(isNext: true),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CustomCalendar(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    onDaySelected: _onDaySelected,
                    onPageChanged: (day) => _onPageChanged(newFocusedDay: day),
                    isDesktop: false,
                    personalDayNumber: _personalDayNumber,
                    events: _events,
                  ),
                  const SizedBox(height: 16),
                  DayDetailPanel(
                    selectedDay: _selectedDay,
                    personalDayNumber: _personalDayNumber,
                    events: _selectedDay != null
                        ? _getEventsForDay(_selectedDay!)
                        : [],
                    onAddTask: _openAddTaskModalForSelectedDay,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    final availableWidth = (constraints.maxWidth - 48) * (3 / 5);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                CalendarHeader(
                  focusedDay: _focusedDay,
                  onTodayButtonTap: () {
                    final now = DateTime.now();
                    if (isSameDay(_focusedDay, now)) return;
                    setState(() {
                      _focusedDay = now;
                      _selectedDay = now;
                    });
                    _fetchEventsForMonth(_focusedDay);
                    _updatePersonalDay(_focusedDay);
                  },
                  onLeftArrowTap: () => _onPageChanged(isNext: false),
                  onRightArrowTap: () => _onPageChanged(isNext: true),
                ),
                const SizedBox(height: 8),
                Expanded(
                  // *** INÍCIO DA ATUALIZAÇÃO ***
                  // 1. Envelopamos o Scrollbar com um widget Theme.
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      // 2. Definimos um tema customizado para a barra de rolagem.
                      scrollbarTheme: ScrollbarThemeData(
                        // 3. A cor da barra agora usa a cor primária do app.
                        thumbColor:
                            MaterialStateProperty.all(AppColors.primary),
                        // Opcional: Adicionamos um arredondamento suave.
                        radius: const Radius.circular(10),
                        // Opcional: Ajustamos a espessura.
                        thickness: MaterialStateProperty.all(8),
                      ),
                    ),
                    child: Scrollbar(
                      controller: _calendarScrollController,
                      // 4. Removemos 'thumbVisibility' e 'trackVisibility' para
                      //    que a barra só apareça ao passar o mouse.
                      child: SingleChildScrollView(
                        controller: _calendarScrollController,
                        padding: const EdgeInsets.only(right: 16.0),
                        child: CustomCalendar(
                          focusedDay: _focusedDay,
                          selectedDay: _selectedDay,
                          onDaySelected: _onDaySelected,
                          onPageChanged: (day) =>
                              _onPageChanged(newFocusedDay: day),
                          isDesktop: true,
                          calendarWidth: availableWidth - 16.0,
                          personalDayNumber: _personalDayNumber,
                          events: _events,
                        ),
                      ),
                    ),
                  ),
                  // *** FIM DA ATUALIZAÇÃO ***
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: DayDetailPanel(
              selectedDay: _selectedDay,
              personalDayNumber: _personalDayNumber,
              events:
                  _selectedDay != null ? _getEventsForDay(_selectedDay!) : [],
              isDesktop: true,
              onAddTask: _openAddTaskModalForSelectedDay,
            ),
          ),
        ],
      ),
    );
  }
}
