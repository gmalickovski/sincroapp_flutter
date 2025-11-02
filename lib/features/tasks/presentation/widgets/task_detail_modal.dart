// lib/features/tasks/presentation/widgets/task_detail_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Para DeepCollectionEquality
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/common/widgets/custom_date_picker_modal.dart';
import 'package:sincro_app_flutter/common/widgets/custom_recurrence_picker_modal.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
// --- INÍCIO DA MUDANÇA: Imports para seleção de meta ---
import 'package:sincro_app_flutter/features/goals/presentation/create_goal_screen.dart';
import 'package:sincro_app_flutter/features/goals/presentation/widgets/create_goal_dialog.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/goal_selection_modal.dart';
// --- FIM DA MUDANÇA ---
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
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
  // --- Variáveis de estado (outras funcionalidades mantidas) ---
  final FirestoreService _firestoreService = FirestoreService();
  late TextEditingController _textController;
  Goal? _selectedGoal;
  List<String> _currentTags = [];
  late int _personalDay;
  VibrationContent? _dayInfo;
  bool _hasChanges = false;
  bool _isLoading = false;
  bool _isLoadingGoal = false;

  // Estados originais para comparação (mantidos)
  late String _originalText;
  late String? _originalGoalId;
  late List<String> _originalTags;
  late DateTime? _originalDateTime;
  late RecurrenceRule _originalRecurrenceRule;

  // Estados para data/hora/recorrência (mantidos)
  late DateTime? _selectedDateTime;
  late RecurrenceRule _recurrenceRule;

  // Estados para UI de Tags (mantidos)
  final TextEditingController _tagInputController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();
  final DeepCollectionEquality _listEquality = const DeepCollectionEquality();

  // --- REMOVIDO: Lógica de Overlay de Meta ---
  // OverlayEntry? _overlayEntry;
  // final LayerLink _layerLink = LayerLink();
  // List<Goal> _allGoals = [];
  // bool _isLoadingGoalsList = false;
  // --- FIM DA REMOÇÃO ---

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

    _textController.addListener(_checkForChanges);

    if (widget.task.journeyId != null && widget.task.journeyId!.isNotEmpty) {
      _loadGoalDetails(widget.task.journeyId!);
    }
    _updateVibrationInfo(_personalDay);
    // --- REMOVIDO: _loadGoalsList(); ---
  }

  @override
  void dispose() {
    _textController.removeListener(_checkForChanges);
    _textController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    // --- REMOVIDO: _removeAutocompleteOverlay(); ---
    super.dispose();
  }

  // --- Funções Helper (Inalteradas) ---

  Future<void> _loadGoalDetails(String goalId) async {
    if (!mounted) return;
    setState(() => _isLoadingGoal = true);
    try {
      final goal =
          await _firestoreService.getGoalById(widget.userData.uid, goalId);
      if (mounted) {
        setState(() {
          _selectedGoal = goal;
          _isLoadingGoal = false;
          _checkForChanges();
        });
      }
    } catch (e) {
      print("Erro ao carregar detalhes da meta: $e");
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
        print("Erro ao calcular dia pessoal para $localDate: $e");
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

    bool changes = textChanged ||
        goalChanged ||
        tagsChanged ||
        dateTimeChanged ||
        recurrenceChanged;

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

  // --- Ações Principais (Inalteradas) ---
  Future<void> _duplicateTask() async {
    // ... (Lógica inalterada) ...
    if (_isLoading || !mounted) return;
    setState(() => _isLoading = true);
    // _removeAutocompleteOverlay(); // Removido

    final dateForCalc = _selectedDateTime ?? DateTime.now();
    int? personalDayForDuplicated = _calculatePersonalDayForDate(dateForCalc);
    if (personalDayForDuplicated == 0) personalDayForDuplicated = null;

    DateTime? finalDueDate;
    TimeOfDay? finalReminderTime;
    if (_selectedDateTime != null) {
      final localSelected = _selectedDateTime!.toLocal();
      finalDueDate =
          DateTime(localSelected.year, localSelected.month, localSelected.day);
      if (localSelected.hour != 0 || localSelected.minute != 0) {
        finalReminderTime = TimeOfDay.fromDateTime(localSelected);
      }
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
      reminderTime: finalReminderTime,
      recurrenceId: null,
    );

    final currentContext = context;
    Navigator.of(currentContext).pop();

    try {
      await _firestoreService.addTask(widget.userData.uid, duplicatedTask);
      if (duplicatedTask.journeyId != null &&
          duplicatedTask.journeyId!.isNotEmpty) {
        await _firestoreService.updateGoalProgress(
            widget.userData.uid, duplicatedTask.journeyId!);
      }
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
            content: Text('Tarefa duplicada.'),
            backgroundColor: AppColors.primary),
      );
    } catch (e) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
            content: Text('Erro ao duplicar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteTask() async {
    // ... (Lógica inalterada) ...
    if (_isLoading || !mounted) return;
    // _removeAutocompleteOverlay(); // Removido
    final currentContext = context;

    final bool? confirmed = await showDialog<bool>(
      context: currentContext,
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
    Navigator.of(currentContext).pop();

    try {
      await _firestoreService.deleteTask(widget.userData.uid, widget.task.id);
      if (goalIdToUpdate != null && goalIdToUpdate.isNotEmpty) {
        await _firestoreService.updateGoalProgress(
            widget.userData.uid, goalIdToUpdate);
      }
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
            content: Text('Tarefa excluída.'), backgroundColor: Colors.orange),
      );
    } catch (e) {
      print("Erro ao excluir tarefa: $e");
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
            content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveChanges() async {
    // ... (Lógica inalterada) ...
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
    // _removeAutocompleteOverlay(); // Removido

    int? newPersonalDay = widget.task.personalDay;
    if (!_compareDateTimes(_selectedDateTime, _originalDateTime)) {
      final dateForCalc = _selectedDateTime ?? DateTime.now();
      newPersonalDay = _calculatePersonalDayForDate(dateForCalc);
      if (newPersonalDay == 0) newPersonalDay = null;
    }

    DateTime? finalDueDateUtc;
    TimeOfDay? finalReminderTime;
    if (_selectedDateTime != null) {
      final localSelected = _selectedDateTime!.toLocal();
      finalDueDateUtc = DateTime.utc(
          localSelected.year, localSelected.month, localSelected.day);
      if (localSelected.hour != 0 || localSelected.minute != 0) {
        finalReminderTime = TimeOfDay.fromDateTime(localSelected);
      }
    }

    final Map<String, dynamic> updates = {
      'text': newText,
      'dueDate': finalDueDateUtc,
      'reminderHour': finalReminderTime?.hour,
      'reminderMinute': finalReminderTime?.minute,
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
    final currentContext = context;

    Navigator.of(currentContext).pop();

    try {
      await _firestoreService.updateTaskFields(
          widget.userData.uid, widget.task.id, updates);

      bool goalChanged = originalGoalId != currentGoalId;
      if (goalChanged) {
        if (originalGoalId != null && originalGoalId.isNotEmpty) {
          await _firestoreService.updateGoalProgress(
              widget.userData.uid, originalGoalId);
        }
      }
      if (currentGoalId != null && currentGoalId.isNotEmpty) {
        await _firestoreService.updateGoalProgress(
            widget.userData.uid, currentGoalId);
      }

      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
            content: Text('Tarefa atualizada.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      print("Erro ao salvar tarefa: $e");
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
            content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectDateAndTimeRecurrence() async {
    // ... (Lógica inalterada) ...
    if (!mounted) return;
    // _removeAutocompleteOverlay(); // Removido
    FocusScope.of(context).unfocus();

    final DateTime initialPickerDate =
        _selectedDateTime?.toLocal() ?? DateTime.now();

    final DatePickerResult? result =
        await showModalBottomSheet<DatePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => CustomDatePickerModal(
        initialDate: initialPickerDate,
        initialRecurrenceRule: _recurrenceRule,
        userData: widget.userData,
      ),
    );

    if (result != null && mounted) {
      bool dateTimeChanged = !_compareDateTimes(
          result.dateTime.toLocal(), _selectedDateTime?.toLocal());
      bool recurrenceChanged = result.recurrenceRule != _recurrenceRule;

      if (dateTimeChanged || recurrenceChanged) {
        setState(() {
          _selectedDateTime = result.dateTime.toLocal();
          _recurrenceRule = result.recurrenceRule;
          _personalDay = _calculatePersonalDayForDate(_selectedDateTime!);
          _updateVibrationInfo(_personalDay);
          _checkForChanges();
        });
      }
    }
  }

  // --- Funções de Tag (Inalteradas) ---
  void _addTag() {
    // _removeAutocompleteOverlay(); // Removido
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
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Limite de 5 tags atingido.'),
                duration: Duration(seconds: 2)),
          );
        _tagInputController.clear();
      }
    } else if (tagText.isNotEmpty && forbiddenChars.hasMatch(tagText)) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tags não podem conter / # @'),
              duration: Duration(seconds: 2)),
        );
      _tagInputController.clear();
    } else {
      _tagInputController.clear();
    }
    if (mounted && _currentTags.length < 5)
      _tagFocusNode.requestFocus();
    else if (mounted) _tagFocusNode.unfocus();
  }

  void _removeTag(String tagToRemove) {
    // _removeAutocompleteOverlay(); // Removido
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

  // --- INÍCIO DA MUDANÇA: Lógica de seleção de meta ---

  // --- REMOVIDO: _loadGoalsList, _removeAutocompleteOverlay, _showGoalSelectionOverlay, _createGoalOverlayEntry, _buildGoalSuggestionItem ---
  // (Toda a lógica de overlay foi removida)

  // --- FUNÇÃO _selectGoal ATUALIZADA ---
  void _selectGoal() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    // 1. Abre o GoalSelectionModal (o mesmo do task_input_modal)
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GoalSelectionModal(
          userId: widget.userData.uid,
          // O modal agora retorna o valor via Navigator.pop()
        );
      },
    );

    if (result == null) {
      // Modal foi dispensado
      return;
    }

    if (result is Goal) {
      // 2. Usuário SELECIONOU uma meta
      setState(() {
        _selectedGoal = result;
        _checkForChanges();
      });
    } else if (result == '_CREATE_NEW_GOAL_') {
      // 3. Usuário clicou em "CRIAR NOVA JORNADA"
      _openCreateGoalWidget();
    }
  }

  // --- NOVA FUNÇÃO: Chama a tela/dialog de criação de meta ---
  void _openCreateGoalWidget() async {
    // Esta função é idêntica à do task_input_modal
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

    // Se a criação foi bem-sucedida, reabre o seletor de metas
    if (creationSuccess == true) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _selectGoal();
      }
    }
  }
  // --- FIM DA MUDANÇA ---

  // --- Build Principal ---
  @override
  Widget build(BuildContext context) {
    bool isModalLayout = MediaQuery.of(context).size.width > 600;
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

    // bottom padding smaller on desktop modal to avoid large empty area
    final double bottomPadding = isModalLayout ? 24.0 : 80.0;

    Widget contentBody = GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        // _removeAutocompleteOverlay(); // Removido
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: _textController,
                    // onTap: _removeAutocompleteOverlay, // Removido
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
                      _buildDateTimeRecurrenceSummaryWidget(), // --- ATUALIZADO ---
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
                            // _removeAutocompleteOverlay(); // Removido
                            if (mounted) {
                              setState(() {
                                _selectedDateTime = null;
                                _recurrenceRule = RecurrenceRule();
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
                // --- REMOVIDO: CompositedTransformTarget ---
                _buildDetailRow(
                  icon: Icons.flag_outlined,
                  value: _isLoadingGoal
                      ? 'Carregando...'
                      : (_selectedGoal?.title ?? 'Adicionar à jornada'),
                  onTap: _selectGoal, // --- ATUALIZADO ---
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
                            // _removeAutocompleteOverlay(); // Removido
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
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            ),
        ],
      ),
    );

    if (isModalLayout) {
      // Desktop dialog: use a Column (not Scaffold) so height adapts to content
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Container(
              decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                      color: vibrationColor.withOpacity(borderOpacity),
                      width: borderWidth)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AppBar as PreferredSize so it doesn't force full scaffold layout
                  PreferredSize(
                    preferredSize: const Size.fromHeight(kToolbarHeight),
                    child: _buildAppBar(),
                  ),
                  // Content (scrolls if too large)
                  Flexible(child: contentBody),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      // ... (Layout de Scaffold inalterado) ...
      return Scaffold(
        backgroundColor: AppColors.cardBackground,
        appBar: _buildAppBar(),
        body: Container(
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: vibrationColor.withOpacity(borderOpacity),
                        width: borderWidth + 1))),
            child: contentBody),
      );
    }
  }

  // --- Helpers de Build (AppBar e Menus inalterados) ---

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText),
          tooltip: 'Fechar',
          onPressed: () {
            // _removeAutocompleteOverlay(); // Removido
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
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
              // _removeAutocompleteOverlay(); // Removido
              if (value == 'duplicate')
                _duplicateTask();
              else if (value == 'delete') _deleteTask();
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

  // --- INÍCIO DA MUDANÇA: Refatoração do Sumário de Data/Hora ---

  /// Constrói um widget de ícone + texto para o sumário.
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

  /// Retorna o texto curto para a data (Hoje, Amanhã, dd/MM/yy).
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

  /// Retorna o texto curto para a recorrência.
  String _getShortRecurrenceText(RecurrenceRule rule) {
    switch (rule.type) {
      case RecurrenceType.daily:
        return 'Diariamente';
      case RecurrenceType.weekly:
        // Se todos os 7 dias estiverem marcados, é o mesmo que "Diariamente"
        if (rule.daysOfWeek.length == 7) return 'Diariamente';
        return 'Semanalmente';
      case RecurrenceType.monthly:
        return 'Mensalmente';
      case RecurrenceType.none:
        return '';
    }
  }

  /// NOVO WIDGET: Constrói o sumário de data/hora/recorrência com ícones.
  Widget _buildDateTimeRecurrenceSummaryWidget() {
    final bool hasDateTime = _selectedDateTime != null;
    final bool hasRecurrence = _recurrenceRule.type != RecurrenceType.none;
    final Color color = (hasDateTime || hasRecurrence)
        ? AppColors.primaryText
        : AppColors.secondaryText;
    final Color iconColor = (hasDateTime || hasRecurrence)
        ? AppColors.secondaryText
        : AppColors.tertiaryText;

    // Caso 1: Nada definido
    if (!hasDateTime && !hasRecurrence) {
      return Text(
        "Adicionar data",
        style: TextStyle(color: color, fontSize: 15),
      );
    }

    List<Widget> children = [];

    // Caso 2: Data definida
    if (hasDateTime) {
      children.add(_buildIconText(
        Icons.calendar_today_outlined,
        _buildDateSummaryText(), // "Hoje", "Amanhã", "dd/MM/yy"
        color,
        iconColor,
      ));
      // Adiciona hora apenas se não for meia-noite
      if (_selectedDateTime!.hour != 0 || _selectedDateTime!.minute != 0) {
        children.add(_buildIconText(
          Icons.alarm,
          DateFormat.Hm('pt_BR').format(_selectedDateTime!),
          color,
          iconColor,
        ));
      }
    }

    // Caso 3: Recorrência definida
    if (hasRecurrence) {
      children.add(_buildIconText(
        Icons.repeat,
        _getShortRecurrenceText(_recurrenceRule), // "Diário", "Semanal", etc.
        color,
        iconColor,
      ));
    }

    // Usa Wrap para quebrar a linha em telas menores se necessário
    return Wrap(
      spacing: 12.0, // Espaço horizontal entre os ícones
      runSpacing: 4.0, // Espaço vertical se quebrar a linha
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  // --- REMOVIDO: _buildDateTimeRecurrenceSummary() (o antigo, de texto longo) ---

  // --- FIM DA MUDANÇA: Refatoração do Sumário de Data/Hora ---

  // _buildDetailRow (Inalterado)
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
            icon == Icons.flag_outlined
                ? Icons.arrow_drop_down_rounded
                : Icons.chevron_right_rounded,
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

  // _buildTagsSection (Inalterado)
  Widget _buildTagsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Align icon closer to the top so the tags/input align vertically
            padding: const EdgeInsets.only(top: 4.0, right: 16.0),
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
                                    AppColors.background.withOpacity(0.6),
                                onDeleted: () => _removeTag(tag),
                                deleteIconColor:
                                    AppColors.secondaryText.withOpacity(0.7),
                                deleteButtonTooltipMessage: "Remover tag",
                                shape: StadiumBorder(
                                    side: BorderSide(
                                        color: Colors.purpleAccent
                                            .withOpacity(0.3))),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0, vertical: 4.0),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  ),
                // Make the tag input align to the top of the column and the text start at top-left
                SizedBox(
                  // a slightly taller field to fit top-aligned text comfortably
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
                          color: AppColors.tertiaryText.withOpacity(0.7)),
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

  // _buildPersonalDaySection (Inalterado)
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

  // _buildPopupMenuItem (Inalterado)
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
} // Fim da classe _TaskDetailModalState
