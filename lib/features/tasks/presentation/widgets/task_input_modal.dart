// lib/features/tasks/presentation/widgets/task_input_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/goal_selection_modal.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class _SyntaxHighlightingController extends TextEditingController {
  final Map<RegExp, TextStyle> patternMap;
  _SyntaxHighlightingController({required this.patternMap});

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final List<InlineSpan> children = [];
    text.splitMapJoin(
      RegExp(patternMap.keys.map((e) => e.pattern).join('|'),
          caseSensitive: false),
      onMatch: (Match match) {
        final pattern = patternMap.entries
            .firstWhere((element) => element.key.hasMatch(match[0]!));
        children
            .add(TextSpan(text: match[0], style: style?.merge(pattern.value)));
        return '';
      },
      onNonMatch: (String nonMatch) {
        children.add(TextSpan(text: nonMatch, style: style));
        return '';
      },
    );
    return TextSpan(style: style, children: children);
  }
}

class TaskInputModal extends StatefulWidget {
  final UserModel? userData;
  final TaskModel? taskToEdit;
  final DateTime? preselectedDate;
  final Goal? preselectedGoal;

  const TaskInputModal({
    super.key,
    required this.userData,
    this.taskToEdit,
    this.preselectedDate,
    this.preselectedGoal,
  });

  @override
  State<TaskInputModal> createState() => _TaskInputModalState();
}

class _TaskInputModalState extends State<TaskInputModal> {
  late _SyntaxHighlightingController _textController;
  final FirestoreService _firestoreService = FirestoreService();

  DateTime _selectedDate = DateTime.now();
  int _personalDay = 0;
  VibrationContent? _dayInfo;

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  List<Goal> _allGoals = [];
  List<Goal> _filteredGoals = [];

  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();
    final monthPattern = TaskParser.getMonthPattern();

    _textController = _SyntaxHighlightingController(
      patternMap: {
        RegExp(r"#(\w+)"): const TextStyle(color: Colors.purpleAccent),
        RegExp(r"@(\w+)"): const TextStyle(color: Colors.cyanAccent),
        RegExp(r"/\s*(?:dia\s+\d{1,2}(?:\s+de)?\s+(" +
                monthPattern +
                r")(?:\s+de\s+\d{4})?|\d{1,2}/\d{1,2}(?:/\d{2,4})?)"):
            const TextStyle(color: Colors.orangeAccent),
      },
    );

    if (_isEditing) {
      String editText = widget.taskToEdit!.text;
      if (widget.taskToEdit!.journeyTitle != null &&
          widget.taskToEdit!.journeyTitle!.isNotEmpty) {
        final simplifiedTag =
            StringSanitizer.toSimpleTag(widget.taskToEdit!.journeyTitle!);
        editText = '${widget.taskToEdit!.text} @$simplifiedTag';
      }
      if (widget.taskToEdit!.dueDate != null) {
        final formattedDate =
            DateFormat('dd/MM/yyyy').format(widget.taskToEdit!.dueDate!);
        editText += ' /${formattedDate}';
      }
      _textController.text = editText;
      _selectedDate = widget.taskToEdit!.dueDate ?? DateTime.now();
    }
    // *** CORREÇÃO DO BUG AQUI ***
    else if (widget.preselectedGoal != null) {
      final simplifiedTag =
          StringSanitizer.toSimpleTag(widget.preselectedGoal!.title);
      // Define o texto inicial diretamente, em vez de chamar a função que causava o erro
      _textController.text = '@$simplifiedTag ';
      // Move o cursor para o final do texto
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    } else if (widget.preselectedDate != null) {
      _selectedDate = widget.preselectedDate!;
      _updateDateInTextField(_selectedDate);
    }

