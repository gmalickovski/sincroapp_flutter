import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _firestore = FirestoreService();
  final _speechService = SpeechService();

  final _inputFocusNode = FocusNode();

  bool _isSending = false;
  final List<AssistantMessage> _messages = [];

  // Controle visual e estado da voz
  bool _isListening = false;
  bool _isInputEmpty = true;
  bool _isFullscreen = false; // Controla modo tela cheia (apenas desktop)

  // Variável chave para corrigir o ECO
  String _textBeforeListening = '';

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller.addListener(_updateInputState);

    // Se o usuário tocar na caixa, para de ouvir
    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus && _isListening) {
        _stopListening();
      }
    });

    // Animação sutil (apenas entrada/saída, sem loop)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Rápido e sutil
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

  // --- Lógica de Envio ---

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

      setState(() {
        _messages.add(AssistantMessage(
          role: 'assistant',
          content: ans.answer,
          time: DateTime.now(),
          actions: alignedActions,
        ));
      });

      _firestore.addAssistantMessage(
          widget.userData.uid,
          AssistantMessage(
              role: 'assistant',
              content: ans.answer,
              time: DateTime.now(),
              actions: alignedActions));
    } catch (e) {
      setState(() {
        _messages.add(AssistantMessage(
            role: 'assistant',
            content:
                'Não consegui processar sua solicitação agora. Tente novamente.\n\n$e',
            time: DateTime.now()));
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
      await _scrollToBottom();
    }
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // --- Lógica de Reconhecimento de Voz (CORREÇÃO DO ECO) ---

  Future<void> _onMicPressed() async {
    _inputFocusNode.unfocus();

    final available = await _speechService.init();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Reconhecimento de voz indisponível ou permissão negada.'),
            backgroundColor: Colors.redAccent));
      }
      return;
    }

    // 1. Salva o texto que JÁ existia antes de começar a falar
    _textBeforeListening = _controller.text;
    // Adiciona espaço se já tiver texto
    if (_textBeforeListening.isNotEmpty &&
        !_textBeforeListening.endsWith(' ')) {
      _textBeforeListening += ' ';
    }

    setState(() {
      _isListening = true;
      _animController.forward(); // Ativa animação (sem loop)
    });

    await _speechService.start(onResult: (text) {
      if (!mounted) return;

      // 2. A mágica anti-eco: Sempre reconstrói usando (Texto Antigo + Voz Atual)
      // O 'text' vindo do serviço é a frase completa da sessão de voz atual.
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
        _animController.reverse(); // Desativa animação
      });
    }
  }

  // --- UI: Botão Dinâmico ---

  Widget _buildDynamicButton() {
    Key key;
    Widget buttonContent;

    if (_isListening) {
      key = const ValueKey('mic_stop');
      buttonContent = GestureDetector(
        onTap: _stopListening,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent,
                width: 1.5,
              ),
            ),
            // Ícone de Stop para indicar que vai parar
            child: const Icon(Icons.stop_rounded, color: Colors.redAccent),
          ),
        ),
      );
    } else if (!_isInputEmpty) {
      key = const ValueKey('send_button');
      buttonContent = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.send, color: Colors.white),
          onPressed: _isSending ? null : _send,
        ),
      );
    } else {
      key = const ValueKey('mic_start');
      buttonContent = GestureDetector(
        onTap: _onMicPressed,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: const Icon(Icons.mic_none, color: AppColors.secondaryText),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Container(key: key, child: buttonContent),
    );
  }

  // --- UI Principal ---

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasKeyboard = bottomInset > 0;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    // Se fullscreen no desktop, forçar 100%
    final initialSize = _isFullscreen && isDesktop 
        ? 1.0 
        : (hasKeyboard ? 0.95 : 0.6);
    final minSize = _isFullscreen && isDesktop 
        ? 1.0 
        : (hasKeyboard ? 0.95 : 0.5);
    final maxSize = 1.0; // Permite expansão total
    final snapSizesList = _isFullscreen && isDesktop
        ? const [1.0]
        : (hasKeyboard ? const [0.95] : const [0.6, 0.95, 1.0]);

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      expand: false,
      snap: true,
      snapSizes: snapSizesList,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: _isFullscreen && isDesktop
                ? BorderRadius.zero // Sem bordas em fullscreen
                : const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, -2)),
            ],
          ),
          child: Column(
            children: [
              // Handle - ocultar em fullscreen desktop
              if (!(_isFullscreen && isDesktop))
                Container(
                  height: 44,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4, left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Sincro IA',
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    // Botão fullscreen apenas no desktop
                    if (isDesktop)
                      IconButton(
                        icon: Icon(
                          _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          color: AppColors.secondaryText,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isFullscreen = !_isFullscreen;
                          });
                        },
                        tooltip: _isFullscreen ? 'Sair da tela cheia' : 'Tela cheia',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // Lista
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isUser = m.role == 'user';
                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 560),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppColors.primaryAccent.withValues(alpha: 0.15)
                              : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMarkdownMessage(m.content, isUser: isUser),
                            if (!isUser && m.actions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final a in m.actions)
                                    _buildActionChip(a, i),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Input
              AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: _inputFocusNode,
                            controller: _controller,
                            onSubmitted: (_) => _send(),
                            maxLines: 4,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(
                              color: AppColors.primaryText,
                              fontSize: 15,
                              height: 1.45,
                            ),
                            decoration: InputDecoration(
                              hintText: _isListening
                                  ? 'Fale agora...'
                                  : 'Pergunte o que quiser...',
                              hintStyle: TextStyle(
                                color: _isListening
                                    ? AppColors.primary
                                    : AppColors.tertiaryText,
                                fontSize: 14,
                                fontWeight: _isListening
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              filled: true,
                              fillColor: AppColors.cardBackground,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(
                                  color:
                                      AppColors.border.withValues(alpha: 0.5),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(
                                  color: _isListening
                                      ? AppColors.primary
                                      : AppColors.border.withValues(alpha: 0.5),
                                  width: _isListening ? 2 : 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Botão Dinâmico
                        _buildDynamicButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Helpers e Métodos Auxiliares ---

  Widget _buildMarkdownMessage(String raw, {required bool isUser}) {
    final sanitized = raw
        .replaceAll(
            RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
        .trim();

    final baseStyle = const TextStyle(
      fontSize: 14,
      height: 1.45,
      color: AppColors.secondaryText,
    );

    return MarkdownBody(
      data: sanitized,
      selectable: false,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        strong: baseStyle.copyWith(
            fontWeight: FontWeight.bold, color: AppColors.primaryText),
        em: baseStyle.copyWith(
            fontStyle: FontStyle.italic, color: AppColors.primaryText),
        code: baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.12),
          color: AppColors.primaryText,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.6),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
              left: BorderSide(color: AppColors.primaryAccent, width: 4)),
          color: AppColors.primaryAccent.withValues(alpha: 0.08),
        ),
        blockquote: baseStyle.copyWith(fontStyle: FontStyle.italic),
        h1: baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
        h2: baseStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        h3: baseStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        listBullet: baseStyle.copyWith(color: AppColors.primaryAccent),
      ),
      onTapLink: (text, href, title) {
        if (href == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Links externos desativados: $href'),
            backgroundColor: Colors.orange));
      },
    );
  }

  String _labelFor(AssistantAction a) {
    switch (a.type) {
      case AssistantActionType.schedule:
        final d = a.date ?? a.startDate;
        String dateStr = '';
        if (d != null) {
          dateStr = _formatDateReadable(d);
          final time = _extractTimeFromTitle(a.title ?? '');
          if (time != null) {
            final hh = time.hour.toString().padLeft(2, '0');
            final mm = time.minute.toString().padLeft(2, '0');
            dateStr += ' às $hh:$mm';
          }
        }
        return '${a.title ?? 'Evento'}${dateStr.isNotEmpty ? ' – $dateStr' : ''}';
      case AssistantActionType.create_task:
        return 'Criar tarefa: ${a.title ?? ''}'.trim();
      case AssistantActionType.create_goal:
        return 'Criar meta: ${a.title ?? ''}'.trim();
      case AssistantActionType.analyze_harmony:
        return 'Analisar harmonia com ${a.title ?? 'parceiro(a)'}';
    }
  }

  String _formatDateReadable(DateTime date) {
    final now = DateTime.now();
    final months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];

    final day = date.day;
    final month = months[date.month - 1];

    if (date.year == now.year) {
      return '$day de $month';
    } else {
      return '$day de $month de ${date.year}';
    }
  }

  Widget _buildActionChip(AssistantAction action, int messageIndex) {
    Color chipColor;
    IconData chipIcon;

    switch (action.type) {
      case AssistantActionType.schedule:
        chipColor = const Color(0xFFFB923C);
        chipIcon = Icons.calendar_today;
        break;
      case AssistantActionType.create_goal:
        chipColor = const Color(0xFF06B6D4);
        chipIcon = Icons.flag_rounded;
        break;
      case AssistantActionType.create_task:
        chipColor = const Color(0xFFFB923C);
        chipIcon = Icons.check_circle_outline;
        break;
      case AssistantActionType.analyze_harmony:
        chipColor = const Color(0xFFEC4899);
        chipIcon = Icons.favorite_border;
        break;
    }

    // Define aparência baseada no estado
    final isDisabled = action.isExecuting || action.isExecuted;
    final effectiveColor = isDisabled 
        ? AppColors.secondaryText 
        : chipColor;
    final opacity = isDisabled ? 0.6 : 1.0;

    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 300),
      child: AnimatedScale(
        scale: action.isExecuting ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: isDisabled 
              ? null 
              : () => _executeAction(context, action, messageIndex: messageIndex),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: action.isExecuted
                  ? AppColors.primaryAccent.withValues(alpha: 0.1)
                  : effectiveColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: action.isExecuted
                    ? AppColors.primaryAccent.withValues(alpha: 0.4)
                    : effectiveColor.withValues(alpha: 0.4),
                width: action.isExecuted ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action.isExecuting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryText),
                    ),
                  )
                else if (action.isExecuted)
                  const Icon(Icons.check_circle, color: AppColors.primaryAccent, size: 16)
                else
                  Icon(chipIcon, color: effectiveColor, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _labelFor(action),
                    style: TextStyle(
                      color: action.isExecuted 
                          ? AppColors.primaryAccent 
                          : effectiveColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: action.isExecuted 
                          ? TextDecoration.lineThrough 
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _executeAction(BuildContext context, AssistantAction a,
      {bool fromAuto = false, int? messageIndex}) async {
    
    // Marca como "executando"
    if (messageIndex != null && messageIndex >= 0 && messageIndex < _messages.length) {
      final msg = _messages[messageIndex];
      if (msg.role == 'assistant' && msg.actions.isNotEmpty) {
        final updatedActions = msg.actions.map((action) {
          if (action == a) {
            return action.copyWith(isExecuting: true);
          }
          return action;
        }).toList();
        
        setState(() {
          _messages[messageIndex] = AssistantMessage(
            role: msg.role,
            content: msg.content,
            time: msg.time,
            actions: updatedActions,
          );
        });
      }
    }

    // Executa a ação
    await _handleAction(context, a);

    // Marca como "executado"
    if (messageIndex != null && messageIndex >= 0 && messageIndex < _messages.length) {
      final msg = _messages[messageIndex];
      if (msg.role == 'assistant' && msg.actions.isNotEmpty) {
        final updatedActions = msg.actions.map((action) {
          if (action == a) {
            return action.copyWith(isExecuting: false, isExecuted: true);
          }
          return action;
        }).toList();
        
        setState(() {
          _messages[messageIndex] = AssistantMessage(
            role: msg.role,
            content: msg.content,
            time: msg.time,
            actions: updatedActions,
          );
        });
      }
    }

    if (!mounted) return;
    
    // Adiciona mensagem de confirmação com emoji
    final confirmation = AssistantMessage(
      role: 'assistant',
      content: fromAuto
          ? '✅ Confirmado: ${_labelFor(a)}'
          : '✅ Ação executada: ${_labelFor(a)}',
      time: DateTime.now(),
    );
    setState(() {
      _messages.add(confirmation);
    });
    _firestore.addAssistantMessage(widget.userData.uid, confirmation);
    await _scrollToBottom();
  }

  Future<void> _handleAction(BuildContext context, AssistantAction a) async {
    final fs = FirestoreService();
    final user = widget.userData;
    final messenger = ScaffoldMessenger.of(context);

    if (a.type == AssistantActionType.create_task ||
        a.type == AssistantActionType.schedule) {
      final due = a.date ?? a.startDate;
      if (due == null) return;
      final utcDate = DateTime.utc(due.year, due.month, due.day);
      final time = _extractTimeFromTitle(a.title ?? '');

      final int? personalDay = _calculatePersonalDay(utcDate);

      await fs.addTask(
          user.uid,
          TaskModel(
              id: '',
              text: a.title ?? 'Evento',
              createdAt: DateTime.now().toUtc(),
              dueDate: utcDate,
              tags: const [],
              reminderTime: time,
              personalDay: personalDay));
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
          content: Text('Tarefa/evento criado com sucesso.'),
          backgroundColor: Colors.green));
    } else if (a.type == AssistantActionType.create_goal) {
      if ((a.title == null || a.title!.isEmpty) ||
          (a.description == null || a.description!.isEmpty) ||
          a.date == null) {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(
            content: Text(
                'Para criar uma meta, informe título, descrição e data alvo.'),
            backgroundColor: Colors.orange));
        return;
      }
      final target = a.date!;
      final targetUtc = DateTime.utc(target.year, target.month, target.day);
      final docRef = await fs.addGoal(user.uid, {
        'title': a.title!,
        'description': a.description!,
        'targetDate': targetUtc,
        'createdAt': DateTime.now().toUtc(),
        'subTasks':
            a.subtasks.map((t) => {'title': t, 'completed': false}).toList(),
      });
      await docRef.update({'id': docRef.id});
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text('Meta criada com sucesso!'),
          backgroundColor: Colors.green));
    } else if (a.type == AssistantActionType.analyze_harmony) {
      if (a.title == null || a.title!.isEmpty || a.date == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Dados incompletos para análise de harmonia.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      // Calcula harmonia do parceiro
      final partnerName = a.title!;
      final partnerBirthDate = DateFormat('dd/MM/yyyy').format(a.date!);
      
      final partnerEngine = NumerologyEngine(
        nomeCompleto: partnerName,
        dataNascimento: partnerBirthDate,
      );
      final partnerResult = partnerEngine.calcular();
      
      if (partnerResult == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Não foi possível calcular a numerologia do parceiro.'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      // Pega harmonia do usuário
      final userEngine = NumerologyEngine(
        nomeCompleto: user.nomeAnalise,
        dataNascimento: user.dataNasc,
      );
      final userResult = userEngine.calcular();
      
      if (userResult == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Não foi possível calcular sua numerologia.'),
          backgroundColor: Colors.red,
        ));
        return;
      }

      // Compara harmonias
      final userHarmony = userResult.estruturas['harmoniaConjugal'] as Map<String, dynamic>;
      final partnerHarmony = partnerResult.estruturas['harmoniaConjugal'] as Map<String, dynamic>;
      
      final userMissao = userResult.numeros['missao'] ?? 0;
      final partnerMissao = partnerResult.numeros['missao'] ?? 0;

      // Monta análise
      final analysis = _buildHarmonyAnalysis(
        userMissao, 
        partnerMissao, 
        userHarmony, 
        partnerHarmony,
        partnerName,
      );

      // Adiciona resposta com análise
      if (!mounted) return;
      final response = AssistantMessage(
        role: 'assistant',
        content: analysis,
        time: DateTime.now(),
      );
      setState(() {
        _messages.add(response);
      });
      _firestore.addAssistantMessage(user.uid, response);
      await _scrollToBottom();
    }
  }

  List<AssistantAction> _lastAssistantActions() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.actions.isNotEmpty) {
        return m.actions;
      }
    }
    return const [];
  }

  int? _lastAssistantMessageIndexWithActions() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.actions.isNotEmpty) return i;
    }
    return null;
  }

  bool _isAffirmative(String input) {
    final lc = input.toLowerCase().trim();
    final r = RegExp(
        r'^(sim|ok(?:ay)?|confirmo|confirma(?:r)?|pode(?: ser)?|fa(?:ça|ca)|faz|manda(?: ver| bala)?|bora|perfeito|isso(?: mesmo)?|claro|beleza)[!. ]*$',
        caseSensitive: false);
    return r.hasMatch(lc);
  }

  TimeOfDay? _extractTimeFromTitle(String title) {
    final r1 = RegExp(r'(\b|\D)([01]?\d|2[0-3]):([0-5]\d)(\b|\D)');
    final r2 = RegExp(r'(\b|\D)([01]?\d|2[0-3])h(\b|\D)', caseSensitive: false);
    final m1 = r1.firstMatch(title);
    if (m1 != null) {
      final hh = int.tryParse(m1.group(2)!);
      final mm = int.tryParse(m1.group(3)!);
      if (hh != null && mm != null) return TimeOfDay(hour: hh, minute: mm);
    }
    final m2 = r2.firstMatch(title);
    if (m2 != null) {
      final hh = int.tryParse(m2.group(2)!);
      if (hh != null) return TimeOfDay(hour: hh, minute: 0);
    }
    return null;
  }

  AssistantAction _chooseActionForAffirmative(
      String input, List<AssistantAction> actions) {
    if (actions.isEmpty) return actions.first;
    final lc = input.toLowerCase();
    final wantsChange =
        RegExp(r'(alterar|mudar|trocar|substituir|troco|mudo)').hasMatch(lc);
    final wantsKeep = RegExp(r'(manter|deixar|ficar assim|ficar)').hasMatch(lc);
    if (wantsChange && actions.length >= 2) return actions[1];
    if (wantsKeep) return actions.first;
    return actions.first;
  }

  int? _calculatePersonalDay(DateTime date) {
    final user = widget.userData;
    if (user.dataNasc.isEmpty || user.nomeAnalise.isEmpty) {
      return null;
    }

    try {
      final engine = NumerologyEngine(
        nomeCompleto: user.nomeAnalise,
        dataNascimento: user.dataNasc,
      );
      final day = engine.calculatePersonalDayForDate(date);
      return (day > 0) ? day : null;
    } catch (e) {
      return null;
    }
  }

  List<AssistantAction> _alignActionsWithAnswer(
      List<AssistantAction> actions, String answerText) {
    if (actions.isEmpty) return actions;

    final extractedDate = _extractDateFromText(answerText) ??
        _extractDateFromText(_controller.text);
    final extractedTime = _extractTimeFromText(answerText) ??
        _extractTimeFromText(_controller.text);

    if (extractedDate == null && extractedTime == null) return actions;

    return actions.map((a) {
      if (a.type == AssistantActionType.schedule ||
          a.type == AssistantActionType.create_task) {
        final newDate = a.date ?? a.startDate ?? extractedDate;
        final newTitle = _ensureTimeInTitle(a.title ?? 'Evento', extractedTime);
        return AssistantAction(
          type: a.type,
          title: newTitle,
          description: a.description,
          date: newDate,
          startDate: a.startDate,
          endDate: a.endDate,
          subtasks: a.subtasks,
        );
      }
      return a;
    }).toList();
  }

  DateTime? _extractDateFromText(String text) {
    final now = DateTime.now().toUtc();
    final rFull = RegExp(r'(\b|\D)(\d{1,2})/(\d{1,2})/(\d{4})(\b|\D)');
    final mFull = rFull.firstMatch(text);
    if (mFull != null) {
      final d = int.tryParse(mFull.group(2)!);
      final m = int.tryParse(mFull.group(3)!);
      final y = int.tryParse(mFull.group(4)!);
      if (d != null && m != null && y != null) {
        return DateTime.utc(y, m, d);
      }
    }
    final rShort = RegExp(r'(\b|\D)(\d{1,2})/(\d{1,2})(\b|\D)');
    final mShort = rShort.firstMatch(text);
    if (mShort != null) {
      final d = int.tryParse(mShort.group(2)!);
      final m = int.tryParse(mShort.group(3)!);
      if (d != null && m != null) {
        return DateTime.utc(now.year, m, d);
      }
    }
    final meses = {
      'janeiro': 1,
      'fevereiro': 2,
      'marco': 3,
      'março': 3,
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
    final rText = RegExp(
        r'(\b|\D)(\d{1,2})\s+de\s+([A-Za-zçÇãÃáÁéÉíÍóÓõÕúÚ]+)\s+de\s+(\d{4})(\b|\D)',
        caseSensitive: false);
    final mText = rText.firstMatch(text);
    if (mText != null) {
      final d = int.tryParse(mText.group(2)!);
      final monthStr = mText.group(3)!.toLowerCase();
      final y = int.tryParse(mText.group(4)!);
      final mm = meses[monthStr];
      if (d != null && mm != null && y != null) {
        return DateTime.utc(y, mm, d);
      }
    }
    final rDia = RegExp(r'dia\s+(\d{1,2})', caseSensitive: false);
    final mDia = rDia.firstMatch(text);
    if (mDia != null) {
      final d = int.tryParse(mDia.group(1)!);
      if (d != null) return DateTime.utc(now.year, now.month, d);
    }
    return null;
  }

  TimeOfDay? _extractTimeFromText(String text) {
    final r1 = RegExp(r'(\b|\D)([01]?\d|2[0-3]):([0-5]\d)(\b|\D)');
    final r2 = RegExp(r'(\b|\D)([01]?\d|2[0-3])h(\b|\D)', caseSensitive: false);
    final m1 = r1.firstMatch(text);
    if (m1 != null) {
      final hh = int.tryParse(m1.group(2)!);
      final mm = int.tryParse(m1.group(3)!);
      if (hh != null && mm != null) return TimeOfDay(hour: hh, minute: mm);
    }
    final m2 = r2.firstMatch(text);
    if (m2 != null) {
      final hh = int.tryParse(m2.group(2)!);
      if (hh != null) return TimeOfDay(hour: hh, minute: 0);
    }
    return null;
  }

  String _ensureTimeInTitle(String title, TimeOfDay? time) {
    if (time == null) return title;
    if (title.contains(':') || title.toLowerCase().contains('h')) return title;
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$title – $hh:$mm';
  }

  String _buildHarmonyAnalysis(
    int userMissao,
    int partnerMissao,
    Map<String, dynamic> userHarmony,
    Map<String, dynamic> partnerHarmony,
    String partnerName,
  ) {
    final vibra = userHarmony['vibra'] as List? ?? [];
    final atrai = userHarmony['atrai'] as List? ?? [];
    final oposto = userHarmony['oposto'] as List? ?? [];
    final passivo = userHarmony['passivo'] as List? ?? [];

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
  }
}
