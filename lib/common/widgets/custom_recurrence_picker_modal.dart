// lib/common/widgets/custom_recurrence_picker_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'custom_end_date_picker_dialog.dart';

// --- Modelos de Dados para Recorr├¬ncia ---

enum RecurrenceType { none, daily, weekly, monthly }

class RecurrenceRule {
  final RecurrenceType type;
  final List<int> daysOfWeek;
  final DateTime? endDate;

  RecurrenceRule({
    this.type = RecurrenceType.none,
    this.daysOfWeek = const [],
    this.endDate,
  });

  RecurrenceRule copyWith({
    RecurrenceType? type,
    List<int>? daysOfWeek,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      daysOfWeek:
          daysOfWeek ?? List.from(this.daysOfWeek), // Cria c├│pia da lista
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurrenceRule &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          _listEquals(daysOfWeek..sort(), other.daysOfWeek..sort()) &&
          endDate == other.endDate;

  @override
  int get hashCode => type.hashCode ^ daysOfWeek.hashCode ^ endDate.hashCode;

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  // --- FIM Operador == e hashCode ---

  String getSummaryText() {
    String summary;
    switch (type) {
      case RecurrenceType.none:
        return "Nunca";
      case RecurrenceType.daily:
        summary = "Diariamente";
        break;
      case RecurrenceType.weekly:
        final Set<int> daysSet =
            daysOfWeek.toSet(); // Usa Set internamente para facilitar
        if (daysSet.isEmpty && type == RecurrenceType.weekly) {
          summary = "Semanalmente";
        } else if (daysSet.length == 7) {
          summary = "Diariamente";
        } else if (daysSet.length == 5 &&
            !daysSet.contains(DateTime.saturday) &&
            !daysSet.contains(DateTime.sunday)) {
          summary = "Dias da semana";
        } else if (daysSet.isNotEmpty) {
          final sortedDays = List<int>.from(daysSet)
            ..sort((a, b) {
              if (a == DateTime.sunday) return 1;
              if (b == DateTime.sunday) return -1;
              return a.compareTo(b);
            });
          final dayNames =
              sortedDays.map((d) => _getDayAbbreviation(d)).join(', ');
          summary = "Semanal ($dayNames)";
        } else {
          summary = "Semanalmente"; // Fallback
        }
        break;
      case RecurrenceType.monthly:
        summary = "Mensalmente";
        break;
    }

    if (endDate != null) {
      final formattedDate = DateFormat.yMd('pt_BR').format(endDate!);
      summary += ", at├® $formattedDate";
    }

    return summary;
  }

  static String _getDayAbbreviation(int day) {
    DateTime refDate = DateTime.now();
    while (refDate.weekday != day) {
      refDate = refDate.add(const Duration(days: 1));
    }
    return DateFormat('E', 'pt_BR').format(refDate);
  }
}

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
  }

  Future<void> _showEndDatePicker() async {
    // Abrir o seletor de data final. Por padr├úo, focar na data de in├¡cio
    // (ou na data j├í selecionada em `_endDate`) para evitar saltos de m├¬s.
    final DateTime? newEndDate = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext dialogContext) {
        return CustomEndDatePickerDialog(
          userData: widget.userData,
          // Antes us├ívamos startDate + 30 dias como inicial ÔÇö isso fazia
          // o calend├írio pular para o m├¬s seguinte (ex: dezembro).
          // Agora usamos _endDate (se existir) ou o pr├│prio startDate para
          // que o calend├írio abra no m├¬s esperado.
          initialDate: _endDate ?? widget.startDate,
          firstDate: widget.startDate,
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
      },
    );

