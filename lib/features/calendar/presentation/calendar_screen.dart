// lib/features/calendar/presentation/calendar_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
// ATUALIZADO: Importa ParsedTask
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import '../models/event_model.dart';
import 'package:sincro_app_flutter/common/widgets/custom_calendar.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_input_modal.dart';
import 'widgets/calendar_header.dart';
import 'widgets/day_detail_panel.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart';

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
    _selectedDay = DateTime(now.year, now.month, now.day);
    // Garante que userId seja pego com segurança
    _userId = _authRepository.getCurrentUser()?.uid ?? '';
    if (_userId.isEmpty) {
      print("ERRO GRAVE: CalendarScreen iniciada sem userId!");
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
    super.dispose();
  }

  Future<void> _initializeStreams(DateTime month,
      {bool isInitialLoad = false}) async {
    // Garante que não prossiga se userId for inválido
    if (_userId.isEmpty) {
      print("ERRO: Tentativa de inicializar streams sem userId.");
      if (mounted) {
        setState(() {
          _isChangingMonth = false;
          _isScreenLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        // Só ativa o loading de tela inteira na carga inicial
        if (isInitialLoad) _isScreenLoading = true;

        // Limpa os dados existentes antes de carregar novos
        _events = {};
        _rawEvents = {};
        _currentTasksDueDate = [];
        _currentTasksCreatedAt = [];
      });
    }

    // Cancela as streams existentes antes de criar novas
    await _tasksDueDateSubscription?.cancel();
    await _tasksCreatedAtSubscription?.cancel();

    final monthUtc = DateTime.utc(month.year, month.month);

    _tasksDueDateSubscription = _firestoreService
        .getTasksDueDateStreamForMonth(_userId, monthUtc)
        .listen(_onTasksDueDateUpdated, onError: (e, s) {
      print("Erro no stream de tasks (dueDate): $e\n$s");
      _onTasksDueDateUpdated([]);
    });

    _tasksCreatedAtSubscription = _firestoreService
        .getTasksCreatedAtStreamForMonth(_userId, monthUtc)
        .listen(_onTasksCreatedAtUpdated, onError: (e, s) {
      print("Erro no stream de tasks (createdAt): $e\n$s");
      _onTasksCreatedAtUpdated([]);
    });

    if (isInitialLoad && mounted && _selectedDay != null) {
      _updatePersonalDay(_selectedDay!);
    }
    if (isInitialLoad && mounted) {
      // O setState será chamado pelo _processEvents
      // setState(() => _isScreenLoading = false);
    }
  }

  void _onTasksDueDateUpdated(List<TaskModel> tasks) {
    _currentTasksDueDate = tasks;
    _processEvents();
  }

  void _onTasksCreatedAtUpdated(List<TaskModel> tasks) {
    _currentTasksCreatedAt = tasks;
    _processEvents();
  }

  void _processEvents() {
    Map<DateTime, List<CalendarEvent>> newEvents = {};
    Map<DateTime, List<dynamic>> newRawEvents = {};

    try {
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
      final allRawData = <dynamic>[...allTasks];

      newRawEvents = groupBy<dynamic, DateTime>(allRawData, (event) {
        DateTime localDate;
        if (event is TaskModel) {
          localDate = event.dueDate ?? event.createdAt;
        } else {
          localDate = DateTime.now();
        }
        return DateTime(localDate.year, localDate.month, localDate.day);
      });

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
            } else {
              return null;
            }
            return CalendarEvent(
                title: title, date: eventDate, type: eventType);
          })
          .whereType<CalendarEvent>()
          .toList();

      newEvents =
          groupBy<CalendarEvent, DateTime>(allCalendarEvents, (calendarEvent) {
        final localDate = calendarEvent.date;
        return DateTime.utc(localDate.year, localDate.month, localDate.day);
      });
    } catch (e, stackTrace) {
      print("Erro em _processEvents: $e\n$stackTrace");
      newRawEvents = {};
      newEvents = {};
    } finally {
      if (mounted) {
        // Faz todas as atualizações em um único setState para evitar reconstruções desnecessárias
        setState(() {
          _events = newEvents;
          _rawEvents = newRawEvents;
          _isChangingMonth = false;
          _isScreenLoading = false;
        });
      }
    }
  }

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

  List<dynamic> _getRawEventsForDay(DateTime day) {
    final localMidnightKey = DateTime(day.year, day.month, day.day);
    return _rawEvents[localMidnightKey] ?? [];
  }

  // ---
  // --- ATUALIZAÇÃO PRINCIPAL AQUI ---
  // ---
  void _openAddTaskModal({TaskModel? task}) async {
    // Usa _selectedDay como data pré-selecionada SE não estiver editando
    final preselectedDateMidnight = (task == null && _selectedDay != null)
        ? DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)
        : null; // Se estiver editando (task != null), não pré-seleciona data

    // Verifica se userId é válido antes de abrir
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: ID do usuário não encontrado.')));
      return;
    }

    await showModalBottomSheet<void>(
      // Alterado para void
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskInputModal(
        userData: widget.userData,
        userId: _userId, // <-- Passa o userId

        // --- ATUALIZADO: Usa os parâmetros corretos ---
        initialDueDate: preselectedDateMidnight, // Renomeado
        taskToEdit: task, // Mantido
        initialTaskText: task?.text, // Passa o texto se estiver editando
        // --- FIM DA ATUALIZAÇÃO ---

        // Usa a nova assinatura com ParsedTask
        onAddTask: (ParsedTask parsedTask) {
          // Verifica se está editando ou adicionando
          if (task != null) {
            // --- LÓGICA DE EDIÇÃO ---
            // Cria um TaskModel atualizado usando copyWith
            final updatedTask = task.copyWith(
              text: parsedTask.cleanText,
              // Usa a data do parser OU a data original da tarefa se o parser não encontrar
              dueDate: parsedTask.dueDate?.toUtc() ?? task.dueDate?.toUtc(),
              journeyId: parsedTask.journeyId, // Usa o ID da jornada do parser
              journeyTitle:
                  parsedTask.journeyTitle, // Usa o título da jornada do parser
              tags: parsedTask.tags, // Usa as tags do parser
              // TODO: Atualizar personalDay se necessário
            );
            // Chama o método de atualização do Firestore
            _firestoreService
                .updateTask(_userId, updatedTask)
                .catchError((error) {
              print("Erro ao ATUALIZAR tarefa pelo calendário: $error");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Erro ao atualizar tarefa: $error'),
                      backgroundColor: Colors.red),
                );
              }
            });
          } else {
            // --- LÓGICA DE ADIÇÃO ---
            final newTask = TaskModel(
              id: '',
              text: parsedTask.cleanText,
              createdAt: DateTime.now().toUtc(),
              // Usa a data do parser OU a data pré-selecionada se o parser não encontrar
              dueDate: parsedTask.dueDate?.toUtc() ??
                  preselectedDateMidnight?.toUtc(),
              journeyId: parsedTask.journeyId,
              journeyTitle: parsedTask.journeyTitle,
              tags: parsedTask.tags,
              // TODO: Adicionar lógica para pegar o personalDay se necessário
            );
            _firestoreService.addTask(_userId, newTask).catchError((error) {
              print("Erro ao ADICIONAR tarefa pelo calendário: $error");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Erro ao salvar tarefa: $error'),
                      backgroundColor: Colors.red),
                );
              }
            });
          }
        },
      ),
    );
    // REMOVIDO: .then(...) desnecessário com streams
  }
  // --- FIM DA ATUALIZAÇÃO ---
  // ---

  // _onPageChanged, _onToggleTask, _handleTaskTap, _isSameMonth, build principal,
  // _buildMobileLayout, _buildWideLayout
  // (Seu código original, sem alterações)
  // --- (Código omitido para brevidade) ---
  Future<void> _onPageChanged(DateTime newFocusedDay) async {
    if (!mounted) return;

    final localMidnightFocusedDay =
        DateTime(newFocusedDay.year, newFocusedDay.month, newFocusedDay.day);

    // Se mudou o mês ou ano
    if (localMidnightFocusedDay.year != _focusedDay.year ||
        localMidnightFocusedDay.month != _focusedDay.month) {
      // Primeiro atualiza o estado para mostrar o loading
      setState(() {
        _focusedDay = localMidnightFocusedDay;
        _isChangingMonth = true;
        _selectedDay = null;
        _personalDayNumber = null;
      });

      // Aguarda a inicialização dos streams
      await _initializeStreams(localMidnightFocusedDay);

      // Não precisa setar _isChangingMonth para false aqui pois
      // _processEvents já faz isso quando termina de processar os eventos
    }
    // Se estiver no mesmo mês, só atualiza o dia focado
    else if (!isSameDay(_focusedDay, localMidnightFocusedDay)) {
      setState(() {
        _focusedDay = localMidnightFocusedDay;
      });
    }
  }

  void _onToggleTask(TaskModel task, bool isCompleted) async {
    try {
      await _firestoreService.updateTaskCompletion(_userId, task.id,
          completed: isCompleted);
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

  void _handleTaskTap(TaskModel task) {
    print("Calendário: Tarefa tocada: ${task.id} - ${task.text}");
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return TaskDetailModal(
          task: task,
          userData: widget.userData,
        );
      },
    );
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
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
      body: SafeArea(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTaskModal,
        backgroundColor: AppColors.primary,
        tooltip: 'Nova Tarefa',
        heroTag: 'calendar_fab',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMobileLayout(
      BuildContext context, Map<DateTime, List<CalendarEvent>> eventsMapUtc) {
    final orientation = MediaQuery.of(context).orientation;

    void _handleTodayTap() {
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
                          onTodayButtonTap: _handleTodayTap,
                          onLeftArrowTap: () => _onPageChanged(DateTime(
                              _focusedDay.year, _focusedDay.month - 1)),
                          onRightArrowTap: () => _onPageChanged(DateTime(
                              _focusedDay.year, _focusedDay.month + 1)),
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
                            if (_isChangingMonth)
                              Positioned.fill(
                                child: Container(
                                  color: AppColors.background.withOpacity(0.5),
                                  child: const Center(
                                    child: CustomLoadingSpinner(),
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
              selectedDay: _selectedDay,
              personalDayNumber: _personalDayNumber,
              events: _selectedDay != null
                  ? _getRawEventsForDay(_selectedDay!)
                  : [],
              isDesktop: false,
              onAddTask: _openAddTaskModal,
              onToggleTask: _onToggleTask,
              onTaskTap: _handleTaskTap,
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
                  focusedDay: _focusedDay,
                  onTodayButtonTap: _handleTodayTap,
                  onLeftArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month - 1)),
                  onRightArrowTap: () => _onPageChanged(
                      DateTime(_focusedDay.year, _focusedDay.month + 1)),
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
                    if (_isChangingMonth)
                      Positioned.fill(
                        child: Container(
                          color: AppColors.background.withOpacity(0.5),
                          child: const Center(
                            child: CustomLoadingSpinner(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8.0),
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
              isDesktop: false,
              onAddTask: _openAddTaskModal,
              onToggleTask: _onToggleTask,
              onTaskTap: _handleTaskTap,
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
                        if (_isChangingMonth)
                          Positioned.fill(
                            child: Container(
                              color: AppColors.background.withOpacity(0.5),
                              child: const Center(
                                child: CustomLoadingSpinner(),
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
              selectedDay: _selectedDay,
              personalDayNumber: _personalDayNumber,
              events: _selectedDay != null
                  ? _getRawEventsForDay(_selectedDay!)
                  : [],
              isDesktop: true,
              onAddTask: _openAddTaskModal,
              onToggleTask: _onToggleTask,
              onTaskTap: _handleTaskTap,
            ),
          ),
        ),
      ],
    );
  }
} // Fim _CalendarScreenState
