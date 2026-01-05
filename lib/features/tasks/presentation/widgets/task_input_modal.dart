import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_date_picker_modal.dart';
import 'package:sincro_app_flutter/common/widgets/modern/schedule_task_sheet.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:sincro_app_flutter/models/date_picker_result.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/goals/presentation/create_goal_screen.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/create_goal_dialog.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/goal_selection_modal.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/tag_selection_modal.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

// --- REMOVIDO: Regex de data e SyntaxHighlightingController ---

class TaskInputModal extends StatefulWidget {
  final Function(ParsedTask parsedTask) onAddTask;
  final UserModel? userData;
  final String userId;
  final String? initialTaskText;
  final DateTime? initialDueDate;
  final TaskModel? taskToEdit;
  final Goal? preselectedGoal;

  const TaskInputModal({
    super.key,
    required this.onAddTask,
    required this.userData,
    required this.userId,
    this.initialTaskText,
    this.initialDueDate,
    this.taskToEdit,
    this.preselectedGoal,
  });

  @override
  State<TaskInputModal> createState() => _TaskInputModalState();
}

class _TaskInputModalState extends State<TaskInputModal> {
  // --- INÍCIO DA MUDANÇA: Controller Padrão ---
  late TextEditingController _textController;
  // --- FIM DA MUDANÇA ---

  DateTime _selectedDateForPill = DateTime.now();
  int _personalDay = 0;
  late RecurrenceRule _selectedRecurrenceRule;
  TimeOfDay? _selectedTime;
  final FocusNode _textFieldFocusNode = FocusNode();

  // --- ESTADO PARA OS "PILLS" ---
  String? _selectedGoalId;
  String? _selectedGoalTitle;
  DateTime? _selectedDate; // Novo estado para a data

  List<String> _selectedTags = []; // Novo estado para as tags
  Duration? _selectedReminderOffset; // Novo estado para o offset do lembrete

  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();

    // --- INÍCIO DA MUDANÇA: Controller Padrão ---
    _textController = TextEditingController();
    // --- FIM DA MUDANÇA ---

    DateTime initialDateForPill = DateTime.now();

    if (_isEditing) {
      _textController.text = widget.taskToEdit!.text;

      // --- INÍCIO DA MUDANÇA: Popula os "pills" em vez do texto ---
      _selectedTags = List.from(widget.taskToEdit!.tags);
      _selectedDate = widget.taskToEdit!.dueDate?.toLocal();
      // --- FIM DA MUDANÇA ---

      initialDateForPill =
          widget.taskToEdit!.dueDate?.toLocal() ?? initialDateForPill;
      _selectedTime = widget.taskToEdit!.reminderTime;
      _selectedRecurrenceRule = RecurrenceRule(
        type: widget.taskToEdit!.recurrenceType,
        daysOfWeek: widget.taskToEdit!.recurrenceDaysOfWeek,
        endDate: widget.taskToEdit!.recurrenceEndDate,
      );

      _selectedGoalId = widget.taskToEdit!.journeyId;
      _selectedGoalTitle = widget.taskToEdit!.journeyTitle;
    } else {
      // Lógica para NOVAS tarefas
      _textController.text = widget.initialTaskText ?? '';
      _selectedTime = null;
      _selectedRecurrenceRule = RecurrenceRule();
      _selectedTags = []; // Começa vazio
      _selectedDate = null; // Garante que o pill de data não apareça por padrão

      // --- INÍCIO DA CORREÇÃO (Problema 1 e 2) ---
      // Lógica condicional:
      // Se uma meta é pré-selecionada, estamos na tela de metas.
      // Se não, estamos no calendário ou foco.
      if (widget.preselectedGoal != null) {
        // --- LÓGICA DA TELA DE METAS ---
        _selectedGoalId = widget.preselectedGoal!.id;
        _selectedGoalTitle = widget.preselectedGoal!.title;

        // --- INÍCIO DA CORREÇÃO ---
        // As linhas que adicionavam a tag automaticamente foram REMOVIDAS.
        // --- FIM DA CORREÇÃO ---

        // Usa a data inicial APENAS para a pílula de vibração (Problema 1)
        if (widget.initialDueDate != null) {
          initialDateForPill = DateTime(
            widget.initialDueDate!.year,
            widget.initialDueDate!.month,
            widget.initialDueDate!.day,
          );
        }
        // _selectedDate continua nulo, então o pill de data não aparece
      } else {
        // --- LÓGICA DO CALENDÁRIO / FOCO ---
        // Só mostra o pill de data se initialDueDate foi EXPLICITAMENTE fornecido
        if (widget.initialDueDate != null) {
          // CORREÇÃO: Usa os componentes da data para evitar shift de fuso horário (UTC -> Local)
          // Se widget.initialDueDate for 29/11 00:00 UTC, toLocal() viraria 28/11 21:00 (BRT).
          // Ao usar DateTime(y,m,d), criamos 29/11 00:00 Local, mantendo o dia correto.
          initialDateForPill = DateTime(
            widget.initialDueDate!.year,
            widget.initialDueDate!.month,
            widget.initialDueDate!.day,
          );
          
          // Define o pill de data SEMPRE se for fornecido (mesmo que seja hoje)
          _selectedDate = initialDateForPill;
        }
      }
      // --- FIM DA CORREÇÃO ---
    }

