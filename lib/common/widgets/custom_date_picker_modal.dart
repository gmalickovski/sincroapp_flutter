// lib/common/widgets/custom_date_picker_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:table_calendar/table_calendar.dart';

import 'custom_time_picker_modal.dart';
import 'custom_month_year_picker.dart';
import 'custom_recurrence_picker_modal.dart'; // Import necessário

// Classe interna para dados da lista de datas
class _DateWithVibration {
  final DateTime date;
  final int personalDay;
  _DateWithVibration(this.date, this.personalDay);
}

// Classe de retorno do modal, incluindo data/hora e regra de recorrência
class DatePickerResult {
  final DateTime dateTime;
  final RecurrenceRule recurrenceRule;
  DatePickerResult(this.dateTime, this.recurrenceRule);
}

class CustomDatePickerModal extends StatefulWidget {
  final DateTime initialDate; // Data inicial para focar/selecionar
  final RecurrenceRule? initialRecurrenceRule; // Regra de recorrência atual
  final UserModel userData; // Dados do usuário para cálculo de numerologia

  const CustomDatePickerModal({
    super.key,
    required this.initialDate,
    required this.userData,
    this.initialRecurrenceRule,
  });

  @override
  State<CustomDatePickerModal> createState() => _CustomDatePickerModalState();
}

class _CustomDatePickerModalState extends State<CustomDatePickerModal> {
  // --- Estados do Widget ---
  bool _isExpanded =
      false; // Controla se a visão compacta ou expandida é mostrada
  late DateTime _selectedDate; // Data selecionada (dia/mês/ano)
  late DateTime
      _calendarFocusedDay; // Mês/Ano atualmente focado nos calendários
  TimeOfDay? _selectedTime; // Hora selecionada (opcional)
  late NumerologyEngine _engine; // Motor para calcular dia pessoal
  final List<_DateWithVibration> _dateList =
      []; // Lista para o scroller horizontal
  final ScrollController _scrollController =
      ScrollController(); // Controlador do scroller
  final double _datePillWidth = 68.0; // Largura fixa das pílulas de data
  late DateTime _todayMidnight; // Data de hoje à meia-noite para comparações
  late RecurrenceRule _recurrenceRule; // Regra de recorrência selecionada

  @override
  void initState() {
    super.initState();

    // Define 'hoje'
    final now = DateTime.now();
    _todayMidnight = DateTime(now.year, now.month, now.day);

    // Define data selecionada (sem hora inicial)
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );

    // Define a hora inicial SE ela existir na initialDate (relevante para TaskDetailModal)
    if (widget.initialDate.hour != 0 || widget.initialDate.minute != 0) {
      _selectedTime = TimeOfDay.fromDateTime(widget.initialDate);
    } else {
      _selectedTime = null; // Mantém nulo se não houver hora específica
    }

    // Foca o calendário no mês da data selecionada
    _calendarFocusedDay = DateTime(_selectedDate.year, _selectedDate.month, 1);

    // Inicializa a regra de recorrência
    _recurrenceRule = widget.initialRecurrenceRule ?? RecurrenceRule();

    // Configura motor de numerologia
    if (widget.userData.nomeAnalise.isNotEmpty &&
        widget.userData.dataNasc.isNotEmpty) {
      _engine = NumerologyEngine(
        nomeCompleto: widget.userData.nomeAnalise,
        dataNascimento: widget.userData.dataNasc,
      );
    } else {
      // Fallback se dados do usuário não estiverem completos
      _engine = NumerologyEngine(
        nomeCompleto: "Sincro App",
        dataNascimento: "01/01/2000",
      );
    }

    // Gera a lista de datas para o scroller (sem atualizar a UI ainda)
    _regenerateDateListForCurrentMonth(doSetState: false);

