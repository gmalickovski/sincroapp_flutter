// lib/features/tasks/presentation/widgets/task_input_modal.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

// Classe de controle de texto com coloração de sintaxe
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

  const TaskInputModal({
    super.key,
    required this.userData,
    this.taskToEdit,
    this.preselectedDate,
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

  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();
    final monthPattern = TaskParser.getMonthPattern();

    _textController = _SyntaxHighlightingController(
      patternMap: {
        RegExp(r"#\w+"): const TextStyle(color: Colors.purpleAccent),
        RegExp(r"@\w+"): const TextStyle(color: Colors.cyanAccent),
        RegExp(r"/\s*(?:dia\s+\d{1,2}(?:\s+de)?\s+(" +
                monthPattern +
                r")(?:\s+de\s+\d{4})?|\d{1,2}/\d{1,2}(?:/\d{2,4})?)"):
            const TextStyle(color: Colors.orangeAccent),
      },
    );

    if (_isEditing) {
      String editText = widget.taskToEdit!.text;
      if (widget.taskToEdit!.journeyId != null) {
        editText += ' @${widget.taskToEdit!.journeyId}';
      }
      if (widget.taskToEdit!.dueDate != null) {
        final formattedDate =
            DateFormat('dd/MM/yyyy').format(widget.taskToEdit!.dueDate!);
        editText += ' /${formattedDate}';
      }
      _textController.text = editText;
      _selectedDate = widget.taskToEdit!.dueDate ?? DateTime.now();
    } else if (widget.preselectedDate != null) {
      _selectedDate = widget.preselectedDate!;
      final formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);
      _textController.text = ' /${formattedDate}';
      // Move o cursor para o início do texto
      _textController.selection = const TextSelection.collapsed(offset: 0);
    }

    _textController.addListener(_onTextChanged);
    if (widget.userData != null) {
      _updateVibrationForDate(_selectedDate);
    }
  }

  void _onTextChanged() {
    final newDate = TaskParser.parseDateFromText(_textController.text);
    if (newDate != null && !_isSameDay(_selectedDate, newDate)) {
      _updateVibrationForDate(newDate);
    } else if (newDate == null && !_isSameDay(_selectedDate, DateTime.now())) {
      _updateVibrationForDate(DateTime.now());
    }
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

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2101),
        locale: const Locale('pt', 'BR'));
    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      _updateVibrationForDate(picked);
      String currentText = TaskParser.parse(_textController.text).cleanText;
      final formattedDate = DateFormat('dd/MM/yyyy').format(picked);
      _textController.text = '$currentText /${formattedDate}';
      _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length));
    }
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

  void _submit() {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    final userId = AuthRepository().getCurrentUser()!.uid;
    final parsedTask = TaskParser.parse(rawText);

    if (_isEditing) {
      final updatedTask = TaskModel(
        id: widget.taskToEdit!.id,
        text: parsedTask.cleanText,
        completed: widget.taskToEdit!.completed,
        createdAt: widget.taskToEdit!.createdAt,
        dueDate: parsedTask.dueDate,
        tags: parsedTask.tags,
        personalDay: _personalDay,
        journeyId: parsedTask.journeyId,
      );
      _firestoreService.updateTask(userId, updatedTask);
    } else {
      final newTask = TaskModel(
        id: '',
        text: parsedTask.cleanText,
        completed: false,
        createdAt: DateTime.now(),
        dueDate: parsedTask.dueDate,
        tags: parsedTask.tags,
        personalDay: _personalDay,
        journeyId: parsedTask.journeyId,
      );
      _firestoreService.addTask(userId, newTask);
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: const BoxDecoration(
          color: Color(0xFF2a2141),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              autofocus: true,
              style:
                  const TextStyle(fontSize: 16, color: AppColors.secondaryText),
              decoration: const InputDecoration(
                hintText: "Adicionar tarefa, #tag, @meta, /data",
                hintStyle: TextStyle(color: AppColors.tertiaryText),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _submit(),
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
                    onTap: () => _insertActionText('@')),
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