    if (newEndDate != null) {
      // Salva o final do dia para incluir a data selecionada
      final endOfDay = DateTime(
          newEndDate.year, newEndDate.month, newEndDate.day, 23, 59, 59);
      setState(() {
        _endDate = endOfDay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- ALTERA├ç├âO (TASK 2): L├│gica de valida├º├úo para o bot├úo OK ---
    final bool isRecurrenceSelected = _selectedType != RecurrenceType.none;
    final bool isEndDateMissing = isRecurrenceSelected && _endDate == null;
    // --- FIM DA ALTERA├ç├âO ---

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
          // --- ALTERA├ç├âO (TASK 2): Passa a flag de valida├º├úo para o bot├úo ---
          _buildActionButtons(context, isEndDateMissing: isEndDateMissing),
          // --- FIM DA ALTERA├ç├âO ---
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
            color: AppColors.tertiaryText.withValues(alpha: 0.5),
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
        // --- ALTERA├ç├âO (TASK 1): Garante uso da fonte do tema ---
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
        // --- FIM DA ALTERA├ç├âO ---
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
                // --- ALTERA├ç├âO (TASK 1): Usa fonte do tema (bodyLarge) ---
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primaryText,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                // --- FIM DA ALTERA├ç├âO ---
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
    // --- ALTERA├ç├âO (TASK 1): Remove decora├º├úo (fundo e borda) ---
    return Container(
      // decoration: BoxDecoration(...) // REMOVIDO
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              "REPETIR ├ÇS",
              // --- ALTERA├ç├âO (TASK 1): Usa fonte do tema (labelMedium) ---
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.secondaryText,
                    letterSpacing: 0.5,
                  ),
              // --- FIM DA ALTERA├ç├âO ---
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
      // --- ALTERA├ç├âO (TASK 1): Raio do InkWell para combinar com o container ---
      borderRadius: BorderRadius.circular(8.0),
      // --- FIM DA ALTERA├ç├âO ---
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        // --- ALTERA├ç├âO (TASK 1): Estilo "Contido" Minimalista ---
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0), // Ret├óngulo arredondado
          // Borda removida para visual mais limpo
        ),
        // --- FIM DA ALTERA├ç├âO ---
        child: Text(
          dayLetter,
          // --- ALTERA├ç├âO (TASK 1): Usa fonte do tema (bodyMedium) ---
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isSelected ? Colors.white : AppColors.secondaryText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
          // --- FIM DA ALTERA├ç├âO ---
        ),
      ),
    );
  }

  // --- ALTERA├ç├âO (TASK 2): Recebe 'isRecurrenceSelected' ---
  Widget _buildEndConditionRow(bool isRecurrenceSelected) {
    // --- ALTERA├ç├âO (TASK 2): L├│gica de texto aprimorada ---
    final String endDateText;
    final Color endDateColor;

    if (!isRecurrenceSelected) {
      endDateText = "Nunca";
      endDateColor = AppColors.secondaryText;
    } else if (_endDate != null) {
      endDateText = DateFormat.yMd('pt_BR').format(_endDate!);
      endDateColor = AppColors.primary;
    } else {
      // Pede ao usu├írio para selecionar a data, pois ├® obrigat├│rio
      endDateText = "Selecionar data";
      endDateColor = AppColors.secondaryText;
    }
    // --- FIM DA ALTERA├ç├âO ---

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (isRecurrenceSelected)
            ? _showEndDatePicker
            : null, // S├│ permite clicar se repetir
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Row(
            children: [
              const Icon(Icons.event_busy_outlined,
                  color: AppColors.tertiaryText, size: 20),
              const SizedBox(width: 16),
              Text(
                "Termina em",
                // --- ALTERA├ç├âO (TASK 1): Usa fonte do tema (bodyLarge) ---
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                // --- FIM DA ALTERA├ç├âO ---
              ),
              const Spacer(),
              Text(
                // --- ALTERA├ç├âO (TASK 2): Usa nova vari├ível de texto ---
                endDateText,
                // --- ALTERA├ç├âO (TASK 1): Usa fonte do tema (bodyLarge) ---
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      // --- ALTERA├ç├âO (TASK 2): Usa nova vari├ível de cor ---
                      color: endDateColor,
                      fontWeight: (isRecurrenceSelected && _endDate != null)
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                // --- FIM DA ALTERA├ç├âO ---
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

  // --- ALTERA├ç├âO (TASK 2): Recebe 'isEndDateMissing' ---
  Widget _buildActionButtons(BuildContext context,
      {required bool isEndDateMissing}) {
    // --- FIM DA ALTERA├ç├âO ---
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
                // --- ALTERA├ç├âO (TASK 1): Usa fonte do tema (bodyLarge) ---
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                // --- FIM DA ALTERA├ç├âO ---
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
              // --- ALTERA├ç├âO (TASK 2): Bot├úo ├® desabilitado se a data for obrigat├│ria e estiver faltando ---
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

                      // Se o bot├úo estava habilitado, 'finalEndDate' n├úo pode ser nulo
                      // (a menos que o tipo seja 'none')
                      final newRule = RecurrenceRule(
                        type: _selectedType,
                        daysOfWeek: finalDaysOfWeek,
                        endDate: finalEndDate,
                      );
                      Navigator.pop(context, newRule);
                    },
              // --- FIM DA ALTERA├ç├âO ---
              child: Text(
                "OK",
                // --- ALTERA├ç├âO (TASK 1): Usa fonte do tema (bodyLarge) ---
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                // --- FIM DA ALTERA├ç├âO ---
              ),
            ),
          ),
        ],
      ),
    );
  }
}
