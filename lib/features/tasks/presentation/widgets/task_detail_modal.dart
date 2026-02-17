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
import 'package:sincro_app_flutter/features/goals/presentation/widgets/create_goal_dialog.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/goal_selection_modal.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/common/widgets/contact_picker_modal.dart';

class TaskDetailModal extends StatefulWidget {
  final TaskModel task;
  final UserModel userData;

  final bool isNew; // NOVO
  final VoidCallback? onClose; // Callback para modo embedado (Desktop)
  final Function(DateTime)? onReschedule; // NOVO: Callback para reagendamento

  const TaskDetailModal({
    super.key,
    required this.task,
    required this.userData,
    this.isNew = false, // Default false
    this.onClose,
    this.onReschedule,
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

  late Duration? _originalReminderOffset;
  late List<String> _originalSharedWith; // NOVO

  // Estados para data/hora/recorrência/lembrete
  late DateTime? _selectedDateTime;
  late RecurrenceRule _recurrenceRule;
  Duration? _reminderOffset;
  List<String> _currentSharedWith = []; // NOVO

  final TextEditingController _tagInputController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();
  final DeepCollectionEquality _listEquality = const DeepCollectionEquality();

  @override
  void didUpdateWidget(TaskDetailModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.id != oldWidget.task.id ||
        widget.isNew != oldWidget.isNew) {
      _initializeState();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
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
      DateTime base = widget.task.dueDate!.toLocal();

      if (widget.task.reminderTime != null) {
        base = DateTime(base.year, base.month, base.day,
            widget.task.reminderTime!.hour, widget.task.reminderTime!.minute);
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
    _originalSharedWith = List.from(widget.task.sharedWith);
    _currentSharedWith = List.from(widget.task.sharedWith);
    _originalDateTime = _selectedDateTime;
    _originalRecurrenceRule = _recurrenceRule.copyWith();
    _originalReminderOffset = _reminderOffset;

    // Listeners are added here, but check if controller was just replaced
    // Since we created a new controller above, we need to add the listener again.
    // NOTE: If this is called from didUpdateWidget, the old controller is garbage collected eventually?
    // Ideally we should dispose the old one if we are replacing it, OR reuse it.
    // For simplicity here (since new task = complete refresh), replacing is safer for state sync.
    _textController.addListener(_checkForChanges);

    if (widget.task.journeyId != null && widget.task.journeyId!.isNotEmpty) {
      _loadGoalDetails(widget.task.journeyId!);
    } else {
      _selectedGoal = null; // Clear if new task has no goal
    }
    _updateVibrationInfo(_personalDay);

    // Reset change flags
    _hasChanges = false;
    // But if it's 'isNew', maybe we don't want to reset if we were drafting?
    // The requirement is that switching tasks (selection) updates the view.
    // So complete reset is correct.
  }

  @override
  void dispose() {
    _textController.removeListener(_checkForChanges);
    _textController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
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
    // Fix: Don't flag goal changes while still loading the goal details
    bool goalChanged = !_isLoadingGoal && (currentGoalId != _originalGoalId);
    bool tagsChanged =
        !_listEquality.equals(_currentTags..sort(), _originalTags..sort());
    bool dateTimeChanged =
        !_compareDateTimes(_selectedDateTime, _originalDateTime);
    bool recurrenceChanged = _recurrenceRule != _originalRecurrenceRule;
    bool reminderChanged = _reminderOffset != _originalReminderOffset;
    bool sharedWithChanged = !_listEquality.equals(
        _currentSharedWith..sort(), _originalSharedWith..sort()); // NOVO

    bool changes = textChanged ||
        goalChanged ||
        tagsChanged ||
        dateTimeChanged ||
        recurrenceChanged ||
        reminderChanged ||
        sharedWithChanged; // NOVO

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

    final messenger = ScaffoldMessenger.of(context);
    // _handleClose(); // REMOVED: Moved to after success

    try {
      await _supabaseService.addTask(widget.userData.uid, duplicatedTask);
      if (duplicatedTask.journeyId != null &&
          duplicatedTask.journeyId!.isNotEmpty) {
        await _supabaseService.updateGoalProgress(
            widget.userData.uid, duplicatedTask.journeyId!);
      }
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Tarefa duplicada.'),
              backgroundColor: AppColors.primary),
        );
        _handleClose(); // Close after success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
              content: Text('Erro ao duplicar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    if (_isLoading || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Confirmar Exclusão',
            style:
                TextStyle(fontFamily: 'Poppins', color: AppColors.primaryText)),
        content: const Text('Tem certeza que deseja excluir esta tarefa?',
            style: TextStyle(
                fontFamily: 'Poppins', color: AppColors.secondaryText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(
                      fontFamily: 'Poppins', color: AppColors.secondaryText))),
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
    // _handleClose(); // REMOVED: Moved to after success

    try {
      await _supabaseService.deleteTask(widget.userData.uid, widget.task.id);
      if (goalIdToUpdate != null && goalIdToUpdate.isNotEmpty) {
        await _supabaseService.updateGoalProgress(
            widget.userData.uid, goalIdToUpdate);
      }
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Tarefa excluída.'),
              backgroundColor: Colors.orange),
        );
        _handleClose(); // Close after success
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red),
        );
      }
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
      DateTime base =
          _selectedDateTime!.toLocal(); // Usa selecionada com hora (se houver)
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
      'recurrenceDaysOfWeek': _recurrenceRule.daysOfWeek,
      'recurrenceEndDate': _recurrenceRule.endDate?.toUtc(),
      'sharedWith': _currentSharedWith, // NOVO
    };

    String? originalGoalId = _originalGoalId;
    String? currentGoalId = _selectedGoal?.id;
    final messenger = ScaffoldMessenger.of(context);

    // _handleClose(); // REMOVED: Moved to after success

    try {
      if (widget.isNew) {
        // --- LOGICA DE CRIAÇÃO ---
        final newTask = widget.task.copyWith(
          text: newText,
          dueDate:
              finalDueDateUtc, // copyWith handles Object? so we pass directly
          tags: _currentTags,
          journeyId: _selectedGoal?.id,
          journeyTitle: _selectedGoal?.title,
          personalDay: newPersonalDay,
          recurrenceType: _recurrenceRule.type,
          recurrenceDaysOfWeek: _recurrenceRule.daysOfWeek,
          recurrenceEndDate: _recurrenceRule.endDate?.toUtc(),
          sharedWith: _currentSharedWith,
          reminderAt: reminderAt,
        );

        await _supabaseService.addTask(widget.userData.uid, newTask);

        // Se houver meta vinculada, atualizar progresso
        if (_selectedGoal?.id != null) {
          await _supabaseService.updateGoalProgress(
              widget.userData.uid, _selectedGoal!.id);
        }

        if (_selectedGoal?.id != null) {
          await _supabaseService.updateGoalProgress(
              widget.userData.uid, _selectedGoal!.id);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Tarefa criada.'), backgroundColor: Colors.green),
          );
          _handleClose(); // Close after success
        }
      } else {
        // --- LOGICA DE ATUALIZAÇÃO (existente) ---
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Tarefa atualizada.'),
                backgroundColor: Colors.green),
          );
          _handleClose(); // Close after success
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false); // Re-enable UI on error
        messenger.showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
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
      builder: (modalContext) {
        // Verifica se é "meia-noite" (00:00) para tratar como "Dia Inteiro" (sem horário definido)
        final bool isMidnight = _selectedDateTime != null &&
            _selectedDateTime!.hour == 0 &&
            _selectedDateTime!.minute == 0;

        return ScheduleTaskSheet(
          initialDate: initialPickerDate,
          initialRecurrence: _recurrenceRule,
          // Se for meia-noite, passa null para iniciar como "Dia Inteiro" (desativado)
          initialTime: (_selectedDateTime != null && !isMidnight)
              ? TimeOfDay.fromDateTime(_selectedDateTime!.toLocal())
              : null,
          initialReminderOffset: _reminderOffset,
          userData: widget.userData,
          goalDeadline: _selectedGoal?.targetDate,
        );
      },
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
        _currentSharedWith =
            []; // Limpa contatos ao selecionar meta (Exclusividade)
        _checkForChanges();
      });
    } else if (result == '_CREATE_NEW_GOAL_') {
      _openCreateGoalWidget();
    }
  }

  // Opens the dialog to create a new goal
  void _openCreateGoalWidget() async {
    final result = await showDialog(
      context: context,
      builder: (context) => CreateGoalDialog(userData: widget.userData),
    );
    if (result == true && mounted) {
      // Refresh or handle new goal
      // Simplification: logic to reload goals usually happens via stream in GoalSelectionModal
    }
  }

  void _rescheduleTask(DateTime date) {
    if (widget.onReschedule != null) {
      widget.onReschedule!(date);
      // Opcional: Fechar o modal se for dia diferente?
      // Por enquanto mantemos aberto para feedback visual ou fechamos se o pai julgar necessário.
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text('Tem certeza que deseja excluir esta tarefa?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Excluir',
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteTask();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomActions() {
    // Se não houver alterações (e não for nova tarefa), mostra botão "Fechar" ocupando toda a largura
    if (!_hasChanges && !widget.isNew) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _handleClose,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                  color: Colors.white, width: 1), // Borda branca
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.transparent,
            ),
            child: const Text('Fechar',
                style: TextStyle(
                    fontFamily: 'Poppins', color: Colors.white, fontSize: 16)),
          ),
        ),
      );
    }

    // Se houver alterações ou for nova tarefa, mostra "Cancelar" e "Salvar"
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          24, 0, 24, 16), // Alinhado com o padding do corpo (24)
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _handleClose,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: Colors.white, width: 1), // Borda branca
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.transparent,
              ),
              child: const Text('Cancelar',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: (_isLoading || _isLoadingShared) ? null : _saveChanges,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(widget.isNew ? 'Criar Tarefa' : 'Salvar Alterações',
                      style:
                          const TextStyle(fontFamily: 'Poppins', fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // Helper para consistência no estilo dos itens do menu
  PopupMenuItem<String> _buildPopupMenuItem({
    required IconData icon,
    required String text,
    required String value,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              color: isDestructive ? Colors.red : AppColors.secondaryText,
              size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
                fontFamily: 'Poppins',
                color: isDestructive ? Colors.red : AppColors.primaryText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UNIFICANDO O LAYOUT: Sempre usar estilo "Card" (Dialog-like)
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
                onChanged: (_) => setState(() {}),
                controller: _textController,
                autofillHints: const [],
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryText,
                    fontSize: 18,
                    height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Digite aqui sua tarefa...',
                  hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.secondaryText.withOpacity(0.5)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                  filled: false,
                  fillColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const Divider(color: AppColors.border, height: 24),
            _buildDetailRow(
              icon: Icons.calendar_month_outlined,
              iconColor: (_selectedDateTime != null ||
                      _recurrenceRule.type != RecurrenceType.none)
                  ? Colors.amber
                  : AppColors.secondaryText,
              valueWidget: _buildDateTimeRecurrenceSummaryWidget(),
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
                            _reminderOffset = null;
                            _personalDay =
                                _calculatePersonalDayForDate(DateTime.now());
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
              iconColor:
                  _selectedGoal != null ? Colors.cyan : AppColors.secondaryText,
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
            const SizedBox(height: 8),

            // NOVO: Seção de Contatos/Compartilhamento
            _buildSharedWithSection(),

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

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    // Se tiver onClose, assumimos que é embedded (Desktop Right Pane)
    final isEmbedded = widget.onClose != null;

    if (isMobile) {
      return Dialog(
        backgroundColor: AppColors.cardBackground,
        insetPadding: EdgeInsets.zero,
        child: Scaffold(
          backgroundColor: AppColors.cardBackground,
          appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: SafeArea(child: _buildAppBar(isMobile: true))),
          body: contentBody,
          bottomNavigationBar: SafeArea(
            child: _buildBottomActions(), // Reuse bottom actions
          ),
        ),
      );
    }

    // Desktop Embedded View (Novo Layout)
    if (isEmbedded) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.0),
          // (Solicitação: Borda destacada para tarefas atrasadas)
          border: (widget.task.isOverdue && !widget.task.completed)
              ? Border.all(color: const Color(0xFFEF5350), width: 1.0)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: Scaffold(
            backgroundColor: AppColors.cardBackground,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: _buildAppBar(isMobile: false),
            ),
            body: contentBody,
            bottomNavigationBar: _buildBottomActions(),
          ),
        ),
      );
    }

    // Desktop Dialog View (Legado/Fallback)
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
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
                  // No modo Dialog ainda usamos o AppBar com botão de fechar no topo e checkmark?
                  // Vamos manter compatibilidade, mas o usuário quer botões em baixo.
                  // Se for dialog, talvez deva manter como era?
                  // O foco é "Desktop UI" que agora é 60/40 embedded.
                  child: _buildAppBar(isMobile: false),
                ),
                Flexible(child: contentBody),
                // Botões de ação em baixo para Dialog também?
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0), // Padding extra
                  child: _buildBottomActions(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar({required bool isMobile}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0, // Remove default spacing to control padding manually
      title: widget.isNew
          ? null // Remove title for new tasks - placeholder in input is sufficient
          : const Padding(
              padding: EdgeInsets.only(left: 24.0), // Match body padding
              child: Text('Edite sua tarefa abaixo',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.secondaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.normal)),
            ),
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: null,
      actions: [
        if (!widget.isNew)
          Padding(
            padding:
                const EdgeInsets.only(right: 16.0), // Match body padding (ish)
            child: Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border, width: 1)),
                  color: AppColors.cardBackground,
                  elevation: 8,
                ),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.secondaryText, size: 24),
                tooltip: "Mais opções",
                onSelected: (value) {
                  if (value == 'duplicate') {
                    _duplicateTask();
                  } else if (value == 'delete') {
                    _confirmDelete();
                  } else if (value == 'today') {
                    _rescheduleTask(DateTime.now());
                  } else if (value == 'tomorrow') {
                    _rescheduleTask(DateTime.now().add(const Duration(days: 1)));
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (widget.onReschedule != null) ...[
                    if (widget.task.isOverdue)
                      const PopupMenuItem(
                        value: 'today',
                        child: Row(children: [
                          Icon(Icons.today, color: AppColors.primary, size: 20),
                          SizedBox(width: 8),
                          Text('Enviar para Hoje',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: AppColors.primary))
                        ]),
                      )
                    else
                      const PopupMenuItem(
                        value: 'tomorrow',
                        child: Row(children: [
                          Icon(Icons.event_available,
                              color: AppColors.secondaryText, size: 20),
                          SizedBox(width: 8),
                          Text('Mover para Amanhã')
                        ]),
                      ),
                    const PopupMenuDivider(height: 1),
                  ],
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
            style: TextStyle(
                fontFamily: 'Poppins', color: textColor, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Métodos auxiliares de texto... (sem alterações)
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
    if (offset.inMinutes == 0) return "No horário";
    if (offset.inMinutes < 60) return "${offset.inMinutes} min antes";
    if (offset.inHours < 24) return "${offset.inHours}h antes";
    return "${offset.inDays} dias antes";
  }

  Widget _buildDateTimeRecurrenceSummaryWidget() {
    final bool hasDateTime = _selectedDateTime != null;
    final bool hasRecurrence = _recurrenceRule.type != RecurrenceType.none;
    final bool hasReminder = _reminderOffset != null;

    final Color color = (hasDateTime || hasRecurrence || hasReminder)
        ? AppColors.primaryText
        : AppColors.secondaryText;

    // COR: Laranja/Amber se tiver data
    final Color iconColor = (hasDateTime || hasRecurrence || hasReminder)
        ? Colors.amber
        : AppColors.tertiaryText;

    if (!hasDateTime && !hasRecurrence) {
      return Text(
        "Adicionar data",
        style: TextStyle(fontFamily: 'Poppins', color: color, fontSize: 15),
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

    if (hasReminder) {
      children.add(_buildIconText(
        Icons.notifications_active_outlined,
        _getReminderText(_reminderOffset!),
        AppColors.primary,
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
    Color? iconColor, // Adicionado parâmetro opcional para cor do ícone
    Widget? trailingAction,
  }) {
    assert(value != null || valueWidget != null,
        'Provide either value or valueWidget');

    Widget rowContent = Row(
      children: [
        Icon(icon, color: iconColor ?? AppColors.secondaryText, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: valueWidget ??
              Text(
                value!,
                style: TextStyle(
                    fontFamily: 'Poppins', color: valueColor, fontSize: 15),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
        ),
        const SizedBox(width: 8),
        if (trailingAction != null)
          trailingAction
        else if (onTap != null)
          const Icon(
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
    // COR: Roxo para tags se tiver tags
    final Color tagIconColor =
        _currentTags.isNotEmpty ? Colors.purpleAccent : AppColors.secondaryText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                top: 8.0, right: 16.0), // Ajuste ALINHAMENTO (antes top: 4.0)
            child: Icon(Icons.label_outline, color: tagIconColor, size: 20),
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
                                    fontFamily: 'Poppins',
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
                    autofillHints: const [], // Prevent browser password save prompt
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: AppColors.secondaryText,
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _currentTags.length < 5
                          ? 'Adicionar tag...'
                          : 'Limite de tags atingido',
                      hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.tertiaryText.withValues(alpha: 0.7)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      hoverColor: Colors.transparent,
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

  bool _isLoadingShared = false;

  // ... (inside State class)

  void _openContactPicker() async {
    if (_isLoadingShared) return;
    setState(() => _isLoadingShared = true);

    try {
      final contacts = await _supabaseService.getContacts(widget.userData.uid);

      if (!mounted) return;
      setState(() => _isLoadingShared = false);

      await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return ContactPickerModal(
            preSelectedUsernames: _currentSharedWith,
            currentDate: _selectedDateTime ?? DateTime.now(),
            initialContacts: contacts, // PASS PRE-LOADED DATA
            onSelectionChanged: (selectedUsernames) {
              setState(() {
                _currentSharedWith = selectedUsernames;
                _checkForChanges();
              });
            },
            onDateChanged: (newDate) {},
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingShared = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao carregar contatos.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ...

  Widget _buildSharedWithSection() {
    return _buildDetailRow(
      icon: Icons.people_outline_rounded,
      iconColor: _currentSharedWith.isNotEmpty
          ? Colors.lightBlueAccent
          : AppColors.secondaryText,
      valueWidget: _isLoadingShared
          ? const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.secondaryText)),
            )
          : (_currentSharedWith.isEmpty
              ? const Text('Adicionar pessoas',
                  style:
                      TextStyle(color: AppColors.secondaryText, fontSize: 15))
              : Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _currentSharedWith.map((username) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 10,
                        child: Text(username[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
                      ),
                      label: Text(username),
                      labelStyle: const TextStyle(fontSize: 12),
                      backgroundColor: AppColors.cardBackground,
                      side: const BorderSide(color: AppColors.border),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () {
                        setState(() {
                          _currentSharedWith.remove(username);
                          _checkForChanges();
                        });
                      },
                    );
                  }).toList(),
                )),
      onTap: (_selectedGoal != null || _isLoadingShared)
          ? null
          : _openContactPicker,
      valueColor: _selectedGoal != null
          ? AppColors.tertiaryText
          : (_currentSharedWith.isNotEmpty
              ? AppColors.primaryText
              : AppColors.secondaryText),
      trailingAction: _selectedGoal != null
          ? null
          : (_isLoadingShared
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.secondaryText))
              : (_currentSharedWith.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 20, color: AppColors.secondaryText),
                      onPressed: _openContactPicker,
                      tooltip: 'Gerenciar pessoas',
                    )
                  : null)),
    );
  }
}
