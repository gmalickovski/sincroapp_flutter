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
import 'package:sincro_app_flutter/services/supabase_service.dart'; // NOVO
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/common/widgets/mention_input_field.dart'; // NOVO
import 'package:sincro_app_flutter/common/widgets/mention_text_editing_controller.dart'; // NOVO
import 'package:sincro_app_flutter/common/widgets/contact_picker_modal.dart'; // NOVO
import 'package:sincro_app_flutter/models/subscription_model.dart'; // NOVO
import 'package:sincro_app_flutter/models/contact_model.dart'; // NOVO


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
  late MentionTextEditingController _textController; // MUDANÇA: Controller com Highlight
  final SupabaseService _supabaseService = SupabaseService(); // Service para buscar contatos
  Set<String> _validUsernames = {}; // Armazena usernames válidos para o highlight
  // --- FIM DA MUDANÇA ---

  DateTime _selectedDateForPill = DateTime.now();
  int _personalDay = 0;
  late RecurrenceRule _selectedRecurrenceRule;
  TimeOfDay? _selectedTime;
  final FocusNode _textFieldFocusNode = FocusNode();

  // --- ESTADO PARA OS "PILLS" ---
  String? _selectedGoalId;
  String? _selectedGoalTitle;
  DateTime? _selectedGoalDeadline; // NOVO: Armazena data da meta
  DateTime? _selectedDate; // Novo estado para a data

  List<String> _selectedTags = []; // Novo estado para as tags
  List<String> _sharedWithUsernames = []; // NOVO: Usernames selecionados para compartilhar
  Duration? _selectedReminderOffset; // Novo estado para o offset do lembrete

  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();

    // --- INÍCIO DA MUDANÇA: Controller Padrão ---
    _textController = MentionTextEditingController(); // Inicializa vazio
    _fetchContactsForMentions(); // Busca contatos para validar mentions
    // --- FIM DA MUDANÇA ---

    DateTime initialDateForPill = DateTime.now();

    if (_isEditing) {
      _textController.text = widget.taskToEdit!.text;

      // --- INÍCIO DA MUDANÇA: Popula os "pills" em vez do texto ---
      _selectedTags = List.from(widget.taskToEdit!.tags);
      _sharedWithUsernames = List.from(widget.taskToEdit!.sharedWith); // NOVO
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
        _selectedGoalDeadline = widget.preselectedGoal!.targetDate; // Popula deadline

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

  List<ContactModel>? _cachedContacts; // Cache for picker
  bool _isLoadingContacts = false; // Loading state for button

  // ...

  Future<void> _fetchContactsForMentions() async {
    try {
      final currentUserId = widget.userId;
      final contacts = await _supabaseService.getContacts(currentUserId);
      
      if (mounted) {
        setState(() {
          _cachedContacts = contacts; // Store full list
          // Filtra ativos e mapeia para usernames não nulos
          _validUsernames = contacts
              .where((c) => c.status == 'active' && c.username != null)
              .map((c) => c.username!)
              .toSet();
              
          _textController.updateValidMentions(_validUsernames);
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar contatos para mentions: $e");
    }
  }

  // ...
  
  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _updateVibrationForDate(DateTime date) {
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
        _selectedGoalDeadline = result.targetDate; // Captura deadline da seleção
        _sharedWithUsernames = []; // Limpa contatos ao selecionar meta (Exclusividade)
      });
    } else if (result == '_CREATE_NEW_GOAL_') {
      _openCreateGoalWidget();
    }
  }

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

  void _showTagSelectionModal() async {
    FocusScope.of(context).unfocus();

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

    if (tagName != null &&
        tagName.isNotEmpty &&
        !_selectedTags.contains(tagName)) {
      setState(() {
        _selectedTags.add(tagName);
      });
    }
  }

  void _showDatePickerModal() {
    FocusScope.of(context).unfocus();
    if (widget.userData == null) return;

    DateTime initialPickerDate = _selectedDate ?? _selectedDateForPill;

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
        goalDeadline: _selectedGoalDeadline,
      ),
    ).then((result) {
      if (result != null) {
        final selectedDateTime = result.dateTime;
        final selectedDateMidnight = DateTime(selectedDateTime.year,
            selectedDateTime.month, selectedDateTime.day);

        _updateVibrationForDate(selectedDateMidnight);

        setState(() {
          _selectedDate = selectedDateMidnight;
          
          if (result.hasTime) {
             _selectedTime = TimeOfDay.fromDateTime(selectedDateTime);
          } else {
             _selectedTime = null;
          }
          
          _selectedRecurrenceRule = result.recurrenceRule;
          _selectedReminderOffset = result.reminderOffset;
        });
      }
    });
  }

  void _submit() async {
    final rawText = _textController.text.trim();

    if (rawText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, digite o nome da tarefa.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 2),
        ),
      );
      _textFieldFocusNode.requestFocus();
      return;
    }

    final ParsedTask textParseResult = TaskParser.parse(rawText);

    final Set<String> mergedTags = {
      ..._selectedTags,
      ...textParseResult.tags
    };
    
    final Set<String> mergedSharedWith = {
      ..._sharedWithUsernames,
      ...textParseResult.sharedWith
    };

    final ParsedTask finalParsedTask = textParseResult.copyWith(
      dueDate: _selectedDate,
      reminderTime: _selectedTime,
      recurrenceRule: _selectedRecurrenceRule,
      tags: mergedTags.toList(),
      sharedWith: mergedSharedWith.toList(),
      journeyId: _selectedGoalId,
      journeyTitle: _selectedGoalTitle,
    ).copyWith(
        reminderAt: () {
            if (_selectedDate == null) return null;
            if (_selectedReminderOffset == null) return null;
            
            DateTime base = _selectedDate!;
            if (_selectedTime != null) {
                base = DateTime(base.year, base.month, base.day, _selectedTime!.hour, _selectedTime!.minute);
            }
            return base.subtract(_selectedReminderOffset!);
        }()
    );

    widget.onAddTask(finalParsedTask);

    if (mounted) Navigator.of(context).pop();
  }
  
  void _openContactPicker() async {
    // Se ainda não carregou, carrega agora
    if (_cachedContacts == null) {
        if (_isLoadingContacts) return;
        setState(() => _isLoadingContacts = true);
        try {
            await _fetchContactsForMentions();
        } finally {
            if (mounted) setState(() => _isLoadingContacts = false);
        }
    }
    
    // Se falhou ou vazio (verifique lógica de retry se necessário, mas aqui assume que tentou)
    final contactsToPass = _cachedContacts ?? []; 

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ContactPickerModal(
          preSelectedUsernames: _sharedWithUsernames,
          currentDate: _selectedDate ?? DateTime.now(),
          initialContacts: contactsToPass, // PASS CACHED DATA
          onSelectionChanged: (selectedUsernames) {
            setState(() {
              _sharedWithUsernames = selectedUsernames;
            });
          },
          onDateChanged: (newDate) {
            setState(() {
              _selectedDate = newDate;
            });
            _updateVibrationForDate(newDate);
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      // Adiciona mentions no texto
      String currentText = _textController.text;
      
      if (currentText.isNotEmpty && !currentText.endsWith(' ')) {
        currentText += ' ';
      }

      for (var username in result) {
        // Só adiciona se não estiver já mencionado?
        // O comportamento anterior era adicionar sempre. Mantemos.
        if (!currentText.contains('@$username')) {
             currentText += '@$username ';
        }
      }

      _textController.text = currentText;
      
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
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  fillColor: Colors.transparent,
                  hoverColor: Colors.transparent,
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
                    // Pill da Meta (EXIBIDO APENAS SE NÃO FOR PRÉ-SELECIONADO)
                    if (_selectedGoalTitle != null &&
                        _selectedGoalTitle!.isNotEmpty &&
                        widget.preselectedGoal == null)
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
                                  _selectedGoalDeadline = null; // Limpa deadline
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
                  // Botão de Meta (EXIBIDO APENAS SE NÃO FOR PRÉ-SELECIONADO)
                  if (widget.preselectedGoal == null)
                    _buildActionButton(
                      icon: Icons.flag_outlined,
                      onTap: _selectGoal,
                      color: _selectedGoalId != null ? Colors.cyanAccent : null,
                    ),
                  _buildActionButton(
                    icon: Icons.calendar_today_outlined,
                    onTap: _showDatePickerModal, // Chama o novo modal
                    color: _selectedDate != null ? Colors.orangeAccent : null,
                  ),

                  
                    if (widget.userData != null && 
                        widget.userData!.subscription.plan != SubscriptionPlan.free)
                      _buildActionButton(
                        icon: Icons.person_outline,
                        onTap: _selectedGoalId != null ? null : _openContactPicker, // Desativa se tiver meta
                        color: _selectedGoalId != null 
                            ? AppColors.tertiaryText.withValues(alpha: 0.3) // Visual desativado
                            : (_sharedWithUsernames.isNotEmpty ? Colors.lightBlueAccent : null),
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