    // --- ALTERAÇÃO (TASK 2): Lógica de scroll inicial modificada ---
    // Agenda o scroll inicial para "Hoje" (se visível) após o primeiro frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        // Prioriza rolar para "Hoje" se estiver no mês focado
        if (_isSameMonth(_todayMidnight, _calendarFocusedDay)) {
          final todayIndex =
              (_todayMidnight.day - 1).clamp(0, _dateList.length - 1);
          _scrollToIndexInCurrentMonth(todayIndex, animated: false);
        }
        // Se "Hoje" não estiver no mês, rola para a data selecionada (ex: editando tarefa futura)
        else if (_isSameMonth(_selectedDate, _calendarFocusedDay)) {
          final selectedIndex =
              (_selectedDate.day - 1).clamp(0, _dateList.length - 1);
          _scrollToIndexInCurrentMonth(selectedIndex, animated: false);
        }
      }
    });
    // --- FIM DA ALTERAÇÃO ---
  }

  // --- Funções Helper ---

  /// Capitaliza a primeira letra de uma string.
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Regenera a lista `_dateList` para o mês atual em `_calendarFocusedDay`.
  void _regenerateDateListForCurrentMonth({bool doSetState = true}) {
    _dateList.clear();
    final int year = _calendarFocusedDay.year;
    final int month = _calendarFocusedDay.month;
    final int daysInMonth = DateTime(year, month + 1, 0).day;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final personalDay = _engine.calculatePersonalDayForDate(date);
      _dateList.add(_DateWithVibration(date, personalDay));
    }

    // Reseta o scroll para o início ao mudar de mês (se o controller estiver pronto)
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // Atualiza a UI se solicitado e o widget estiver montado
    if (doSetState && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Libera o controlador de scroll
    super.dispose();
  }

  /// Alterna entre a visão compacta e expandida do calendário.
  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  /// Atualiza `_selectedDate` quando um dia é selecionado.
  /// Impede a seleção de dias anteriores a hoje.
  void _handleDateSelection(DateTime date) {
    // Permite selecionar 'hoje'
    if (date.isBefore(_todayMidnight) && !_isSameDay(date, _todayMidnight)) {
      return; // Ignora dias passados
    }
    setState(() {
      _selectedDate = date; // Atualiza a data selecionada
    });
  }

  /// Combina a data e hora selecionadas, cria o `DatePickerResult` e fecha o modal.
  void _confirmSelection() {
    DateTime finalDateTime = _selectedDate; // Começa só com a data
    // Adiciona a hora se ela foi selecionada
    if (_selectedTime != null) {
      finalDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }
    // Cria o objeto de resultado com data/hora e regra de recorrência
    final result = DatePickerResult(finalDateTime, _recurrenceRule);
    Navigator.of(context).pop(result); // Fecha o modal retornando o resultado
  }

  /// Abre o modal customizado para seleção de horário.
  Future<void> _showCustomTimePicker(BuildContext context) async {
    final TimeOfDay? picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor:
          Colors.transparent, // O modal filho tem seu próprio fundo
      isScrollControlled:
          true, // Permite que o modal cresça conforme necessário
      builder: (BuildContext builderContext) {
        return CustomTimePickerModal(
          // Passa a hora atual selecionada ou a hora atual como inicial
          initialTime: _selectedTime ?? TimeOfDay.now(),
        );
      },
    );
    // Atualiza o estado se uma hora foi selecionada
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  /// Verifica se dois `DateTime` representam o mesmo dia (ignora hora).
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Verifica se dois `DateTime` estão no mesmo mês e ano.
  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  /// Abre o modal customizado para seleção de mês e ano.
  Future<void> _showCustomMonthYearPicker(BuildContext context) async {
    HapticFeedback.lightImpact(); // Feedback tátil
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext builderContext) {
        return CustomMonthYearPicker(
          initialDate: _calendarFocusedDay, // Mês/ano focado atualmente
          firstDate: DateTime(2020), // Limite inferior
          lastDate: DateTime(2101), // Limite superior
        );
      },
    );
    // Atualiza o mês focado e regenera a lista de dias se um mês/ano foi selecionado
    if (picked != null) {
      setState(() {
        _calendarFocusedDay = DateTime(picked.year, picked.month, 1);
        _regenerateDateListForCurrentMonth();
      });

      // --- ALTERAÇÃO (TASK 2): Rola para "Hoje" se o usuário navegar para o mês atual ---
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scrollController.hasClients &&
            _isSameMonth(_todayMidnight, _calendarFocusedDay)) {
          final todayIndex =
              (_todayMidnight.day - 1).clamp(0, _dateList.length - 1);
          _scrollToIndexInCurrentMonth(todayIndex, animated: true);
        }
      });
      // --- FIM DA ALTERAÇÃO ---
    }
  }

  /// Abre o modal customizado para seleção da regra de recorrência.
  Future<void> _showRecurrencePicker() async {
    // Garante que a data passada não tenha hora/minuto
    final startDate =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    final RecurrenceRule? newRule = await showModalBottomSheet<RecurrenceRule>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext builderContext) {
        return CustomRecurrencePickerModal(
          initialRule: _recurrenceRule, // Passa a regra atual
          userData: widget.userData, // Necessário para o seletor de data final
          startDate: startDate, // Passa a data de início da tarefa
        );
      },
    );
    // Atualiza o estado se uma nova regra foi selecionada
    if (newRule != null) {
      setState(() {
        _recurrenceRule = newRule;
      });
    }
  }

  /// Rola a lista de dias horizontalmente.
  void _scrollDays(int direction) {
    if (!_scrollController.hasClients || !mounted) return;
    HapticFeedback.lightImpact();

    final screenWidth = MediaQuery.of(context).size.width;
    // Rola 70% da tela para manter algum contexto visual
    final double jump = (screenWidth * 0.7) * direction;
    final double newOffset = (_scrollController.offset + jump)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
  // --- FIM DA ALTERAÇÃO ---

  /// Faz o scroll horizontal na lista de dias (`_dateList`) para centralizar o `index` fornecido.
  void _scrollToIndexInCurrentMonth(int index, {bool animated = true}) {
    // Verifica se o widget está montado, o controller está pronto e o índice é válido
    if (mounted &&
        _scrollController.hasClients &&
        index >= 0 &&
        index < _dateList.length) {
      final screenWidth = MediaQuery.of(context).size.width;
      // Calcula o offset necessário para centralizar o item
      final scrollOffset =
          (index * _datePillWidth) - (screenWidth / 2) + (_datePillWidth / 2);
      final maxScroll = _scrollController.position.maxScrollExtent;
      // Garante que o offset esteja dentro dos limites do scroll
      final targetOffset =
          scrollOffset.clamp(0.0, maxScroll < 0 ? 0.0 : maxScroll);

      if (!animated) {
        _scrollController.jumpTo(targetOffset); // Scroll instantâneo
      } else {
        _scrollController.animateTo(
          // Scroll com animação
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }
  // --- Fim Funções Helper ---

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      // Anima a altura do modal ao expandir/recolher
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Padding(
        // Empurra o conteúdo para cima quando o teclado aparece
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          // Container principal do modal
          padding: const EdgeInsets.only(top: 8.0),
          decoration: const BoxDecoration(
            color: AppColors.cardBackground, // Cor de fundo definida
            borderRadius: BorderRadius.only(
              // Cantos arredondados no topo
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
          ),
          constraints: BoxConstraints(
            // Limita a altura máxima
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          // Adiciona Material para garantir contexto aos widgets filhos
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              // Layout principal em coluna
              mainAxisSize: MainAxisSize.min, // Encolhe para o conteúdo
              children: [
                // Conteúdo rolável (calendários, botões de hora/recorrência)
                Flexible(
                  // Permite que o conteúdo interno cresça até o limite
                  child: SingleChildScrollView(
                    // Permite rolagem se o conteúdo exceder
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDragHandle(), // Alça para fechar/expandir
                        // Anima a transição entre visão compacta e expandida
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          crossFadeState: _isExpanded
                              ? CrossFadeState
                                  .showSecond // Mostra calendário completo
                              : CrossFadeState
                                  .showFirst, // Mostra scroller horizontal
                          firstChild: _buildCompactView(),
                          secondChild: _buildExpandedView(),
                        ),
                        // Divisor antes dos botões de hora/recorrência
                        const Divider(
                            color: AppColors.border,
                            height: 24,
                            indent: 16,
                            endIndent: 16),
                        _buildTimePickerButton(
                            context), // Botão para adicionar/editar hora
                        _buildRecurrenceSection(
                            context), // Botão para adicionar/editar recorrência
                        const SizedBox(height: 16), // Espaçamento inferior
                      ],
                    ),
                  ),
                ),
                // Rodapé fixo com botões de ação
                const Divider(color: AppColors.border, height: 1),
                Padding(
                  // Botões Cancelar/Selecionar
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(
                              context), // Fecha sem retornar valor
                          child: const Text(
                            "Cancelar",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 16,
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
                          onPressed:
                              _confirmSelection, // Chama a função que retorna o resultado
                          child: const Text(
                            "Selecionar",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Espaçamento extra na base para safe area (entalhes, etc.)
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom > 0
                        ? MediaQuery.of(context)
                            .padding
                            .bottom // Usa o padding da safe area
                        : 16) // Ou um padding padrão
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Widgets Internos ---

  /// Constrói a alça ("drag handle") no topo do modal.
  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: _toggleExpand, // Toca para expandir/recolher
      onVerticalDragUpdate: (details) {
        // Arrasta para expandir/recolher
        if (details.primaryDelta! < -4 && !_isExpanded)
          _toggleExpand(); // Arrasta pra cima
        else if (details.primaryDelta! > 4 && _isExpanded)
          _toggleExpand(); // Arrasta pra baixo
      },
      child: Container(
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
      ),
    );
  }

  /// Constrói o título "Definir Data".
  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
      child: Text(
        "Definir Data",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primaryText, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Constrói a visão compacta (título, header do mês, scroller de dias).
  Widget _buildCompactView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // _buildTitle(context), // Título movido para fora do AnimatedCrossFade
        _buildCompactHeader(context),
        _buildDateScroller(context), // <<< Contém Material wrapper
      ],
    );
  }

  /// Constrói o header da visão compacta (Setas < Mês/Ano >).
  Widget _buildCompactHeader(BuildContext context) {
    // Formata o mês e ano focados (ex: "Outubro de 2025")
    final titleText =
        _capitalize(DateFormat.yMMMM('pt_BR').format(_calendarFocusedDay));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // Alinha itens nas pontas
        children: [
          // --- ALTERAÇÃO (TASK 1): Função da seta esquerda alterada ---
          _buildCompactNavButton(
            Icons.chevron_left,
            () => _scrollDays(-1), // Rola dias para a esquerda
          ),
          // --- FIM DA ALTERAÇÃO ---

          // Texto Mês/Ano clicável para abrir o seletor
          InkWell(
            onTap: () => _showCustomMonthYearPicker(context),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titleText,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // --- ALTERAÇÃO (TASK 1): Função da seta direita alterada ---
          _buildCompactNavButton(
            Icons.chevron_right,
            () => _scrollDays(1), // Rola dias para a direita
          ),
          // --- FIM DA ALTERAÇÃO ---
        ],
      ),
    );
  }

  /// Constrói os botões de navegação de mês (< >) para a visão compacta.
  Widget _buildCompactNavButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: AppColors.primaryText),
      iconSize: 20,
      padding: EdgeInsets.zero, // Remove padding extra
      constraints: const BoxConstraints(), // Permite tamanho menor
      splashRadius: 20, // Raio do efeito de clique
      onPressed: onPressed,
    );
  }

  /// Constrói o `ListView` horizontal com os `_DatePill` para a visão compacta.
  Widget _buildDateScroller(BuildContext context) {
    // Envolve com Material para garantir contexto aos filhos do ListView.builder
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        // Define a altura fixa do scroller
        height: 100,
        child: ListView.builder(
          controller: _scrollController, // Controlador para scroll programático
          scrollDirection: Axis.horizontal, // Scroll horizontal
          padding: const EdgeInsets.symmetric(
              horizontal: 16.0), // Espaçamento nas laterais
          itemCount: _dateList.length, // Número de dias no mês
          itemBuilder: (context, index) {
            // Proteção contra índices inválidos
            if (index < 0 || index >= _dateList.length) {
              return const SizedBox.shrink();
            }

            final data = _dateList[index]; // Pega os dados do dia
            final bool isSelected = _isSameDay(data.date, _selectedDate);
            final bool isToday = _isSameDay(data.date, _todayMidnight);
            // Dia passado (e não hoje)
            final bool isPastDay =
                data.date.isBefore(_todayMidnight) && !isToday;

            // Define o texto do dia da semana
            String dayOfWeek;
            if (isToday) {
              dayOfWeek = "Hoje";
            } else if (_isSameDay(
                data.date, _todayMidnight.add(const Duration(days: 1)))) {
              dayOfWeek = "Amanhã";
            } else {
              dayOfWeek = toBeginningOfSentenceCase(
                      DateFormat.E('pt_BR').format(data.date)) ??
                  '';
            }

            // Retorna o widget _DatePill para este dia
            return _DatePill(
              dayOfWeek: dayOfWeek,
              dayOfMonth: data.date.day.toString(),
              personalDay: data.personalDay,
              isSelected: isSelected,
              isToday: isToday,
              width: _datePillWidth,
              isPastDay: isPastDay,
              // Define o onTap (null para dias passados)
              onTap: isPastDay
                  ? null
                  : () {
                      _handleDateSelection(data.date);
                    },
            );
          },
        ),
      ),
    );
  }

  /// Constrói a visão expandida (título, calendário completo).
  Widget _buildExpandedView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitle(context), // Título "Definir Data"
        _buildFullCalendarView(context), // <<< Contém Material wrapper
      ],
    );
  }

  /// Constrói o `TableCalendar` para a visão expandida.
  Widget _buildFullCalendarView(BuildContext context) {
    // Envolve com Material para garantir contexto aos builders do TableCalendar
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: TableCalendar(
          locale: 'pt_BR',
          focusedDay: _calendarFocusedDay,
          firstDay: DateTime(2020),
          lastDay: DateTime(2101),
          selectedDayPredicate: (day) => _isSameDay(day, _selectedDate),
          enabledDayPredicate: (day) =>
              !day.isBefore(_todayMidnight) || _isSameDay(day, _todayMidnight),
          onDaySelected: (selectedDay, focusedDay) {
            if (!selectedDay.isBefore(_todayMidnight) ||
                _isSameDay(selectedDay, _todayMidnight)) {
              _handleDateSelection(selectedDay);
            }
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _calendarFocusedDay =
                  DateTime(focusedDay.year, focusedDay.month, 1);
              _regenerateDateListForCurrentMonth();
            });
          },
          // --- Estilos ---
          headerStyle: HeaderStyle(
            titleCentered: false,
            formatButtonVisible: false,
            titleTextStyle: const TextStyle(height: 0, fontSize: 0),
            leftChevronPadding: EdgeInsets.zero,
            rightChevronPadding: EdgeInsets.zero,
            leftChevronMargin: const EdgeInsets.symmetric(horizontal: 4),
            rightChevronMargin: const EdgeInsets.symmetric(horizontal: 4),
            leftChevronIcon: const Icon(Icons.chevron_left,
                color: AppColors.primaryText, size: 24),
            rightChevronIcon: const Icon(Icons.chevron_right,
                color: AppColors.primaryText, size: 24),
          ),
          daysOfWeekStyle: const DaysOfWeekStyle(
            weekdayStyle:
                TextStyle(color: AppColors.secondaryText, fontSize: 12),
            weekendStyle:
                TextStyle(color: AppColors.secondaryText, fontSize: 12),
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
          // --- Builders Customizados ---
          calendarBuilders: CalendarBuilders(
            headerTitleBuilder: (context, day) {
              final titleText =
                  _capitalize(DateFormat.yMMMM('pt_BR').format(day));
              return Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showCustomMonthYearPicker(context),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              titleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.secondaryText,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      // Seleciona hoje e foca no mês atual
                      _handleDateSelection(_todayMidnight);
                      setState(() {
                        final now = DateTime.now();
                        _calendarFocusedDay = DateTime(now.year, now.month, 1);
                        _regenerateDateListForCurrentMonth();
                      });
                      // Opcional: Fechar o modal ao clicar em Hoje?
                      // _confirmSelection();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "Hoje",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              );
            },
            // Builders para as células dos dias
            defaultBuilder: (context, day, focusedDay) {
              final personalDay = _engine.calculatePersonalDayForDate(day);
              final isToday = _isSameDay(day, _todayMidnight);
              final isSelected = _isSameDay(day, _selectedDate);
              final isEnabled = !day.isBefore(_todayMidnight) || isToday;
              return _buildCalendarDayCell(
                day: day,
                personalDay: personalDay,
                isSelected: isSelected,
                isToday: isToday,
                isOutside: false,
                isEnabled: isEnabled,
              );
            },
            outsideBuilder: (context, day, focusedDay) {
              return _buildCalendarDayCell(
                day: day,
                personalDay: 0,
                isSelected: false,
                isToday: false,
                isOutside: true,
                isEnabled: false,
              );
            },
            selectedBuilder: (context, day, focusedDay) {
              final personalDay = _engine.calculatePersonalDayForDate(day);
              final isToday = _isSameDay(day, _todayMidnight);
              return _buildCalendarDayCell(
                day: day,
                personalDay: personalDay,
                isSelected: true,
                isToday: isToday,
                isOutside: false,
                isEnabled: true,
              );
            },
            todayBuilder: (context, day, focusedDay) {
              final personalDay = _engine.calculatePersonalDayForDate(day);
              final isSelected = _isSameDay(day, _selectedDate);
              return _buildCalendarDayCell(
                day: day,
                personalDay: personalDay,
                isSelected: isSelected,
                isToday: true,
                isOutside: false,
                isEnabled: true,
              );
            },
            disabledBuilder: (context, day, focusedDay) {
              final personalDay = _engine.calculatePersonalDayForDate(day);
              return _buildCalendarDayCell(
                day: day,
                personalDay: personalDay,
                isSelected: false,
                isToday: false,
                isOutside: !_isSameMonth(day, _calendarFocusedDay),
                isEnabled: false,
              );
            },
          ),
        ),
      ),
    );
  }

  /// Constrói a célula individual de um dia para o `TableCalendar`.
  Widget _buildCalendarDayCell({
    required DateTime day,
    required int personalDay,
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
    required bool isEnabled,
  }) {
    // Lógica visual da célula (sem alterações)
    Color borderColor =
        isOutside ? Colors.transparent : AppColors.border.withValues(alpha: 0.5);
    Color cellFillColor = Colors.transparent;
    double borderWidth = 0.8;
    if (isToday && isEnabled && !isSelected) {
      borderColor = AppColors.primary.withValues(alpha: 0.6);
      borderWidth = 1.5;
    }
    if (isSelected && isEnabled) {
      cellFillColor = AppColors.primary;
      borderColor = AppColors.primary;
      borderWidth = 2.0;
    }
    if (!isEnabled && !isOutside) {
      borderColor = AppColors.border.withValues(alpha: 0.3);
      borderWidth = 0.5;
    }
    Color baseDayTextColor;
    if (isSelected && isEnabled) {
      baseDayTextColor = Colors.white;
    } else if (isToday && isEnabled) {
      baseDayTextColor = AppColors.primary;
    } else if (isOutside) {
      baseDayTextColor = AppColors.tertiaryText.withValues(alpha: 0.5);
    } else {
      baseDayTextColor = AppColors.secondaryText;
    }
    Color dayTextColor =
        isEnabled ? baseDayTextColor : baseDayTextColor.withValues(alpha: 0.4);
    FontWeight dayFontWeight = ((isToday || isSelected) && isEnabled)
        ? FontWeight.bold
        : FontWeight.normal;
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
      child: (personalDay > 0 && !isOutside)
          ? VibrationPill(
              vibrationNumber: personalDay,
              type: VibrationPillType.micro,
              forceInvertedColors: (isSelected && isEnabled),
            )
          : const SizedBox(height: 16, width: 16),
    );

    // Retorna o Container (NÃO precisa mais do Material wrapper aqui)
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

  /// Constrói a linha para adicionar/editar o horário.
  Widget _buildTimePickerButton(BuildContext context) {
    final String timeText = _selectedTime != null
        ? _selectedTime!.format(context)
        : "Adicionar horário";
    final Color activeColor =
        _selectedTime != null ? AppColors.primary : AppColors.secondaryText;
    final FontWeight fontWeight =
        _selectedTime != null ? FontWeight.w600 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: () => _showCustomTimePicker(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Icon(Icons.access_time, color: activeColor, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  timeText,
                  style: TextStyle(
                      color: activeColor, fontSize: 16, fontWeight: fontWeight),
                ),
              ),
              if (_selectedTime != null)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedTime = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close,
                        color: AppColors.tertiaryText, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Constrói a linha para adicionar/editar a recorrência.
  Widget _buildRecurrenceSection(BuildContext context) {
    final String recurrenceText = _recurrenceRule.getSummaryText();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: _showRecurrencePicker,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              const Icon(Icons.repeat,
                  color: AppColors.secondaryText, size: 20),
              const SizedBox(width: 16),
              const Text(
                "Repetir",
                style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                recurrenceText,
                style: TextStyle(
                    color: _recurrenceRule.type == RecurrenceType.none
                        ? AppColors.secondaryText
                        : AppColors.primary,
                    fontSize: 16,
                    fontWeight: _recurrenceRule.type == RecurrenceType.none
                        ? FontWeight.w400
                        : FontWeight.w500),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.tertiaryText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
} // Fim da classe _CustomDatePickerModalState

// --- Widget Auxiliar (_DatePill - com alterações) ---

class _DatePill extends StatelessWidget {
  // Construtor e variáveis (sem alterações)
  final String dayOfWeek;
  final String dayOfMonth;
  final int personalDay;
  final bool isSelected;
  final bool isToday;
  final VoidCallback? onTap;
  final double width;
  final bool isPastDay;
  const _DatePill({
    required this.dayOfWeek,
    required this.dayOfMonth,
    required this.personalDay,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
    required this.width,
    required this.isPastDay,
  });

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DE CORES E OPACIDADE MODIFICADA ---
    final double opacity = isPastDay ? 0.4 : 1.0;

    // Define cores base
    Color bgColor = AppColors
        .cardBackground; // Padrão: fundo do modal (corrige "fundo preto")
    Color baseTextColor = AppColors.secondaryText;
    Color baseDayNumColor = AppColors.primaryText;
    Color baseBorderColor = AppColors.border;
    double borderWidth = 1.0;

    if (isToday && !isSelected) {
      // Estado "Hoje" (não selecionado)
      baseTextColor = AppColors.primary;
      baseDayNumColor = AppColors.primary;
      baseBorderColor = AppColors.primary.withValues(alpha: 0.6);
      borderWidth = 1.5;
      // bgColor permanece AppColors.cardBackground
    }
    if (isSelected) {
      // Estado "Selecionado"
      bgColor = AppColors.primary; // Fundo muda
      baseTextColor = Colors.white;
      baseDayNumColor = Colors.white;
      baseBorderColor = AppColors.primary;
      borderWidth = 2.0;
    }

    // O Opacity é aplicado no widget pai, então não precisamos
    // aplicar .withValues(alpha: ) em cada cor individualmente.
    // --- FIM DAS MODIFICAÇÕES ---

    return Opacity(
      opacity: opacity, // Aplica opacidade a tudo (para dias passados)
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              // Usa a cor base. O Opacity pai cuida do esmaecimento.
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                // Usa a cor base da borda. O Opacity pai cuida do esmaecimento.
                color: baseBorderColor,
                width: borderWidth,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayOfWeek.toUpperCase(),
                  style: TextStyle(
                    // Usa a cor base do texto. O Opacity pai cuida do esmaecimento.
                    color: baseTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayOfMonth,
                  style: TextStyle(
                    // Usa a cor base do número. O Opacity pai cuida do esmaecimento.
                    color: baseDayNumColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 24,
                  child: (personalDay > 0)
                      ? VibrationPill(
                          vibrationNumber: personalDay,
                          type: VibrationPillType.compact,
                          forceInvertedColors: isSelected,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
