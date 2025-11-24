import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';
import 'package:sincro_app_flutter/features/assistant/services/assistant_service.dart';
import 'package:sincro_app_flutter/features/assistant/services/speech_service.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/firestore_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/common/widgets/user_avatar.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/widgets/inline_goal_form.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/widgets/chat_animations.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/widgets/inline_compatibility_form.dart';

class AssistantPanel extends StatefulWidget {
  final UserModel userData;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;
  final VoidCallback? onClose;

  const AssistantPanel({
    super.key,
    required this.userData,
    this.isFullScreen = false,
    this.onToggleFullScreen,
    this.onClose,
  });

  static Future<void> show(BuildContext context, UserModel userData) async {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    if (isDesktop) {
      await showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) => AssistantPanel(userData: userData),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AssistantPanel(userData: userData),
      );
    }
  }

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
  bool _isSending = false; // Controls the "Typing..." indicator
  bool _isListening = false;
  bool _isInputEmpty = true;
  String _textBeforeListening = '';
  
  // Mobile Sheet Controller
  late DraggableScrollableController _sheetController;
  bool _isSheetExpanded = false;
  
  // Desktop Window Mode
  late bool _isWindowMode;

  // --- Animation ---
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isWindowMode = widget.isFullScreen;
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_onSheetChanged);

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

  void _onSheetChanged() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    // Consider expanded if > 0.9
    final isExpanded = size > 0.9;
    if (_isSheetExpanded != isExpanded) {
      setState(() {
        _isSheetExpanded = isExpanded;
      });
    }
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
  void didUpdateWidget(AssistantPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFullScreen != widget.isFullScreen) {
      _isWindowMode = widget.isFullScreen;
    }
  }

  @override
  void dispose() {
    _speechService.stop();
    _controller.removeListener(_updateInputState);
    _inputFocusNode.dispose();
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    _animController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Auto Scroll ---

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0.0, // Reverse list: 0.0 is the bottom
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
      _isSending = true; // Start typing animation
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
      if (mounted) setState(() => _isSending = false); // Stop typing animation
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
    return actions.first;
  }

  List<AssistantAction> _alignActionsWithAnswer(
      List<AssistantAction> actions, String answer) {
    return actions;
  }

  Future<void> _executeAction(
      BuildContext context, AssistantAction action,
      {bool fromAuto = false, int messageIndex = -1, int actionIndex = -1}) async {

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
          text: data['title'] ?? 'Nova Tarefa',
          createdAt: DateTime.now(),
          dueDate: DateTime.tryParse(data['date'] ?? '') ?? DateTime.now(),
          completed: false,
        );
        await _firestore.addTask(widget.userData.uid, newTask);
      } else if (action.type == AssistantActionType.analyze_harmony) {
        final data = action.data;
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
       if (messageIndex != -1 && messageIndex < _messages.length && actionIndex != -1) {
        setState(() {
          final msg = _messages[messageIndex];
          if (actionIndex < msg.actions.length) {
            final updatedActions = List<AssistantAction>.from(msg.actions);
            updatedActions[actionIndex] = action.copyWith(isExecuting: false);
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
        } catch (e) {
          try {
            dob = DateFormat('d/M/yyyy').parse(partnerDob);
          } catch (e2) {
            // ignore
          }
        }
      } else if (partnerDob.contains('-')) {
        dob = DateTime.tryParse(partnerDob);
      }

      if (dob == null) {
        return "❌ Data de nascimento inválida para análise. Por favor, forneça no formato DD/MM/AAAA (ex: 31/05/1991).";
      }

      final formattedDobForEngine = DateFormat('dd/MM/yyyy').format(dob);

      final partnerNumerology = NumerologyEngine(
        nomeCompleto: partnerName.trim(),
        dataNascimento: formattedDobForEngine,
      ).calcular();

      final userNumerology = NumerologyEngine(
        nomeCompleto: widget.userData.nomeAnalise,
        dataNascimento: widget.userData.dataNasc,
      ).calcular();

      if (userNumerology == null || partnerNumerology == null) {
        return "❌ Não foi possível calcular a numerologia para a análise. Verifique os dados.";
      }

      final userMissao = userNumerology.numeros['missao'] as int? ?? 0;
      final partnerMissao = partnerNumerology.numeros['missao'] as int? ?? 0;

      final userHarmony = userNumerology.estruturas['harmoniaConjugal'] as Map<String, dynamic>? ?? {};

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

    } catch (e) {
      return "Erro ao calcular harmonia: $e";
    }
  }

  // --- Goal Form Handling ---

  Future<void> _handleGoalFormSubmit(Goal goal, int messageIndex) async {
    try {
      // 1. Gerar ID e Salvar a meta
      final docRef = FirebaseFirestore.instance.collection('users').doc(widget.userData.uid).collection('goals').doc();
      final goalId = docRef.id;
      
      // Cria a meta com o ID gerado e SEM as subtasks internas (pois serão salvas como Tasks externas)
      // Mas mantemos subTasks no objeto local para iterar abaixo
      final goalToSave = goal.copyWith(id: goalId, subTasks: []);
      
      await docRef.set(goalToSave.toFirestore());

      // 2. Salvar os marcos como Tarefas
      final firestoreService = FirestoreService();
      int addedCount = 0;
      for (final subTask in goal.subTasks) {
        final newTask = TaskModel(
          id: '', // Será gerado pelo addTask
          text: subTask.title,
          completed: false,
          createdAt: DateTime.now(),
          dueDate: goal.targetDate, // Usa a data da meta como sugestão
          journeyId: goalId,
          journeyTitle: goal.title,
          goalId: goalId,
        );
        await firestoreService.addTask(widget.userData.uid, newTask);
        addedCount++;
      }

      // 3. Atualizar UI
      setState(() {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          actions: _messages[messageIndex].actions.map((a) {
            if (a.type == AssistantActionType.create_goal) {
              return a.copyWith(isExecuted: true);
            }
            return a;
          }).toList(),
        );
        
        // Adicionar mensagem de confirmação
        _messages.insert(0, AssistantMessage(
          text: 'Jornada "${goal.title}" criada com sucesso! 🚀\nAdicionei $addedCount marcos à sua lista de tarefas.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      
      await _scrollToBottom();

    } catch (e) {
      debugPrint('Erro ao salvar meta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar jornada: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCompatibilityFormSubmit(String partnerName, DateTime partnerDob, int messageIndex) async {
    try {
      // 1. Calculate Partner's Numerology
      final partnerEngine = NumerologyEngine(
        nomeCompleto: partnerName,
        dataNascimento: DateFormat('dd/MM/yyyy').format(partnerDob),
      );
      final partnerProfile = partnerEngine.calculateProfile();

      // 2. Get User's Numerology
      final user = widget.userData;
      NumerologyResult? userNumerology;
      if (user.nomeAnalise.isNotEmpty && user.dataNasc.isNotEmpty) {
        userNumerology = NumerologyEngine(
                nomeCompleto: user.nomeAnalise, dataNascimento: user.dataNasc)
            .calculateProfile();
      }
      userNumerology ??= NumerologyEngine(
              nomeCompleto: 'Indefinido', dataNascimento: '1900-01-01')
          .calculateProfile();

      // 3. Check Compatibility
      final userHarmonia = userNumerology.numeros['harmoniaConjugal'] ?? 0;
      final partnerHarmonia = partnerProfile.numeros['harmoniaConjugal'] ?? 0;
      final compatibility = NumerologyEngine.checkCompatibility(userHarmonia, partnerHarmonia);

      // 4. Update message to mark action as executed and add confirmation
      if (messageIndex < _messages.length) {
        setState(() {
          final msg = _messages[messageIndex];
          final updatedActions = msg.actions.map((action) {
            if (action.type == AssistantActionType.analyze_compatibility) {
              return action.copyWith(
                isExecuted: true,
                needsUserInput: false,
              );
            }
            return action;
          }).toList();
          _messages[messageIndex] = msg.copyWith(actions: updatedActions);

          // Add confirmation message
          _messages.add(AssistantMessage(
            role: 'assistant',
            content: '💘 **Análise de Compatibilidade Iniciada!**\n\n🔮 Analisando a harmonia entre você e **$partnerName**...\n\n📊 Status: **${compatibility['status']}**\n\nAguarde a análise completa!',
            time: DateTime.now(),
          ));
        });

        await _scrollToBottom();
      }

      // 5. Start typing animation for full analysis
      setState(() => _isSending = true);

      // 6. Construct Prompt
      final prompt = '''
Realize uma ANÁLISE DE COMPATIBILIDADE AMOROSA/AFINIDADE detalhada entre:

USUÁRIO: ${user.primeiroNome}
- Harmonia Conjugal: $userHarmonia
- Destino: ${userNumerology.numeros['destino']}
- Expressão: ${userNumerology.numeros['expressao']}
- Motivação: ${userNumerology.numeros['motivacao']}
- Dia Pessoal: ${userNumerology.numeros['diaPessoal']}

PARCEIRO(A): $partnerName (Nasc: ${DateFormat('dd/MM/yyyy').format(partnerDob)})
- Harmonia Conjugal: $partnerHarmonia
- Destino: ${partnerProfile.numeros['destino']}
- Expressão: ${partnerProfile.numeros['expressao']}
- Motivação: ${partnerProfile.numeros['motivacao']}
- Dia Pessoal: ${partnerProfile.numeros['diaPessoal']}

RESULTADO DA HARMONIA CONJUGAL:
- Status: ${compatibility['status']}
- Descrição Técnica: ${compatibility['descricao']}

INSTRUÇÕES:
1. Explique o que significa a Harmonia Conjugal de cada um.
2. Analise a compatibilidade baseada no Status acima (Vibram Juntos, Atração, Opostos, etc.).
3. Se forem OPOSTOS, explique que podem dar certo com sabedoria.
4. Se forem IGUAIS, alerte sobre a monotonia (exceto 5).
5. Use também os outros números (Destino, Expressão) para complementar a análise.
6. Seja empático, construtivo e use emojis.
''';

      // 7. Fetch Context
      final tasks = await _firestore.getRecentTasks(user.uid, limit: 30);
      final goals = await _firestore.getActiveGoals(user.uid);
      final recentJournal = await _firestore.getJournalEntriesForMonth(user.uid, DateTime.now());

      // 8. Ask AI
      final ans = await AssistantService.ask(
        question: prompt,
        user: user,
        numerology: userNumerology,
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
              content: 'Desculpe, não consegui realizar a análise agora. Tente novamente mais tarde.\n\n$e',
              time: DateTime.now()));
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
      await _scrollToBottom();
    }
  }

  // --- UI Components ---

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AnimatedMessageBubble(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedAvatar(
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: SvgPicture.asset(
                  'assets/images/icon-ia-sincroapp-branco-v1.svg',
                ),
              ),
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
              child: const TypingIndicator(
                color: AppColors.primary,
                dotSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(AssistantAction action, int messageIndex, int actionIndex, bool anyActionExecuted) {
    final isExecuted = action.isExecuted;
    final isExecuting = action.isExecuting;
    final isDisabled = isExecuted || isExecuting || anyActionExecuted;

    String label = action.title ?? 'Ação';
    if (action.date != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final actionDate = DateTime(action.date!.year, action.date!.month, action.date!.day);
      String dateStr = actionDate.isAtSameMomentAs(today)
          ? 'Hoje'
          : DateFormat('dd/MM', 'pt_BR').format(action.date!);
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
                  ? AppColors.border.withValues(alpha: 0.3)
                  : AppColors.cardBackground, // Fundo mais sutil (card background)
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExecuted
                ? AppColors.success
                : isDisabled
                    ? Colors.transparent
                    : AppColors.primary, // Borda mais visível (cor primária sólida)
            width: 1.5, // Borda um pouco mais espessa
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                          : Colors.white.withOpacity(0.9), // Texto mais claro e com contraste
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  decoration: isExecuted ? TextDecoration.lineThrough : TextDecoration.none, // Garante sem sublinhado
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
    final anyActionExecuted = m.actions.any((a) => a.isExecuted || a.isExecuting);

    // Use a unique key based on time to preserve state and animations
    return Padding(
      key: ValueKey(m.time.toString()),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 1. Main Content (Avatar + Text)
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end, // Avatar na parte inferior
            children: [
              if (!isUser) ...[
                // AI Avatar - Static (no animation) because it was already there during typing
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    'assets/images/icon-ia-sincroapp-branco-v1.svg',
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: isUser
                    ? AnimatedMessageBubble( // User message still slides in
                        duration: const Duration(milliseconds: 400),
                        child: _buildMessageBubbleContent(m, isUser),
                      )
                    : MorphingMessageBubble( // AI message morphs from typing size
                        duration: const Duration(milliseconds: 600),
                        child: _buildMessageBubbleContent(m, isUser),
                      ),
              ),
              if (isUser) ...[
                const SizedBox(width: 12),
                AnimatedAvatar(
                  child: UserAvatar(
                    firstName: widget.userData.primeiroNome,
                    lastName: widget.userData.sobrenome,
                    photoUrl: widget.userData.photoUrl,
                    radius: 20,
                  ),
                ),
              ],
            ],
          ),
          
          // 2. Actions (Form or Chips) - Enters with delay
          // Check if there's a create_goal action that needs user input (show form)
          if (!isUser && m.actions.any((a) => a.type == AssistantActionType.create_goal && a.needsUserInput && !a.isExecuted))
            AnimatedMessageBubble(
              delay: const Duration(milliseconds: 1000), // Wait for text morph (600ms) + buffer
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 40 + 12), 
                    Expanded(
                      child: InlineGoalForm(
                        userData: widget.userData,
                        prefilledTitle: m.actions.firstWhere((a) => a.type == AssistantActionType.create_goal).title,
                        prefilledDescription: m.actions.firstWhere((a) => a.type == AssistantActionType.create_goal).description,
                        prefilledTargetDate: m.actions.firstWhere((a) => a.type == AssistantActionType.create_goal).date,
                        prefilledSubtasks: m.actions.firstWhere((a) => a.type == AssistantActionType.create_goal).subtasks,
                        onSave: (goal) => _handleGoalFormSubmit(goal, index),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Check if there's a compatibility analysis action (show form)
          else if (!isUser && m.actions.any((a) => a.type == AssistantActionType.analyze_compatibility && !a.isExecuted))
             AnimatedMessageBubble(
              delay: const Duration(milliseconds: 1000), // Wait for text morph (600ms) + buffer
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // AI Avatar for compatibility form
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: SvgPicture.asset(
                        'assets/images/icon-ia-sincroapp-branco-v1.svg',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InlineCompatibilityForm(
                        userData: widget.userData,
                        onAnalyze: (name, dob) => _handleCompatibilityFormSubmit(name, dob, index),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Otherwise show action chips
          else if (!isUser && m.actions.isNotEmpty)
            // Only animate if there are non-executed actions
            // If all actions are executed (chips are confirmation/summary), show without animation
            anyActionExecuted
                ? Padding(
                    padding: const EdgeInsets.only(left: 44, top: 12),
                    child: Wrap(
                      spacing: 8, runSpacing: 8,
                      children: m.actions.asMap().entries.map((entry) {
                        return _buildActionChip(entry.value, index, entry.key, anyActionExecuted);
                      }).toList(),
                    ),
                  )
                : AnimatedMessageBubble(
                    delay: const Duration(milliseconds: 1000), // Wait for text morph (600ms) + buffer
                    child: Padding(
                      padding: const EdgeInsets.only(left: 44, top: 12),
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: m.actions.asMap().entries.map((entry) {
                          return _buildActionChip(entry.value, index, entry.key, anyActionExecuted);
                        }).toList(),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildMessageBubbleContent(AssistantMessage m, bool isUser) {
    return Container(
      margin: isUser
          ? (MediaQuery.of(context).size.width > 700 ? const EdgeInsets.only(left: 40.0) : null)
          : (MediaQuery.of(context).size.width > 700 ? const EdgeInsets.only(right: 40.0) : null),
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
    );
  }

  // --- Main Layout ---

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    if (!isDesktop && !widget.isFullScreen) {
      // Mobile Modal Mode
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: 0.5,
          minChildSize: 0.0, // Allow closing
          maxChildSize: 1.0, // Allow full screen
          snap: true,
          snapSizes: const [0.5, 1.0], 
          builder: (context, scrollController) {
            return _buildPanelContent(context, sheetScrollController: scrollController, isModal: true);
          },
        ),
      );
    }

    // Desktop Modal / FullScreen / Mobile FullScreen
    return _buildPanelContent(context, isModal: !widget.isFullScreen);
  }

  Widget _buildPanelContent(BuildContext context, {ScrollController? sheetScrollController, required bool isModal}) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final screenSize = MediaQuery.of(context).size;
    
    // Desktop Sizing Logic
    double? width;
    double? height;
    
    if (isDesktop) {
      if (_isWindowMode) {
        // "Large Floating Modal" - Window Mode (Widescreen)
        width = 1200;
        height = 600;
      } else {
        // "Normal Floating Modal"
        width = 600;
        height = 550;
      }
      
      // Clamp to screen size
      if (width > screenSize.width - 40) width = screenSize.width - 40;
      if (height > screenSize.height - 40) height = screenSize.height - 40;
    }

    // Border Radius Logic
    BorderRadiusGeometry borderRadius;
    if (isDesktop) {
      if (_isWindowMode) {
        borderRadius = BorderRadius.circular(24); // All rounded for Window Mode
      } else {
        borderRadius = const BorderRadius.vertical(top: Radius.circular(24)); // Top rounded for Normal Mode
      }
    } else {
      // Mobile
      if (_isSheetExpanded) {
        borderRadius = BorderRadius.zero;
      } else {
        borderRadius = const BorderRadius.vertical(top: Radius.circular(24));
      }
    }

    final panelContent = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: width,
      height: height,
      clipBehavior: Clip.hardEdge, // Ensure children don't overflow rounded corners
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: borderRadius,
        boxShadow: isModal || isDesktop
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header
          // If modal, wrap header in a ListView with the sheet controller to enable dragging
          if (isModal && sheetScrollController != null)
            SizedBox(
              height: 70, // Fixed height for header area
              child: ListView(
                controller: sheetScrollController,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(), // Prevent overscroll glow
                children: [
                  _buildHeader(isModal, isDesktop),
                ],
              ),
            )
          else
            _buildHeader(isModal, isDesktop),
          
          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Always use internal controller for chat
              reverse: true,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isSending && index == 0) {
                  return _buildTypingIndicator();
                }
                final msgIndex = _isSending ? index - 1 : index;
                final actualMsg = _messages[_messages.length - 1 - msgIndex];
                final originalIndex = _messages.length - 1 - msgIndex;
                return _buildMessageItem(actualMsg, originalIndex);
              },
            ),
          ),

          // Input Area
          _buildInputArea(),
        ],
      ),
    );

    if (isDesktop) {
      // Center the panel on Desktop and handle outside clicks
      return GestureDetector(
        onTap: () {
          // Close on outside click
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
             Navigator.of(context).pop();
          }
        },
        behavior: HitTestBehavior.opaque, // Catch all clicks
        child: Container(
          height: screenSize.height,
          width: screenSize.width,
          color: Colors.transparent,
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: _isWindowMode ? Alignment.center : Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // Consume clicks on the panel itself
              child: panelContent,
            ),
          ),
        ),
      );
    }

    return panelContent;
  }

  Widget _buildHeader(bool isModal, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle (Mobile Only)
          if (isModal && !isDesktop && !_isSheetExpanded)
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Row(
            children: [
              SvgPicture.asset(
                'assets/images/icon-ia-sincroapp-v1.svg',
                width: 32,
                height: 32,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sincro IA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              
              // --- Desktop Buttons ---
              
              // Window Mode Toggle (Desktop Only)
              if (isDesktop)
                IconButton(
                  icon: Icon(
                    _isWindowMode ? Icons.close_fullscreen_rounded : Icons.open_in_new_rounded,
                    color: AppColors.secondaryText,
                  ),
                  onPressed: () {
                    setState(() {
                      _isWindowMode = !_isWindowMode;
                    });
                    if (widget.onToggleFullScreen != null) {
                      widget.onToggleFullScreen!();
                    }
                  },
                  tooltip: _isWindowMode ? 'Restaurar Tamanho' : 'Modo Janela',
                ),
              
              // Close Button (Always Visible on Desktop, or Mobile Modal)
              if (isDesktop || isModal)
                 IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText),
                  onPressed: () {
                     if (widget.onClose != null) {
                        widget.onClose!();
                      } else if (!isDesktop && isModal) {
                        // Mobile internal close logic
                        _sheetController.animateTo(
                          0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        // Desktop default close
                        Navigator.of(context).pop();
                      }
                  },
                  tooltip: 'Fechar',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end, // Align bottom for multiline
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Added vertical padding
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _inputFocusNode,
                maxLines: 5, // Allow up to 5 lines
                minLines: 1,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Como posso ajudar hoje?',
                  border: InputBorder.none,
                  isDense: true, // Compact layout
                  hintStyle: TextStyle(color: AppColors.secondaryText),
                ),
                onSubmitted: (_) => _send(), // Note: onSubmitted might not trigger with multiline + enter
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildDynamicButton(),
        ],
      ),
    );
  }

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


}


