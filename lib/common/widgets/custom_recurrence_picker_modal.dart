// lib/common/widgets/custom_recurrence_picker_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/common/widgets/scrollable_chips_row.dart';

// --- Widget do Modal ---

class CustomRecurrencePickerModal extends StatefulWidget {
  final RecurrenceRule initialRule;
  final UserModel userData;
  final DateTime startDate;

  const CustomRecurrencePickerModal({
    super.key,
    required this.initialRule,
    required this.userData,
    required this.startDate,
  });

  @override
  State<CustomRecurrencePickerModal> createState() =>
      _CustomRecurrencePickerModalState();
}

class _CustomRecurrencePickerModalState
    extends State<CustomRecurrencePickerModal> {
  late RecurrenceType _selectedType;
  late List<int> _selectedDays;
  DateTime? _endDate;
  late String _selectedCategory;

  final Map<int, String> _weekDayNames = {
    DateTime.monday: "S",
    DateTime.tuesday: "T",
    DateTime.wednesday: "Q",
    DateTime.thursday: "Q",
    DateTime.friday: "S",
    DateTime.saturday: "S",
    DateTime.sunday: "D",
  };
  final List<int> _orderedWeekDays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialRule.type;
    _selectedDays = List<int>.from(widget.initialRule.daysOfWeek);
    _endDate = widget.initialRule.endDate;
    _selectedCategory = widget.initialRule.recurrenceCategory;
  }

  Future<void> _showEndDatePicker() async {
    final DateTime? newEndDate = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext dialogContext) {
        return CustomEndDatePickerDialog(
          userData: widget.userData,
          initialDate: _endDate ?? widget.startDate,
          firstDate: widget.startDate,
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
      },
    );

    if (newEndDate != null) {
      final endOfDay = DateTime(
          newEndDate.year, newEndDate.month, newEndDate.day, 23, 59, 59);
      setState(() {
        _endDate = endOfDay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRecurrenceSelected = _selectedType != RecurrenceType.none;
    final bool isEndDateMissing = isRecurrenceSelected && _endDate == null;

    return Container(
      padding: const EdgeInsets.only(top: 8.0),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          _buildTitle(context),
          const Divider(color: AppColors.border, height: 1),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNaturezaRow(),
                  const Divider(color: AppColors.border, height: 1, indent: 16, endIndent: 16),
                  _buildFrequencyOptions(),
                  AnimatedCrossFade(
                    firstChild:
                        const SizedBox(width: double.infinity, height: 0),
                    secondChild: _buildWeeklySelector(),
                    crossFadeState: _selectedType == RecurrenceType.weekly
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                    firstCurve: Curves.easeOut,
                    secondCurve: Curves.easeIn,
                    sizeCurve: Curves.easeInOut,
                  ),
                  if (_selectedType != RecurrenceType.weekly)
                    const Divider(
                        color: AppColors.border,
                        height: 1,
                        indent: 16,
                        endIndent: 16),
                  _buildEndConditionRow(isRecurrenceSelected),
                ],
              ),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          _buildActionButtons(context, isEndDateMissing: isEndDateMissing),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom
                  : 16)
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      color: Colors.transparent,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.tertiaryText.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
      child: Text(
        "Repetir Tarefa",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildNaturezaRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ScrollableChipsRow(
        children: [
          _buildCategoryChip("Fixar na Agenda", 'commitment',
              Icons.push_pin_outlined),
          const SizedBox(width: 8),
          _buildCategoryChip(
              "Fluir na Trilha", 'flow', Icons.waves),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value, IconData icon) {
    final isSelected = _selectedCategory == value;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.secondaryText),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedCategory = value;
          });
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.secondaryText,
        fontFamily: 'Poppins',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _buildFrequencyOptions() {
    return Column(
      children: [
        _buildOptionRow(RecurrenceType.none, "Nunca"),
        _buildOptionRow(RecurrenceType.daily, "Diariamente"),
        _buildOptionRow(RecurrenceType.weekly, "Semanalmente"),
        _buildOptionRow(RecurrenceType.monthly, "Mensalmente"),
      ],
    );
  }

  Widget _buildOptionRow(RecurrenceType type, String title) {
    final bool isSelected = _selectedType == type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
            if (type != RecurrenceType.weekly) {
              _selectedDays.clear();
            } else if (_selectedDays.isEmpty) {
              _selectedDays = [widget.startDate.weekday];
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primaryText,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "REPETIR ÀS",
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.secondaryText,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _orderedWeekDays.map((dayKey) {
              final dayLetter = _weekDayNames[dayKey] ?? '?';
              return _buildDayToggle(dayKey, dayLetter);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayToggle(int dayKey, String dayLetter) {
    final bool isSelected = _selectedDays.contains(dayKey);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_selectedType == RecurrenceType.weekly &&
                _selectedDays.length > 1) {
              _selectedDays.remove(dayKey);
            } else if (_selectedType != RecurrenceType.weekly) {
              _selectedDays.remove(dayKey);
            }
          } else {
            _selectedDays.add(dayKey);
          }
        });
      },
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          dayLetter,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSelected ? Colors.white : AppColors.secondaryText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
        ),
      ),
    );
  }

  Widget _buildEndConditionRow(bool isRecurrenceSelected) {
    final String endDateText;
    final Color endDateColor;

    if (!isRecurrenceSelected) {
      endDateText = "Nunca";
      endDateColor = AppColors.secondaryText;
    } else if (_endDate != null) {
      endDateText = DateFormat.yMd('pt_BR').format(_endDate!);
      endDateColor = AppColors.primary;
    } else {
      endDateText = "Selecionar data";
      endDateColor = AppColors.secondaryText;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (isRecurrenceSelected)
            ? _showEndDatePicker
            : null, 
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            children: [
              const Icon(Icons.event_busy_outlined,
                  color: AppColors.tertiaryText, size: 20),
              const SizedBox(width: 16),
              Text(
                "Termina em",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const Spacer(),
              Text(
                endDateText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: endDateColor,
                      fontWeight: (isRecurrenceSelected && _endDate != null)
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
              ),
              const SizedBox(width: 4),
              if (isRecurrenceSelected)
                const Icon(Icons.chevron_right,
                    color: AppColors.tertiaryText, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context,
      {required bool isEndDateMissing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "Cancelar",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: isEndDateMissing
                  ? null
                  : () {
                      final finalDaysOfWeek =
                          _selectedType == RecurrenceType.weekly
                              ? _selectedDays
                              : <int>[];
                      final finalEndDate = _selectedType != RecurrenceType.none
                          ? _endDate
                          : null;

                      final newRule = RecurrenceRule(
                        type: _selectedType,
                        daysOfWeek: finalDaysOfWeek,
                        endDate: finalEndDate,
                        recurrenceCategory: _selectedCategory,
                      );
                      Navigator.pop(context, newRule);
                    },
              child: Text(
                "OK",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
