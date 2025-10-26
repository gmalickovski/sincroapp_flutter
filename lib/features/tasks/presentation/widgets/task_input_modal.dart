import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
// --- INÍCIO DA MUDANÇA: Importar o novo modal ---
import 'package:sincro_app_flutter/common/widgets/custom_date_picker_modal.dart';
// --- FIM DA MUDANÇA ---
import 'package:sincro_app_flutter/common/utils/string_sanitizer.dart';
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart';
import 'package:sincro_app_flutter/features/authentication/data/auth_repository.dart';
// import 'package:sincro_app_flutter/features/authentication/data/content_data.dart'; // Não usado aqui
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
// REMOVIDO: import 'package:sincro_app_flutter/features/tasks/presentation/widgets/goal_selection_modal.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

// --- Regex (inalterados) ---
const String _monthPattern =
    "janeiro|fevereiro|março|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro|jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez";
final RegExp _ddMmYyPattern = RegExp(r'/\s*(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?');
final RegExp _fullDatePattern = RegExp(r'/\s*dia\s+(\d{1,2})(?:\s+de)?\s+(' +
    _monthPattern +
    r')(?:\s+de\s+(\d{4}))?');
// --- Fim Regex ---

// --- _SyntaxHighlightingController (inalterado) ---
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
// --- Fim _SyntaxHighlightingController ---

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

  DateTime _dateForVibration = DateTime.now();
  DateTime? _parsedDueDate;
  int _personalDay = 0;

  OverlayEntry? _goalOverlayEntry;
  final LayerLink _layerLink = LayerLink();
  List<Goal> _allGoals = [];
  List<Goal> _filteredGoals = [];

  OverlayEntry? _tagOverlayEntry;
  List<String> _allTags = [];
  List<String> _filteredTags = [];
  bool _isLoadingTags = false;

  bool get _isEditing => widget.taskToEdit != null;

  // --- NOVO: FocusNode para o TextField principal ---
  final FocusNode _textFieldFocusNode = FocusNode();
  // --- FIM NOVO ---

  @override
  void initState() {
    super.initState();

    _textController = _SyntaxHighlightingController(
      patternMap: {
        RegExp(r"#(\w+)", caseSensitive: false):
            const TextStyle(color: Colors.purpleAccent),
        RegExp(r"@([\w-]+)", caseSensitive: false):
            const TextStyle(color: Colors.cyanAccent),
        _ddMmYyPattern: const TextStyle(color: Colors.orangeAccent),
        _fullDatePattern: const TextStyle(color: Colors.orangeAccent),
      },
    );

    // Lógica de inicialização (com ajustes para pré-seleção)
    if (_isEditing) {
      String editText = widget.taskToEdit!.text;
      if (widget.taskToEdit!.tags.isNotEmpty) {
        editText += widget.taskToEdit!.tags.map((tag) => ' #$tag').join('');
      }
      if (widget.taskToEdit!.journeyTitle != null &&
          widget.taskToEdit!.journeyTitle!.isNotEmpty) {
        final simplifiedTag =
            StringSanitizer.toSimpleTag(widget.taskToEdit!.journeyTitle!);
        editText += ' @$simplifiedTag';
      }
      if (widget.taskToEdit!.dueDate != null) {
        final formattedDate =
            DateFormat('dd/MM/yyyy').format(widget.taskToEdit!.dueDate!);
        editText += ' /${formattedDate}';
      }
      _textController.text = editText.trim();
      _parsedDueDate = widget.taskToEdit!.dueDate;
      _dateForVibration = widget.taskToEdit!.dueDate ?? DateTime.now();
    }
    // Alterado para não pré-preencher a meta no campo de texto
    else if (widget.preselectedGoal != null) {
      _dateForVibration = DateTime.now();
      // A meta @nomedametaatual agora está "por baixo dos panos".
      // Não definimos mais o _textController.text aqui.
      // O hintText será atualizado no build() para refletir isso.
    }
    // Alterado para não pré-preencher a data no campo de texto
    else if (widget.preselectedDate != null) {
      _parsedDueDate = widget.preselectedDate; // Data "por baixo dos panos"
      _dateForVibration = widget.preselectedDate!; // Para a pílula de vibração
      // Não definimos mais o _textController.text aqui
    } else {
      // Se não houver data pré-selecionada, define _dateForVibration para hoje
      _dateForVibration = DateTime.now();
    }

    _textController.addListener(_onTextChanged);
    if (widget.userData != null) {
      _updateVibrationForDate(_dateForVibration);
      _loadGoals();
      _loadTags();
    }

    // --- NOVO: Focar o campo de texto após a build inicial ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Usa o FocusNode associado ao TextField
      _textFieldFocusNode.requestFocus();
      // Se pré-selecionou algo (exceto meta ou data), move o cursor para o final
      if (widget.preselectedDate != null) {
        _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length));
      }
    });
    // --- FIM NOVO ---
  }

  Future<void> _loadGoals() async {
    // ... (inalterado) ...
    if (widget.userData != null && widget.userData!.uid.isNotEmpty) {
      _allGoals = await _firestoreService.getActiveGoals(widget.userData!.uid);
      if (mounted) {
        setState(() {});
      }
    } else {
      print("Erro: UID do usuário não disponível para carregar metas.");
      _allGoals = [];
    }
  }

  Future<void> _loadTags() async {
    // ... (inalterado) ...
    if (widget.userData == null || widget.userData!.uid.isEmpty) return;
    setState(() => _isLoadingTags = true);
    try {
      final recentTasks = await _firestoreService
          .getRecentTasks(widget.userData!.uid, limit: 50);
      final tagSet = <String>{};
      for (var task in recentTasks) {
        tagSet.addAll(task.tags);
      }
      _allTags = tagSet.toList();
      _allTags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } catch (e) {
      print("Erro ao carregar tags recentes: $e");
      _allTags = [];
    } finally {
      if (mounted) {
        setState(() => _isLoadingTags = false);
      }
    }
  }

  void _onTextChanged() {
    // ... (código inalterado) ...
    _parsedDueDate = TaskParser.parseDateFromText(_textController.text);
    final currentDateToShow =
        _parsedDueDate ?? widget.preselectedDate ?? DateTime.now();

    if (!_isSameDay(_dateForVibration, currentDateToShow)) {
      _updateVibrationForDate(currentDateToShow);
    }
    _handleGoalAutocomplete();
    _handleTagAutocomplete();
  }

  // --- Lógica de Autocomplete (inalterada) ---
  void _handleGoalAutocomplete() {
    if (widget.preselectedGoal != null) {
      _removeGoalOverlay();
      return;
    }
    final text = _textController.text;
    final cursorPos = _textController.selection.start;
    if (cursorPos < 0) {
      _removeGoalOverlay();
      return;
    }
    final atMatch = RegExp(r"@([\w-]*)$", caseSensitive: false)
        .firstMatch(text.substring(0, cursorPos));
    if (atMatch != null) {
      final query = atMatch.group(1) ?? '';
      _filteredGoals = _allGoals.where((goal) {
        final simpleTitle = StringSanitizer.toSimpleTag(goal.title);
        return simpleTitle.toLowerCase().contains(query.toLowerCase());
      }).toList();
      if (_filteredGoals.isNotEmpty) {
        _showGoalOverlay();
      } else {
        _removeGoalOverlay();
      }
    } else {
      _removeGoalOverlay();
    }
  }

  void _handleTagAutocomplete() {
    final text = _textController.text;
    final cursorPos = _textController.selection.start;
    if (cursorPos < 0) {
      _removeTagOverlay();
      return;
    }
    final hashMatch = RegExp(r"#(\w*)$", caseSensitive: false)
        .firstMatch(text.substring(0, cursorPos));
    if (hashMatch != null) {
      final query = hashMatch.group(1) ?? '';
      _filteredTags = _allTags.where((tag) {
        return tag.toLowerCase().contains(query.toLowerCase());
      }).toList();
      if (_filteredTags.isNotEmpty) {
        _showTagOverlay();
      } else {
        _removeTagOverlay();
      }
    } else {
      _removeTagOverlay();
    }
  }

  void _showGoalOverlay() {
    _removeTagOverlay();
    _removeGoalOverlay();
    _goalOverlayEntry = _createGoalOverlayEntry();
    Overlay.of(context).insert(_goalOverlayEntry!);
  }

  void _showTagOverlay() {
    _removeGoalOverlay();
    _removeTagOverlay();
    _tagOverlayEntry = _createTagOverlayEntry();
    Overlay.of(context).insert(_tagOverlayEntry!);
  }

  void _removeGoalOverlay() {
    _goalOverlayEntry?.remove();
    _goalOverlayEntry = null;
  }

  void _removeTagOverlay() {
    _tagOverlayEntry?.remove();
    _tagOverlayEntry = null;
  }

  OverlayEntry _createGoalOverlayEntry() {
    final List<Goal> goalsToShow = _filteredGoals;
    const double overlayHeight = 174.0;
    const double verticalGap = 10.0;
    const Offset overlayOffset = Offset(0, -(overlayHeight + verticalGap));

    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 250,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: overlayOffset,
            child: Material(
              elevation: 4.0,
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: overlayHeight),
                child: goalsToShow.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text('Nenhuma jornada encontrada.',
                              style: TextStyle(color: AppColors.secondaryText)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(4),
                        shrinkWrap: true,
                        itemCount: goalsToShow.length,
                        itemBuilder: (context, index) =>
                            _buildGoalSuggestionItem(goalsToShow[index]),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  OverlayEntry _createTagOverlayEntry() {
    final List<String> tagsToShow = _filteredTags;
    const double overlayHeight = 174.0;
    const double verticalGap = 10.0;
    const Offset overlayOffset = Offset(0, -(overlayHeight + verticalGap));

    return OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 200,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: overlayOffset,
            child: Material(
              elevation: 4.0,
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: overlayHeight),
                child: _isLoadingTags
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)),
                      )
                    : tagsToShow.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text('Nenhuma tag encontrada.',
                                  style: TextStyle(
                                      color: AppColors.secondaryText)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(4),
                            shrinkWrap: true,
                            itemCount: tagsToShow.length,
                            itemBuilder: (context, index) =>
                                _buildTagSuggestionItem(tagsToShow[index]),
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
            _removeGoalOverlay();
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

  Widget _buildTagSuggestionItem(String tag) {
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
          splashColor: Colors.purpleAccent.withOpacity(0.2),
          hoverColor: Colors.purpleAccent.withOpacity(0.1),
          onTap: () {
            _updateTagInTextField(tag);
            _removeTagOverlay();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '#$tag',
              style: const TextStyle(color: Colors.purpleAccent, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
  // --- Fim Autocomplete ---

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _updateVibrationForDate(DateTime date) {
    // ... (inalterado) ...
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
          _dateForVibration = date;
          _personalDay = day;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _dateForVibration = date;
          _personalDay = 0;
        });
      }
    }
  }

  // --- Funções de atualização de texto (inalteradas) ---
  void _updateDateInTextField(DateTime newDate) {
    _updateVibrationForDate(newDate);
    _parsedDueDate = newDate;
    String currentText = _textController.text;
    final textWithoutDate = currentText
        .replaceAll(RegExp(r'/\s*\d{1,2}/\d{1,2}(?:/\d{2,4})?\s*'), '')
        .replaceAll(
            RegExp(
                r'/\s*dia\s+\d{1,2}(?:\s+de)?\s+' +
                    _monthPattern +
                    r'(?:\s+de\s+\d{4})?\s*',
                caseSensitive: false),
            '')
        .trim();
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
    final atMatch = RegExp(r"@([\w-]*)$", caseSensitive: false)
        .firstMatch(textBeforeCursor);
    String newText;
    int cursorPosition;
    if (atMatch != null) {
      final textBeforeTag = textBeforeCursor.substring(0, atMatch.start);
      final textAfterCursor = currentText.substring(selection.end);
      newText = '$textBeforeTag@$simplifiedTag $textAfterCursor'.trim();
      cursorPosition = textBeforeTag.length + simplifiedTag.length + 2;
    } else {
      final textWithoutGoal = currentText
          .replaceAll(RegExp(r"@[\w-]+\s*", caseSensitive: false), '')
          .trim();
      newText = '$textWithoutGoal @$simplifiedTag'.trim();
      cursorPosition = newText.length;
    }
    _textController.text = newText;
    _textController.selection =
        TextSelection.fromPosition(TextPosition(offset: cursorPosition));
    _textFieldFocusNode.requestFocus();
  }

  void _updateTagInTextField(String tag) {
    final currentText = _textController.text;
    final selection = _textController.selection;
    final textBeforeCursor = currentText.substring(0, selection.start);
    final hashMatch =
        RegExp(r"#(\w*)$", caseSensitive: false).firstMatch(textBeforeCursor);
    String newText;
    int cursorPosition;
    if (hashMatch != null) {
      final textBeforeTag = textBeforeCursor.substring(0, hashMatch.start);
      final textAfterCursor = currentText.substring(selection.end);
      newText = '$textBeforeTag#$tag $textAfterCursor'.trim();
      cursorPosition = textBeforeTag.length + tag.length + 2;
    } else {
      final textBefore = currentText.substring(0, selection.start);
      final textAfter = currentText.substring(selection.end);
      newText = '$textBefore#$tag $textAfter'.trim();
      cursorPosition = textBefore.length + tag.length + 2;
    }
    _textController.text = newText;
    _textController.selection =
        TextSelection.fromPosition(TextPosition(offset: cursorPosition));
    _textFieldFocusNode.requestFocus();
  }
  // --- Fim atualização texto ---

  // --- Funções _selectDate, _selectGoal, _selectTag ---

  // --- INÍCIO DA MUDANÇA: Substituir showDatePicker pelo novo modal ---
  Future<void> _selectDate(BuildContext context) async {
    _removeGoalOverlay();
    _removeTagOverlay();

    // Proteção para garantir que temos os dados do usuário para o motor
    if (widget.userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Erro ao carregar dados do usuário."),
          backgroundColor: Colors.red));
      return;
    }

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent, // O modal_custom tem seu próprio fundo
      builder: (modalContext) => CustomDatePickerModal(
        initialDate: _parsedDueDate ?? _dateForVibration,
        userData: widget.userData!, // Já verificamos que não é nulo
      ),
    );

    if (picked != null && !_isSameDay(picked, _dateForVibration)) {
      _updateDateInTextField(picked);
    }
  }
  // --- FIM DA MUDANÇA ---

  void _selectGoal(BuildContext context) {
    // ... (inalterado, já usa overlay) ...
    _removeTagOverlay();
    if (_goalOverlayEntry != null) {
      _removeGoalOverlay();
      return;
    }
    _filteredGoals = List.from(_allGoals);
    _filteredGoals
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (mounted) {
      _showGoalOverlay();
    }
  }

  void _selectTag(BuildContext context) {
    // ... (inalterado, já usa overlay) ...
    _removeGoalOverlay();
    _textFieldFocusNode.requestFocus();
    if (_tagOverlayEntry != null) {
      _removeTagOverlay();
      return;
    }
    _filteredTags = List.from(_allTags);
    if (mounted) {
      _showTagOverlay();
    }
  }
  // --- Fim seletores ---

  void _insertActionText(String char) {
    // ... (inalterado) ...
    _removeGoalOverlay();
    _removeTagOverlay();
    final text = _textController.text;
    final selection = _textController.selection;
    final newText = text.replaceRange(selection.start, selection.end, char);
    final newOffset = selection.start + char.length;

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _textController.selection = TextSelection.collapsed(offset: newOffset);
      if (char == '@') {
        _handleGoalAutocomplete();
      }
    });
  }

  void _submit() async {
    // ... (inalterado) ...
    _removeGoalOverlay();
    _removeTagOverlay();
    final rawText = _textController.text.trim();

    if (rawText.isEmpty && widget.preselectedGoal == null) {
      Navigator.of(context).pop(false);
      return;
    }

    final userId = AuthRepository().getCurrentUser()?.uid;
    if (userId == null) {
      print("Erro: Usuário não logado ao submeter tarefa.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro de autenticação ao salvar.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final ParsedTask parsedResult = await TaskParser.parse(rawText, userId);

      final DateTime? finalDueDate = _parsedDueDate ?? widget.preselectedDate;

      final String? finalJourneyId =
          parsedResult.journeyId ?? widget.preselectedGoal?.id;
      final String? finalJourneyTitle =
          parsedResult.journeyTitle ?? widget.preselectedGoal?.title;

      String finalText = parsedResult.cleanText;

      if (finalText.isEmpty && finalJourneyId != null) {
        finalText = "Novo Marco";
      }

      final List<String> finalTags = parsedResult.tags;

      int? finalPersonalDay;
      if (widget.userData != null &&
          widget.userData!.dataNasc.isNotEmpty &&
          widget.userData!.nomeAnalise.isNotEmpty) {
        final engine = NumerologyEngine(
          nomeCompleto: widget.userData!.nomeAnalise,
          dataNascimento: widget.userData!.dataNasc,
        );
        final dateForCalc = finalDueDate ?? DateTime.now();
        finalPersonalDay = engine.calculatePersonalDayForDate(dateForCalc);
      } else {
        finalPersonalDay = _personalDay > 0
            ? _personalDay
            : null; // Usa o _personalDay calculado no init
      }

      if (_isEditing) {
        if (widget.taskToEdit == null) {
          print("Erro: Tentando editar tarefa nula.");
          throw Exception("Task a ser editada não encontrada.");
        }
        final Map<String, dynamic> updates = {
          'text': finalText,
          'dueDate': finalDueDate,
          'tags': finalTags,
          'journeyId': finalJourneyId,
          'journeyTitle': finalJourneyTitle,
          'personalDay': finalPersonalDay,
        };
        await _firestoreService.updateTaskFields(
            userId, widget.taskToEdit!.id, updates);

        final originalGoalId = widget.taskToEdit!.journeyId;
        if (originalGoalId != finalJourneyId) {
          if (originalGoalId != null && originalGoalId.isNotEmpty) {
            _firestoreService.updateGoalProgress(userId, originalGoalId);
          }
          if (finalJourneyId != null && finalJourneyId.isNotEmpty) {
            _firestoreService.updateGoalProgress(userId, finalJourneyId);
          }
        } else if (finalJourneyId != null && finalJourneyId.isNotEmpty) {
          _firestoreService.updateGoalProgress(userId, finalJourneyId);
        }
      } else {
        final newTask = TaskModel(
          id: '',
          text: finalText,
          completed: false,
          createdAt: DateTime.now(),
          dueDate: finalDueDate,
          tags: finalTags,
          journeyId: finalJourneyId,
          journeyTitle: finalJourneyTitle,
          personalDay: finalPersonalDay,
        );
        await _firestoreService.addTask(userId, newTask);
        if (newTask.journeyId != null && newTask.journeyId!.isNotEmpty) {
          _firestoreService.updateGoalProgress(userId, newTask.journeyId!);
        }
      }

      Navigator.of(context).pop(true); // Sucesso
    } catch (e) {
      print("Erro detalhado ao salvar/processar tarefa: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Ocorreu um erro ao salvar a tarefa: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _removeGoalOverlay();
    _removeTagOverlay();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (build method inalterado) ...
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
          _removeGoalOverlay();
          _removeTagOverlay();
        },
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompositedTransformTarget(
                link: _layerLink,
                child: TextField(
                  focusNode: _textFieldFocusNode,
                  controller: _textController,
                  style: const TextStyle(
                      fontSize: 16, color: AppColors.primaryText),
                  decoration: InputDecoration(
                    hintText: widget.preselectedGoal != null
                        ? "Adicionar novo marco..."
                        : "Adicionar tarefa, #tag, @meta, /data",
                    hintStyle: const TextStyle(color: AppColors.tertiaryText),
                    border: InputBorder.none,
                  ),
                  onTap: () {
                    _removeGoalOverlay();
                    _removeTagOverlay();
                  },
                  onSubmitted: (_) => _submit(),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildActionButton(
                      icon: Icons.label_outline,
                      onTap: () => _selectTag(context)),
                  if (widget.preselectedGoal == null)
                    _buildActionButton(
                        icon: Icons.flag_outlined,
                        onTap: () => _selectGoal(context)),
                  if (widget.preselectedDate == null)
                    _buildActionButton(
                        icon: Icons.calendar_today_outlined,
                        onTap: () => _selectDate(context)),
                  const Spacer(),
                  if (_personalDay > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: VibrationPill(
                        vibrationNumber: _personalDay,
                        onTap: () {
                          _removeGoalOverlay();
                          _removeTagOverlay();
                          showVibrationInfoModal(context,
                              vibrationNumber: _personalDay);
                        },
                      ),
                    ),
                  Padding(
                    padding:
                        EdgeInsets.only(left: _personalDay > 0 ? 8.0 : 0.0),
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          minimumSize: const Size(44, 36)),
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

  Widget _buildActionButton(
      {required IconData icon, required VoidCallback onTap}) {
    // ... (helper inalterado) ...
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.tertiaryText),
      splashRadius: 20,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
    );
  }
}
