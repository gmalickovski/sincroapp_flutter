import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';
import 'package:sincro_app_flutter/features/assistant/services/assistant_service.dart';
import 'package:sincro_app_flutter/features/assistant/services/speech_service.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class AssistantPanel extends StatefulWidget {
  final UserModel userData;

  const AssistantPanel({super.key, required this.userData});

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel>
    with SingleTickerProviderStateMixin {
  // --- Controllers & Services ---
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _firestore = FirestoreService();
  final _speechService = SpeechService();
  final _inputFocusNode = FocusNode();

  // --- State Variables ---
  final List<AssistantMessage> _messages = [];
  bool _isSending = false;
  bool _isListening = false;
  bool _isInputEmpty = true;
  bool _isFullscreen = false;
  String _textBeforeListening = '';

  // --- Animation ---
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateInputState);
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus && _isListening) {
        _stopListening();
      }
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  void _updateInputState() {
    final isEmpty = _controller.text.trim().isEmpty;
    if (_isInputEmpty != isEmpty) {
      setState(() {
        _isInputEmpty = isEmpty;
      });
    }
  }

  @override
  void dispose() {
    _speechService.stop();
    _controller.removeListener(_updateInputState);
    _inputFocusNode.dispose();
    _animController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Auto Scroll ---

  Future<void> _scrollToBottom() async {
    // Com lista invertida (reverse: true), o "bottom" é o offset 0
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0.0, // Topo da lista invertida = Fim do chat
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // --- Logic: Send Message ---

  Future<void> _send() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    if (_isListening) await _stopListening();

    setState(() {
      _messages.add(
          AssistantMessage(role: 'user', content: q, time: DateTime.now()));
      _isSending = true;
    });

    _firestore.addAssistantMessage(widget.userData.uid,
        AssistantMessage(role: 'user', content: q, time: DateTime.now()));
    _controller.clear();
    _inputFocusNode.unfocus();
    
    await _scrollToBottom();

    // Check for affirmative response to pending actions
    final pendingActions = _lastAssistantActions();
    if (_isAffirmative(q) && pendingActions.isNotEmpty) {
      try {
        final chosen = _chooseActionForAffirmative(q, pendingActions);
        final idx = _lastAssistantMessageIndexWithActions();
        await _executeAction(context, chosen,
            fromAuto: true, messageIndex: idx);
      } finally {
        if (mounted) setState(() => _isSending = false);
        await _scrollToBottom();
      }
      return;
    }

    // Normal AI processing
    try {
      final user = widget.userData;
      NumerologyResult? numerology;
      if (user.nomeAnalise.isNotEmpty && user.dataNasc.isNotEmpty) {
        numerology = NumerologyEngine(
                nomeCompleto: user.nomeAnalise, dataNascimento: user.dataNasc)
            .calcular();
      }
      numerology ??= NumerologyEngine(
              nomeCompleto: 'Indefinido', dataNascimento: '1900-01-01')
          .calcular();

      final tasks = await _firestore.getRecentTasks(user.uid, limit: 30);
      final goals = await _firestore.getActiveGoals(user.uid);
      final recentJournal =
          await _firestore.getJournalEntriesForMonth(user.uid, DateTime.now());

      final ans = await AssistantService.ask(
        question: q,
        user: user,
        numerology: numerology!,
        tasks: tasks,
        goals: goals,
        recentJournal: recentJournal,
        chatHistory: _messages,
      );

      final alignedActions = _alignActionsWithAnswer(ans.actions, ans.answer);

      if (mounted) {
        setState(() {
          _messages.add(AssistantMessage(
            role: 'assistant',
            content: ans.answer,
            time: DateTime.now(),
            actions: alignedActions,
          ));
        });
      }

      _firestore.addAssistantMessage(
          widget.userData.uid,
          AssistantMessage(
              role: 'assistant',
              content: ans.answer,
              time: DateTime.now(),
              actions: alignedActions));
      
      await _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(AssistantMessage(
              role: 'assistant',
              content:
                  'Não consegui processar sua solicitação agora. Tente novamente.\n\n$e',
              time: DateTime.now()));
        });
        await _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
      await _scrollToBottom();
    }
  }

  // --- Logic: Speech ---

  Future<void> _onMicPressed() async {
    _inputFocusNode.unfocus();
    final available = await _speechService.init();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Reconhecimento de voz indisponível.'),
            backgroundColor: Colors.redAccent));
      }
      return;
    }

    _textBeforeListening = _controller.text;
    if (_textBeforeListening.isNotEmpty && !_textBeforeListening.endsWith(' ')) {
      _textBeforeListening += ' ';
    }

    setState(() {
      _isListening = true;
      _animController.forward();
    });

    await _speechService.start(onResult: (text) {
      if (!mounted) return;
      final newFullText = '$_textBeforeListening$text';
      setState(() {
        _controller.text = newFullText;
        _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length));
      });
    }, onDone: () {
      if (mounted && _isListening) {
        _stopListening();
      }
    });
  }

  Future<void> _stopListening() async {
    await _speechService.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _animController.reverse();
      });
    }
  }

  // --- Logic: Actions & Helpers ---

  List<AssistantAction> _lastAssistantActions() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'assistant' && _messages[i].actions.isNotEmpty) {
        // Filter only pending actions
        return _messages[i].actions.where((a) => !a.isExecuted).toList();
      }
    }
    return [];
  }

  int _lastAssistantMessageIndexWithActions() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'assistant' && _messages[i].actions.isNotEmpty) {
        return i;
      }
    }
    return -1;
  }

  bool _isAffirmative(String text) {
    final t = text.toLowerCase().trim();
    return t == 'sim' ||
        t == 'claro' ||
        t == 'com certeza' ||
        t == 'pode ser' ||
        t == 'faça isso' ||
        t == 'ok' ||
        t == 'confirmar';
  }

  AssistantAction _chooseActionForAffirmative(
      String text, List<AssistantAction> actions) {
    // Simple logic: return the first one. Can be improved.
    return actions.first;
  }

  List<AssistantAction> _alignActionsWithAnswer(
      List<AssistantAction> actions, String answer) {
    // Logic to attach actions to the answer
    return actions;
  }

  Future<void> _executeAction(
      BuildContext context, AssistantAction action,
      {bool fromAuto = false, int messageIndex = -1, int actionIndex = -1}) async {
    
    // Mark as executing
    if (messageIndex != -1 && messageIndex < _messages.length && actionIndex != -1) {
      setState(() {
        final msg = _messages[messageIndex];
        if (actionIndex < msg.actions.length) {
          final updatedActions = List<AssistantAction>.from(msg.actions);
          updatedActions[actionIndex] = action.copyWith(isExecuting: true);
          _messages[messageIndex] = msg.copyWith(actions: updatedActions);
        }
      });
    }

    try {
      if (action.type == AssistantActionType.create_task) {
        final data = action.data;
        final newTask = TaskModel(
          id: '',
          // userId removed as it is not in TaskModel
          text: data['title'] ?? 'Nova Tarefa', // Changed title to text to match TaskModel
          // description removed as it is not in TaskModel (maybe put in text or ignore)
          createdAt: DateTime.now(),
          dueDate: DateTime.tryParse(data['date'] ?? '') ?? DateTime.now(),
          completed: false,
          // priority removed as it is not in TaskModel
        );
        await _firestore.addTask(widget.userData.uid, newTask);
      } else if (action.type == AssistantActionType.analyze_harmony) {
        // Harmony Logic
        final data = action.data;
        // Fallback to title/date if specific keys are missing (backward compatibility or hallucination)
        final partnerName = data['partner_name'] ?? action.title ?? ''; 
        final partnerDob = data['partner_dob'] ?? data['date'] ?? '';
        
        if (partnerName.isNotEmpty && partnerDob.isNotEmpty) {
           final analysis = _buildHarmonyAnalysis(partnerName, partnerDob);
           setState(() {
             _messages.add(AssistantMessage(
               role: 'assistant',
               content: analysis,
               time: DateTime.now()
             ));
           });
           await _scrollToBottom();
        }
      }

      // Mark as executed
      if (messageIndex != -1 && messageIndex < _messages.length && actionIndex != -1) {
        setState(() {
          final msg = _messages[messageIndex];
          if (actionIndex < msg.actions.length) {
            final updatedActions = List<AssistantAction>.from(msg.actions);
            updatedActions[actionIndex] = updatedActions[actionIndex].copyWith(
              isExecuting: false,
              isExecuted: true,
            );
            _messages[messageIndex] = msg.copyWith(actions: updatedActions);
          }
        });
      }

      // Show "Feito!" only for non-harmony actions (as harmony shows its own result)
      if (!fromAuto && action.type != AssistantActionType.analyze_harmony) {
        setState(() {
          _messages.add(AssistantMessage(
              role: 'assistant',
              content: 'Feito! ✅',
              time: DateTime.now()));
        });
        await _scrollToBottom();
      }
    } catch (e) {
      // Handle error, reset executing state
       if (messageIndex != -1 && messageIndex < _messages.length && actionIndex != -1) {
        setState(() {
          final msg = _messages[messageIndex];
          if (actionIndex < msg.actions.length) {
            final updatedActions = List<AssistantAction>.from(msg.actions);
            updatedActions[actionIndex] = action.copyWith(isExecuting: false); // Reset
            _messages[messageIndex] = msg.copyWith(actions: updatedActions);
          }
        });
      }
      
      setState(() {
        _messages.add(AssistantMessage(
            role: 'assistant',
            content: 'Erro ao executar ação: $e',
            time: DateTime.now()));
      });
      await _scrollToBottom();
    }
  }

  String _buildHarmonyAnalysis(String partnerName, String partnerDob) {
    try {
      // Debug: Log inputs
      print('🔍 Harmony Analysis Debug:');
      print('Partner Name: "$partnerName"');
      print('Partner DOB (raw): "$partnerDob"');
      
      DateTime? dob;
      
      // Try multiple date formats
      if (partnerDob.contains('/')) {
        try {
          dob = DateFormat('dd/MM/yyyy').parse(partnerDob);
          print('✅ Parsed as dd/MM/yyyy: $dob');
        } catch (e) {
          print('❌ Failed dd/MM/yyyy: $e');
          // Try d/M/yyyy
          try {
            dob = DateFormat('d/M/yyyy').parse(partnerDob);
            print('✅ Parsed as d/M/yyyy: $dob');
          } catch (e2) {
            print('❌ Failed d/M/yyyy: $e2');
          }
        }
      } else if (partnerDob.contains('-')) {
        dob = DateTime.tryParse(partnerDob);
        print('✅ Parsed as ISO: $dob');
      }
      
      if (dob == null) {
        print('❌ All date parsing failed');
        return "❌ Data de nascimento inválida para análise. Por favor, forneça no formato DD/MM/AAAA (ex: 31/05/1991).";
      }

      // CRITICAL: NumerologyEngine ONLY accepts dd/MM/yyyy format
      final formattedDobForEngine = DateFormat('dd/MM/yyyy').format(dob);
      print('Partner DOB (for engine): $formattedDobForEngine');
      print('User Name: "${widget.userData.nomeAnalise}"');
      print('User DOB: "${widget.userData.dataNasc}"');

      final partnerNumerology = NumerologyEngine(
        nomeCompleto: partnerName.trim(),
        dataNascimento: formattedDobForEngine, // Use dd/MM/yyyy format
      ).calcular();

      final userNumerology = NumerologyEngine(
        nomeCompleto: widget.userData.nomeAnalise,
        dataNascimento: widget.userData.dataNasc,
      ).calcular();

      print('Partner Numerology: ${partnerNumerology != null ? "✅ Success" : "❌ Null"}');
      print('User Numerology: ${userNumerology != null ? "✅ Success" : "❌ Null"}');

      if (userNumerology == null || partnerNumerology == null) {
        return """
❌ Não foi possível calcular a numerologia para a análise.

**Detalhes do erro:**
- Nome do parceiro: "$partnerName" (${partnerName.trim().isEmpty ? 'VAZIO' : 'OK'})
- Data do parceiro: "$formattedDob" (${partnerNumerology == null ? 'FALHOU' : 'OK'})
- Seus dados: "${widget.userData.nomeAnalise}" / "${widget.userData.dataNasc}" (${userNumerology == null ? 'FALHOU' : 'OK'})

Por favor, verifique se o nome completo e a data de nascimento estão corretos.
""";
      }

      // Extract Mission Numbers (Missão)
      final userMissao = userNumerology.numeros['missao'] as int? ?? 0;
      final partnerMissao = partnerNumerology.numeros['missao'] as int? ?? 0;

      print('User Missão: $userMissao');
      print('Partner Missão: $partnerMissao');

      // Extract Harmony Structures
      final userHarmony = userNumerology.estruturas['harmoniaConjugal'] as Map<String, dynamic>? ?? {};
      
      final vibra = userHarmony['vibra'] as List? ?? [];
      final atrai = userHarmony['atrai'] as List? ?? [];
      final oposto = userHarmony['oposto'] as List? ?? [];
      final passivo = userHarmony['passivo'] as List? ?? [];

      print('Harmony Lists - Vibra: $vibra, Atrai: $atrai, Oposto: $oposto, Passivo: $passivo');

      String compatibilityLevel;
      String emoji;
      String explanation;

      if (vibra.contains(partnerMissao)) {
        compatibilityLevel = "Vibração Perfeita";
        emoji = "💖";
        explanation = "Vocês possuem uma **vibração perfeita**! Há uma sintonia natural e profunda entre vocês.";
      } else if (atrai.contains(partnerMissao)) {
        compatibilityLevel = "Alta Atração";
        emoji = "✨";
        explanation = "Existe uma **forte atração** entre vocês. A relação tende a ser harmoniosa e complementar.";
      } else if (oposto.contains(partnerMissao)) {
        compatibilityLevel = "Energias Opostas";
        emoji = "⚡";
        explanation = "Vocês possuem **energias opostas**. Isso pode gerar desafios, mas também crescimento mútuo se houver compreensão.";
      } else if (passivo.contains(partnerMissao)) {
        compatibilityLevel = "Relação Passiva";
        emoji = "🌙";
        explanation = "A relação tende a ser **passiva e tranquila**. Pode faltar intensidade, mas há estabilidade.";
      } else {
        compatibilityLevel = "Neutro";
        emoji = "🔄";
        explanation = "A relação é **neutra** do ponto de vista numerológico. O sucesso dependerá de outros fatores.";
      }

      print('✅ Analysis complete: $compatibilityLevel');

      return '''
## $emoji Análise de Harmonia Conjugal

**Sua Missão**: $userMissao
**Missão de $partnerName**: $partnerMissao

**Compatibilidade**: $compatibilityLevel

$explanation

### Detalhes da sua Harmonia Conjugal:
- **Vibra com**: ${vibra.join(', ')}
- **Atrai**: ${atrai.join(', ')}
- **Oposto**: ${oposto.join(', ')}
- **Passivo**: ${passivo.join(', ')}

Lembre-se: a numerologia é uma ferramenta de autoconhecimento. O sucesso de qualquer relacionamento depende de amor, respeito, comunicação e esforço mútuo! 💕
''';

    } catch (e, stackTrace) {
      print('❌ Exception in _buildHarmonyAnalysis: $e');
      print('Stack trace: $stackTrace');
      return "Erro ao calcular harmonia: $e\n\nPor favor, tente novamente ou entre em contato com o suporte.";
    }
  }

  // --- UI Components ---

  Widget _buildDynamicButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: _isListening
          ? GestureDetector(
              key: const ValueKey('stop'),
              onTap: _stopListening,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: const Icon(Icons.stop_rounded, color: Colors.redAccent),
              ),
            )
          : !_isInputEmpty
              ? GestureDetector(
                  key: const ValueKey('send'),
                  onTap: _isSending ? null : _send,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: _isSending
                        ? const Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                )
              : GestureDetector(
                  key: const ValueKey('mic'),
                  onTap: _onMicPressed,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.mic_none_rounded, color: AppColors.secondaryText),
                  ),
                ),
    );
  }

  Widget _buildActionChip(AssistantAction action, int messageIndex, int actionIndex, bool anyActionExecuted) {
    final isExecuted = action.isExecuted;
    final isExecuting = action.isExecuting;
    
    // Disable if THIS action is executed/executing OR if ANY other sibling is executed/executing
    // (Single choice logic: once you pick one, others are disabled)
    final isDisabled = isExecuted || isExecuting || anyActionExecuted;

    String label = action.title ?? 'Ação';
    if (action.date != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final actionDate = DateTime(action.date!.year, action.date!.month, action.date!.day);

      String dateStr;
      if (actionDate.isAtSameMomentAs(today)) {
        dateStr = 'Hoje';
      } else {
        dateStr = DateFormat('dd/MM', 'pt_BR').format(action.date!);
      }
      label = '$label - $dateStr';
    }

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () => _executeAction(context, action, messageIndex: messageIndex, actionIndex: actionIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isExecuted
              ? AppColors.success.withValues(alpha: 0.1)
              : isDisabled 
                  ? AppColors.border.withValues(alpha: 0.3) // Disabled look
                  : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExecuted
                ? AppColors.success
                : isDisabled
                    ? Colors.transparent
                    : AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Removed Loading Spinner as requested
            if (isExecuted)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.check, size: 16, color: AppColors.success),
              ),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isExecuted 
                      ? AppColors.success 
                      : isDisabled 
                          ? AppColors.secondaryText 
                          : AppColors.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  decoration: isExecuted ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(AssistantMessage m, int index) {
    final isUser = m.role == 'user';
    // Check if any action in this message is already executed or executing
    final anyActionExecuted = m.actions.any((a) => a.isExecuted || a.isExecuting);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primaryAccent.withValues(alpha: 0.1) : AppColors.cardBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser ? Colors.transparent : AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: MarkdownBody(
                    data: m.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isUser ? AppColors.primaryText : AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!isUser && m.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 12),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: m.actions.asMap().entries.map((entry) {
                  final actionIndex = entry.key;
                  final action = entry.value;
                  return _buildActionChip(action, index, actionIndex, anyActionExecuted);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 200),
                const SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Main Build ---

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery for screen-based layout decision instead of parent constraints
    final isDesktop = MediaQuery.of(context).size.width > 768;

    // Mobile Layout (DraggableScrollableSheet)
    if (!isDesktop) {
      // Wrap the sheet in Padding to push it up when keyboard opens
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          snap: true,
          builder: (context, sheetScrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle & Header (Driven by sheetScrollController)
                  SizedBox(
                    height: 70, // Fixed height for the header area
                    child: ListView(
                      controller: sheetScrollController,
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Header Content
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text('Sincro IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Spacer(),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                  
                  // Chat Area (Driven by internal _scrollController)
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController, // Use internal controller for messages
                      padding: const EdgeInsets.all(20),
                      reverse: true, 
                      // Add 1 to count if sending (for typing indicator)
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        // If sending, the first item (index 0 in reverse) is the typing indicator
                        if (_isSending && i == 0) {
                          return _buildTypingIndicator();
                        }
                        
                        // Adjust index: if sending, shift message index by 1
                        final adjustedIndex = _isSending ? i - 1 : i;
                        final index = _messages.length - 1 - adjustedIndex;
                        return _buildMessageItem(_messages[index], index);
                      },
                    ),
                  ),
                  // Input Area
                  _buildInputArea(isMobile: true),
                ],
              ),
            );
          },
        ),
      );
    }

    // Desktop Layout
    return _buildDesktopLayout();
  }

  Widget _buildDesktopLayout() {
    // Expanded Mode: Large centered dialog
    if (_isFullscreen) {
      return Stack(
        children: [
          // Backdrop
          GestureDetector(
            onTap: () => setState(() => _isFullscreen = false),
            child: Container(color: Colors.black54),
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85, // 85% of screen width
              height: MediaQuery.of(context).size.height * 0.90, // 90% of screen height
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  )
                ],
              ),
              child: _buildPanelContent(isExpanded: true),
            ),
          ),
        ],
      );
    }

    // Minimized Mode: Bottom-right sheet (mobile-like)
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        width: 480,
        height: 650,
        margin: const EdgeInsets.only(right: 24, bottom: 90),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: _buildPanelContent(isExpanded: false),
      ),
    );
  }

  Widget _buildPanelContent({required bool isExpanded}) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sincro IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Assistente Virtual', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.close_fullscreen : Icons.open_in_full,
                  color: AppColors.secondaryText,
                ),
                onPressed: () {
                  setState(() {
                    _isFullscreen = !_isFullscreen;
                  });
                },
                tooltip: isExpanded ? 'Minimizar' : 'Expandir',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            reverse: true,
            itemCount: _messages.length + (_isSending ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (_isSending && i == 0) {
                return _buildTypingIndicator();
              }
              final adjustedIndex = _isSending ? i - 1 : i;
              final index = _messages.length - 1 - adjustedIndex;
              return _buildMessageItem(_messages[index], index);
            },
          ),
        ),
        // Input
        _buildInputArea(isMobile: false),
      ],
    );
  }

  Widget _buildInputArea({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _inputFocusNode,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Como posso ajudar?',
                    hintStyle: TextStyle(color: AppColors.secondaryText),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildDynamicButton(),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(
          color: AppColors.secondaryText,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