    // --- REMOVIDO: _textController.addListener(_onTextChanged) ---

    // Define a data para a pílula de vibração (usa data selecionada ou a data inicial)
    _selectedDateForPill = _selectedDate ?? initialDateForPill;
    if (widget.userData != null) {
      _updateVibrationForDate(_selectedDateForPill);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _textFieldFocusNode.requestFocus();
      _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length));
    });
  }

  // --- REMOVIDO: _onTextChanged ---

  // isSameDay (inalterada)
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // _updateVibrationForDate (inalterada)
  void _updateVibrationForDate(DateTime date) {
    // Consistent with Firestore: convert to UTC midnight for calculation
    final dateMidnight = DateTime.utc(date.year, date.month, date.day);
    if (widget.userData != null &&
        widget.userData!.dataNasc.isNotEmpty &&
        widget.userData!.nomeAnalise.isNotEmpty) {
      final engine = NumerologyEngine(
        nomeCompleto: widget.userData!.nomeAnalise,
        dataNascimento: widget.userData!.dataNasc,
      );
      try {
        final day = engine.calculatePersonalDayForDate(dateMidnight);
        if (mounted) {
          setState(() {
            _selectedDateForPill = dateMidnight;
            _personalDay = day;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _selectedDateForPill = dateMidnight;
            _personalDay = 0;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _selectedDateForPill = dateMidnight;
          _personalDay = 0;
        });
      }
    }
  }

  // --- REMOVIDO: _insertActionText ---

  // _selectGoal (inalterada - já está correta)
  void _selectGoal() async {
    if (widget.preselectedGoal != null) return;
    if (widget.userData == null) return;

    FocusScope.of(context).unfocus();

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GoalSelectionModal(
          userId: widget.userId,
        );
      },
    );

    if (result == null) return;

    if (result is Goal) {
      setState(() {
        _selectedGoalId = result.id;
        _selectedGoalTitle = result.title;
      });
    } else if (result == '_CREATE_NEW_GOAL_') {
      _openCreateGoalWidget();
    }
  }

  // _openCreateGoalWidget (inalterada - já está correta)
  void _openCreateGoalWidget() async {
    if (widget.userData == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    bool? creationSuccess;

    if (isMobile) {
      creationSuccess = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => CreateGoalScreen(userData: widget.userData!),
          fullscreenDialog: true,
        ),
      );
    } else {
      creationSuccess = await showDialog<bool>(
        context: context,
        builder: (context) {
          return CreateGoalDialog(userData: widget.userData!);
        },
      );
    }

    if (creationSuccess == true) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _selectGoal();
      }
    }
  }

  // --- INÍCIO DA MUDANÇA: _showTagSelectionModal atualizada ---
  void _showTagSelectionModal() async {
    FocusScope.of(context).unfocus();

    // Abre o modal e espera o retorno (String)
    final String? tagName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TagSelectionModal(
          userId: widget.userId,
        );
      },
    );

    // Adiciona a tag ao estado se ela for válida e não existir
    if (tagName != null &&
        tagName.isNotEmpty &&
        !_selectedTags.contains(tagName)) {
      setState(() {
        _selectedTags.add(tagName);
      });
    }
  }
  // --- FIM DA MUDANÇA ---

  // --- INÍCIO DA MUDANÇA: _showDatePickerModal atualizada ---
  void _showDatePickerModal() {
    FocusScope.of(context).unfocus();
    if (widget.userData == null) return;

    // A data inicial é a data já selecionada, ou a data do "pill", ou hoje
    DateTime initialPickerDate = _selectedDate ?? _selectedDateForPill;

    // Adiciona a hora (se já houver uma)
    initialPickerDate = DateTime(
      initialPickerDate.year,
      initialPickerDate.month,
      initialPickerDate.day,
      _selectedTime?.hour ?? 0,
      _selectedTime?.minute ?? 0,
    );

    RecurrenceRule ruleToPass = _selectedRecurrenceRule;

    showModalBottomSheet<DatePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleTaskSheet(
        initialDate: initialPickerDate,
        initialTime: _selectedTime,
        initialRecurrence: ruleToPass,
        userData: widget.userData!,
      ),
    ).then((result) {
      if (result != null) {
        final selectedDateTime = result.dateTime;
        final selectedDateMidnight = DateTime(selectedDateTime.year,
            selectedDateTime.month, selectedDateTime.day);

        // Atualiza a pílula de vibração
        _updateVibrationForDate(selectedDateMidnight);

        // Atualiza o estado
        setState(() {
          _selectedDate = selectedDateMidnight; // Armazena a data (meia-noite) para pílulas e lógica
          
          // Se o usuário selecionou um horário, extraímos dele.
          // Se não (Dia Inteiro), fica null.
          if (result.hasTime) {
             _selectedTime = TimeOfDay.fromDateTime(selectedDateTime);
          } else {
             _selectedTime = null;
          }
          
          _selectedRecurrenceRule = result.recurrenceRule;
          _selectedReminderOffset = result.reminderOffset; // Captura offset
        });
      }
    });
  }
  // --- FIM DA MUDANÇA ---

  // --- INÍCIO DA MUDANÇA: _submit atualizado ---
  void _submit() async {
    final rawText = _textController.text.trim();

    // 1. Validação de texto obrigatório
    if (rawText.isEmpty) {
      // Mostra um feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite o nome da tarefa.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 2),
        ),
      );
      _textFieldFocusNode.requestFocus(); // Foca no campo de texto
      return;
    }

    // 2. Parser simplificado (síncrono)
    final ParsedTask textParseResult = TaskParser.parse(rawText);

    // 3. Define a data
    final ParsedTask finalParsedTask = textParseResult.copyWith(
      // cleanText já está correto vindo do parse
      dueDate: _selectedDate, // Envia a data do "pill" (pode ser null)
      reminderTime: _selectedTime,
      recurrenceRule: _selectedRecurrenceRule,
      tags: _selectedTags, // Envia a lista de tags
      journeyId: _selectedGoalId, // Envia o ID da meta
      journeyTitle: _selectedGoalTitle, // Envia o Título da meta
      // O Dia Pessoal será recalculado no foco_do_dia_screen com base na data
    ).copyWith(
        reminderAt: () {
            // Calculate numeric reminderAt
            if (_selectedDate == null) return null;
            if (_selectedReminderOffset == null) return null;
            
            DateTime base = _selectedDate!; // Midnight
            if (_selectedTime != null) {
                base = DateTime(base.year, base.month, base.day, _selectedTime!.hour, _selectedTime!.minute);
            }
            return base.subtract(_selectedReminderOffset!);
        }()
    );

    widget.onAddTask(finalParsedTask);

    if (mounted) Navigator.of(context).pop();
  }
  // --- FIM DA MUDANÇA ---

  @override
  void dispose() {
    // _textController.removeListener(_onTextChanged); // Removido
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // --- INÍCIO DA MUDANÇA: build() atualizado com "Pills" ---
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 12),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                focusNode: _textFieldFocusNode,
                controller: _textController, // Controller padrão
                style:
                    const TextStyle(fontSize: 16, color: AppColors.primaryText),
                decoration: InputDecoration(
                  hintText: _selectedGoalId != null
                      ? "Adicionar novo marco..."
                      : "Adicionar tarefa...", // Hint simplificado
                  hintStyle: const TextStyle(color: AppColors.tertiaryText),
                  border: InputBorder.none,
                ),
                onTap: () {},
                onSubmitted: (_) => _submit(),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
              ),

              // --- INÍCIO: ÁREA DE "PILLS" ---
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Wrap(
                  spacing: 6.0, // Espaço horizontal entre os pills
                  runSpacing: 4.0, // Espaço vertical entre as linhas de pills
                  children: [
                    // Pill da Meta (lógica que já tínhamos)
                    if (_selectedGoalTitle != null &&
                        _selectedGoalTitle!.isNotEmpty)
                      _buildPill(
                        label: _selectedGoalTitle!,
                        icon: Icons.flag_rounded,
                        color: Colors.cyanAccent,
                        onDeleted: widget.preselectedGoal != null
                            ? null
                            : () {
                                setState(() {
                                  _selectedGoalId = null;
                                  _selectedGoalTitle = null;
                                });
                              },
                      ),

                    // Pill da Data
                    if (_selectedDate != null)
                      _buildPill(
                        label: _formatDateReadable(_selectedDate!),
                        icon: Icons.calendar_today_rounded,
                        color: Colors.orangeAccent,
                        onDeleted: () {
                          setState(() {
                            _selectedDate = null;
                            _selectedTime = null; // Reseta a hora também
                            _selectedRecurrenceRule =
                                RecurrenceRule(); // Reseta recorrência
                            _updateVibrationForDate(
                                DateTime.now()); // Atualiza pílula de vibração
                          });
                        },
                      ),

                    // Pills das Tags
                    ..._selectedTags.map(
                      (tag) => _buildPill(
                        label: tag,
                        icon: Icons.label_rounded,
                        color: Colors.purpleAccent,
                        onDeleted: () {
                          setState(() {
                            _selectedTags.remove(tag);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // --- FIM: ÁREA DE "PILLS" ---

              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.label_outline,
                    onTap: _showTagSelectionModal, // Chama o novo modal
                    color:
                        _selectedTags.isNotEmpty ? Colors.purpleAccent : null,
                  ),
                  _buildActionButton(
                    icon: Icons.flag_outlined,
                    onTap: widget.preselectedGoal != null ? null : _selectGoal,
                    color: _selectedGoalId != null
                        ? Colors.cyanAccent
                        : (widget.preselectedGoal != null
                            ? AppColors.tertiaryText.withValues(alpha: 0.3)
                            : AppColors.tertiaryText),
                  ),
                  _buildActionButton(
                    icon: Icons.calendar_today_outlined,
                    onTap: _showDatePickerModal, // Chama o novo modal
                    color: _selectedDate != null ? Colors.orangeAccent : null,
                  ),
                  const Spacer(),
                  if (_personalDay > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: VibrationPill(
                        vibrationNumber: _personalDay,
                        onTap: () {
                          showVibrationInfoModal(context,
                              vibrationNumber: _personalDay);
                        },
                      ),
                    ),
                  Padding(
                    padding:
                        EdgeInsets.only(left: _personalDay > 0 ? 8.0 : 0.0),
                    child: ElevatedButton(
                      onPressed: _submit, // Chama o submit atualizado
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: const CircleBorder(), // Botão circular
                          padding: const EdgeInsets.all(12), // Padding uniforme
                          minimumSize: const Size(44, 44)), // Quadrado perfeito para círculo
                      child: Icon(
                        _isEditing ? Icons.check : Icons.arrow_upward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
  // --- FIM DA MUDANÇA: build() ---

  // Helper _buildActionButton (modificado para aceitar cor opcional)
  Widget _buildActionButton(
      {required IconData icon, required VoidCallback? onTap, Color? color}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color ?? AppColors.tertiaryText),
      splashRadius: 20,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }

  // --- NOVO HELPER: _buildPill ---
  /// Cria um "pill" (etiqueta) customizado.
  Widget _buildPill({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onDeleted, // torna a remoção opcional
  }) {
    return InputChip(
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      avatar: Icon(
        icon,
        size: 16,
        color: color,
      ),
      backgroundColor: AppColors.background.withValues(alpha: 0.5),
      onDeleted: onDeleted,
      deleteIconColor: AppColors.secondaryText.withValues(alpha: 0.7),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: color.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  // Formata data de forma legível: "12 de Dezembro" ou "12 de Dezembro de 2026"
  // Inclui horário se _selectedTime estiver definido
  String _formatDateReadable(DateTime date) {
    final now = DateTime.now();
    final months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];

    final day = date.day;
    final month = months[date.month - 1];

    String dateStr;
    if (date.year == now.year) {
      dateStr = '$day de $month';
    } else {
      dateStr = '$day de $month de ${date.year}';
    }

    // Adiciona horário se houver (e se não for nulo)
    if (_selectedTime != null) {
      final hh = _selectedTime!.hour.toString().padLeft(2, '0');
      final mm = _selectedTime!.minute.toString().padLeft(2, '0');
      dateStr += ' às $hh:$mm';
    }

    return dateStr;
  }
}
