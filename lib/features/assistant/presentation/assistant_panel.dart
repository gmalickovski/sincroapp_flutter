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
      {bool fromAuto = false, int messageIndex = -1}) async {
    
    // Mark as executing
    if (messageIndex != -1 && messageIndex < _messages.length) {
      setState(() {
        final msg = _messages[messageIndex];
        final actionIndex = msg.actions.indexOf(action);
        if (actionIndex != -1) {
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
          userId: widget.userData.uid,
          title: data['title'] ?? 'Nova Tarefa',
          description: data['description'] ?? '',
          date: DateTime.tryParse(data['date'] ?? '') ?? DateTime.now(),
          isCompleted: false,
          priority: TaskPriority.values.firstWhere(
            (e) => e.toString().split('.').last == (data['priority'] ?? 'medium'),
            orElse: () => TaskPriority.medium,
          ),
        );
        await _firestore.addTask(newTask);
      } else if (action.type == AssistantActionType.analyze_harmony) {
        // Harmony Logic
        final data = action.data;
        final partnerName = data['partner_name'] ?? '';
        final partnerDob = data['partner_dob'] ?? '';
        
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
      if (messageIndex != -1 && messageIndex < _messages.length) {
        setState(() {
          final msg = _messages[messageIndex];
          final actionIndex = msg.actions.indexWhere((a) => 
            a.type == action.type && a.title == action.title); // Better matching
            
          if (actionIndex != -1) {
            final updatedActions = List<AssistantAction>.from(msg.actions);
            updatedActions[actionIndex] = updatedActions[actionIndex].copyWith(
              isExecuting: false,
              isExecuted: true,
            );
            _messages[messageIndex] = msg.copyWith(actions: updatedActions);
          }
        });
      }

      if (!fromAuto) {
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
       if (messageIndex != -1 && messageIndex < _messages.length) {
        setState(() {
          final msg = _messages[messageIndex];
          final actionIndex = msg.actions.indexOf(action);
          if (actionIndex != -1) {
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
      DateTime? dob;
      if (partnerDob.contains('/')) {
        try {
          dob = DateFormat('dd/MM/yyyy').parse(partnerDob);
        } catch (_) {}
      } else {
        dob = DateTime.tryParse(partnerDob);
      }
      
      if (dob == null) return "Data de nascimento inválida para análise.";

      final partnerNumerology = NumerologyEngine(
        nomeCompleto: partnerName,
        dataNascimento: DateFormat('yyyy-MM-dd').format(dob),
      ).calcular();

      final userNumerology = NumerologyEngine(
        nomeCompleto: widget.userData.nomeAnalise,
        dataNascimento: widget.userData.dataNasc,
      ).calcular();

      // FIXED: Access 'numeros' map instead of 'mapa'
      final userExp = userNumerology.numeros['expressao'] ?? 0;
      final partnerExp = partnerNumerology.numeros['expressao'] ?? 0;
      final userDest = userNumerology.numeros['destino'] ?? 0;
      final partnerDest = partnerNumerology.numeros['destino'] ?? 0;

      // FIXED: Use 'primeiroNome' instead of 'nome'
      return "Compreendido, ${widget.userData.primeiroNome}! Analisando as vibrações energéticas de vocês dois:\n\n"
          "**${widget.userData.nomeAnalise}** (Expressão $userExp, Destino $userDest)\n"
          "**$partnerName** (Expressão $partnerExp, Destino $partnerDest)\n\n"
          "A dinâmica entre um número **$userExp** e um número **$partnerExp** na Expressão sugere uma troca interessante. "
          "${_getCompatibilityText(userExp, partnerExp)}\n\n"
          "No Caminho do Destino ($userDest e $partnerDest), vocês buscam objetivos que podem se complementar. "
          "É importante manter o diálogo aberto e respeitar as diferenças individuais para construir uma harmonia duradoura.";
    } catch (e) {
      return "Erro ao calcular harmonia: $e";
    }
  }

  String _getCompatibilityText(int n1, int n2) {
    if (n1 == n2) return "Vocês compartilham vibrações semelhantes, o que facilita a compreensão mútua.";
    if ((n1 + n2) % 3 == 0) return "Há uma fluidez natural na comunicação e na forma como expressam sentimentos.";
    return "Vocês possuem qualidades distintas que, quando unidas, podem criar uma parceria poderosa e equilibrada.";
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

  Widget _buildActionChip(AssistantAction action, int messageIndex) {
    final isExecuted = action.isExecuted;
    final isExecuting = action.isExecuting;

    return GestureDetector(
      onTap: (isExecuted || isExecuting)
          ? null
          : () => _executeAction(context, action, messageIndex: messageIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isExecuted
              ? AppColors.success.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExecuted
                ? AppColors.success
                : AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isExecuting)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (isExecuted)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.check, size: 16, color: AppColors.success),
              ),
            Text(
              action.title,
              style: TextStyle(
                color: isExecuted ? AppColors.success : AppColors.primary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                decoration: isExecuted ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(AssistantMessage m, int index) {
    final isUser = m.role == 'user';
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
                children: m.actions.map((a) => _buildActionChip(a, index)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // --- Main Build ---

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 768;
        
        // Mobile Layout (DraggableScrollableSheet)
        if (!isDesktop) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.5,
            maxChildSize: 1.0,
            snap: true,
            builder: (context, scrollController) {
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
                    // Header
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
                    // Chat Area
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController, // Essential for drag
                        padding: const EdgeInsets.all(20),
                        reverse: true, // Invertido para auto-scroll funcionar nativamente
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          // Ajuste do índice para lista invertida
                          final index = _messages.length - 1 - i;
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
          );
        }

        // Desktop Layout
        return _buildDesktopLayout();
      },
    );
  }

  Widget _buildDesktopLayout() {
    // If fullscreen, show dialog (handled by _toggleFullscreen logic, but here we render the "minimized" floating panel)
    // Actually, the user wants a "mode de visualização expandido".
    // I will render a Floating Panel that can expand.
    
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        width: _isFullscreen ? MediaQuery.of(context).size.width : 450,
        height: _isFullscreen ? MediaQuery.of(context).size.height : 600,
        margin: _isFullscreen ? EdgeInsets.zero : const EdgeInsets.only(right: 20, bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 8))
          ],
          border: _isFullscreen ? null : Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
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
                    icon: Icon(_isFullscreen ? Icons.close_fullscreen : Icons.open_in_full),
                    onPressed: () {
                      setState(() {
                        _isFullscreen = !_isFullscreen;
                      });
                    },
                    tooltip: _isFullscreen ? 'Minimizar' : 'Expandir',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController, // We control this on desktop!
                padding: const EdgeInsets.all(24),
                reverse: true, // Invertido também no desktop
                itemCount: _messages.length,
                itemBuilder: (ctx, i) {
                  final index = _messages.length - 1 - i;
                  return _buildMessageItem(_messages[index], index);
                },
              ),
            ),
            // Input
            _buildInputArea(isMobile: false),
          ],
        ),
      ),
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
                  maxLines: 5,
                  minLines: 1,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(fontSize: 15, height: 1.5),
                  decoration: InputDecoration(
                    hintText: _isListening ? 'Ouvindo...' : 'Como posso ajudar?',
                    hintStyle: TextStyle(color: _isListening ? AppColors.primary : AppColors.tertiaryText),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
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
