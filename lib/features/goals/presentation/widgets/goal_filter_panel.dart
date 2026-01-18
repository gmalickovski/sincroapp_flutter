
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/foco_do_dia_screen.dart'; // To access TaskViewScope
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/common/utils/smart_popup_utils.dart';

class GoalFilterPanel extends StatefulWidget {
  final TaskViewScope initialScope;
  final DateTime? initialDate; 
  final int? initialVibration;
  final String? initialTag;
  final List<String> availableTags;
  final UserModel? userData;
  final Function(TaskViewScope, DateTime?, int?, String?) onApply;
  final VoidCallback onClearInPanel;
  
  const GoalFilterPanel({
    super.key,
    required this.initialScope,
    this.initialDate,
    this.initialVibration,
    this.initialTag,
    required this.availableTags,
    this.userData,
    required this.onApply,
    required this.onClearInPanel,
  });

  @override
  State<GoalFilterPanel> createState() => _GoalFilterPanelState();
}

class _GoalFilterPanelState extends State<GoalFilterPanel> {
  late TaskViewScope _tempScope;
  late DateTime? _tempDate;
  late int? _tempVibration;
  late String? _tempTag;
  final GlobalKey _datePickerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tempScope = widget.initialScope;
    _tempDate = widget.initialDate;
    _tempVibration = widget.initialVibration;
    _tempTag = widget.initialTag;
  }

  String _getScopeLabel(TaskViewScope type) {
    switch (type) {
      case TaskViewScope.focoDoDia: return 'Foco do Dia';
      case TaskViewScope.todas: return 'Todas as Tarefas';
      case TaskViewScope.concluidas: return 'Concluídas';
      case TaskViewScope.atrasadas: return 'Atrasadas';
    }
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
                
                // 1. SCOPE DROPDOWN
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.view_agenda_outlined, color: AppColors.secondaryText, size: 20),
                  title: DropdownButton<TaskViewScope>(
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
                    items: [
                      TaskViewScope.todas,
                      TaskViewScope.focoDoDia,
                      TaskViewScope.concluidas,
                      TaskViewScope.atrasadas,
                    ].map((type) {
                      final bool isSelected = _tempScope == type;
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          _getScopeLabel(type),
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),
                const Text("Refinar", style: TextStyle(color: AppColors.secondaryText, fontSize: 16, fontWeight: FontWeight.normal, fontFamily: 'Poppins')),
                const SizedBox(height: 8),

                // 2. FILTERS (Date, Tag, Vib)
                // Date Filter Button
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: AppColors.secondaryText, size: 20),
                  title: InkWell(
                    key: _datePickerKey,
                    onTap: () { // async removed, using callback or then
                         if (widget.userData == null) return;
                         final DateTime firstDate = DateTime(2020);
                         final DateTime lastDate = DateTime.now().add(const Duration(days: 365));
                         DateTime initial = _tempDate ?? DateTime.now();
                         if (initial.isBefore(firstDate)) initial = firstDate;
                         if (initial.isAfter(lastDate)) initial = lastDate;
 
                         showDialog(
                           context: context,
                           builder: (context) => CustomEndDatePickerDialog(
                             initialDate: initial,
                             firstDate: firstDate,
                             lastDate: lastDate,
                             userData: widget.userData!,
                           ),
                         ).then((pickedDate) {
                              if (pickedDate != null && pickedDate is DateTime) {
                                setState(() => _tempDate = pickedDate);
                              }
                         });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _tempDate == null ? 'Por Data' : DateFormat('dd/MM/yyyy').format(_tempDate!),
                            style: TextStyle(
                              color: _tempDate != null ? AppColors.primary : Colors.white,
                              fontWeight: _tempDate != null ? FontWeight.bold : FontWeight.normal,
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
                                  child: Icon(Icons.close, color: AppColors.secondaryText, size: 16),
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
                  leading: const Icon(Icons.wb_sunny_outlined, color: AppColors.secondaryText, size: 20),
                  title: DropdownButton<int?>(
                    value: _tempVibration,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Por Dia Pessoal', style: TextStyle(color: AppColors.secondaryText, fontSize: 14, fontFamily: 'Poppins')),
                    dropdownColor: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    onChanged: (value) => setState(() => _tempVibration = value),
                    selectedItemBuilder: (BuildContext context) {
                      return [
                        null, // Null item
                        ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22] // Vibration numbers
                      ].map((int? v) {
                        if (v == null) {
                           return const Text('Dias Pessoais', style: TextStyle(color: Colors.white, fontFamily: 'Poppins'));
                        }
                        return Row(
                          children: [
                            VibrationPill(vibrationNumber: v, type: VibrationPillType.compact),
                            const SizedBox(width: 12),
                            Text('Dia Pessoal $v', style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
                          ],
                        );
                      }).toList();
                    },
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('Dias Pessoais', style: TextStyle(fontFamily: 'Poppins'))),
                      ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22].map((v) {
                         final bool isSelected = _tempVibration == v;
                         return DropdownMenuItem<int?>(
                              value: v, 
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      VibrationPill(vibrationNumber: v, type: VibrationPillType.compact),
                                      const SizedBox(width: 12),
                                      Text('Dia Pessoal $v', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : null, fontFamily: 'Poppins')),
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
                                        child: Icon(Icons.close, color: AppColors.secondaryText, size: 16),
                                      ),
                                    ),
                                ],
                              ));
                      }),
                    ],
                  ),
                ),

                // Tags Filter
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.label_outline, color: AppColors.secondaryText, size: 20),
                  title: DropdownButton<String?>(
                    value: _tempTag,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Por Tag', style: TextStyle(color: AppColors.secondaryText, fontSize: 14, fontFamily: 'Poppins')),
                    dropdownColor: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'),
                    onChanged: (value) => setState(() => _tempTag = value),
                     items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Tags', style: TextStyle(fontFamily: 'Poppins'))),
                      ...widget.availableTags.map((tag) {
                        final bool isSelected = _tempTag == tag;
                        return DropdownMenuItem<String?>(
                              value: tag, 
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(tag, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : null, fontFamily: 'Poppins')),
                                  if (isSelected)
                                    InkWell(
                                      onTap: () {
                                        setState(() => _tempTag = null);
                                        Navigator.pop(context);
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.close, color: AppColors.secondaryText, size: 16),
                                      ),
                                    ),
                                ],
                              ));
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                        onPressed: () {
                          widget.onClearInPanel();
                          setState(() {
                               _tempScope = TaskViewScope.todas;
                               _tempDate = null;
                               _tempVibration = null;
                               _tempTag = null;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Limpar Filtros',
                            style: TextStyle(color: AppColors.primary, fontFamily: 'Poppins'))),
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          widget.onApply(_tempScope, _tempDate, _tempVibration, _tempTag),
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