    _textController.addListener(_onTextChanged);
    if (widget.userData != null) {
      _updateVibrationForDate(_selectedDate);
      _loadGoals();
    }
  }

  Future<void> _loadGoals() async {
    _allGoals = await _firestoreService.getActiveGoals(widget.userData!.uid);
  }

  void _onTextChanged() {
    final parsedDate = TaskParser.parseDateFromText(_textController.text);
    final currentDateToShow = parsedDate ?? DateTime.now();

    if (!_isSameDay(_selectedDate, currentDateToShow)) {
      _updateVibrationForDate(currentDateToShow);
    }

    _handleAutocomplete();
  }

  void _handleAutocomplete() {
    final text = _textController.text;
    final cursorPos = _textController.selection.start;

    if (cursorPos < 0) {
      _removeAutocompleteOverlay();
      return;
    }

    final atMatch = RegExp(r"@(\w*)$").firstMatch(text.substring(0, cursorPos));

    if (atMatch != null) {
      final query = atMatch.group(1) ?? '';
      _filteredGoals = _allGoals.where((goal) {
        final simpleTitle = StringSanitizer.toSimpleTag(goal.title);
        return simpleTitle.toLowerCase().contains(query.toLowerCase());
      }).toList();

      if (_filteredGoals.isNotEmpty) {
        _showAutocompleteOverlay();
      } else {
        _removeAutocompleteOverlay();
      }
    } else {
      _removeAutocompleteOverlay();
    }
  }

  void _showAutocompleteOverlay() {
    _removeAutocompleteOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeAutocompleteOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 250,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, -160),
            child: Material(
              elevation: 4.0,
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 174),
                child: ListView.builder(
                  padding: const EdgeInsets.all(4),
                  shrinkWrap: true,
                  itemCount: _filteredGoals.length,
                  itemBuilder: (context, index) {
                    final goal = _filteredGoals[index];
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

  Widget _buildGoalSuggestionItem(Goal goal) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: AppColors.primary.withOpacity(0.2),
          hoverColor: AppColors.primary.withOpacity(0.1),
          onTap: () {
            _updateGoalInTextField(goal);
            _removeAutocompleteOverlay();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              goal.title,
              style:
                  const TextStyle(color: AppColors.primaryText, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _updateVibrationForDate(DateTime date) {
    if (widget.userData?.dataNasc.isNotEmpty == true &&
        widget.userData?.nomeAnalise.isNotEmpty == true) {
      final engine = NumerologyEngine(
        nomeCompleto: widget.userData!.nomeAnalise,
        dataNascimento: widget.userData!.dataNasc,
      );
      final day = engine.calculatePersonalDayForDate(date);
      if (mounted) {
        setState(() {
          _selectedDate = date;
          _personalDay = day;
          _dayInfo = ContentData.vibracoes['diaPessoal']?[_personalDay];
        });
      }
    }
  }

  void _updateDateInTextField(DateTime newDate) {
    _updateVibrationForDate(newDate);
    String currentText = _textController.text;

    final datePattern = RegExp(
        r"\s*/\s*(?:dia\s+\d{1,2}(?:\s+de)?\s+(" +
            TaskParser.getMonthPattern() +
            r")(?:\s+de\s+\d{4})?|\d{1,2}/\d{1,2}(?:/\d{2,4})?)",
        caseSensitive: false);

    final textWithoutDate = currentText.replaceAll(datePattern, '').trim();
    final formattedDate = DateFormat('dd/MM/yyyy').format(newDate);
    final newText = '$textWithoutDate /${formattedDate}'.trim();
    _textController.text = newText;
    _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length));
  }

  void _updateGoalInTextField(Goal goal) {
    final simplifiedTag = StringSanitizer.toSimpleTag(goal.title);
    final currentText = _textController.text;

    final selection = _textController.selection;
    final textBeforeCursor = currentText.substring(0, selection.start);

    final atMatch = RegExp(r"@\w*$").firstMatch(textBeforeCursor);

    String newText;
    if (atMatch != null) {
      final textBeforeTag = textBeforeCursor.substring(0, atMatch.start);
      final textAfterCursor = currentText.substring(selection.end);
      newText = '$textBeforeTag@$simplifiedTag $textAfterCursor'.trim();
    } else {
      final textWithoutGoal =
          currentText.replaceAll(RegExp(r"@\w+"), '').trim();
      newText = '$textWithoutGoal @$simplifiedTag'.trim();
    }

    _textController.text = newText;
    _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length));
    FocusScope.of(context).requestFocus();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
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
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      _updateDateInTextField(picked);
    }
  }

  void _selectGoal(BuildContext context) {
    _removeAutocompleteOverlay();
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => GoalSelectionModal(
          userId: widget.userData!.uid,
          onGoalSelected: _updateGoalInTextField,
        ),
      ),
    );
  }

  void _insertActionText(String char) {
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = text.replaceRange(selection.start, selection.end, char);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + char.length),
    );
  }

  void _submit() async {
    _removeAutocompleteOverlay();
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    final userId = AuthRepository().getCurrentUser()!.uid;
    final parsedResult = await TaskParser.parse(rawText, userId);

    if (_isEditing) {
      final updatedTask = widget.taskToEdit!.copyWith(
        text: parsedResult.cleanText,
        dueDate: parsedResult.dueDate,
        tags: parsedResult.tags,
        journeyId: parsedResult.journeyId,
        journeyTitle: parsedResult.journeyTitle,
        personalDay: _personalDay,
      );
      _firestoreService.updateTask(userId, updatedTask);
    } else {
      final newTask = TaskModel(
        id: '',
        text: parsedResult.cleanText,
        completed: false,
        createdAt: DateTime.now(),
        dueDate: parsedResult.dueDate,
        tags: parsedResult.tags,
        journeyId: parsedResult.journeyId,
        journeyTitle: parsedResult.journeyTitle,
        personalDay: _personalDay,
      );
      _firestoreService.addTask(userId, newTask);
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _removeAutocompleteOverlay();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompositedTransformTarget(
              link: _layerLink,
              child: TextField(
                controller: _textController,
                autofocus: true,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.secondaryText),
                decoration: const InputDecoration(
                  hintText: "Adicionar tarefa, #tag, @meta, /data",
                  hintStyle: TextStyle(color: AppColors.tertiaryText),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 12),
            if (_personalDay > 0 && _dayInfo != null)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      VibrationPill(
                        vibrationNumber: _personalDay,
                        onTap: () => showVibrationInfoModal(context,
                            vibrationNumber: _personalDay),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dayInfo!.descricaoCurta,
                          style: const TextStyle(
                              color: AppColors.secondaryText, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildActionButton(
                    icon: Icons.label_outline,
                    onTap: () => _insertActionText('#')),
                _buildActionButton(
                    icon: Icons.track_changes_outlined,
                    onTap: () => _selectGoal(context)),
                _buildActionButton(
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _selectDate(context)),
                const Spacer(),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  child: Icon(
                    _isEditing ? Icons.check : Icons.arrow_upward,
                    color: Colors.white,
                    size: 20,
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.tertiaryText),
      splashRadius: 20,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }
}

void showVibrationInfoModal(BuildContext context,
    {required int vibrationNumber}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: Text("Informação da Vibração $vibrationNumber",
          style: const TextStyle(color: AppColors.primaryText)),
      content: const Text("Detalhes sobre esta vibração...",
          style: TextStyle(color: AppColors.secondaryText)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              const Text("Fechar", style: TextStyle(color: AppColors.primary)),
        ),
      ],
    ),
  );
}
