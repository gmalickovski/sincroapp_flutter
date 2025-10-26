// lib/features/tasks/presentation/widgets/task_detail_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
// Import necessário para getColorsForVibration e showVibrationInfoModal
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
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
  // --- Variáveis de estado (sem alterações) ---
  final FirestoreService _firestoreService = FirestoreService();
  late TextEditingController _textController;
  late DateTime? _selectedDueDate;
  Goal? _selectedGoal;
  List<String> _currentTags = [];
  late int _personalDay;
  VibrationContent? _dayInfo;
  bool _hasChanges = false;
  bool _isLoading = false;
  bool _isLoadingGoal = false;

  late String _originalText;
  late DateTime? _originalDueDate;
  late String? _originalGoalId;
  late List<String> _originalTags;

  final TextEditingController _tagInputController = TextEditingController();
  final FocusNode _tagFocusNode = FocusNode();
  final DeepCollectionEquality _listEquality = const DeepCollectionEquality();

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  List<Goal> _allGoals = [];
  bool _isLoadingGoalsList = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.task.text);
    _selectedDueDate = widget.task.dueDate;
    _currentTags = List.from(widget.task.tags);
    _personalDay =
        _calculatePersonalDayForDate(_selectedDueDate ?? DateTime.now());

    _originalText = widget.task.text;
    _originalDueDate = widget.task.dueDate;
    _originalGoalId = widget.task.journeyId;
    _originalTags = List.from(widget.task.tags);

    _textController.addListener(_checkForChanges);

    if (widget.task.journeyId != null && widget.task.journeyId!.isNotEmpty) {
      _loadGoalDetails(widget.task.journeyId!);
    }
    _updateVibrationInfo(_personalDay);
    _loadGoalsList();
  }

  @override
  void dispose() {
    _textController.removeListener(_checkForChanges);
    _textController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    _removeAutocompleteOverlay();
    super.dispose();
  }

  // --- Funções Originais (sem alterações na lógica principal) ---

  Future<void> _loadGoalDetails(String goalId) async {
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
    if (dayNumber > 0) {
      _dayInfo = ContentData.vibracoes['diaPessoal']?[dayNumber];
    } else {
      _dayInfo = null;
    }
  }

  int _calculatePersonalDayForDate(DateTime date) {
    if (widget.userData.dataNasc.isNotEmpty) {
      final engine = NumerologyEngine(
          nomeCompleto: widget.userData.nomeAnalise,
          dataNascimento: widget.userData.dataNasc);
      return engine.calculatePersonalDayForDate(date);
    }
    return 0;
  }

  void _checkForChanges() {
    final currentGoalId = _selectedGoal?.id;
    bool tagsChanged = !_listEquality.equals(_currentTags, _originalTags);

    bool changes = _textController.text != _originalText ||
        _selectedDueDate != _originalDueDate ||
        currentGoalId != _originalGoalId ||
        tagsChanged;

    if (changes != _hasChanges) {
      setState(() {
        _hasChanges = changes;
      });
    }
  }

  Future<void> _duplicateTask() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _removeAutocompleteOverlay();
    Navigator.pop(context);

    final dateForCalc = _selectedDueDate ?? DateTime.now();
    int? personalDayForDuplicated = _calculatePersonalDayForDate(dateForCalc);
    if (personalDayForDuplicated == 0) personalDayForDuplicated = null;

    final duplicatedTask = widget.task.copyWith(
      id: '',
      text: _textController.text.trim(),
      dueDate: _selectedDueDate,
      tags: List.from(_currentTags),
      journeyId: _selectedGoal?.id,
      journeyTitle: _selectedGoal?.title,
      personalDay: personalDayForDuplicated,
      completed: false,
      createdAt: DateTime.now(),
    );

    try {
      await _firestoreService.addTask(widget.userData.uid, duplicatedTask);
      if (duplicatedTask.journeyId != null &&
          duplicatedTask.journeyId!.isNotEmpty) {
        _firestoreService.updateGoalProgress(
            widget.userData.uid, duplicatedTask.journeyId!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tarefa duplicada.'),
            backgroundColor: AppColors.primary),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erro ao duplicar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTask() async {
    if (_isLoading) return;
    _removeAutocompleteOverlay();

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

    setState(() => _isLoading = true);

    try {
      await _firestoreService.deleteTask(widget.userData.uid, widget.task.id);
      if (_originalGoalId != null && _originalGoalId!.isNotEmpty) {
        _firestoreService.updateGoalProgress(
            widget.userData.uid, _originalGoalId!);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tarefa excluída.'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print("Erro ao excluir tarefa: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges || _isLoading) return;
    setState(() => _isLoading = true);
    _removeAutocompleteOverlay();

    int? newPersonalDay = _personalDay;
    if (_selectedDueDate != _originalDueDate) {
      final dateForCalc = _selectedDueDate ?? DateTime.now();
      newPersonalDay = _calculatePersonalDayForDate(dateForCalc);
    }
    if (newPersonalDay == 0) newPersonalDay = null;

    final Map<String, dynamic> updates = {
      'text': _textController.text.trim(),
      'dueDate': _selectedDueDate,
      'tags': _currentTags,
      'journeyId': _selectedGoal?.id,
      'journeyTitle': _selectedGoal?.title,
      'personalDay': newPersonalDay,
    };

    try {
      await _firestoreService.updateTaskFields(
          widget.userData.uid, widget.task.id, updates);

      final currentGoalId = _selectedGoal?.id;
      if (_originalGoalId != currentGoalId) {
        if (_originalGoalId != null && _originalGoalId!.isNotEmpty) {
          _firestoreService.updateGoalProgress(
              widget.userData.uid, _originalGoalId!);
        }
        if (currentGoalId != null && currentGoalId.isNotEmpty) {
          _firestoreService.updateGoalProgress(
              widget.userData.uid, currentGoalId);
        }
      } else if (currentGoalId != null && currentGoalId.isNotEmpty) {
        _firestoreService.updateGoalProgress(
            widget.userData.uid, currentGoalId);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tarefa atualizada.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Erro ao salvar tarefa: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    _removeAutocompleteOverlay();

    final DateTime initial = _selectedDueDate ?? DateTime.now();
    final DateTime first = DateTime(2020);
    final DateTime last = DateTime(2101);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.primaryText,
            ),
            dialogBackgroundColor: AppColors.background,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.cardBackground,
              foregroundColor: AppColors.primaryText,
              iconTheme: IconThemeData(color: AppColors.primaryText),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && !_isSameDay(picked, _selectedDueDate)) {
      setState(() {
        _selectedDueDate = picked;
        _personalDay = _calculatePersonalDayForDate(picked);
        _updateVibrationInfo(_personalDay);
        _checkForChanges();
      });
    }
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // --- Funções de Tag (inalteradas) ---
  void _addTag() {
    _removeAutocompleteOverlay();

    final String tagText =
        _tagInputController.text.trim().replaceAll(' ', '-').toLowerCase();
    if (tagText.isNotEmpty && !_currentTags.contains(tagText)) {
      if (_currentTags.length < 5) {
        setState(() {
          _currentTags.add(tagText);
          _tagInputController.clear();
          _checkForChanges();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Limite de 5 tags atingido.'),
              duration: Duration(seconds: 2)),
        );
        _tagInputController.clear();
      }
    } else {
      _tagInputController.clear();
    }
    _tagFocusNode.requestFocus();
  }

  void _removeTag(String tagToRemove) {
    _removeAutocompleteOverlay();
    setState(() {
      _currentTags.remove(tagToRemove);
      _checkForChanges();
    });
  }

  // --- LÓGICA DO POPUP FLUTUANTE (inalterada) ---
  Future<void> _loadGoalsList() async {
    if (widget.userData.uid.isEmpty) return;
    setState(() => _isLoadingGoalsList = true);
    try {
      _allGoals = await _firestoreService.getActiveGoals(widget.userData.uid);
    } catch (e) {
      print("Erro ao carregar lista de metas: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao carregar jornadas: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGoalsList = false);
      }
    }
  }

  void _removeAutocompleteOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showGoalSelectionOverlay() {
    _removeAutocompleteOverlay();
    _overlayEntry = _createGoalOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _selectGoal() {
    FocusScope.of(context).unfocus();
    if (_overlayEntry != null) {
      _removeAutocompleteOverlay();
      return;
    }
    if (_allGoals.isEmpty && !_isLoadingGoalsList) {
      _loadGoalsList().then((_) {
        if (mounted) _showGoalSelectionOverlay();
      });
    } else {
      _showGoalSelectionOverlay();
    }
  }

  OverlayEntry _createGoalOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 300,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0.0, 45.0),
            child: Material(
              elevation: 4.0,
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: _isLoadingGoalsList
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                      )
                    : _allGoals.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Nenhuma jornada ativa encontrada.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(4),
                            shrinkWrap: true,
                            itemCount:
                                _allGoals.length + 1, // +1 para "Nenhuma"
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _buildGoalSuggestionItem(null);
                              }
                              final goal = _allGoals[index - 1];
                              return _buildGoalSuggestionItem(goal);
                            },
                          ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoalSuggestionItem(Goal? goal) {
    final bool isSelected = (_selectedGoal == null && goal == null) ||
        (_selectedGoal?.id == goal?.id);
    final String title = goal?.title ?? 'Nenhuma';

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.2)
            : AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.primary.withOpacity(0.2),
          hoverColor: AppColors.primary.withOpacity(0.1),
          onTap: () {
            setState(() {
              _selectedGoal = goal;
              _checkForChanges();
            });
            _removeAutocompleteOverlay();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.primaryText,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // --- Build Principal Refatorado ---
  @override
  Widget build(BuildContext context) {
    bool isModalLayout = MediaQuery.of(context).size.width > 600;
    final vibrationColor = getColorsForVibration(_personalDay).background;
    const borderOpacity = 0.7;
    const borderWidth = 2.0;

    Widget contentBody = GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _removeAutocompleteOverlay();
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Chave para altura ajustável
              children: [
                // Campo de Texto Principal
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: _textController,
                    onTap: _removeAutocompleteOverlay,
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

                // --- Seção de Detalhes (Data e Meta) ---
                _buildDetailRow(
                  icon: Icons.calendar_month_outlined,
                  value: _selectedDueDate != null
                      ? DateFormat('EEE, dd/MM/yyyy', 'pt_BR')
                          .format(_selectedDueDate!)
                      : 'Adicionar data',
                  onTap: _selectDate,
                  valueColor: _selectedDueDate != null
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                  trailingAction: _selectedDueDate != null
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: AppColors.secondaryText),
                          tooltip: 'Remover data',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _removeAutocompleteOverlay();
                            setState(() {
                              _selectedDueDate = null;
                              _personalDay =
                                  _calculatePersonalDayForDate(DateTime.now());
                              _updateVibrationInfo(_personalDay);
                              _checkForChanges();
                            });
                          },
                        )
                      : null,
                ),

                const SizedBox(height: 8),

                CompositedTransformTarget(
                  link: _layerLink,
                  child: _buildDetailRow(
                    icon: Icons.flag_outlined,
                    value: _isLoadingGoal
                        ? 'Carregando...'
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
                              _removeAutocompleteOverlay();
                              setState(() {
                                _selectedGoal = null;
                                _checkForChanges();
                              });
                            },
                          )
                        : null,
                  ),
                ),

                const Divider(color: AppColors.border, height: 32),

                // --- Seção de Tags ---
                _buildTagsSection(), // Função helper refatorada

                // --- Seção Dia Pessoal (Nova) ---
                if (_personalDay > 0 && _dayInfo != null) ...[
                  const Divider(color: AppColors.border, height: 32),
                  _buildPersonalDaySection(), // Função helper nova
                ]
              ],
            ),
          ),
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            ),
        ],
      ),
    );

    // Estrutura do Modal/Dialog/Scaffold
    if (isModalLayout) {
      // DESKTOP / TABLET LARGO
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Material(
              color: AppColors.cardBackground,
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  side: BorderSide(
                      color: vibrationColor.withOpacity(borderOpacity),
                      width: borderWidth)),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: _buildAppBar(),
                body: contentBody,
              ),
            ),
          ),
        ),
      );
    } else {
      // MOBILE
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

  // AppBar Refatorada (com padding no PopupMenu)
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.cardBackground,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Botão Salvar
        AnimatedOpacity(
          opacity: _hasChanges ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Visibility(
            visible: _hasChanges,
            child: Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: _hasChanges ? 2 : 0,
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
        // --- INÍCIO DA MUDANÇA: Padding antes do Popup ---
        Padding(
          padding: const EdgeInsets.only(right: 8.0), // Adiciona espaço AQUI
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.secondaryText),
            color: AppColors.cardBackground,
            tooltip: "Mais opções",
            onSelected: (value) {
              _removeAutocompleteOverlay();
              if (value == 'duplicate')
                _duplicateTask();
              else if (value == 'delete') _deleteTask();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              _buildPopupMenuItem(
                  icon: Icons.copy_outlined,
                  text: 'Duplicar Tarefa',
                  value: 'duplicate'),
              const PopupMenuDivider(height: 1, color: AppColors.border),
              _buildPopupMenuItem(
                  icon: Icons.delete_outline_rounded,
                  text: 'Excluir Tarefa',
                  value: 'delete',
                  isDestructive: true),
            ],
          ),
        ),
        // --- FIM DA MUDANÇA ---
      ],
    );
  }

  // Seção de Tags Refatorada (Ícone label_outline e Alinhamento)
  Widget _buildTagsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        // --- INÍCIO DA MUDANÇA: Alinhamento do Ícone ---
        crossAxisAlignment: CrossAxisAlignment.start, // Alinha o ícone ao topo
        // --- FIM DA MUDANÇA ---
        children: [
          Padding(
            padding: const EdgeInsets.only(
                top: 12.0,
                right:
                    16.0), // Padding ajustado para alinhar com o centro da primeira linha de chips/textfield
            // --- INÍCIO DA MUDANÇA: Ícone Tags ---
            child: Icon(Icons.label_outline, // Ícone de etiqueta
                // --- FIM DA MUDANÇA ---
                color: AppColors.secondaryText,
                size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                        bottom: 4.0), // Espaço consistente abaixo dos chips
                    child: Wrap(
                      spacing: 8.0,
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
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _tagInputController,
                    focusNode: _tagFocusNode,
                    onTap: _removeAutocompleteOverlay,
                    style: const TextStyle(
                        color: AppColors.secondaryText, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _currentTags.length < 5
                          ? 'Adicionar tag...'
                          : 'Limite de tags atingido',
                      hintStyle: TextStyle(
                          color: AppColors.tertiaryText.withOpacity(0.7)),
                      border: InputBorder.none,
                      // Ajuste no padding vertical para melhor alinhamento com o ícone
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12.0),
                      isDense: true,
                    ),
                    enabled: _currentTags.length < 5,
                    onSubmitted: (_) => _addTag(),
                    onEditingComplete: _addTag,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Nova Seção Dia Pessoal (Ícone wb_sunny e Texto descricaoCompleta)
  Widget _buildPersonalDaySection() {
    final colors = getColorsForVibration(_personalDay);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(top: 4.0, right: 16.0), // Padding padrão
            // --- INÍCIO DA MUDANÇA: Ícone Dia Pessoal ---
            child: Icon(Icons.wb_sunny_rounded,
                color: colors.background, size: 20),
            // --- FIM DA MUDANÇA ---
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Título do Dia Pessoal
                Text(
                  'Dia Pessoal $_personalDay: ${_dayInfo!.titulo}',
                  style: TextStyle(
                    color: colors.background,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8), // Espaço padrão
                // --- INÍCIO DA MUDANÇA: Texto Descrição Completa ---
                Text(
                  _dayInfo!.descricaoCompleta.isEmpty
                      ? _dayInfo!.descricaoCurta // Fallback
                      : _dayInfo!.descricaoCompleta, // Usa a completa
                  style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                      height: 1.5),
                ),
                // --- FIM DA MUDANÇA ---
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper _buildDetailRow (inalterado)
  Widget _buildDetailRow({
    required IconData icon,
    required String value,
    VoidCallback? onTap,
    Color valueColor = AppColors.primaryText,
    Widget? trailingAction,
  }) {
    // ... (código inalterado) ...
    Widget rowContent = Row(
      children: [
        Icon(icon, color: AppColors.secondaryText, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 15),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
          child: rowContent,
        ),
      ),
    );
  }

  // Helper _buildPopupMenuItem (inalterado)
  PopupMenuItem<String> _buildPopupMenuItem({
    required IconData icon,
    required String text,
    required String value,
    bool isDestructive = false,
  }) {
    // ... (código inalterado) ...
    final color =
        isDestructive ? Colors.redAccent.shade100 : AppColors.secondaryText;
    final hoverColor = isDestructive
        ? Colors.red.withOpacity(0.1)
        : AppColors.primary.withOpacity(0.1);

    return PopupMenuItem<String>(
      value: value,
      height: 44,
      textStyle: TextStyle(
          color:
              isDestructive ? Colors.redAccent.shade100 : AppColors.primaryText,
          fontSize: 14),
      child: Container(
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(text),
          ],
        ),
      ),
    );
  }
} // Fim da classe _TaskDetailModalState

// A função showVibrationInfoModal não é chamada diretamente neste arquivo,
// mas a importação de vibration_pill.dart é mantida para getColorsForVibration.
