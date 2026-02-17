// lib/features/journal/presentation/widgets/journal_filter_panel.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';

import 'package:sincro_app_flutter/features/journal/models/journal_view_scope.dart'; // New Import
// import 'package:sincro_app_flutter/features/journal/presentation/journal_screen.dart'; // REMOVED to break cycle

class JournalFilterPanel extends StatefulWidget {
  final JournalViewScope initialScope;
  final DateTime? initialDate;
  final int? initialVibration;
  final int? initialMood;
  final Function(JournalViewScope, DateTime?, int?, int?) onApply;
  final VoidCallback onClearInPanel;
  final bool isBottomSheet;
  final UserModel userData;

  const JournalFilterPanel({
    super.key,
    required this.initialScope,
    this.initialDate,
    this.initialVibration,
    this.initialMood,
    required this.onApply,
    required this.onClearInPanel,
    this.isBottomSheet = false,
    required this.userData,
  });

  @override
  State<JournalFilterPanel> createState() => _JournalFilterPanelState();
}

class _JournalFilterPanelState extends State<JournalFilterPanel> {
  late JournalViewScope _tempScope;
  late DateTime? _tempDate;
  late int? _tempVibration;
  late int? _tempMood;
  final GlobalKey _datePickerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tempScope = widget.initialScope;
    _tempDate = widget.initialDate;
    _tempVibration = widget.initialVibration;
    _tempMood = widget.initialMood;
  }

  String _getScopeLabel(JournalViewScope type) {
    if (type == JournalViewScope.todas) return 'Todas as Anotações';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
            )
          ],
        ),
        child: SingleChildScrollView(
          padding: isMobile
              ? const EdgeInsets.all(16)
              : const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Removed title as requested
              // 1. SCOPE DROPDOWN
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_outlined,
                    color: AppColors.secondaryText, size: 20),
                title: DropdownButton<JournalViewScope>(
                  value: _tempScope,
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    if (value != null) setState(() => _tempScope = value);
                  },
                  items: JournalViewScope.values.map((type) {
                    final bool isSelected = _tempScope == type;
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        _getScopeLabel(type),
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),
              const Text("Refinar",
                  style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Poppins')),
              const SizedBox(height: 8),

              // 2. FILTERS
              // Date Filter
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today,
                    color: AppColors.secondaryText, size: 20),
                title: InkWell(
                  key: _datePickerKey,
                  onTap: () {
                    final DateTime firstDate = DateTime(2020);
                    final DateTime lastDate =
                        DateTime.now().add(const Duration(days: 365));
                    DateTime initial = _tempDate ?? DateTime.now();
                    if (initial.isBefore(firstDate)) initial = firstDate;
                    if (initial.isAfter(lastDate)) initial = lastDate;

                    showDialog(
                      context: context,
                      builder: (context) => CustomEndDatePickerDialog(
                        initialDate: initial,
                        firstDate: firstDate,
                        lastDate: lastDate,
                        userData: widget.userData,
                      ),
                    ).then((pickedDate) {
                      if (pickedDate != null && pickedDate is DateTime) {
                        setState(() => _tempDate = pickedDate);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    // padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _tempDate == null
                              ? 'Por Data'
                              : DateFormat('dd/MM/yyyy').format(_tempDate!),
                          style: TextStyle(
                            color: _tempDate != null
                                ? AppColors.primary
                                : Colors.white,
                            fontWeight: _tempDate != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        if (_tempDate != null)
                          InkWell(
                            onTap: () => setState(() => _tempDate = null),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.close,
                                  color: AppColors.secondaryText, size: 16),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Vibration Filter
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wb_sunny_outlined,
                    color: AppColors.secondaryText, size: 20),
                title: DropdownButton<int?>(
                  value: _tempVibration,
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Por Dia Pessoal',
                      style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                          fontFamily: 'Poppins')),
                  dropdownColor: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Poppins'),
                  onChanged: (value) {
                    setState(() => _tempVibration = value);
                  },
                  selectedItemBuilder: (BuildContext context) {
                    return [
                      null,
                      ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22]
                    ].map((int? v) {
                      if (v == null) {
                        return const Text('Dias Pessoais',
                            style: TextStyle(
                                color: Colors.white, fontFamily: 'Poppins'));
                      }
                      return Row(
                        children: [
                          VibrationPill(
                              vibrationNumber: v,
                              type: VibrationPillType.compact),
                          const SizedBox(width: 12),
                          Text('Dia Pessoal $v',
                              style: const TextStyle(
                                  color: Colors.white, fontFamily: 'Poppins')),
                        ],
                      );
                    }).toList();
                  },
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Dias Pessoais',
                            style: TextStyle(fontFamily: 'Poppins'))),
                    ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22].map((v) {
                      final isSelected = _tempVibration == v;
                      return DropdownMenuItem<int?>(
                          value: v,
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    VibrationPill(
                                        vibrationNumber: v,
                                        type: VibrationPillType.compact),
                                    const SizedBox(width: 12),
                                    Text('Dia Pessoal $v',
                                        style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? AppColors.primary
                                                : null,
                                            fontFamily: 'Poppins')),
                                  ],
                                ),
                                if (isSelected)
                                  InkWell(
                                    onTap: () {
                                      setState(() => _tempVibration = null);
                                      Navigator.pop(context);
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.close,
                                          color: AppColors.secondaryText,
                                          size: 16),
                                    ),
                                  ),
                              ]));
                    }),
                  ],
                ),
              ),

              // Mood Selector
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _MoodSelector(
                  selectedMood: _tempMood,
                  onMoodSelected: (mood) {
                    setState(
                        () => _tempMood = (_tempMood == mood) ? null : mood);
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                      onPressed: () {
                        widget.onClearInPanel();
                        setState(() {
                          _tempScope = JournalViewScope.todas;
                          _tempDate = null;
                          _tempVibration = null;
                          _tempMood = null;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Limpar Filtros',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontFamily: 'Poppins'))),
                  const Spacer(),
                  IconButton(
                    onPressed: () => widget.onApply(
                        _tempScope, _tempDate, _tempVibration, _tempMood),
                    icon: const Icon(Icons.check, color: AppColors.primary),
                    tooltip: 'Aplicar',
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final int? selectedMood;
  final ValueChanged<int> onMoodSelected;

  const _MoodSelector({this.selectedMood, required this.onMoodSelected});

  @override
  Widget build(BuildContext context) {
    final moods = {1: '😔', 2: '😟', 3: '😐', 4: '😊', 5: '😄'};

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: moods.entries.map((entry) {
        final moodId = entry.key;
        final emoji = entry.value;
        final isSelected = selectedMood == moodId;

        return GestureDetector(
          onTap: () => onMoodSelected(moodId),
          child: AnimatedScale(
            scale: isSelected ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : Colors.transparent,
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 1)
                    : null,
              ),
              // *** INÍCIO DA CORREÇÃO: Cor dos Emoticons ***
              // Envolvemos o Text com um DefaultTextStyle para "proteger" a cor do emoji
              // do tema do popover.
              child: DefaultTextStyle(
                style: const TextStyle(),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              // *** FIM DA CORREÇÃO ***
            ),
          ),
        );
      }).toList(),
    );
  }
}
