import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';

// Classe de controle de texto com coloração de sintaxe
class _SyntaxHighlightingController extends TextEditingController {
  final Map<RegExp, TextStyle> patternMap;
  final TextStyle? defaultStyle;

  _SyntaxHighlightingController({required this.patternMap, this.defaultStyle});

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final List<InlineSpan> children = [];
    final text = this.text;

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
  final Function(ParsedTask parsedTask, DateTime dueDate) onAddTask;
  final UserModel? userData;

  const TaskInputModal({
    super.key,
    required this.onAddTask,
    required this.userData,
  });

  @override
  State<TaskInputModal> createState() => _TaskInputModalState();
}

class _TaskInputModalState extends State<TaskInputModal> {
  late _SyntaxHighlightingController _textController;

  DateTime _selectedDate = DateTime.now();
  int _personalDay = 0;
  VibrationContent? _dayInfo;

  // Mapa de meses para o parser
  static const Map<String, int> _monthMap = {
    'janeiro': 1,
    'fevereiro': 2,
    'março': 3,
    'marco': 3,
    'abril': 4,
    'maio': 5,
    'junho': 6,
    'julho': 7,
    'agosto': 8,
    'setembro': 9,
    'outubro': 10,
    'novembro': 11,
    'dezembro': 12,
  };

  @override
  void initState() {
    super.initState();

    // ATUALIZAÇÃO 1: Construir o padrão de meses dinamicamente
    final monthPattern = _monthMap.keys.join('|');

    _textController = _SyntaxHighlightingController(
      patternMap: {
        RegExp(r"#\w+"): const TextStyle(color: Colors.purpleAccent),
        RegExp(r"@\w+"): const TextStyle(color: Colors.cyanAccent),
        // Regex de data agora usa o padrão de meses específico
        RegExp(r"/\s*(?:dia\s+\d{1,2}(?:\s+de)?\s+(" +
                monthPattern +
                r")(?:\s+de\s+\d{4})?|\d{1,2}/\d{1,2}(?:/\d{4})?)"):
            const TextStyle(color: Colors.orangeAccent),
      },
    );

    _textController.addListener(_onTextChanged);
    if (widget.userData != null) {
      _updateVibrationForDate(DateTime.now());
    }
  }

  @override
  void didUpdateWidget(TaskInputModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userData == null && widget.userData != null) {
      _updateVibrationForDate(DateTime.now());
    }
  }

  // ATUALIZAÇÃO 2: Lógica de parsing de data aprimorada para ser mais precisa
  DateTime _parseDateFromText(String text) {
    final textLower = text.toLowerCase();
    final now = DateTime.now();
    final monthPattern = _monthMap.keys.join('|');

    // Padrão unificado e preciso para linguagem natural: /dia 10 [de] dezembro [de 2025]
    var match = RegExp(r'/\s*dia\s+(\d{1,2})(?:\s+de)?\s+(' +
            monthPattern +
            r')(?:\s+de\s+(\d{4}))?')
        .firstMatch(textLower);
    if (match != null) {
      try {
        final day = int.parse(match.group(1)!);
        final monthName = match.group(2)!;
        final yearStr = match.group(3);
        final month = _monthMap[monthName];

        if (month != null) {
          final year = yearStr != null ? int.parse(yearStr) : now.year;
          var date = DateTime(year, month, day);

          if (yearStr == null &&
              date.isBefore(DateTime(now.year, now.month, now.day))) {
            date = DateTime(now.year + 1, month, day);
          }
          return date;
        }
      } catch (e) {/* Ignora */}
    }

    // Padrão: /dia 10
    match = RegExp(r'/\s*dia\s+(\d{1,2})').firstMatch(textLower);
    if (match != null) {
      try {
        final day = int.parse(match.group(1)!);
        var date = DateTime(now.year, now.month, day);
        if (date.isBefore(DateTime(now.year, now.month, now.day))) {
          date = DateTime(now.year, now.month + 1, day);
        }
        return date;
      } catch (e) {/* Ignora */}
    }

    // Padrão numérico: /10/12/2025 ou /10/12
    match =
        RegExp(r'/\s*(\d{1,2})/(\d{1,2})(?:/(\d{4}))?').firstMatch(textLower);
    if (match != null) {
      try {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        final year =
            match.group(3) != null ? int.parse(match.group(3)!) : now.year;

        var date = DateTime(year, month, day);
        if (match.group(3) == null &&
            date.isBefore(DateTime(now.year, now.month, now.day))) {
          date = DateTime(now.year + 1, month, day);
        }
        return date;
      } catch (e) {/* Ignora */}
    }

    return now;
  }

  void _onTextChanged() {
    final newDate = _parseDateFromText(_textController.text);
    if (!isSameDay(_selectedDate, newDate)) {
      _updateVibrationForDate(newDate);
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _updateVibrationForDate(DateTime date) {
    if (widget.userData != null &&
        widget.userData!.dataNasc.isNotEmpty &&
        widget.userData!.nomeAnalise.isNotEmpty) {
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
    if (rawText.isNotEmpty) {
      final parsedTask = TaskParser.parse(rawText);
      widget.onAddTask(parsedTask, _selectedDate);
      Navigator.of(context).pop();
    }
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
          color: Color(0xFF27272a),
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
                hintText: "Adicionar tarefa, #tag... /data",
                hintStyle: TextStyle(color: AppColors.tertiaryText),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            if (_personalDay > 0 && _dayInfo != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    onTap: () {
                      _insertActionText('/');
                    }),
                const Spacer(),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  child: const Icon(Icons.arrow_upward,
                      color: Colors.white, size: 20),
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
