import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/common/widgets/sincro_filter_selector.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/models/contact_model.dart';

/// A Generic "Select" Option helper
class MobileFilterOption {
  final String label;
  final dynamic value;
  final IconData? icon;

  MobileFilterOption({required this.label, required this.value, this.icon});
}

enum MobileFilterType {
  date,
  mood,
  vibration,
  select,
  tag,
  goal,
  contact,
  sort
}

enum DateFilterMode { interval, month, year }

class MobileFilterSheet extends StatefulWidget {
  final MobileFilterType type;
  final bool isDesktop;
  final DateTime? selectedDate;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final int? selectedMood;
  final int? selectedVibration;

  // Select Params (Generic)
  final List<MobileFilterOption>? options;
  final dynamic selectedOption;

  // Tag Params
  final List<String>? availableTags;
  final String? selectedTag;

  // Goal & Contact Params
  final List<Goal>? goals;
  final List<ContactModel>? contacts;

  final UserModel? userData;

  const MobileFilterSheet({
    super.key,
    required this.type,
    this.selectedDate,
    this.selectedStartDate,
    this.selectedEndDate,
    this.selectedMood,
    this.selectedVibration,
    this.options,
    this.selectedOption,
    this.availableTags,
    this.selectedTag,
    this.goals,
    this.contacts,
    this.isDesktop = false,
    this.userData,
  });

  @override
  State<MobileFilterSheet> createState() => _MobileFilterSheetState();
}

class _MobileFilterSheetState extends State<MobileFilterSheet> {
  // Date State
  DateFilterMode _dateMode = DateFilterMode.interval;
  DateTime _focusedDay = DateTime.now();

  DateTime? _tempStartDate;
  DateTime? _tempEndDate;

  // Mood/Vibration State
  int? _tempMood;
  int? _tempVibration;

  // Select/Tag State
  dynamic _tempSelectedOption;
  String? _tempSelectedTag;

  // Sort State
  String? _sortCategory;

  bool _hasCleared = false;

  // UI State for Interval View
  bool _isSelectingItem = false; // For Goal/Contact selection list
  bool _isSelectingYearMonth = false; // For Interval View (Calendar)
  bool _isSelectingYearInMonthView = false; // For Month View Year Selector
  DateTime? _preSelectorFocusedDay; // Salva posição antes do seletor mês/ano

  late NumerologyEngine _engine;

  @override
  void initState() {
    super.initState();
    _focusedDay =
        widget.selectedStartDate ?? widget.selectedDate ?? DateTime.now();

    _tempStartDate = widget.selectedStartDate ?? widget.selectedDate;
    _tempEndDate = widget.selectedEndDate ?? widget.selectedDate;
    _tempMood = widget.selectedMood;
    _tempMood = widget.selectedMood;
    _tempVibration = widget.selectedVibration;
    _tempSelectedOption = widget.selectedOption;
    _tempSelectedTag = widget.selectedTag;

    // Initialize Numerology Engine
    if (widget.userData != null &&
        widget.userData!.nomeAnalise.isNotEmpty &&
        widget.userData!.dataNasc.isNotEmpty) {
      _engine = NumerologyEngine(
        nomeCompleto: widget.userData!.nomeAnalise,
        dataNascimento: widget.userData!.dataNasc,
      );
    } else {
      _engine = NumerologyEngine(
        nomeCompleto: "User",
        dataNascimento: "01/01/2000",
      );
    }

    if (widget.type == MobileFilterType.date) {
      if (_tempStartDate != null && _tempEndDate != null) {
        final isFullMonth = _tempStartDate!.day == 1 &&
            _tempEndDate!.day ==
                DateTime(_tempEndDate!.year, _tempEndDate!.month + 1, 0).day;

        final isFullYear = _tempStartDate!.month == 1 &&
            _tempStartDate!.day == 1 &&
            _tempEndDate!.month == 12 &&
            _tempEndDate!.day == 31;

        if (isFullYear) {
          _dateMode = DateFilterMode.year;
        } else if (isFullMonth) {
          _dateMode = DateFilterMode.month;
        } else {
          _dateMode = DateFilterMode.interval;
        }
      }
    } else if (widget.type == MobileFilterType.sort &&
        _tempSelectedOption != null) {
      if (_tempSelectedOption.toString().startsWith('date')) {
        _sortCategory = 'date';
      } else if (_tempSelectedOption.toString().startsWith('alpha')) {
        _sortCategory = 'alpha';
      }
    }
  }

  void _onApply() {
    DateTime? finalDate;
    if (_tempStartDate != null &&
        (_tempEndDate == null || isSameDay(_tempStartDate, _tempEndDate))) {
      finalDate = _tempStartDate;
    }

    Navigator.pop(context, {
      'date': finalDate,
      'startDate': finalDate != null ? null : _tempStartDate,
      'endDate': finalDate != null ? null : _tempEndDate,
      'mood': _tempMood,
      'vibration': _tempVibration,
      'value': _tempSelectedOption,
      'tag': _tempSelectedTag,
      'goalId': _tempSelectedOption, // Map to specific key for safety
      'contactId': _tempSelectedOption, // Map to specific key for safety
    });
  }

