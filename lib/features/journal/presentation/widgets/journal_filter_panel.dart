// lib/features/journal/presentation/widgets/journal_filter_panel.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_end_date_picker_dialog.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class JournalFilterPanel extends StatefulWidget {
  final DateTime? initialDate;
  final int? initialVibration;
  final int? initialMood;
  final Function(DateTime?, int?, int?) onApply;
  final VoidCallback onClearInPanel;
  final bool isBottomSheet;
  final UserModel userData;

  const JournalFilterPanel({
    super.key,
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
  late DateTime? _tempDate;
  late int? _tempVibration;
  late int? _tempMood;

  @override
  void initState() {
    super.initState();
    _tempDate = widget.initialDate;
    _tempVibration = widget.initialVibration;
    _tempMood = widget.initialMood;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtros',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today,
                  color: AppColors.secondaryText),
              title: Text(
                  _tempDate == null
                      ? 'Filtrar por data'
                      : DateFormat('dd/MM/yyyy').format(_tempDate!),
                  style: const TextStyle(color: Colors.white)),
              trailing: _tempDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.secondaryText, size: 20),
                      onPressed: () => setState(() => _tempDate = null))
                  : null,
              onTap: () async {
                // Open custom calendar dialog instead of the default Flutter date picker
                final DateTime firstDate = DateTime(2020);
                final DateTime lastDate =
                    DateTime.now().add(const Duration(days: 365));
                DateTime initial = _tempDate ?? DateTime.now();
                // Clamp initial within range to avoid assertion errors
                if (initial.isBefore(firstDate)) initial = firstDate;
                if (initial.isAfter(lastDate)) initial = lastDate;

                final pickedDate = await showDialog<DateTime>(
                  context: context,
                  barrierDismissible: true,
                  builder: (ctx) => CustomEndDatePickerDialog(
                    initialDate: initial,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    userData: widget.userData,
                  ),
                );
                if (pickedDate != null) {
                  setState(() => _tempDate = pickedDate);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.star_border, color: AppColors.secondaryText),
              title: DropdownButton<int?>(
                value: _tempVibration,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                hint: const Text('Filtrar por Dia Pessoal',
                    style: TextStyle(color: AppColors.secondaryText)),
                dropdownColor: AppColors.cardBackground,
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() => _tempVibration = value);
                },
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('Todos os Dias Pessoais')),
                  ...[1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22]
                      .map((v) => DropdownMenuItem<int?>(
                          value: v, child: Text('Dia Pessoal $v')))
                      .toList(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtrar por humor',
                      style: TextStyle(color: AppColors.secondaryText)),
                  const SizedBox(height: 8),
                  _MoodSelector(
                    selectedMood: _tempMood,
                    onMoodSelected: (mood) {
                      setState(
                          () => _tempMood = (_tempMood == mood) ? null : mood);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                    onPressed: () {
                      widget.onClearInPanel();
                      Navigator.pop(context);
                    },
                    child: const Text('Limpar Filtros',
                        style: TextStyle(color: AppColors.primary))),
                const Spacer(),
                ElevatedButton(
                  onPressed: () =>
                      widget.onApply(_tempDate, _tempVibration, _tempMood),
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
            transform: isSelected
                ? (Matrix4.identity()..scale(1.2))
                : Matrix4.identity(),
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
        );
      }).toList(),
    );
  }
}
