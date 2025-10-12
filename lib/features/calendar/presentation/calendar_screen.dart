// lib/features/calendar/presentation/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';
import '../models/event_model.dart';
import 'package:sincro_app_flutter/common/widgets/custom_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

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
  UserModel? _currentUserModel;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _userId = _authRepository.getCurrentUser()!.uid;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _currentUserModel = await _firestoreService.getUserData(_userId);
    // await _fetchEventsForMonth(_focusedDay);
    if (_selectedDay != null) {
      _updatePersonalDay(_selectedDay!);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEventsForMonth(DateTime month) async {
    if (!mounted) return;
    // setState(() => _isLoading = true);
    final fetchedEvents =
        await _firestoreService.getEventsForMonth(_userId, month);
    final groupedEvents = groupBy(
        fetchedEvents,
        (event) =>
            DateTime.utc(event.date.year, event.date.month, event.date.day));
    if (mounted) {
      setState(() {
        _events = groupedEvents;
        // _isLoading = false;
      });
    }
  }

  void _updatePersonalDay(DateTime date) {
    if (_currentUserModel != null && _currentUserModel!.dataNasc.isNotEmpty) {
      final engine = NumerologyEngine(
          nomeCompleto: _currentUserModel!.nomeAnalise,
          dataNascimento: _currentUserModel!.dataNasc);
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
          floatingActionButton:
              isDesktop ? null : const _CustomFloatingActionButton(),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          _buildCalendarHeader(),
          _buildDaysOfWeekHeader(), // Barra dos dias da semana (Fixa)
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CustomCalendar(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    onDaySelected: _onDaySelected,
                    onPageChanged: (day) => setState(() => _focusedDay = day),
                    isDesktop: false,
                    personalDayNumber: _personalDayNumber,
                    events: _events,
                  ),
                  const SizedBox(height: 16),
                  _DayDetailPanel(
                    selectedDay: _selectedDay,
                    personalDayNumber: _personalDayNumber,
                    events: const [], // Lista vazia por agora
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
                _buildCalendarHeader(),
                _buildDaysOfWeekHeader(), // Barra dos dias da semana (Fixa)
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: CustomCalendar(
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      onDaySelected: _onDaySelected,
                      onPageChanged: (day) => setState(() => _focusedDay = day),
                      isDesktop: true,
                      calendarWidth: availableWidth,
                      personalDayNumber: _personalDayNumber,
                      events: _events,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: _DayDetailPanel(
              selectedDay: _selectedDay,
              personalDayNumber: _personalDayNumber,
              events: const [], // Lista vazia por agora
              isDesktop: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            toBeginningOfSentenceCase(
                DateFormat.yMMMM('pt_BR').format(_focusedDay))!,
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => _onPageChanged(isNext: false),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime.now();
                    _selectedDay = _focusedDay;
                  });
                  // _fetchEventsForMonth(_focusedDay);
                  _updatePersonalDay(_focusedDay);
                },
                child: const Text('Hoje',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () => _onPageChanged(isNext: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ALTERAÇÃO 2: Novo widget para a barra dos dias da semana ---
  Widget _buildDaysOfWeekHeader() {
    final days = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    return Row(
      children: days
          .map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: AppColors.tertiaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  void _onPageChanged({required bool isNext}) {
    final newFocusedDay = isNext
        ? DateTime(_focusedDay.year, _focusedDay.month + 1)
        : DateTime(_focusedDay.year, _focusedDay.month - 1);
    setState(() => _focusedDay = newFocusedDay);
    // _fetchEventsForMonth(newFocusedDay);
  }
}

class _DayDetailPanel extends StatelessWidget {
  final DateTime? selectedDay;
  final int? personalDayNumber;
  final List<CalendarEvent> events;
  final bool isDesktop;

  const _DayDetailPanel({
    this.selectedDay,
    this.personalDayNumber,
    required this.events,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null && isDesktop) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 48, color: AppColors.tertiaryText),
              SizedBox(height: 16),
              Text(
                "Selecione um dia",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryText),
              ),
              Text(
                "Escolha uma data para ver os detalhes.",
                style: TextStyle(color: AppColors.tertiaryText),
              ),
            ],
          ),
        ),
      );
    }

    if (selectedDay == null) {
      return const SizedBox.shrink();
    }

    final formattedDate = toBeginningOfSentenceCase(
        DateFormat("EEEE, 'dia' d", 'pt_BR').format(selectedDay!));

    return Container(
      decoration: BoxDecoration(
          color: isDesktop ? AppColors.cardBackground : Colors.transparent,
          borderRadius: isDesktop ? BorderRadius.circular(12) : null,
          border: isDesktop
              ? null
              : Border(top: BorderSide(color: Colors.grey.shade800))),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              if (personalDayNumber != null)
                _VibrationPill(vibrationNumber: personalDayNumber!),
            ],
          ),
          const SizedBox(height: 16),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48.0),
              child: Text(
                "Nenhum item para este dia.",
                style: TextStyle(color: AppColors.tertiaryText),
              ),
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text("Tarefas do Dia"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text("Nova Anotação"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            )
          ]
        ],
      ),
    );
  }
}

class _VibrationPill extends StatelessWidget {
  final int vibrationNumber;
  const _VibrationPill({required this.vibrationNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary)),
      child: Text(
        "Vibração $vibrationNumber",
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CustomFloatingActionButton extends StatefulWidget {
  const _CustomFloatingActionButton();

  @override
  State<_CustomFloatingActionButton> createState() =>
      __CustomFloatingActionButtonState();
}

class __CustomFloatingActionButtonState
    extends State<_CustomFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotateAnimation;
  late Animation<double> _translateAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _translateAnimation = Tween<double>(begin: 0.0, end: 65.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_isOpen) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    setState(() => _isOpen = !_isOpen);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: Offset(0, -_translateAnimation.value * 2),
          child:
              _buildSecondaryButton(Icons.book_outlined, "Nova Anotação", () {
            print("Nova Anotação");
            _toggle();
          }),
        ),
        Transform.translate(
          offset: Offset(0, -_translateAnimation.value),
          child: _buildSecondaryButton(Icons.check_box_outlined, "Nova Tarefa",
              () {
            print("Nova Tarefa");
            _toggle();
          }),
        ),
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: RotationTransition(
            turns: _rotateAnimation,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryButton(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _isOpen ? 1.0 : 0.0,
      child: FloatingActionButton.small(
        tooltip: tooltip,
        onPressed: _isOpen ? onPressed : null,
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.purple.shade200,
        heroTag: null,
        child: Icon(icon),
      ),
    );
  }
}
