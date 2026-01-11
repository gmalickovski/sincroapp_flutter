
import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/foco_do_dia_screen.dart'; // To access TaskFilterType enum
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class TaskFilterPanel extends StatefulWidget {
  final TaskViewScope initialScope;
  final DateTime? initialDate; 
  final int? initialVibration;
  final String? initialTag;
  final List<String> availableTags;
  final UserModel? userData;
  final Function(TaskViewScope, DateTime?, int?, String?) onApply;
  final VoidCallback onClearInPanel;
  
  const TaskFilterPanel({
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
  State<TaskFilterPanel> createState() => _TaskFilterPanelState();
}

class _TaskFilterPanelState extends State<TaskFilterPanel> {
  late TaskViewScope _tempScope;
  late DateTime? _tempDate;
  late int? _tempVibration;
  late String? _tempTag;

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
    return Material( // Added Material to fix "No Material widget found" error
      type: MaterialType.transparency,
      child: Container(
        width: 350,
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
        child: Padding(
          // Reduced top padding as requested
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Removed title as requested
              // Removed extra SizedBox here as padding handles it better
              
              // 1. SCOPE DROPDOWN (O que ver?)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.view_agenda_outlined, color: AppColors.secondaryText),
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
                  items: TaskViewScope.values.map((type) {
                    final bool isSelected = _tempScope == type;
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        _getScopeLabel(type),
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),
              const Text("Refinar por...", style: TextStyle(color: AppColors.secondaryText, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 2. FILTERS (Date, Tag, Vib)
              // Date Filter Button
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: AppColors.secondaryText),
                title: InkWell(
                  onTap: () async {
                       if (widget.userData == null) return;
                       final DateTime firstDate = DateTime(2020);
                       final DateTime lastDate = DateTime.now().add(const Duration(days: 365));
                       DateTime initial = _tempDate ?? DateTime.now();
                       if (initial.isBefore(firstDate)) initial = firstDate;
                       if (initial.isAfter(lastDate)) initial = lastDate;

                       final pickedDate = await showDialog<DateTime>(
                        context: context,
                        barrierDismissible: true,
                        builder: (ctx) => CustomEndDatePickerDialog(
                          initialDate: initial,
                          firstDate: firstDate,
                          lastDate: lastDate,
                          userData: widget.userData!,
                        ),
                      );

                      if (pickedDate != null) {
                        setState(() => _tempDate = pickedDate);
                      }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _tempDate == null ? 'Por Data' : DateFormat('dd/MM/yyyy').format(_tempDate!),
                          style: TextStyle(
                            color: _tempDate != null ? AppColors.primary : Colors.white,
                            fontWeight: _tempDate != null ? FontWeight.bold : FontWeight.normal,
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
                leading: const Icon(Icons.star_border, color: AppColors.secondaryText),
                title: DropdownButton<int?>(
                  value: _tempVibration,
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Por Dia Pessoal', style: TextStyle(color: AppColors.secondaryText)),
                  dropdownColor: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => setState(() => _tempVibration = value),
                  selectedItemBuilder: (BuildContext context) {
                    return [
                      null, // Null item
                      ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22] // Vibration numbers
                    ].map((int? v) {
                      if (v == null) {
                         return const Text('Dias Pessoais', style: TextStyle(color: Colors.white));
                      }
                      return Row(
                        children: [
                          VibrationPill(vibrationNumber: v, type: VibrationPillType.compact),
                          const SizedBox(width: 12),
                          Text('Dia Pessoal $v', style: const TextStyle(color: Colors.white)),
                        ],
                      );
                    }).toList();
                  },
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Dias Pessoais')),
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
                                    Text('Dia Pessoal $v', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : null)),
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
                leading: const Icon(Icons.label_outline, color: AppColors.secondaryText),
                title: DropdownButton<String?>(
                  value: _tempTag,
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Por Tag', style: TextStyle(color: AppColors.secondaryText)),
                  dropdownColor: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => setState(() => _tempTag = value),
                   items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Tags')),
                    ...widget.availableTags.map((tag) {
                      final bool isSelected = _tempTag == tag;
                      return DropdownMenuItem<String?>(
                            value: tag, 
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tag, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : null)),
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
                          style: TextStyle(color: AppColors.primary))),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () =>
                        widget.onApply(_tempScope, _tempDate, _tempVibration, _tempTag),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: const Text('Aplicar',
                        style: TextStyle(color: Colors.white)),
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
