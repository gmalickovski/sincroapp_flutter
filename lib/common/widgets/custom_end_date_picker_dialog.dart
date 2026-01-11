// lib/common/widgets/custom_end_date_picker_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_month_year_picker.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:table_calendar/table_calendar.dart';

class CustomEndDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final UserModel userData;

  const CustomEndDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.userData,
  });

  @override
  State<CustomEndDatePickerDialog> createState() =>
      _CustomEndDatePickerDialogState();
}

class _CustomEndDatePickerDialogState extends State<CustomEndDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _focusedDay;
  late DateTime _todayMidnight;
  late NumerologyEngine _engine;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayMidnight = DateTime(now.year, now.month, now.day);

    // Normalize incoming dates to local date-only (avoid timezone shifts)
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _focusedDay = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );

    // Configura o motor de numerologia
    if (widget.userData.nomeAnalise.isNotEmpty &&
        widget.userData.dataNasc.isNotEmpty) {
      _engine = NumerologyEngine(
        nomeCompleto: widget.userData.nomeAnalise,
        dataNascimento: widget.userData.dataNasc,
      );
    } else {
      _engine = NumerologyEngine(
        nomeCompleto: "Sincro App",
        dataNascimento: "01/01/2000",
      );
    }
  }

  // --- Funções de Lógica (copiadas de custom_date_picker_modal.dart) ---
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Exibe o modal de seleção de mês e ano.
  void _showMonthYearPicker() async {
    // Usamos o 'context' do State do Dialog. O showModalBottomSheet
    // encontrará o Navigator raiz para exibir o modal.
    final DateTime? pickedDate = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent, // O picker já tem sua cor e borda
      isScrollControlled: true,
      builder: (sheetContext) {
        // Passamos as datas relevantes para o picker
        return CustomMonthYearPicker(
          initialDate: _focusedDay,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
        );
      },
    );

    // Se o usuário selecionou "OK" (pickedDate != null)
    // e o widget ainda está "montado" (na árvore de widgets).
    if (pickedDate != null && mounted) {
      setState(() {
        // Atualizamos o _focusedDay. O TableCalendar detectará
        // essa mudança e navegará para a página correta.
        _focusedDay = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header com X e Check
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   IconButton(
                     onPressed: () => Navigator.pop(context),
                     icon: const Icon(Icons.close, color: AppColors.secondaryText),
                     tooltip: 'Cancelar',
                   ),
                   Text(
                     "Selecionar Data",
                     style: Theme.of(context).textTheme.titleLarge?.copyWith(
                         color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 18),
                   ),
                   IconButton(
                     onPressed: () => Navigator.pop(context, _selectedDate),
                     icon: const Icon(Icons.check, color: AppColors.primary), // Check de confirmação
                     tooltip: 'Confirmar',
                   ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            Flexible(
              child: SingleChildScrollView(
                // Adicionado padding que antes estava no header
                padding: const EdgeInsets.only(top: 16.0),
                child: _buildFullCalendarView(context),
              ),
            ),
            // Bottom buttons removed per request
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- Widgets do Calendário (copiados de custom_date_picker_modal.dart) ---

  Widget _buildFullCalendarView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TableCalendar(
        locale: 'pt_BR',
        focusedDay: _focusedDay,
        firstDay: widget.firstDate,
        lastDay: widget.lastDate,
        selectedDayPredicate: (day) => _isSameDay(day, _selectedDate),
        // Predicado de habilitação: Apenas dias a partir da data de início
        enabledDayPredicate: (day) =>
            day.isAfter(widget.firstDate) || _isSameDay(day, widget.firstDate),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDate = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        headerStyle: const HeaderStyle(
          titleCentered: true, // Centralizado
          formatButtonVisible: false,
          titleTextStyle: TextStyle(height: 0, fontSize: 0),
          leftChevronPadding: EdgeInsets.zero,
          rightChevronPadding: EdgeInsets.zero,
          leftChevronMargin: EdgeInsets.symmetric(horizontal: 4),
          rightChevronMargin: EdgeInsets.symmetric(horizontal: 4),
          leftChevronIcon: Icon(Icons.chevron_left,
              color: AppColors.primaryText, size: 24),
          rightChevronIcon: Icon(Icons.chevron_right,
              color: AppColors.primaryText, size: 24),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppColors.secondaryText, fontSize: 12),
          weekendStyle: TextStyle(color: AppColors.secondaryText, fontSize: 12),
        ),
        rowHeight: 54,
        calendarStyle: const CalendarStyle(
          defaultDecoration: BoxDecoration(),
          weekendDecoration: BoxDecoration(),
          outsideDecoration: BoxDecoration(),
          selectedDecoration: BoxDecoration(),
          todayDecoration: BoxDecoration(),
          disabledTextStyle: TextStyle(
              color: AppColors.tertiaryText, fontStyle: FontStyle.italic),
        ),
        calendarBuilders: CalendarBuilders(
          // Header agora é clicável
          headerTitleBuilder: (context, day) {
            final titleText =
                _capitalize(DateFormat.yMMMM('pt_BR').format(day));
            // Header agora é um InkWell que chama o seletor de Mês/Ano
            return InkWell(
              onTap: _showMonthYearPicker, // Chama a nova função
              borderRadius: BorderRadius.circular(8.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                // Use a Row that allows the title to shrink/ellipsize on small screens
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        titleText,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Ícone para indicar visualmente que é clicável
                    const Icon(
                      Icons.unfold_more_rounded,
                      color: AppColors.secondaryText,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },

          // Reutiliza o builder de célula idêntico
          defaultBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            final bool isToday = _isSameDay(day, _todayMidnight);
            final bool isSelected = _isSameDay(day, _selectedDate);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: isSelected,
              isToday: isToday,
              isOutside: false,
              isEnabled: true, // Lógica de enabledDayPredicate já cuida disso
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            final bool isToday = _isSameDay(day, _todayMidnight);
            final bool isSelected = _isSameDay(day, _selectedDate);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: isSelected,
              isToday: isToday,
              isOutside: true,
              isEnabled: false,
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            final bool isToday = _isSameDay(day, _todayMidnight);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: true,
              isToday: isToday,
              isOutside: false,
              isEnabled: true,
            );
          },
          disabledBuilder: (context, day, focusedDay) {
            final personalDay = _engine.calculatePersonalDayForDate(day);
            final bool isToday = _isSameDay(day, _todayMidnight);
            return _buildCalendarDayCell(
              day: day,
              personalDay: personalDay,
              isSelected: false,
              isToday: isToday,
              isOutside: !_isSameMonth(day, _focusedDay),
              isEnabled: false,
            );
          },
        ),
      ),
    );
  }

  // --- ALTERAÇÃO (TASK 3): Lógica de estilo da célula do calendário ---
  /// Constrói a Célula do Dia (lógica visual idêntica ao modal principal)
  Widget _buildCalendarDayCell({
    required DateTime day,
    required int personalDay,
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
    required bool isEnabled,
  }) {
    // Definimos os padrões de estilo aqui
    Color borderColor = Colors.transparent; // Sem borda por padrão
    Color cellFillColor; // Cor de fundo da célula
    double borderWidth = 0; // Sem borda por padrão

    if (isSelected && isEnabled) {
      // Dia selecionado: Fundo primário, com borda primária
      cellFillColor = AppColors.primary;
      borderColor = AppColors.primary;
      borderWidth = 2.0;
    } else if (isToday && isEnabled) {
      // Dia "Hoje": Fundo primário sutil, sem borda
      cellFillColor = AppColors.primary.withValues(alpha: 0.25);
    } else if (!isEnabled) {
      // Dia desabilitado: Fundo muito sutil
      // --- ALTERAÇÃO: Trocado AppColors.border.withValues(alpha: 0.3) por branco com opacidade ---
      cellFillColor = Colors.white.withValues(alpha: 0.02);
    } else {
      // Dia padrão (habilitado, não selecionado, não hoje):
      // --- ALTERAÇÃO: Trocado AppColors.border por branco com opacidade para um visual mais suave ---
      cellFillColor = Colors.white.withValues(alpha: 0.05);
    }
    // --- FIM DA ALTERAÇÃO (TASK 3) ---

    Color baseDayTextColor;
    if (isSelected && isEnabled) {
      baseDayTextColor = Colors.white;
    } else if (isToday && isEnabled) {
      baseDayTextColor = AppColors.primary;
    } else if (isOutside) {
      baseDayTextColor = AppColors.tertiaryText;
    } else {
      baseDayTextColor = AppColors.secondaryText;
    }

    Color dayTextColor =
        isEnabled ? baseDayTextColor : baseDayTextColor.withValues(alpha: 0.4);

    FontWeight dayFontWeight = FontWeight.normal;
    if ((isToday || isSelected) && isEnabled) {
      dayFontWeight = FontWeight.bold;
    }

    Widget dayNumberWidget = Text(
      day.day.toString(),
      style: TextStyle(
        color: dayTextColor,
        fontWeight: dayFontWeight,
        fontSize: 11,
      ),
    );

    Widget vibrationWidget = Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: (personalDay > 0)
          ? VibrationPill(
              vibrationNumber: personalDay,
              type: VibrationPillType.micro,
              forceInvertedColors: (isSelected && isEnabled),
            )
          : const SizedBox(height: 16, width: 16),
    );

    return Container(
      margin: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6.0),
        // Aplicando as novas variáveis de estilo
        border: Border.all(color: borderColor, width: borderWidth),
        color: cellFillColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: dayNumberWidget,
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: vibrationWidget,
            ),
          ],
        ),
      ),
    );
  }
}
