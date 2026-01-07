import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import 'package:sincro_app_flutter/common/widgets/mention_input_field.dart'; // NOVO
import 'package:sincro_app_flutter/common/widgets/mention_text_editing_controller.dart'; // NOVO
import 'package:sincro_app_flutter/common/widgets/contact_picker_modal.dart'; // NOVO

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
  // --- IN├ìCIO DA MUDAN├çA: Controller Padr├úo ---
  late MentionTextEditingController _textController; // MUDAN├çA: Controller com Highlight
  // --- FIM DA MUDAN├çA ---

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
  List<String> _sharedWithUsernames = []; // NOVO: Usernames selecionados para compartilhar
  Duration? _selectedReminderOffset; // Novo estado para o offset do lembrete

  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();

    // --- IN├ìCIO DA MUDAN├çA: Controller Padr├úo ---
    _textController = MentionTextEditingController(); // MUDAN├çA
    // --- FIM DA MUDAN├çA ---

    DateTime initialDateForPill = DateTime.now();

    if (_isEditing) {
      _textController.text = widget.taskToEdit!.text;

      // --- IN├ìCIO DA MUDAN├çA: Popula os "pills" em vez do texto ---
      _selectedTags = List.from(widget.taskToEdit!.tags);
      _sharedWithUsernames = List.from(widget.taskToEdit!.sharedWith); // NOVO
      _selectedDate = widget.taskToEdit!.dueDate?.toLocal();
      // --- FIM DA MUDAN├çA ---

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
      // L├│gica para NOVAS tarefas
      _textController.text = widget.initialTaskText ?? '';
      _selectedTime = null;
      _selectedRecurrenceRule = RecurrenceRule();
      _selectedTags = []; // Come├ºa vazio
      _selectedDate = null; // Garante que o pill de data n├úo apare├ºa por padr├úo

      // --- IN├ìCIO DA CORRE├ç├âO (Problema 1 e 2) ---
      // L├│gica condicional:
      // Se uma meta ├® pr├®-selecionada, estamos na tela de metas.
      // Se n├úo, estamos no calend├írio ou foco.
      if (widget.preselectedGoal != null) {
        // --- L├ôGICA DA TELA DE METAS ---
        _selectedGoalId = widget.preselectedGoal!.id;
        _selectedGoalTitle = widget.preselectedGoal!.title;

        // --- IN├ìCIO DA CORRE├ç├âO ---
        // As linhas que adicionavam a tag automaticamente foram REMOVIDAS.
        // --- FIM DA CORRE├ç├âO ---

        // Usa a data inicial APENAS para a p├¡lula de vibra├º├úo (Problema 1)
        if (widget.initialDueDate != null) {
          initialDateForPill = DateTime(
            widget.initialDueDate!.year,
            widget.initialDueDate!.month,
            widget.initialDueDate!.day,
          );
        }
        // _selectedDate continua nulo, ent├úo o pill de data n├úo aparece
      } else {
        // --- L├ôGICA DO CALEND├üRIO / FOCO ---
        // S├│ mostra o pill de data se initialDueDate foi EXPLICITAMENTE fornecido
        if (widget.initialDueDate != null) {
          // CORRE├ç├âO: Usa os componentes da data para evitar shift de fuso hor├írio (UTC -> Local)
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
      // --- FIM DA CORRE├ç├âO ---
    }

    // --- REMOVIDO: _textController.addListener(_onTextChanged) ---

    // Define a data para a p├¡lula de vibra├º├úo (usa data selecionada ou a data inicial)
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

  // _selectGoal (inalterada - j├í est├í correta)
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

  // _openCreateGoalWidget (inalterada - j├í est├í correta)
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

  // --- IN├ìCIO DA MUDAN├çA: _showTagSelectionModal atualizada ---
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

    // Adiciona a tag ao estado se ela for v├ílida e n├úo existir
    if (tagName != null &&
        tagName.isNotEmpty &&
        !_selectedTags.contains(tagName)) {
      setState(() {
        _selectedTags.add(tagName);
      });
    }
  }
  // --- FIM DA MUDAN├çA ---

  // --- IN├ìCIO DA MUDAN├çA: _showDatePickerModal atualizada ---
  void _showDatePickerModal() {
    FocusScope.of(context).unfocus();
    if (widget.userData == null) return;

    // A data inicial ├® a data j├í selecionada, ou a data do "pill", ou hoje
    DateTime initialPickerDate = _selectedDate ?? _selectedDateForPill;

    // Adiciona a hora (se j├í houver uma)
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

        // Atualiza a p├¡lula de vibra├º├úo
        _updateVibrationForDate(selectedDateMidnight);

        // Atualiza o estado
        setState(() {
          _selectedDate = selectedDateMidnight; // Armazena a data (meia-noite) para p├¡lulas e l├│gica
          
          // Se o usu├írio selecionou um hor├írio, extra├¡mos dele.
          // Se n├úo (Dia Inteiro), fica null.
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
  // --- FIM DA MUDAN├çA ---

  // --- IN├ìCIO DA MUDAN├çA: _submit atualizado ---
  void _submit() async {
    final rawText = _textController.text.trim();

    // 1. Valida├º├úo de texto obrigat├│rio
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

    // 2. Parser simplificado (s├¡ncrono)
    final ParsedTask textParseResult = TaskParser.parse(rawText);

    // 3. Define a data
    final ParsedTask finalParsedTask = textParseResult.copyWith(
      // cleanText j├í est├í correto vindo do parse
      dueDate: _selectedDate, // Envia a data do "pill" (pode ser null)
      reminderTime: _selectedTime,
      recurrenceRule: _selectedRecurrenceRule,
      tags: _selectedTags, // Envia a lista de tags
      journeyId: _selectedGoalId, // Envia o ID da meta
      journeyTitle: _selectedGoalTitle, // Envia o T├¡tulo da meta
      // O Dia Pessoal ser├í recalculado no foco_do_dia_screen com base na data
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
  // --- FIM DA MUDAN├çA ---

  void _openContactPicker() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ContactPickerModal(
          preSelectedUsernames: _sharedWithUsernames,
          currentDate: _selectedDate ?? DateTime.now(),
          onSelectionChanged: (selectedUsernames) {
            // Atualiza o estado com os usernames selecionados
            setState(() {
              _sharedWithUsernames = selectedUsernames;
            });
            // Não fecha o modal aqui, o usuário pode continuar selecionando
          },
          onDateChanged: (newDate) {
            // A data é atualizada quando o usuário clica no ✓ para confirmar
            setState(() {
              _selectedDate = newDate;
            });
            // Update vibration pill for the new date
            _updateVibrationForDate(newDate);
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Adiciona mentions no texto
      String currentText = _textController.text;
      
      // Adiciona espa├ºo se n├úo tiver
      if (currentText.isNotEmpty && !currentText.endsWith(' ')) {
        currentText += ' ';
      }

      for (var username in result) {
        currentText += '@$username ';
      }

      _textController.text = currentText;
      
      // Move cursor para o final
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
  }

  @override
  void dispose() {
    // _textController.removeListener(_onTextChanged); // Removido
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // --- IN├ìCIO DA MUDAN├çA: build() atualizado com "Pills" ---
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
              // Substitu├¡do TextField por MentionInputField
              MentionInputField(
                controller: _textController,
                focusNode: _textFieldFocusNode,
                onSubmitted: (_) => _submit(), // Chama o submit atualizado
                hintText: _selectedGoalId != null
                    ? "Adicionar novo marco... use @ para mencionar"
                    : "Adicionar tarefa... use @ para mencionar",
                decoration: InputDecoration(
                  hintStyle: const TextStyle(color: AppColors.tertiaryText),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
              ),

              // --- IN├ìCIO: ├üREA DE "PILLS" ---
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Wrap(
                  spacing: 6.0, // Espa├ºo horizontal entre os pills
                  runSpacing: 4.0, // Espa├ºo vertical entre as linhas de pills
                  children: [
                    // Pill da Meta (l├│gica que j├í t├¡nhamos)
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
                            _selectedTime = null; // Reseta a hora tamb├®m
                            _selectedRecurrenceRule =
                                RecurrenceRule(); // Reseta recorr├¬ncia
                            _updateVibrationForDate(
                                DateTime.now()); // Atualiza p├¡lula de vibra├º├úo
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
                    
                    // Pills dos Contatos Compartilhados
                    ..._sharedWithUsernames.map(
                      (username) => _buildPill(
                        label: '@$username',
                        icon: Icons.person,
                        color: Colors.lightBlueAccent,
                        onDeleted: () {
                          setState(() {
                            _sharedWithUsernames.remove(username);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // --- FIM: ├üREA DE "PILLS" ---

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
                            ? AppColors.tertiaryText.withOpacity(0.3)
                            : AppColors.tertiaryText),
                  ),
                  _buildActionButton(
                    icon: Icons.calendar_today_outlined,
                    onTap: _showDatePickerModal, // Chama o novo modal
                    color: _selectedDate != null ? Colors.orangeAccent : null,
                  ),
                  // NOVO: Botão para abrir o Contact Picker
                  _buildActionButton(
                    icon: Icons.person_add_alt,
                    onTap: _openContactPicker,
                    color: _sharedWithUsernames.isNotEmpty ? Colors.lightBlueAccent : null,
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
                          shape: const CircleBorder(), // Bot├úo circular
                          padding: const EdgeInsets.all(12), // Padding uniforme
                          minimumSize: const Size(44, 44)), // Quadrado perfeito para c├¡rculo
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
  // --- FIM DA MUDAN├çA: build() ---

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
    VoidCallback? onDeleted, // torna a remo├º├úo opcional
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

  // Formata data de forma leg├¡vel: "12 de Dezembro" ou "12 de Dezembro de 2026"
  // Inclui hor├írio se _selectedTime estiver definido
  String _formatDateReadable(DateTime date) {
    final now = DateTime.now();
    final months = [
      'Janeiro',
      'Fevereiro',
      'Mar├ºo',
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

    // Adiciona hor├írio se houver (e se n├úo for nulo)
    if (_selectedTime != null) {
      final hh = _selectedTime!.hour.toString().padLeft(2, '0');
      final mm = _selectedTime!.minute.toString().padLeft(2, '0');
      dateStr += ' ├ás $hh:$mm';
    }

    return dateStr;
  }
}