  void _onClear() {
    setState(() {
      _tempStartDate = null;
      _tempEndDate = null;
      _tempMood = null;
      _tempVibration = null;
      _tempSelectedOption = null;
      _tempSelectedTag = null;
      _hasCleared = true;
      _focusedDay = DateTime.now(); // Reset calendar position to today
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Poppins'),
      ),
      child: Container(
        constraints: BoxConstraints(
          // Allow dynamic height up to 90% of screen height
          maxHeight: widget.isDesktop
              ? double.infinity
              : MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: widget.isDesktop
              ? BorderRadius.circular(16)
              : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (widget.type == MobileFilterType.date)
              _buildDateSegmentControl(),
            Flexible(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: (widget.type == MobileFilterType.date ||
                            widget.type == MobileFilterType.select)
                        ? 16.0
                        : 0.0),
                child: _buildContent(),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ... (Header and SegmentControl remain same) ...

  // 2. Month View (Year Selector + Month Grid)
  Widget _buildMonthView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Shrink wrap
        children: [
          // Year Selector Header with interactive toggle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isSelectingYearInMonthView)
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    onPressed: () => setState(
                        () => _focusedDay = DateTime(_focusedDay.year - 1)),
                  ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSelectingYearInMonthView =
                          !_isSelectingYearInMonthView;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${_focusedDay.year}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isSelectingYearInMonthView
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                if (!_isSelectingYearInMonthView)
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    onPressed: () => setState(
                        () => _focusedDay = DateTime(_focusedDay.year + 1)),
                  ),
              ],
            ),
          ),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _isSelectingYearInMonthView
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: GridView.builder(
              shrinkWrap: true, // Key for fitting content
              physics:
                  const NeverScrollableScrollPhysics(), // Scroll handled by parent
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 3.0, // Reduced height (was 2.5)
                crossAxisSpacing: 12,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final monthDate = DateTime(_focusedDay.year, index + 1);
                // Check if selected range matches this month
                final isSelected = _tempStartDate != null &&
                    _tempEndDate != null &&
                    _tempStartDate!.year == monthDate.year &&
                    _tempStartDate!.month == monthDate.month;

                return InkWell(
                  onTap: () {
                    if (isSelected) {
                      setState(() {
                        _tempStartDate = null;
                        _tempEndDate = null;
                      });
                    } else {
                      final start =
                          DateTime(monthDate.year, monthDate.month, 1);
                      final end = DateTime(
                          monthDate.year, monthDate.month + 1, 0, 23, 59, 59);
                      setState(() {
                        _tempStartDate = start;
                        _tempEndDate = end;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Text(
                      DateFormat('MMM', 'pt_BR')
                          .format(monthDate)
                          .toUpperCase(),
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.secondaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14, // Standardized font size
                      ),
                    ),
                  ),
                );
              },
            ),
            secondChild: SizedBox(
              // Reuse the Year View logic but handled locally for the month view context
              // We can reuse the _buildYearView content logic but we need to ensure it updates _focusedDay
              // instead of setting the full date range directly if we want it to just change the year.
              // BUT the user likely wants to select the year and Go BACK to month view.
              height: 300, // Fixed height for year selector inside month view
              child: _buildYearSelectorForMonthView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelectorForMonthView() {
    final currentYear = DateTime.now().year;
    final years = List.generate(41, (index) => currentYear - 20 + index);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 8,
      ),
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        final isSelected = _focusedDay.year == year;

        return InkWell(
          onTap: () {
            setState(() {
              _focusedDay = DateTime(year, _focusedDay.month, _focusedDay.day);
              _isSelectingYearInMonthView = false; // Switch back to month view
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Text(
              "$year",
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.secondaryText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _canGoBack {
    if (widget.type == MobileFilterType.goal ||
        widget.type == MobileFilterType.contact ||
        widget.type == MobileFilterType.sort) {
      return _isSelectingItem;
    }
    if (widget.type == MobileFilterType.date) {
      if (_dateMode == DateFilterMode.interval) return _isSelectingYearMonth;
      if (_dateMode == DateFilterMode.month) return _isSelectingYearInMonthView;
    }
    return false;
  }

  void _handleBack() {
    setState(() {
      if (widget.type == MobileFilterType.goal ||
          widget.type == MobileFilterType.contact ||
          widget.type == MobileFilterType.sort) {
        _isSelectingItem = false;
      } else if (widget.type == MobileFilterType.date) {
        if (_dateMode == DateFilterMode.interval) _isSelectingYearMonth = false;
        if (_dateMode == DateFilterMode.month)
          _isSelectingYearInMonthView = false;
      }
    });
  }

  Widget _buildHeader() {
    String title = "";
    switch (widget.type) {
      case MobileFilterType.date:
        title = "Filtrar por Data";
        break;
      case MobileFilterType.mood:
        title = "Filtrar por Humor";
        break;
      case MobileFilterType.vibration:
        title = "Filtrar por Vibração";
        break;
      case MobileFilterType.select:
        title = "Selecionar Opção";
        break;
      case MobileFilterType.tag:
        title = "Filtrar por Tag";
        break;
      case MobileFilterType.goal:
        title = "Filtrar por Meta";
        break;
      case MobileFilterType.contact:
        title = "Filtrar por Contato";
        break;
      case MobileFilterType.sort:
        title = "Ordenar";
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(
          top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_canGoBack)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.secondaryText),
                onPressed: _handleBack,
                tooltip: 'Voltar',
              ),
            ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSegmentControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildSegmentButton("Intervalo", DateFilterMode.interval),
            _buildSegmentButton("Mês", DateFilterMode.month),
            _buildSegmentButton("Ano", DateFilterMode.year),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String label, DateFilterMode mode) {
    final isSelected = _dateMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _dateMode = mode;
            _focusedDay = _tempStartDate ?? DateTime.now();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(vertical: 16), // Standardized padding
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.secondaryText,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasActiveSelection {
    if (widget.type == MobileFilterType.date) {
      return _tempStartDate != null;
    } else if (widget.type == MobileFilterType.mood) {
      return _tempMood != null;
    } else if (widget.type == MobileFilterType.vibration) {
      return _tempVibration != null;
    } else if (widget.type == MobileFilterType.select) {
      return _tempSelectedOption != null;
    } else if (widget.type == MobileFilterType.tag) {
      return _tempSelectedTag != null;
    } else if (widget.type == MobileFilterType.goal ||
        widget.type == MobileFilterType.contact ||
        widget.type == MobileFilterType.sort) {
      return _tempSelectedOption != null;
    }
    return false;
  }

  bool get _shouldShowActionButtons {
    if (_hasCleared) return false;

    if (widget.type == MobileFilterType.date) {
      return !isSameDay(_tempStartDate, widget.selectedStartDate) ||
          !isSameDay(_tempEndDate, widget.selectedEndDate);
    } else if (widget.type == MobileFilterType.mood) {
      return _tempMood != widget.selectedMood;
    } else if (widget.type == MobileFilterType.vibration) {
      return _tempVibration != widget.selectedVibration;
    } else if (widget.type == MobileFilterType.select) {
      return _tempSelectedOption != widget.selectedOption;
    } else if (widget.type == MobileFilterType.tag) {
      return _tempSelectedTag != widget.selectedTag;
    } else if (widget.type == MobileFilterType.goal ||
        widget.type == MobileFilterType.contact ||
        widget.type == MobileFilterType.sort) {
      return _tempSelectedOption != widget.selectedOption;
    }
    return false;
  }

  Widget _buildFooter() {
    // Quando o seletor de mês/ano está aberto, mostra botões Voltar/Confirmar
    final bool showSelectorButtons = _isSelectingYearMonth || _isSelectingYearInMonthView;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child));
        },
        child: showSelectorButtons
            ? Row(
                key: const ValueKey('SelectorButtons'),
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            // Cancelar: restaurar posição anterior
                            if (_isSelectingYearMonth && _preSelectorFocusedDay != null) {
                              _focusedDay = _preSelectorFocusedDay!;
                            }
                            _isSelectingYearMonth = false;
                            _isSelectingYearInMonthView = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Voltar",
                            style: TextStyle(
                                color: AppColors.secondaryText,
                                fontFamily: 'Poppins')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          // Confirmar: apenas mantém _focusedDay atual (navegação) e volta
                          setState(() {
                            _isSelectingYearMonth = false;
                            _isSelectingYearInMonthView = false;
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                                  (states) => AppColors.primary),
                          foregroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                                  (states) => Colors.white),
                          elevation: WidgetStateProperty.resolveWith<double>(
                              (states) => 0),
                          padding: WidgetStateProperty
                              .resolveWith<EdgeInsetsGeometry>((states) =>
                                  const EdgeInsets.symmetric(vertical: 12)),
                          shape:
                              WidgetStateProperty.resolveWith<OutlinedBorder>(
                                  (states) {
                            if (states.contains(WidgetState.hovered)) {
                              return RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                    color: Colors.white, width: 2),
                              );
                            }
                            return RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: AppColors.primary, width: 2),
                            );
                          }),
                        ),
                        child: const Text("Confirmar",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins')),
                      ),
                    ),
                  ),
                ],
              )
            : _shouldShowActionButtons
                ? Row(
                    key: const ValueKey('ActionButtons'),
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _onClear,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Limpar",
                                style: TextStyle(
                                    color: AppColors.secondaryText,
                                    fontFamily: 'Poppins')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _onApply,
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color>(
                                      (states) => AppColors.primary),
                              foregroundColor:
                                  WidgetStateProperty.resolveWith<Color>(
                                      (states) => Colors.white),
                              elevation: WidgetStateProperty.resolveWith<double>(
                                  (states) => 0),
                              padding: WidgetStateProperty
                                  .resolveWith<EdgeInsetsGeometry>((states) =>
                                      const EdgeInsets.symmetric(vertical: 12)),
                              shape:
                                  WidgetStateProperty.resolveWith<OutlinedBorder>(
                                      (states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                        color: Colors.white,
                                        width: 2),
                                  );
                                }
                                return RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: AppColors.primary, width: 2),
                                );
                              }),
                            ),
                            child: const Text("Aplicar",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins')),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 48,
                    key: const ValueKey('CloseButton'),
                    child: OutlinedButton(
                      onPressed: () {
                        if (_hasCleared) {
                          _onApply();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.cardBackground,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Fechar",
                          style: TextStyle(
                              color: AppColors.secondaryText,
                              fontFamily: 'Poppins')),
                    ),
                  ),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.type) {
      case MobileFilterType.mood:
        return _buildMoodContent();
      case MobileFilterType.vibration:
        return _buildVibrationContent();
      case MobileFilterType.date:
        return _buildDateContent();
      case MobileFilterType.select:
        return _buildSelectContent();
      case MobileFilterType.tag:
        return _buildTagContent();
      case MobileFilterType.goal:
        return _buildGoalContent();
      case MobileFilterType.contact:
        return _buildContactContent();
      case MobileFilterType.sort:
        return _buildSortContent();
    }
  }

  // --- Date Content & Logic ---

  Widget _buildDateContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.0, 0.05), end: Offset.zero)
                  .animate(animation),
              child: child,
            ));
      },
      child: KeyedSubtree(
        key: ValueKey<DateFilterMode>(_dateMode),
        child: _buildDateContentBody(),
      ),
    );
  }

  Widget _buildDateContentBody() {
    switch (_dateMode) {
      case DateFilterMode.interval:
        return _buildIntervalView();
      case DateFilterMode.month:
        return _buildMonthView();
      case DateFilterMode.year:
        return _buildYearView();
    }
  }

  // 1. Interval View (Calendar with Range Selection)
  Widget _buildIntervalView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCustomHeader(),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            firstChild: _buildTableCalendar(),
            secondChild: _buildMonthYearSelector(),
            crossFadeState: _isSelectingYearMonth
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader() {
    final headerText = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!_isSelectingYearMonth)
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () => setState(() => _focusedDay =
                  DateTime(_focusedDay.year, _focusedDay.month - 1)),
            )
          else
            const SizedBox(width: 48), // Spacer to keep title centered

          GestureDetector(
            onTap: () {
              setState(() {
                if (!_isSelectingYearMonth) {
                  _preSelectorFocusedDay = _focusedDay;
                }
                _isSelectingYearMonth = !_isSelectingYearMonth;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headerText
                      .toUpperCase(), // Capitalize first letter logic handled by styles/formatting usually, but generic uppercase works
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins'),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isSelectingYearMonth
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),

          if (!_isSelectingYearMonth)
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () => setState(() => _focusedDay =
                  DateTime(_focusedDay.year, _focusedDay.month + 1)),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    return _MonthYearSelector(
      focusedDay: _focusedDay,
      onDateChanged: (newDate) {
        setState(() {
          _focusedDay = newDate;
        });
      },
    );
  }

  Widget _buildTableCalendar() {
    return TableCalendar(
      locale: 'pt_BR',
      firstDay: DateTime(2020),
      lastDay: DateTime(2050), // Extended range
      focusedDay: _focusedDay,
      currentDay: DateTime.now(),

      daysOfWeekHeight: 24.0,

      rangeSelectionMode: RangeSelectionMode.enforced,
      rangeStartDay: _tempStartDate,
      rangeEndDay: _tempEndDate,

      onDaySelected: (selectedDay, focusedDay) {
        if (_isSelectingYearMonth)
          return; // Disable selection while picker is open

        setState(() {
          _focusedDay = focusedDay;

          // Hitting Start Date -> Toggle it off (or shift end to start)
          if (_tempStartDate != null &&
              isSameDay(selectedDay, _tempStartDate)) {
            if (_tempEndDate != null) {
              _tempStartDate = _tempEndDate;
              _tempEndDate = null;
            } else {
              _tempStartDate = null;
            }
            return;
          }

          // Hitting End Date -> Toggle it off
          if (_tempEndDate != null && isSameDay(selectedDay, _tempEndDate)) {
            _tempEndDate = null;
            return;
          }

          // New Date Selection
          if (_tempStartDate == null) {
            _tempStartDate = selectedDay;
          } else if (_tempEndDate == null) {
            if (selectedDay.isBefore(_tempStartDate!)) {
              _tempEndDate = _tempStartDate;
              _tempStartDate = selectedDay;
            } else {
              _tempEndDate = selectedDay;
            }
          } else {
            // Toggling: if they click the exact same start date and no end date is set, toggle off.
            if (_tempEndDate == null &&
                isSameDay(_tempStartDate, selectedDay)) {
              _tempStartDate = null;
            } else {
              _tempStartDate = selectedDay;
              _tempEndDate = null;
            }
          }
          _hasCleared = false; // Add this line
        });
      },

      calendarFormat: CalendarFormat.month,
      headerVisible: false, // Hide default header
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        weekendTextStyle:
            TextStyle(color: AppColors.secondaryText, fontFamily: 'Poppins'),
        rangeHighlightColor: Colors.transparent,
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle:
            TextStyle(color: AppColors.secondaryText, fontFamily: 'Poppins'),
        weekendStyle:
            TextStyle(color: AppColors.secondaryText, fontFamily: 'Poppins'),
      ),
      // Custom Builders for Vibration Pills
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return _buildCalendarDayCell(
            day: day,
            isEnabled: true,
            isSelected: false,
            isToday: isSameDay(day, DateTime.now()),
            isOutside: false,
            isRangeStart: false,
            isRangeEnd: false,
            isWithinRange: false,
          );
        },
        rangeStartBuilder: (context, day, focusedDay) {
          return _buildCalendarDayCell(
            day: day,
            isEnabled: true,
            isSelected: true,
            isToday: isSameDay(day, DateTime.now()),
            isOutside: false,
            isRangeStart: true,
            isRangeEnd: false,
            isWithinRange: false,
          );
        },
        rangeEndBuilder: (context, day, focusedDay) {
          return _buildCalendarDayCell(
            day: day,
            isEnabled: true,
            isSelected: true,
            isToday: isSameDay(day, DateTime.now()),
            isOutside: false,
            isRangeStart: false,
            isRangeEnd: true,
            isWithinRange: false,
          );
        },
        withinRangeBuilder: (context, day, focusedDay) {
          return _buildCalendarDayCell(
            day: day,
            isEnabled: true,
            isSelected: true,
            isToday: isSameDay(day, DateTime.now()),
            isOutside: false,
            isRangeStart: false,
            isRangeEnd: false,
            isWithinRange: true,
          );
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildCalendarDayCell(
            day: day,
            isEnabled: true,
            isSelected: false,
            isToday: true,
            isOutside: false,
            isRangeStart: false,
            isRangeEnd: false,
            isWithinRange: false,
          );
        },
        outsideBuilder: (context, day, focusedDay) {
          return _buildCalendarDayCell(
            day: day,
            isEnabled: false,
            isSelected: false,
            isToday: false,
            isOutside: true,
            isRangeStart: false,
            isRangeEnd: false,
            isWithinRange: false,
          );
        },
        disabledBuilder: (context, day, focusedDay) {
          return _buildCalendarDayCell(
            day: day,
            isEnabled: false,
            isSelected: false,
            isToday: isSameDay(day, DateTime.now()),
            isOutside: true,
            isRangeStart: false,
            isRangeEnd: false,
            isWithinRange: false,
          );
        },
      ),
    );
  }

  Widget _buildCalendarDayCell({
    required DateTime day,
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
    required bool isEnabled,
    required bool isRangeStart,
    required bool isRangeEnd,
    required bool isWithinRange,
  }) {
    final personalDay = _engine.calculatePersonalDayForDate(day);

    Color borderColor = Colors.transparent;
    Color cellFillColor = Colors.white.withValues(alpha: 0.05);
    double borderWidth = 0;

    // Logic adapted for Range Selection
    if (isRangeStart || isRangeEnd) {
      cellFillColor = AppColors.primary;
      borderColor = AppColors.primary;
      borderWidth = 2.0;
    } else if (isWithinRange) {
      cellFillColor =
          AppColors.primary.withValues(alpha: 0.5); // Lighter for range
      borderColor = Colors.transparent;
    } else if (isToday && isEnabled) {
      cellFillColor = AppColors.primary.withValues(alpha: 0.25);
      if (!isWithinRange && !isRangeStart && !isRangeEnd) {
        // If today is not selected, give it a border
        borderColor = AppColors.primary;
        borderWidth = 1.0;
      }
    } else if (!isEnabled) {
      cellFillColor = Colors.white.withValues(alpha: 0.02);
    }

    Color baseDayTextColor = AppColors.secondaryText;
    if ((isRangeStart || isRangeEnd) && isEnabled) {
      baseDayTextColor = Colors.white;
    } else if (isWithinRange) {
      baseDayTextColor = Colors.white;
    } else if (isToday && isEnabled) {
      baseDayTextColor = AppColors.primary;
    } else if (isOutside) {
      baseDayTextColor = AppColors.tertiaryText;
    }

    Widget dayNumberWidget = Text(
      day.day.toString(),
      style: TextStyle(
        color: isEnabled
            ? baseDayTextColor
            : baseDayTextColor.withValues(alpha: 0.4),
        fontWeight: (isToday || isRangeStart || isRangeEnd)
            ? FontWeight.bold
            : FontWeight.normal,
        fontSize: 11,
      ),
    );

    Widget vibrationWidget = Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: (personalDay > 0)
          ? VibrationPill(
              vibrationNumber: personalDay,
              type: VibrationPillType.micro,
              forceInvertedColors:
                  (isRangeStart || isRangeEnd || isWithinRange) && isEnabled,
            )
          : const SizedBox(height: 16, width: 16),
    );

    return Container(
      margin: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: borderColor, width: borderWidth),
        color: cellFillColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.topLeft, child: dayNumberWidget),
            Align(alignment: Alignment.bottomRight, child: vibrationWidget),
          ],
        ),
      ),
    );
  }

  // 3. Year View (Grid of years)
  Widget _buildYearView() {
    final currentYear = DateTime.now().year;
    // Generate a wider range for scrolling (e.g., 20 past, 20 future)
    final years = List.generate(41, (index) => currentYear - 20 + index);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 3.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 8,
        ),
        itemCount: years.length,
        itemBuilder: (context, index) {
          final year = years[index];
          // Check if selected range matches this year
          final isSelected = _tempStartDate != null &&
              _tempEndDate != null &&
              _tempStartDate!.year == year &&
              _tempStartDate!.month == 1 &&
              _tempStartDate!.day == 1 &&
              _tempEndDate!.year == year &&
              _tempEndDate!.month == 12 &&
              _tempEndDate!.day == 31;

          return InkWell(
            onTap: () {
              if (isSelected) {
                setState(() {
                  _tempStartDate = null;
                  _tempEndDate = null;
                  _hasCleared = false; // Add this line
                });
              } else {
                final start = DateTime(year, 1, 1);
                final end = DateTime(year, 12, 31, 23, 59, 59);
                setState(() {
                  _tempStartDate = start;
                  _tempEndDate = end;
                  _hasCleared = false; // Add this line
                });
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border),
              ),
              child: Text(
                "$year",
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.secondaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Standardized font size
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Adaptive Grid Helper ---
  Widget _buildAdaptiveGrid({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required double minItemWidth,
    double spacing = 12,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;

        // 1. Calculate Max Columns possible
        int maxCols = ((maxWidth + spacing) / (minItemWidth + spacing)).floor();
        if (maxCols < 1) maxCols = 1;

        // 2. Find optimal columns to avoid having just 1 item in the last row (orphan)
        // We iterate down from maxCols.
        int optimalCols = maxCols;
        for (int cols = maxCols; cols >= 1; cols--) {
          int remainder = itemCount % cols;
          // Accept if remainder is 0 (perfect fit) or remainder > 1 (no single orphan)
          // Also accept if cols=1 (can't go lower)
          // If remainder is 1 and rows > 1, we try to avoid it.
          bool hasOrphan = remainder == 1 && itemCount > cols;

          if (!hasOrphan) {
            optimalCols = cols;
            break;
          }
        }

        // 3. Build Rows
        List<Widget> rows = [];
        for (int i = 0; i < itemCount; i += optimalCols) {
          int chunkSize =
              (i + optimalCols > itemCount) ? (itemCount - i) : optimalCols;

          List<Widget> rowChildren = [];
          for (int j = 0; j < chunkSize; j++) {
            rowChildren.add(
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: j < chunkSize - 1
                        ? spacing
                        : 0, // Right spacing for all but last
                  ),
                  child: itemBuilder(context, i + j),
                ),
              ),
            );
          }

          rows.add(
            Padding(
              padding: EdgeInsets.only(
                  bottom: (i + chunkSize < itemCount) ? spacing : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Align top for text flows
                children: rowChildren,
              ),
            ),
          );
        }

        return Column(
          children: rows,
        );
      },
    );
  }

  // --- Mood Content ---
  Widget _buildMoodContent() {
    final moods = [1, 2, 3, 4, 5];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _buildAdaptiveGrid(
          itemCount: moods.length,
          minItemWidth: 40, // Reduced min width
          spacing: 8,
          itemBuilder: (context, index) {
            final mood = moods[index];
            final isSelected = _tempMood == mood;
            final color = SincroFilterSelector.getMoodColor(mood);

            return Align(
              alignment: Alignment.topCenter, // "midtop"
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _tempMood = isSelected ? null : mood;
                    _hasCleared = false;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? color : Colors.transparent,
                        shape: BoxShape.circle,
                        // No border for cleaner look, matching user request
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4))
                              ]
                            : [],
                      ),
                      child: Icon(
                        SincroFilterSelector.getMoodIcon(mood),
                        color: isSelected ? Colors.white : color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getMoodLabel(mood),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? color : AppColors.secondaryText,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getMoodLabel(int mood) {
    switch (mood) {
      case 1:
        return 'Péssimo';
      case 2:
        return 'Ruim';
      case 3:
        return 'Neutro';
      case 4:
        return 'Bom';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }

  // --- Vibration Content ---
  Widget _buildVibrationContent() {
    final vibes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _buildAdaptiveGrid(
          itemCount: vibes.length,
          minItemWidth: 40, // Reduced min width
          spacing: 8,
          itemBuilder: (context, index) {
            final vibe = vibes[index];
            final isSelected = _tempVibration == vibe;
            final colors = getColorsForVibration(vibe);

            return Align(
              alignment: Alignment.topCenter, // "midtop"
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _tempVibration = isSelected ? null : vibe;
                    _hasCleared = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Text(
                      '$vibe',
                      style: TextStyle(
                        color: isSelected ? Colors.white : colors.background,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.background : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isSelected ? Colors.transparent : colors.background,
                      width: 2,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Select Content (Generic) ---
  Widget _buildSelectContent() {
    if (widget.options == null || widget.options!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("Nenhuma opÃ§Ã£o disponÃ­vel",
            style: TextStyle(color: AppColors.secondaryText)),
      );
    }

    // Filter out "Todas" option
    final filteredOptions =
        widget.options?.where((opt) => opt.label != "Todas").toList();

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredOptions?.length ?? 0,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final option = filteredOptions![index];
        final isSelected = _tempSelectedOption == option.value;

        return _HoverableOptionTile(
          isSelected: isSelected,
          overrideSelectionColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          onTap: () {
            setState(() {
              _tempSelectedOption = isSelected ? null : option.value;
              _hasCleared = false;
            });
          },
          child: Row(
            children: [
              if (option.icon != null) ...[
                Icon(option.icon,
                    color: isSelected ? AppColors.primary : Colors.white,
                    size: 24),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle,
                    color: AppColors.primary, size: 20),
            ],
          ),
        );
      },
    );
  }

  // --- Tag Content ---
  Widget _buildTagContent() {
    if (widget.availableTags == null || widget.availableTags!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("Nenhuma tag disponÃ­vel",
            style: TextStyle(color: AppColors.secondaryText)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 12,
        children: widget.availableTags!.map((tag) {
          final isSelected = _tempSelectedTag == tag;
          return ChoiceChip(
            label: Text(tag),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _tempSelectedTag = selected ? tag : null;
                _hasCleared = false;
              });
            },
            selectedColor: Colors.purple, // Requested Pink/Purple
            backgroundColor: AppColors.background,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.secondaryText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Poppins',
              fontSize: 13,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : AppColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Goal Content ---
  Widget _buildGoalContent() {
    if (_isSelectingItem) {
      // Show List of Goals
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (child, animation) {
          final curvedAnimation =
              CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
        child: Column(
          key: const ValueKey('GoalList'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text("Selecione uma Meta",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
            ),
            if (widget.goals == null || widget.goals!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Nenhuma meta encontrada.",
                    style: TextStyle(color: AppColors.secondaryText)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.goals!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final goal = widget.goals![index];
                    final isSelected = _tempSelectedOption == goal.id;

                    return _HoverableOptionTile(
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _tempSelectedOption = isSelected ? null : goal.id;
                          _hasCleared = false;
                        });
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(goal.title,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.cyan : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                )),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: Colors.cyan, size: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    }

    // Default View: Todas vs Selecionar Meta
    final bool isAllSelected = _tempSelectedOption == 'all';
    final bool isSpecificSelected =
        _tempSelectedOption != null && _tempSelectedOption != 'all';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      transitionBuilder: (child, animation) {
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.3, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      child: Padding(
        key: const ValueKey('GoalMenu'),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Fix: Use min size
          children: [
            // Option 1: Todas
            _HoverableOptionTile(
              isSelected: isAllSelected,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              onTap: () {
                setState(() {
                  // Toggle: If currently 'all', unselect (null). Else select 'all'.
                  _tempSelectedOption = isAllSelected ? null : 'all';
                  _hasCleared = false;
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.list, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text("Todas as Metas",
                          style: TextStyle(color: Colors.white, fontSize: 14))),
                  if (isAllSelected)
                    const Icon(Icons.check_circle,
                        color: Colors.cyan, size: 20),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Option 2: Selecionar Meta >
            _HoverableOptionTile(
              isSelected: isSpecificSelected,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              onTap: () {
                setState(() {
                  _isSelectingItem = true;
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.flag, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          isSpecificSelected
                              ? "Meta Selecionada"
                              : "Selecionar Meta",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14))),
                  const Icon(Icons.chevron_right,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Contact Content ---
  Widget _buildContactContent() {
    if (_isSelectingItem) {
      // Show List of Contacts
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (child, animation) {
          final curvedAnimation =
              CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
        child: Column(
          key: const ValueKey('ContactList'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text("Selecione um Contato",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
            ),
            if (widget.contacts == null || widget.contacts!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Nenhum contato encontrado.",
                    style: TextStyle(color: AppColors.secondaryText)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.contacts!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final contact = widget.contacts![index];
                    final isSelected = _tempSelectedOption ==
                        contact.userId; // Assuming userId is unique filter Key

                    return _HoverableOptionTile(
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _tempSelectedOption =
                              isSelected ? null : contact.userId;
                          _hasCleared = false;
                        });
                      },
                      overrideSelectionColor: Colors.blue,
                      child: Row(
                        children: [
                          // Initial or Photo
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withValues(alpha: 0.2),
                              image: contact.photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(contact.photoUrl!),
                                      fit: BoxFit.cover)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: contact.photoUrl == null
                                ? Text(contact.displayName[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14))
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(contact.displayName,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.blue : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                )),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: Colors.blue, size: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    }

    // Default View
    final bool isAllSelected = _tempSelectedOption == 'all';
    final bool isSpecificSelected =
        _tempSelectedOption != null && _tempSelectedOption != 'all';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      transitionBuilder: (child, animation) {
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.3, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      child: Padding(
        key: const ValueKey('ContactMenu'),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Fix: Use min size to avoid extra space
          children: [
            // Option 1: Todos
            _HoverableOptionTile(
              isSelected: isAllSelected,
              overrideSelectionColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              onTap: () {
                setState(() {
                  _tempSelectedOption = isAllSelected ? null : 'all';
                  _hasCleared = false;
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.people_outline,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text("Todos",
                          style: TextStyle(color: Colors.white, fontSize: 14))),
                  if (isAllSelected)
                    const Icon(Icons.check_circle,
                        color: Colors.blue, size: 20),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Option 2: Selecionar Contato >
            _HoverableOptionTile(
              isSelected: isSpecificSelected,
              overrideSelectionColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              onTap: () {
                setState(() {
                  _isSelectingItem = true;
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.person_search,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          isSpecificSelected
                              ? "Contato Selecionado"
                              : "Selecionar Contato",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14))),
                  const Icon(Icons.chevron_right,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sort Content ---
  Widget _buildSortContent() {
    if (_isSelectingItem) {
      final isDate = _sortCategory == 'date';
      final options = isDate
          ? [
              MobileFilterOption(
                  label: 'Mais recentes (Decrescente)',
                  value: 'date_desc',
                  icon: Icons.arrow_downward),
              MobileFilterOption(
                  label: 'Mais antigas (Crescente)',
                  value: 'date_asc',
                  icon: Icons.arrow_upward),
            ]
          : [
              MobileFilterOption(
                  label: 'A-Z (Crescente)',
                  value: 'alpha_asc',
                  icon: Icons.sort_by_alpha),
              MobileFilterOption(
                  label: 'Z-A (Decrescente)',
                  value: 'alpha_desc',
                  icon: Icons.sort_by_alpha),
            ];

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (child, animation) {
          final curvedAnimation =
              CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
        child: Column(
          key: ValueKey('SortList_${_sortCategory}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(isDate ? "Por Data" : "Por Nome",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = _tempSelectedOption == option.value;

                  return _HoverableOptionTile(
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _tempSelectedOption = isSelected ? null : option.value;
                        _hasCleared = false;
                      });
                    },
                    overrideSelectionColor: AppColors.primary,
                    child: Row(
                      children: [
                        Icon(option.icon,
                            color:
                                isSelected ? AppColors.primary : Colors.white,
                            size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(option.label,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              )),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: AppColors.primary, size: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Default View: select sort category
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      transitionBuilder: (child, animation) {
        final curvedAnimation =
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.3, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
      child: Padding(
        key: const ValueKey('SortMenu'),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HoverableOptionTile(
              isSelected:
                  _sortCategory == 'date' && _tempSelectedOption != null,
              onTap: () {
                setState(() {
                  _sortCategory = 'date';
                  _isSelectingItem = true;
                });
              },
              overrideSelectionColor: AppColors.primary,
              child: const Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text("Data",
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.secondaryText),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _HoverableOptionTile(
              isSelected:
                  _sortCategory == 'alpha' && _tempSelectedOption != null,
              onTap: () {
                setState(() {
                  _sortCategory = 'alpha';
                  _isSelectingItem = true;
                });
              },
              overrideSelectionColor: AppColors.primary,
              child: const Row(
                children: [
                  Icon(Icons.sort_by_alpha, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text("Ordem Alfabética",
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.secondaryText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoverableOptionTile extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;
  final Color? overrideSelectionColor;
  final EdgeInsetsGeometry? padding;

  const _HoverableOptionTile({
    required this.isSelected,
    required this.onTap,
    required this.child,
    this.overrideSelectionColor,
    this.padding,
  });

  @override
  State<_HoverableOptionTile> createState() => _HoverableOptionTileState();
}

class _HoverableOptionTileState extends State<_HoverableOptionTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final selectionColor = widget.overrideSelectionColor ??
        Colors.cyan; // Default cyan for Goals, override for others
    // Mapping: Goals=Cyan, Contacts=Blue, Scope=Primary(DeepPurple/Default)
    // Note: The original code used AppColors.primary for Scope.
    // If overrideSelectionColor is null, we might want to default to Primary or handle it.
    // Goals used cyan. Contacts used blue. Scope used Primary.
    // Let's check call sites.

    // Actually, let's use the passed color or default to Primary if not provided?
    // In strict mode: Goals passed nothing (checked previous code.. oh, I didn't pass anything for Goals in my previous Step 1820 replacement!).
    // Wait, in Step 1820, I replaced Code for Goal List.
    // `_HoverableOptionTile(isSelected: isSelected, ...)`
    // The previous code for Goal List used `isSelectd ? Colors.cyan`.

    // I need to ensure _HoverableOptionTile defaults to Cyan if I want to match Goal List without passing color?
    // No, cleaner to pass the color.
    // BUT I ALREADY WROTE the code for Goal List in Step 1820 and I DID NOT pass a color.
    // So the default MUST be Cyan to match what I wrote? Or I should update Goal List too?
    // Updating Goal List now would require finding it again.
    // Let's set default to Cyan to be safe for the code I already wrote, or app-wide primary?
    // Goals = Cyan.
    // If I set default to Cyan, Scope (which uses Primary) will be wrong unless I pass Primary.
    // Scope is in THIS update (Chunk 1). I can pass `overrideSelectionColor: AppColors.primary`.

    // Rechecking Step 1820:
    // `color: isSelected ? Colors.cyan : ...`
    // I replaced it with `_HoverableOptionTile(...)`.
    // So `_HoverableOptionTile` needs to default to Cyan or I need to update Goal List.
    // I cannot update Goal List easily in this same call without a huge context.
    // I will set default to Colors.cyan.

    final effectiveSelectionColor =
        widget.overrideSelectionColor ?? Colors.cyan;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: widget.padding ??
              const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? effectiveSelectionColor.withValues(alpha: 0.2)
                : AppColors
                    .cardBackground, // No background modification on hover
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected
                  ? effectiveSelectionColor
                  : (_isHovering
                      ? AppColors.primary
                      : AppColors.border), // Only change border color on hover
              width: widget.isSelected
                  ? 2
                  : 1, // Keep width 1 unless selected to prevent shifting
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _MonthYearSelector extends StatefulWidget {
  final DateTime focusedDay;
  final ValueChanged<DateTime> onDateChanged;

  const _MonthYearSelector({
    required this.focusedDay,
    required this.onDateChanged,
  });

  @override
  State<_MonthYearSelector> createState() => _MonthYearSelectorState();
}

class _MonthYearSelectorState extends State<_MonthYearSelector> {
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  final List<String> _months = [
    "JANEIRO",
    "FEVEREIRO",
    "MARÇO",
    "ABRIL",
    "MAIO",
    "JUNHO",
    "JULHO",
    "AGOSTO",
    "SETEMBRO",
    "OUTUBRO",
    "NOVEMBRO",
    "DEZEMBRO"
  ];

  late List<int> _years;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    _years = List.generate(41, (index) => currentYear - 20 + index);

    _monthController =
        FixedExtentScrollController(initialItem: widget.focusedDay.month - 1);

    // Find initial year index. If mostly out of bounds, default to middle.
    int yearIndex = _years.indexOf(widget.focusedDay.year);
    if (yearIndex == -1) yearIndex = 20; // Default to current/middle

    _yearController = FixedExtentScrollController(initialItem: yearIndex);
  }

  @override
  void didUpdateWidget(_MonthYearSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedDay != oldWidget.focusedDay) {
      // Update Month
      final targetMonthIndex = widget.focusedDay.month - 1;
      if (_monthController.selectedItem != targetMonthIndex) {
        // Only jump if significantly different to avoid fighting the scroll
        _monthController.jumpToItem(targetMonthIndex);
      }

      // Update Year
      final targetYearIndex = _years.indexOf(widget.focusedDay.year);
      if (targetYearIndex != -1 &&
          _yearController.selectedItem != targetYearIndex) {
        _yearController.jumpToItem(targetYearIndex);
      }
    }
  }

  @override
  void dispose() {
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Row(
        children: [
          // Months
          Expanded(
            child: ListWheelScrollView.useDelegate(
              itemExtent: 40,
              perspective: 0.005,
              physics: const FixedExtentScrollPhysics(),
              controller: _monthController,
              onSelectedItemChanged: (index) {
                final newMonth = index + 1;
                // Prevent unnecessary updates if possible, but focusedDay needs to change
                if (newMonth != widget.focusedDay.month) {
                  widget.onDateChanged(
                      DateTime(widget.focusedDay.year, newMonth));
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _months.length,
                builder: (context, index) {
                  final isSelected = (index + 1) == widget.focusedDay.month;
                  return Center(
                    child: Text(
                      _months[index],
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.secondaryText,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: isSelected ? 18 : 16,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Years
          Expanded(
            child: ListWheelScrollView.useDelegate(
              itemExtent: 40,
              perspective: 0.005,
              physics: const FixedExtentScrollPhysics(),
              controller: _yearController,
              onSelectedItemChanged: (index) {
                final newYear = _years[index];
                if (newYear != widget.focusedDay.year) {
                  widget.onDateChanged(
                      DateTime(newYear, widget.focusedDay.month));
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _years.length,
                builder: (context, index) {
                  final year = _years[index];
                  final isSelected = year == widget.focusedDay.year;
                  return Center(
                    child: Text(
                      "$year",
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.secondaryText,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: isSelected ? 18 : 16,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
