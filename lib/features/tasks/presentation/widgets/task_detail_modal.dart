// lib/features/tasks/presentation/widgets/task_detail_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Para DeepCollectionEquality
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/custom_loading_spinner.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/models/date_picker_result.dart';
import 'package:sincro_app_flutter/common/widgets/modern/schedule_task_sheet.dart';
import 'package:sincro_app_flutter/models/recurrence_rule.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/goals/presentation/create_goal_screen.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/create_goal_dialog.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/goal_selection_modal.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class TaskDetailModal extends StatefulWidget {
  final TaskModel task;
  final UserModel userData;

  const TaskDetailModal({
    super.key,
    required this.task,
    required this.userData,
  });

  @override
  State<TaskDetailModal> createState() => _TaskDetailModalState();
}

class _TaskDetailModalState extends State<TaskDetailModal> {
  final SupabaseService _supabaseService = SupabaseService();
  late TextEditingController _textController;
  Goal? _selectedGoal;
  List<String> _currentTags = [];
  late int _personalDay;
  VibrationContent? _dayInfo;
  bool _hasChanges = false;
  bool _isLoading = false;
  bool _isLoadingGoal = false;

  // Estados originais para comparação
  late String _originalText;
  late String? _originalGoalId;
  late List<String> _originalTags;
  late DateTime? _originalDateTime;
  late RecurrenceRule _originalRecurrenceRule;
  late Duration? _originalReminderOffset; // Novo

  // Estados para data/hora/recorrência/lembrete
  late DateTime? _selectedDateTime;
  late RecurrenceRule _recurrenceRule;
  Duration? _reminderOffset; // Novo

  final TextEditingController _tagInputController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();
  final DeepCollectionEquality _listEquality = const DeepCollectionEquality();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.task.text);
    _currentTags = List.from(widget.task.tags);

    if (widget.task.dueDate != null) {
      final date = widget.task.dueDate!.toLocal();
      final time =
          widget.task.reminderTime ?? const TimeOfDay(hour: 0, minute: 0);
      _selectedDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } else {
      _selectedDateTime = null;
    }

    // Calcula offset inicial do lembrete
    if (widget.task.reminderAt != null && widget.task.dueDate != null) {
        // DueDate no DB é UTC? TaskModel usa UTC.
        // Se reminderAt é UTC 13:50 e DueDate é UTC 14:00 -> 10min.
        // O Date Picker Result usa um Offset (Duration).
        // Aqui tentamos recuperar esse offset.
        // Assumindo que o reminderAt é relativo ao DateTime COMPLETO (com hora).
        // Se a tarefa não tem hora (All Day), o reminderAt é relativo à meia-noite?
        // Sim, conforme TaskInputModal: base = DateTime(y,m,d) ou DateTime(y,m,d,h,m).
        
        DateTime base = widget.task.dueDate!.toLocal();
        // Ajuste para base: se user tinha definido hora, base usa hora. Se não, meia noite.
        // TaskModel dueDate tem hora? Sim, sempre tem 00:00 se for all day, ou H:M se tiver hora.
        // Mas a gente precisa saber se 'tem hora' ou não? 
        // O TaskModel armazena reminderTime (TimeOfDay) que é usado quando TEM HORA.
        // Se não tem hora, reminderTime costuma ser null?
        // O widget.task.reminderTime armazena a hora da tarefa (Due Time).
        
        if (widget.task.reminderTime != null) {
             base = DateTime(base.year, base.month, base.day, widget.task.reminderTime!.hour, widget.task.reminderTime!.minute);
        } else {
             base = DateTime(base.year, base.month, base.day);
        }
        
        _reminderOffset = base.difference(widget.task.reminderAt!.toLocal());
        if (_reminderOffset!.isNegative) _reminderOffset = null; // Safety
    } else {
        _reminderOffset = null;
    }


    _recurrenceRule = RecurrenceRule(
      type: widget.task.recurrenceType,
      daysOfWeek: widget.task.recurrenceDaysOfWeek,
      endDate: widget.task.recurrenceEndDate?.toLocal(),
    );

    _personalDay =
        _calculatePersonalDayForDate(_selectedDateTime ?? DateTime.now());

    _originalText = widget.task.text;
    _originalGoalId = widget.task.journeyId;
    _originalTags = List.from(widget.task.tags);
    _originalDateTime = _selectedDateTime;
    _originalRecurrenceRule = _recurrenceRule.copyWith();
    _originalReminderOffset = _reminderOffset;

    _textController.addListener(_checkForChanges);

    if (widget.task.journeyId != null && widget.task.journeyId!.isNotEmpty) {
      _loadGoalDetails(widget.task.journeyId!);
    }
    _updateVibrationInfo(_personalDay);
  }

  @override
  void dispose() {
    _textController.removeListener(_checkForChanges);
    _textController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadGoalDetails(String goalId) async {
    if (!mounted) return;
    setState(() => _isLoadingGoal = true);
    try {
      final goal =
          await _supabaseService.getGoalById(widget.userData.uid, goalId);
      if (mounted) {
        setState(() {
          _selectedGoal = goal;
          _isLoadingGoal = false;
          _checkForChanges();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingGoal = false);
      }
    }
  }

  void _updateVibrationInfo(int dayNumber) {
    if (dayNumber > 0 &&
        (dayNumber <= 9 || dayNumber == 11 || dayNumber == 22)) {
      _dayInfo =
          ContentData.vibracoes['diaPessoal']?.containsKey(dayNumber) ?? false
              ? ContentData.vibracoes['diaPessoal']![dayNumber]
              : null;
    } else {
      _dayInfo = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  int _calculatePersonalDayForDate(DateTime date) {
    final localDate = date.toLocal();
    if (widget.userData.dataNasc.isNotEmpty &&
        widget.userData.nomeAnalise.isNotEmpty) {
      try {
        final engine = NumerologyEngine(
            nomeCompleto: widget.userData.nomeAnalise,
            dataNascimento: widget.userData.dataNasc);
        return engine.calculatePersonalDayForDate(localDate);
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  void _checkForChanges() {
    final currentGoalId = _selectedGoal?.id;
    bool textChanged = _textController.text != _originalText;
    bool goalChanged = currentGoalId != _originalGoalId;
    bool tagsChanged =
        !_listEquality.equals(_currentTags..sort(), _originalTags..sort());
    bool dateTimeChanged =
        !_compareDateTimes(_selectedDateTime, _originalDateTime);
    bool recurrenceChanged = _recurrenceRule != _originalRecurrenceRule;
    bool reminderChanged = _reminderOffset != _originalReminderOffset;

    bool changes = textChanged ||
        goalChanged ||
        tagsChanged ||
        dateTimeChanged ||
        recurrenceChanged ||
        reminderChanged;

    if (changes != _hasChanges && mounted) {
      setState(() {
        _hasChanges = changes;
      });
    }
  }

  bool _compareDateTimes(DateTime? dt1, DateTime? dt2) {
    if (dt1 == null && dt2 == null) return true;
    if (dt1 == null || dt2 == null) return false;
    final localDt1 = dt1.toLocal();
    final localDt2 = dt2.toLocal();
    return localDt1.year == localDt2.year &&
        localDt1.month == localDt2.month &&
        localDt1.day == localDt2.day &&
        localDt1.hour == localDt2.hour &&
        localDt1.minute == localDt2.minute;
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  Future<void> _duplicateTask() async {
    if (_isLoading || !mounted) return;
    setState(() => _isLoading = true);

    final dateForCalc = _selectedDateTime ?? DateTime.now();
    int? personalDayForDuplicated = _calculatePersonalDayForDate(dateForCalc);
    if (personalDayForDuplicated == 0) personalDayForDuplicated = null;

    DateTime? finalDueDate;
    // TimeOfDay? finalReminderTime; // Não precisamos separar
    if (_selectedDateTime != null) {
      finalDueDate = _selectedDateTime!.toUtc();
    }

    // Calcula reminderAt para a nova tarefa
    DateTime? reminderAt;
    if (finalDueDate != null && _reminderOffset != null) {
        // finalDueDate já é UTC e contém a hora completa se definida
        reminderAt = finalDueDate.subtract(_reminderOffset!); 
    }

    final duplicatedTask = TaskModel(
      id: '',
      text: _textController.text.trim(),
      completed: false,
      createdAt: DateTime.now().toUtc(),
      dueDate: finalDueDate?.toUtc(),
      tags: List.from(_currentTags),
      journeyId: _selectedGoal?.id,
      journeyTitle: _selectedGoal?.title,
      personalDay: personalDayForDuplicated,
      recurrenceType: _recurrenceRule.type,
      recurrenceDaysOfWeek: _recurrenceRule.daysOfWeek,
      recurrenceEndDate: _recurrenceRule.endDate?.toUtc(),
      // reminderTime: finalReminderTime, // Removido
      reminderAt: reminderAt, // Usa o reminderAt calculado
      recurrenceId: null,
    );

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();

    try {
      await _supabaseService.addTask(widget.userData.uid, duplicatedTask);
      if (duplicatedTask.journeyId != null &&
          duplicatedTask.journeyId!.isNotEmpty) {
        await _supabaseService.updateGoalProgress(
            widget.userData.uid, duplicatedTask.journeyId!);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Tarefa duplicada.'),
            backgroundColor: AppColors.primary),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('Erro ao duplicar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteTask() async {
    if (_isLoading || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Confirmar Exclusão',
            style: TextStyle(color: AppColors.primaryText)),
        content: const Text('Tem certeza que deseja excluir esta tarefa?',
            style: TextStyle(color: AppColors.secondaryText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.secondaryText))),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );

    if (confirmed != true) return;

    String? goalIdToUpdate = widget.task.journeyId;
    if (!mounted) return;
    navigator.pop();

    try {
      await _supabaseService.deleteTask(widget.userData.uid, widget.task.id);
      if (goalIdToUpdate != null && goalIdToUpdate.isNotEmpty) {
        await _supabaseService.updateGoalProgress(
            widget.userData.uid, goalIdToUpdate);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Tarefa excluída.'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges || _isLoading || !mounted) return;

    final newText = _textController.text.trim();
    if (newText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("O texto da tarefa não pode estar vazio."),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    int? newPersonalDay = widget.task.personalDay;
    if (!_compareDateTimes(_selectedDateTime, _originalDateTime)) {
      final dateForCalc = _selectedDateTime ?? DateTime.now();
      newPersonalDay = _calculatePersonalDayForDate(dateForCalc);
      if (newPersonalDay == 0) newPersonalDay = null;
    }

    DateTime? finalDueDateUtc;
    if (_selectedDateTime != null) {
      // Salva o Datetime completo com hora, convertido para UTC
      finalDueDateUtc = _selectedDateTime!.toUtc();
    }

    DateTime? reminderAt;
    if (finalDueDateUtc != null && _reminderOffset != null) {
        DateTime base = _selectedDateTime!.toLocal(); // Usa selecionada com hora (se houver)
        // Se selectedDateTime não tiver hora mas reminderTime tiver... espera, selectedDateTime CONTÉM a hora se definida
        reminderAt = base.subtract(_reminderOffset!).toUtc();
    }

    final Map<String, dynamic> updates = {
      'text': newText,
      'dueDate': finalDueDateUtc,
      // 'reminderHour': finalReminderTime?.hour, // Removido
      // 'reminderMinute': finalReminderTime?.minute, // Removido
      'reminder_at': reminderAt?.toIso8601String(), // Envia data calculada
      'tags': _currentTags,
      'journeyId': _selectedGoal?.id,
      'journeyTitle': _selectedGoal?.title,
      'personalDay': newPersonalDay,
      'recurrenceType': _recurrenceRule.type != RecurrenceType.none
          ? _recurrenceRule.type.toString()
          : null,
      'recurrenceDaysOfWeek': _recurrenceRule.daysOfWeek,
      'recurrenceEndDate': _recurrenceRule.endDate?.toUtc(),
    };

    String? originalGoalId = _originalGoalId;
    String? currentGoalId = _selectedGoal?.id;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    navigator.pop();

    try {
      await _supabaseService.updateTaskFields(
          widget.userData.uid, widget.task.id, updates);

      bool goalChanged = originalGoalId != currentGoalId;
      if (goalChanged) {
        if (originalGoalId != null && originalGoalId.isNotEmpty) {
          await _supabaseService.updateGoalProgress(
              widget.userData.uid, originalGoalId);
        }
      }
      if (currentGoalId != null && currentGoalId.isNotEmpty) {
        await _supabaseService.updateGoalProgress(
            widget.userData.uid, currentGoalId);
      }

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Tarefa atualizada.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDateAndTimeRecurrence() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    final DateTime initialPickerDate =
        _selectedDateTime?.toLocal() ?? DateTime.now();

    final DatePickerResult? result =
        await showModalBottomSheet<DatePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => ScheduleTaskSheet(
        initialDate: initialPickerDate,
        initialRecurrence: _recurrenceRule,
        initialTime: _selectedDateTime != null 
            ? TimeOfDay.fromDateTime(_selectedDateTime!.toLocal())
            : null,
        initialReminderOffset: _reminderOffset, // Passa o offset atual
        userData: widget.userData,
      ),
    );

    if (result != null && mounted) {
      bool dateTimeChanged = !_compareDateTimes(
          result.dateTime.toLocal(), _selectedDateTime?.toLocal());
      bool recurrenceChanged = result.recurrenceRule != _recurrenceRule;
      final newOffset = result.reminderOffset;
      bool reminderChanged = newOffset != _reminderOffset;

      if (dateTimeChanged || recurrenceChanged || reminderChanged) {
        setState(() {
          _selectedDateTime = result.dateTime.toLocal();
          _recurrenceRule = result.recurrenceRule;
          _reminderOffset = newOffset; // Atualiza offset
          _personalDay = _calculatePersonalDayForDate(_selectedDateTime!);
          _updateVibrationInfo(_personalDay);
          _checkForChanges();
        });
      }
    }
  }

  void _addTag() {
    final String tagText = _tagInputController.text
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .toLowerCase();
    final forbiddenChars = RegExp(r'[/#@]');

    if (tagText.isNotEmpty &&
        !forbiddenChars.hasMatch(tagText) &&
        !_currentTags.contains(tagText)) {
      if (_currentTags.length < 5) {
        if (mounted) {
          setState(() {
            _currentTags.add(tagText);
            _tagInputController.clear();
            _checkForChanges();
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Limite de 5 tags atingido.'),
                duration: Duration(seconds: 2)),
          );
        }
        _tagInputController.clear();
      }
    } else if (tagText.isNotEmpty && forbiddenChars.hasMatch(tagText)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tags não podem conter / # @'),
              duration: Duration(seconds: 2)),
        );
      }
      _tagInputController.clear();
    } else {
      _tagInputController.clear();
    }
    if (mounted && _currentTags.length < 5) {
      _tagFocusNode.requestFocus();
    } else if (mounted) {
      _tagFocusNode.unfocus();
    }
  }

  void _removeTag(String tagToRemove) {
    if (mounted) {
      setState(() {
        _currentTags.remove(tagToRemove);
        _checkForChanges();
        if (_currentTags.length == 4) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tagFocusNode.requestFocus();
          });
        }
      });
    }
  }

  void _selectGoal() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GoalSelectionModal(
          userId: widget.userData.uid,
        );
      },
    );

    if (result == null) return;

    if (result is Goal) {
      setState(() {
        _selectedGoal = result;
        _checkForChanges();
      });
    } else if (result == '_CREATE_NEW_GOAL_') {
      _openCreateGoalWidget();
    }
  }

  void _openCreateGoalWidget() async {
    final screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    bool? creationSuccess;

    if (isMobile) {
      creationSuccess = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => CreateGoalScreen(userData: widget.userData),
          fullscreenDialog: true,
        ),
      );
    } else {
      creationSuccess = await showDialog<bool>(
        context: context,
        builder: (context) {
          return CreateGoalDialog(userData: widget.userData);
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

  @override
  Widget build(BuildContext context) {
    // UNIFICANDO O LAYOUT: Sempre usar estilo "Card" (Dialog-like)
    // Se for mobile, usamos constraints menores ou adaptáveis
    final int currentPersonalDay =
        _calculatePersonalDayForDate(_selectedDateTime ?? DateTime.now());

    if (currentPersonalDay != _personalDay && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _personalDay = currentPersonalDay;
            _updateVibrationInfo(_personalDay);
          });
        }
      });
    }

    final vibrationColor = getColorsForVibration(currentPersonalDay).background;
    const borderOpacity = 0.6;
    const borderWidth = 1.5;

    Widget contentBody = GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: _textController,
                    style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 18,
                        height: 1.4),
                    decoration: const InputDecoration(
                      hintText: 'Descrição da tarefa...',
                      hintStyle: TextStyle(color: AppColors.secondaryText),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4.0),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const Divider(color: AppColors.border, height: 24),
                _buildDetailRow(
                  icon: Icons.calendar_month_outlined,
                  valueWidget:
                      _buildDateTimeRecurrenceSummaryWidget(),
                  onTap: _selectDateAndTimeRecurrence,
                  valueColor: (_selectedDateTime != null ||
                          _recurrenceRule.type != RecurrenceType.none)
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                  trailingAction: (_selectedDateTime != null ||
                          _recurrenceRule.type != RecurrenceType.none)
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: AppColors.secondaryText),
                          tooltip: 'Remover agendamento',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _selectedDateTime = null;
                                _recurrenceRule = RecurrenceRule();
                                _reminderOffset = null; // Remove lembrete tb
                                _personalDay = _calculatePersonalDayForDate(
                                    DateTime.now());
                                _updateVibrationInfo(_personalDay);
                                _checkForChanges();
                              });
                            }
                          },
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  icon: Icons.flag_outlined,
                  valueWidget: _isLoadingGoal
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: CustomLoadingSpinner(size: 20))
                      : null,
                  value: _isLoadingGoal
                      ? null
                      : (_selectedGoal?.title ?? 'Adicionar à jornada'),
                  onTap: _selectGoal,
                  valueColor: _selectedGoal != null
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                  trailingAction: _selectedGoal != null
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: AppColors.secondaryText),
                          tooltip: 'Desvincular meta',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _selectedGoal = null;
                                _checkForChanges();
                              });
                            }
                          },
                        )
                      : null,
                ),
                const Divider(color: AppColors.border, height: 32),
                _buildTagsSection(),
                if (_personalDay > 0 && _dayInfo != null) ...[
                  const Divider(color: AppColors.border, height: 32),
                  _buildPersonalDaySection(),
                ]
              ],
            ),
          ),
      );

      // Layout Unificado: Style like a centered Dialog/Card
      // Isso funciona tanto em desktop (Dialog) quanto mobile (dentro de Scaffold ou Dialog)
      // Ajuste: usar Dialog widget sempre, mas com insetPadding ajustado?
      // O usuário quer "parecido com desktop". O desktop é um Dialog flutuante.
      // Se retornamos Dialog, ele deve ser renderizado como filho de showDialog OU como filho de um Page route.
      // Se for Page Route, Dialog fica centralizado.
      
      return Dialog(
        backgroundColor: Colors.transparent, // Transparente para usar o container
        insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0), // Margens no mobile
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700), // Max width para desktop
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0), // Bordas arredondadas (como na imagem)
            child: Container(
              decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                      color: vibrationColor.withValues(alpha: borderOpacity),
                      width: borderWidth)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PreferredSize(
                    preferredSize: const Size.fromHeight(kToolbarHeight),
                    child: _buildAppBar(),
                  ),
                  Flexible(child: contentBody),
                ],
              ),
            ),
          ),
        ),
      );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText),
          tooltip: 'Fechar',
          onPressed: () {
            Navigator.maybePop(context);
          }),
      actions: [
        AnimatedOpacity(
          opacity: _hasChanges ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Visibility(
            visible: _hasChanges,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CustomLoadingSpinner(size: 20))
                    : const Text('Salvar',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.secondaryText),
            color: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            tooltip: "Mais opções",
            onSelected: (value) {
              if (value == 'duplicate') {
                _duplicateTask();
              } else if (value == 'delete') {
                _deleteTask();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              _buildPopupMenuItem(
                  icon: Icons.copy_outlined,
                  text: 'Duplicar Tarefa',
                  value: 'duplicate'),
              const PopupMenuDivider(height: 1),
              _buildPopupMenuItem(
                  icon: Icons.delete_outline_rounded,
                  text: 'Excluir Tarefa',
                  value: 'delete',
                  isDestructive: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconText(
      IconData icon, String text, Color textColor, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _buildDateSummaryText() {
    if (_selectedDateTime == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final localSelectedDate = _selectedDateTime!.toLocal();
    final selectedDateOnly = DateTime(
        localSelectedDate.year, localSelectedDate.month, localSelectedDate.day);

    if (_isSameDay(selectedDateOnly, today)) return 'Hoje';
    if (_isSameDay(selectedDateOnly, tomorrow)) return 'Amanhã';
    if (localSelectedDate.year == now.year) {
      return DateFormat('EEE, dd/MM', 'pt_BR').format(localSelectedDate);
    }
    return DateFormat('dd/MM/yy', 'pt_BR').format(localSelectedDate);
  }

  String _getShortRecurrenceText(RecurrenceRule rule) {
    switch (rule.type) {
      case RecurrenceType.daily:
        return 'Diariamente';
      case RecurrenceType.weekly:
        if (rule.daysOfWeek.length == 7) return 'Diariamente';
        return 'Semanalmente';
      case RecurrenceType.monthly:
        return 'Mensalmente';
      case RecurrenceType.none:
        return '';
    }
  }

  String _getReminderText(Duration offset) {
      // Ex: 00:10:00 -> "10 min antes"
      if (offset.inMinutes == 0) return "No horário do evento"; // ou "Em ponto"
      
      if (offset.inMinutes < 60) {
          return "${offset.inMinutes} min antes";
      }
      if (offset.inHours < 24) {
          return "${offset.inHours}h antes";
      }
      return "${offset.inDays} dias antes";
  }

  Widget _buildDateTimeRecurrenceSummaryWidget() {
    final bool hasDateTime = _selectedDateTime != null;
    final bool hasRecurrence = _recurrenceRule.type != RecurrenceType.none;
    final bool hasReminder = _reminderOffset != null;
    
    final Color color = (hasDateTime || hasRecurrence || hasReminder)
        ? AppColors.primaryText
        : AppColors.secondaryText;
    final Color iconColor = (hasDateTime || hasRecurrence || hasReminder)
        ? AppColors.secondaryText
        : AppColors.tertiaryText;

    if (!hasDateTime && !hasRecurrence) {
      return Text(
        "Adicionar data",
        style: TextStyle(color: color, fontSize: 15),
      );
    }

    List<Widget> children = [];

    if (hasDateTime) {
      children.add(_buildIconText(
        Icons.calendar_today_outlined,
        _buildDateSummaryText(),
        color,
        iconColor,
      ));
      if (_selectedDateTime!.hour != 0 || _selectedDateTime!.minute != 0) {
        children.add(_buildIconText(
          Icons.alarm,
          DateFormat.Hm('pt_BR').format(_selectedDateTime!),
          color,
          iconColor,
        ));
      }
    }

    if (hasRecurrence) {
      children.add(_buildIconText(
        Icons.repeat,
        _getShortRecurrenceText(_recurrenceRule),
        color,
        iconColor,
      ));
    }
    
    // Mostra o lembrete
    if (hasReminder) {
        children.add(_buildIconText(
            Icons.notifications_active_outlined,
            _getReminderText(_reminderOffset!),
            AppColors.primary, // Destaque na cor
            AppColors.primary,
        ));
    }

    return Wrap(
      spacing: 12.0,
      runSpacing: 4.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    String? value,
    Widget? valueWidget,
    VoidCallback? onTap,
    Color valueColor = AppColors.primaryText,
    Widget? trailingAction,
  }) {
    assert(value != null || valueWidget != null,
        'Provide either value or valueWidget');

    Widget rowContent = Row(
      children: [
        Icon(icon, color: AppColors.secondaryText, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: valueWidget ??
              Text(
                value!,
                style: TextStyle(color: valueColor, fontSize: 15),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
        ),
        const SizedBox(width: 8),
        if (trailingAction != null)
          trailingAction
        else if (onTap != null)
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.secondaryText,
            size: 24,
          ),
      ],
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
            child: rowContent,
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
        child: rowContent,
      );
    }
  }

  Widget _buildTagsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4.0, right: 16.0),
            child: Icon(Icons.label_outline,
                color: AppColors.secondaryText, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Wrap(
                      spacing: 6.0,
                      runSpacing: 4.0,
                      children: _currentTags
                          .map((tag) => InputChip(
                                label: Text(tag),
                                labelStyle: const TextStyle(
                                    color: Colors.purpleAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                backgroundColor:
                                    AppColors.background.withValues(alpha: 0.6),
                                onDeleted: () => _removeTag(tag),
                                deleteIconColor: AppColors.secondaryText
                                    .withValues(alpha: 0.7),
                                deleteButtonTooltipMessage: "Remover tag",
                                shape: StadiumBorder(
                                    side: BorderSide(
                                        color: Colors.purpleAccent
                                            .withValues(alpha: 0.3))),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0, vertical: 4.0),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  ),
                SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _tagInputController,
                    focusNode: _tagFocusNode,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _currentTags.length < 5
                          ? 'Adicionar tag...'
                          : 'Limite de tags atingido',
                      hintStyle: TextStyle(
                          color: AppColors.tertiaryText.withValues(alpha: 0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                      isDense: true,
                    ),
                    enabled: _currentTags.length < 5,
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDaySection() {
    if (_dayInfo == null) return const SizedBox.shrink();
    final colors = getColorsForVibration(_personalDay);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0, right: 16.0),
            child: Icon(Icons.wb_sunny_rounded,
                color: colors.background, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dia Pessoal $_personalDay: ${_dayInfo!.titulo}',
                  style: TextStyle(
                    color: colors.background,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _dayInfo!.descricaoCompleta.isNotEmpty
                      ? _dayInfo!.descricaoCompleta
                      : _dayInfo!.descricaoCurta,
                  style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required IconData icon,
    required String text,
    required String value,
    bool isDestructive = false,
  }) {
    final color =
        isDestructive ? Colors.redAccent.shade100 : AppColors.secondaryText;
    final textColor =
        isDestructive ? Colors.redAccent.shade100 : AppColors.primaryText;

    return PopupMenuItem<String>(
      value: value,
      height: 44,
      textStyle: TextStyle(color: textColor, fontSize: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
}

