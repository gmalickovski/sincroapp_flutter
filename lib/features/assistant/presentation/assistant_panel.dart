import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/widgets/chat_animations.dart'; // Chat Animations
import 'package:sincro_app_flutter/common/parser/task_parser.dart';
import 'package:sincro_app_flutter/common/parser/parser_popup.dart';
import 'package:sincro_app_flutter/features/assistant/presentation/widgets/action_proposal_bubble.dart'; // Action Bubble
import 'package:sincro_app_flutter/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // NEW: For direct Supabase calls
import 'package:sincro_app_flutter/features/assistant/services/speech_service.dart';
import 'package:sincro_app_flutter/services/harmony_service.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/assistant/services/n8n_service.dart';
import 'package:sincro_app_flutter/features/assistant/services/assistant_service.dart';
import 'package:uuid/uuid.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart'; // Task Model
import 'package:sincro_app_flutter/models/recurrence_rule.dart'; // RecurrenceType enum
import 'package:sincro_app_flutter/features/tasks/presentation/widgets/task_detail_modal.dart'; // NOVO: Task Detail Modal
import 'package:sincro_app_flutter/common/widgets/vibration_pill.dart'; // Vibration Pill for dynamic colors
import 'package:sincro_app_flutter/features/assistant/presentation/widgets/agent_star_icon.dart'; // Animated Icon

class AssistantPanel extends StatefulWidget {
  final UserModel userData;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;
  final VoidCallback? onClose;
  final String? initialMessage;
  final ScrollController? sheetScrollController;

  const AssistantPanel({
    super.key,
    required this.userData,
    this.isFullScreen = false,
    this.onToggleFullScreen,
    this.onClose,
    this.initialMessage,
    this.sheetScrollController,
    this.numerologyData, // Received from Dashboard
    this.activeContext, // New: Active Tab Name
  });

  final NumerologyResult? numerologyData;
  final String? activeContext;

  static Future<void> show(BuildContext context, UserModel userData,
      {String? initialMessage}) async {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    if (isDesktop) {
      await showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) =>
            AssistantPanel(userData: userData, initialMessage: initialMessage),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true, // Use root navigator to cover FAB
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 1.0, // Start at full screen
          minChildSize: 0.9,
          maxChildSize: 1.0,
          builder: (_, controller) => AssistantPanel(
              userData: userData,
              initialMessage: initialMessage,
              sheetScrollController: controller),
        ),
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
  final _supabase = SupabaseService();
  final _speechService = SpeechService();
  final _harmonyService = HarmonyService();
  final _inputFocusNode = FocusNode();
  final Set<String> _animatedMessageIds = {};

  // --- State Variables ---
  String? _currentConversationId; // Tracks active conversation
  List<AssistantMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isListening = false;
  bool _isInputEmpty = true;
  String _textBeforeListening = '';

  // Mentions State
  OverlayEntry? _mentionsOverlay;
  List<ParserSuggestion> _mentionCandidates = [];
  ParserKeyType _activeKeyType = ParserKeyType.mention;

  // Mobile Sheet Controller (if needed internally, but we use scroll controller passed in)
  late DraggableScrollableController _sheetController;
  final bool _isSheetExpanded = false; // Internal tracking

  // N8N Service
  final N8nService _n8nService = N8nService(); // Use singleton or provider

  @override
  void initState() {
    super.initState();
    _sheetController =
        DraggableScrollableController(); // Fix: Initialize to prevent late error on dispose
    _loadHistory();
    _speechService.init();

    _controller.addListener(_updateInputState); // Existing listener
    _controller.addListener(_checkMentions); // 🚀 New Listener for Mentions

    // Initial Message logic...
  }

  @override
  void dispose() {
    _hideMentionsOverlay(); // Cleanup
    _controller.removeListener(_updateInputState);
    _controller.removeListener(_checkMentions);
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _updateInputState() {
    setState(() {
      _isInputEmpty = _controller.text.trim().isEmpty;
    });
  }

  // --- Mentions Logic ---
  void _checkMentions() {
    final text = _controller.text;
    final selection = _controller.selection;

    // Only check if cursor is valid
    if (selection.baseOffset < 0) {
      _hideMentionsOverlay();
      return;
    }

    // Find the word being typed at cursor
    final cursorIndex = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorIndex);

    // Regex to find the last token starting with @ or !
    // Matches whitespace/start + (@ or !) + characters until cursor
    final regex = RegExp(r'(?:\s|^)([@!][a-zA-Z0-9_À-ÿ]*)$');
    final match = regex.firstMatch(textBeforeCursor);

    if (match != null) {
      final token = match.group(1)!; // e.g., "@ali" or "!"
      final prefix = token[0]; // '@' or '!'
      final query = token.substring(1).toLowerCase(); // "ali"

      _fetchCandidates(prefix, query);
    } else {
      _hideMentionsOverlay();
    }
  }

  void _fetchCandidates(String prefix, String query) async {
    List<ParserSuggestion> results = [];
    ParserKeyType keyType;

    if (prefix == '@') {
      keyType = ParserKeyType.mention;
      // Mock Contacts - Replace with real ContactService later
      final allContacts = [
        const ParserSuggestion(
            id: '1',
            label: '@Alice',
            type: ParserKeyType.mention,
            description: 'Designer'),
        const ParserSuggestion(
            id: '2',
            label: '@Bob',
            type: ParserKeyType.mention,
            description: 'Developer'),
        const ParserSuggestion(
            id: '3',
            label: '@Carol',
            type: ParserKeyType.mention,
            description: 'Manager'),
      ];
      results = allContacts
          .where((c) => c.label.toLowerCase().contains(query))
          .toList();
    } else if (prefix == '!') {
      keyType = ParserKeyType.goal;
      // Mock Goals - Replace with real GoalService later
      final allGoals = [
        const ParserSuggestion(
            id: 'g1',
            label: '!Marathon',
            type: ParserKeyType.goal,
            description: 'Run 42km'),
        const ParserSuggestion(
            id: 'g2',
            label: '!Website',
            type: ParserKeyType.goal,
            description: 'Launch Site'),
        const ParserSuggestion(
            id: 'g3',
            label: '!Meditation',
            type: ParserKeyType.goal,
            description: 'Daily Practice'),
      ];
      results =
          allGoals.where((c) => c.label.toLowerCase().contains(query)).toList();
    } else {
      keyType = ParserKeyType.tag;
    }

    _activeKeyType = keyType;
    if (results.isNotEmpty) {
      _showMentionsOverlay(results);
    } else {
      _hideMentionsOverlay();
    }
  }

  void _showMentionsOverlay(List<ParserSuggestion> candidates) {
    _mentionCandidates = candidates;

    if (_mentionsOverlay != null) {
      // Just rebuild/update if already showing
      _mentionsOverlay!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _mentionsOverlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 16,
        right: 16,
        child: ParserPopup(
          suggestions: _mentionCandidates,
          activeType: _activeKeyType,
          onSelected: (suggestion) {
            _applyMention(suggestion);
          },
        ),
      ),
    );

    overlay.insert(_mentionsOverlay!);
  }

  void _hideMentionsOverlay() {
    _mentionsOverlay?.remove();
    _mentionsOverlay = null;
  }

  void _applyMention(ParserSuggestion suggestion) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorIndex = selection.baseOffset;

    // Find start of token again
    final textBeforeCursor = text.substring(0, cursorIndex);
    final regex = RegExp(r'(?:\s|^)([@!][a-zA-Z0-9_À-ÿ]*)$');
    final match = regex.firstMatch(textBeforeCursor);

    if (match != null) {
      final tokenStart =
          match.start + (match.group(0)!.startsWith(' ') ? 1 : 0);
      final tokenEnd = cursorIndex;

      final newText =
          text.replaceRange(tokenStart, tokenEnd, "${suggestion.label} ");
      _controller.text = newText;

      // Move cursor to end of inserted mention
      _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: tokenStart + suggestion.label.length + 1));
    }

    _hideMentionsOverlay();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch recent conversations
      final conversations =
          await AssistantService.fetchConversations(widget.userData.uid);
      if (conversations.isNotEmpty) {
        // 2. Load the most recent one
        final lastConv = conversations.first;
        _currentConversationId = lastConv.id;
        final msgs = await AssistantService.fetchMessages(
            widget.userData.uid, lastConv.id);
        setState(() {
          _messages = msgs;
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsgId = const Uuid().v4();
    final userMsg = AssistantMessage(
      id: userMsgId,
      content: text,
      role: 'user',
      time: DateTime.now(),
    );

    setState(() {
      _messages.insert(0, userMsg); // Reverse list
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Persist User Message (Create conversation if needed)
    if (_currentConversationId == null) {
      // Generate title from message (truncated)
      final title = text.length > 30 ? "${text.substring(0, 30)}..." : text;
      _currentConversationId =
          await AssistantService.createConversation(widget.userData.uid, title);
    }

    // Log message linked to conversation
    AssistantService.saveMessage(
        widget.userData.uid, userMsg, _currentConversationId);

    try {
      // 1. Call AssistantService (Wrapper that handles Context & Logic)
      final answer = await AssistantService.ask(
        question: text,
        user: widget.userData,
        numerology: widget.numerologyData ??
            NumerologyEngine(
                    nomeCompleto: widget.userData.nomeAnalise.isNotEmpty
                        ? widget.userData.nomeAnalise
                        : "${widget.userData.primeiroNome} ${widget.userData.sobrenome}",
                    dataNascimento: widget.userData.dataNasc)
                .calculateProfile(),
        tasks: [], // TODO: Inject TaskProvider or similar
        goals: [], // TODO: Inject GoalProvider
        recentJournal: [], // TODO: Inject JournalProvider
        activeContext: widget.activeContext, // Pass context
      );

      final assistantMsg = AssistantMessage(
        id: const Uuid().v4(),
        content: answer.answer, // The text response
        role: 'assistant',
        time: DateTime.now(),
        actions: answer.actions, // Pass actions
        embeddedTasks:
            answer.embeddedTasks, // NOVO: Passar tasks para renderizar
      );

      if (mounted) {
        setState(() {
          _messages.insert(0, assistantMsg);
        });

        // Persist Assistant Message
        await AssistantService.saveMessage(
            widget.userData.uid, assistantMsg, _currentConversationId);

        // Handle Actions (Navigations, Creations) if any
        if (answer.actions.isNotEmpty) {
          // TODO: Implement Action Handler
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _send() {
    _sendMessage(_controller.text);
  }

  void _handleActionConfirm(
      AssistantAction action, DateTime selectedDate) async {
    // Determine Action Type
    // For now, assume 'propose_task' implies creating a task
    try {
      final payload = action.data['payload'] as Map<String, dynamic>? ?? {};
      final title =
          action.title ?? payload['title'] as String? ?? 'Nova Tarefa';

      // Calculate Personal Day for the selected date
      final personalDay = NumerologyEngine.calculatePersonalDay(
          selectedDate, widget.userData.dataNasc);

      // Create TaskModel
      final newTask = TaskModel(
        id: const Uuid().v4(),
        text: title,
        completed: false,
        createdAt: DateTime.now(),
        dueDate: selectedDate,
        personalDay: personalDay, // 🚀 Vibration Pill Logic
        tags:
            (payload['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );

      debugPrint("Creating Task: ${newTask.text} at $selectedDate");

      // Real Persistence Call
      await SupabaseService().addTask(widget.userData.uid, newTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Agendado para ${DateFormat('d/MM HH:mm').format(selectedDate)}'),
            backgroundColor: AppColors.success,
          ),
        );

        // Update UI State (Mark executed & Persist Selected Date)
        setState(() {
          for (var msg in _messages) {
            final index = msg.actions.indexOf(action);
            if (index != -1) {
              msg.actions[index] = action.copyWith(
                isExecuted: true,
                date: selectedDate, // Update to show what was picked
              );
              break;
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error executing action: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    // With reverse list, scroll to 0
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // --- Speech Logic ---
  void _onMicPressed() async {
    if (!_isListening) {
      bool available = await _speechService.init();
      if (available) {
        setState(() {
          _isListening = true;
          _textBeforeListening = _controller.text;
        });
        _speechService.start(
          onResult: (text) {
            if (mounted) {
              _controller.text = "$_textBeforeListening $text"; // Append
            }
          },
        );
      } else {
        // Show error
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() async {
    await _speechService.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Determine scroll controller to use
    final scrollCtrl = widget.sheetScrollController ?? _scrollController;
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final isModal = !isDesktop;

    return Material(
      color: Colors.transparent, // Root is transparent for "floating" effect
      child: Stack(
        children: [
          // 1. Messages Layer (Behind Header/Footer)
          Positioned.fill(
            child: Container(
              color: AppColors.background, // Base solid background
              child: ListView.builder(
                controller: scrollCtrl,
                reverse: true,
                // Add padding to avoid content being hidden behind fixed Header and Input
                // Header is ~90, Input ~80. Adding extra breathing room.
                padding: const EdgeInsets.fromLTRB(16, 110, 16, 100),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  bool shouldAnimate = !_animatedMessageIds.contains(msg.id);
                  if (shouldAnimate) _animatedMessageIds.add(msg.id);

                  return ChatMessageItem(
                    message: msg,
                    isUser: msg.isUser,
                    animate: shouldAnimate,
                    onActionConfirm: _handleActionConfirm,
                    onActionCancel: (action) {
                      debugPrint("Action cancelled: ${action.type}");
                    },
                    userData: widget.userData,
                  );
                },
              ),
            ),
          ),

          // 2. Header (Top Overlay)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(isModal, isDesktop),
          ),

          // 3. Input (Bottom Overlay)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInputArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isModal, bool isDesktop) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.background.withValues(alpha: 0.7),
          ],
        ),
        border: const Border(bottom: BorderSide(color: Colors.transparent)),
      ),
      child: SafeArea(
        // Ensure it doesn't clip on notches
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center items vertically
            children: [
              // 1. Floating Animated Star
              const AgentStarIcon(
                size: 50,
                mode: AgentStarMode.dashboard,
                isStatic: false,
                isHollow: false,
                slowAnimation: true,
              ),

              const SizedBox(width: 8),

              // 2. Dynamic Bubble (Flexible)
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: (_messages.isEmpty && !_isSending)
                      ? Container(
                          key: const ValueKey('idle_greeting'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12).copyWith(
                              bottomLeft: const Radius.circular(0),
                            ),
                            border: Border.all(
                                color: AppColors.primary, width: 1.5),
                          ),
                          child: const Text(
                            "Olá, eu sou o Sincro IA, como posso te ajudar hoje?",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            softWrap: true, // Allow wrapping
                          ),
                        )
                      : ConstrainedBox(
                          key: const ValueKey('active_title'),
                          constraints: const BoxConstraints(minHeight: 48),
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Sincro IA",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 16), // Gap between bubble and buttons

              // 3. Right Controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_comment_rounded,
                        color: AppColors.secondaryText),
                    onPressed: () {
                      if (!_isSending) {
                        setState(() {
                          _messages.clear();
                          _animatedMessageIds.clear();
                          _currentConversationId = null; // Start Fresh
                        });
                      }
                    },
                    tooltip: 'Nova Conversa',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.history_rounded,
                        color: AppColors.secondaryText),
                    onPressed: _showHistory,
                    tooltip: 'Histórico',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.secondaryText),
                    onPressed: widget.onClose ??
                        () => Navigator.of(context, rootNavigator: true).pop(),
                    tooltip: isDesktop ? 'Recolher Painel' : 'Fechar',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Histórico de Conversas",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: AppColors.secondaryText),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                fit: FlexFit.tight,
                child: FutureBuilder<List<AssistantConversation>>(
                  future:
                      AssistantService.fetchConversations(widget.userData.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("Nenhuma conversa recente.",
                            style: TextStyle(color: AppColors.secondaryText)),
                      );
                    }

                    final conversations = snapshot.data!;

                    return ListView.separated(
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final formattedDate =
                            DateFormat('dd/MM HH:mm').format(conv.createdAt);
                        final isSelected = conv.id == _currentConversationId;

                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: ListTile(
                            leading: Icon(Icons.chat_bubble_outline,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.secondaryText,
                                size: 20),
                            title: Text(
                              conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                            subtitle: Text(
                              formattedDate,
                              style: const TextStyle(
                                  color: AppColors.secondaryText, fontSize: 12),
                            ),
                            onTap: () async {
                              Navigator.pop(context); // Close dialog
                              if (conv.id == _currentConversationId) return;

                              setState(() {
                                _isLoading = true;
                                _currentConversationId = conv.id;
                              });

                              try {
                                final msgs =
                                    await AssistantService.fetchMessages(
                                        widget.userData.uid, conv.id);
                                if (mounted) {
                                  setState(() {
                                    _messages = msgs;
                                    _isLoading = false;
                                  });
                                }
                              } catch (e) {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      key: const ValueKey('typing_indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12).copyWith(
          topLeft: const Radius.circular(0),
        ),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Pensando",
            style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
          ),
          SizedBox(width: 4),
          TypingIndicator(color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.background,
            AppColors.background.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _inputFocusNode.hasFocus
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.2),
                        blurRadius: _inputFocusNode.hasFocus ? 16 : 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                    border: Border.all(
                      color: _inputFocusNode.hasFocus
                          ? AppColors.primary.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.1),
                      width: _inputFocusNode.hasFocus ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _inputFocusNode,
                          maxLines: 5,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          obscureText: false,
                          enableSuggestions: true,
                          autocorrect: true,
                          autofillHints: const [], // Prevent browser password save prompt
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: 'Pergunte sobre sua energia...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                            hintStyle: TextStyle(color: Colors.white30),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap:
                    _isInputEmpty ? _onMicPressed : (_isSending ? null : _send),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    gradient: _isListening
                        ? const LinearGradient(
                            colors: [Colors.redAccent, Colors.red])
                        : const LinearGradient(colors: [
                            AppColors.primary,
                            AppColors.primaryAccent
                          ]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening
                                ? Colors.red
                                : AppColors.primaryAccent)
                            .withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Icon(
                            _isInputEmpty
                                ? (_isListening ? Icons.stop : Icons.mic)
                                : Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Chat Widgets ---

class ChatMessageItem extends StatelessWidget {
  final AssistantMessage message;
  final bool isUser;
  final bool animate;
  final Function(AssistantAction, DateTime) onActionConfirm;
  final Function(AssistantAction) onActionCancel;
  final UserModel? userData; // NOVO: Para abrir TaskDetailModal

  const ChatMessageItem({
    super.key,
    required this.message,
    required this.isUser,
    this.animate = false,
    required this.onActionConfirm,
    required this.onActionCancel,
    this.userData, // NOVO
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Se tem tasks, exibe tudo em um único balão (texto + tasks)
        if (!isUser && message.hasTasks)
          _buildTaskListBubble(context)
        else
          _buildBubble(context),
        // Mostrar ActionProposalBubble SOMENTE para propose_task/create_task, NÃO para task_list
        if (!isUser && message.actions.isNotEmpty && !message.hasTasks)
          ...message.actions.map((action) {
            final typeStr = action.type.toString();
            final actionType = action.data['type']?.toString() ?? '';
            // Ignorar task_list - já exibido visualmente acima
            if (actionType == 'task_list') return const SizedBox.shrink();

            final isProposal = typeStr.contains('propose_task') ||
                typeStr.contains('create_task') ||
                actionType == 'propose_task' ||
                actionType == 'create_task';

            if (isProposal) {
              return ActionProposalBubble(
                action: action,
                onConfirm: (date) => onActionConfirm(action, date),
                onCancel: () => onActionCancel(action),
              );
            }
            return const SizedBox.shrink();
          }),
      ],
    );

    if (animate) {
      return ChatBubbleAnimation(isUser: isUser, child: content);
    }
    return content;
  }

  Widget _buildBubble(BuildContext context) {
    // [FIX] Don't render empty bubbles (Ghost Bubble fix)
    if (message.content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    // Se tiver tasks, o build() já separa em dois widgets

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
            bottom: 8), // Reduced bottom margin as actions might follow
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.cardBackgroundLight,
          gradient: isUser
              ? LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.primaryAccent.withValues(alpha: 0.3)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft:
                isUser ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight:
                isUser ? const Radius.circular(4) : const Radius.circular(20),
          ),
          border: Border.all(
            color: isUser
                ? AppColors.primaryAccent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                    color: Colors.white, fontSize: 15, height: 1.4),
                strong: const TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NOVO: Widget para exibir texto introdutório separado das tasks
  Widget _buildTextBubble(BuildContext context) {
    if (message.content.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: MarkdownBody(
          data: message.content,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            strong: const TextStyle(
                color: AppColors.primaryAccent, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // Widget para exibir lista visual de tarefas (texto + tasks em um único balão)
  Widget _buildTaskListBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Texto introdutório - APENAS a primeira linha (título), não a lista de tarefas
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  // Extrair apenas a primeira linha (título) - remover lista de tarefas
                  _extractTitle(message.content),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),

            // Lista de tarefas (containers visuais)
            ...message.embeddedTasks
                .map((taskData) => _buildInlineTaskItem(context, taskData)),

            // Footer com hora
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                DateFormat('HH:mm').format(message.timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Extrai apenas o título do texto (primeira linha antes da lista de tarefas)
  String _extractTitle(String content) {
    // Padrões que indicam início de lista de tarefas
    final listPatterns = [
      RegExp(r'\n\s*1\.'), // Lista numerada
      RegExp(r'\n\s*-'), // Lista com traço
      RegExp(r'\n\s*\*'), // Lista com asterisco
      RegExp(r'\n\s*•'), // Lista com bullet
    ];

    // Encontrar o primeiro padrão de lista
    int firstListIndex = content.length;
    for (final pattern in listPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null && match.start < firstListIndex) {
        firstListIndex = match.start;
      }
    }

    // Retornar apenas o texto antes da lista
    String title = content.substring(0, firstListIndex).trim();

    // Se não encontrou lista, pegar apenas a primeira linha
    if (title == content.trim()) {
      final lines = content.split('\n');
      title = lines.first.trim();
    }

    return title;
  }

  // Item de tarefa inline no chat (simplificado do TaskItem)
  Widget _buildInlineTaskItem(
      BuildContext context, Map<String, dynamic> taskData) {
    final text = taskData['text'] ?? 'Sem título';
    final personalDay = taskData['personal_day'];
    final journeyTitle = taskData['journey_title'];
    final isOverdue = taskData['is_overdue'] == true;
    final completed = taskData['completed'] == true;
    final dateFormatted = taskData['date_formatted'] ?? '';
    final recurrenceType =
        taskData['recurrence_type']?.toString().toLowerCase() ?? 'none';
    // [FIX] Strict check for recurrence to avoid showing icon for 'none', 'null' or empty
    final validRecurrenceTypes = [
      'daily',
      'weekly',
      'monthly',
      'yearly',
      'custom'
    ];
    final isRecurrent = validRecurrenceTypes.contains(recurrenceType);

    final reminderAt = taskData['reminder_at'];
    final hasReminder = reminderAt != null && reminderAt.toString() != 'null';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openTaskDetail(context, taskData),
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOverdue
                    ? Colors.red.withValues(alpha: 0.3)
                    : AppColors.primaryAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                // Checkbox visual (clicável para toggle)
                GestureDetector(
                  onTap: () => _toggleTaskComplete(context, taskData),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: completed
                            ? AppColors.success
                            : AppColors.primaryAccent.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      color: completed
                          ? AppColors.success.withValues(alpha: 0.2)
                          : Colors.transparent,
                    ),
                    child: completed
                        ? const Icon(Icons.check,
                            size: 14, color: AppColors.success)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Texto e info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          color: completed ? Colors.white54 : Colors.white,
                          fontSize: 14,
                          decoration:
                              completed ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Data
                          if (dateFormatted.isNotEmpty) ...[
                            Icon(
                              Icons.calendar_today,
                              size: 11,
                              color: isOverdue ? Colors.red : Colors.white38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateFormatted,
                              style: TextStyle(
                                color: isOverdue ? Colors.red : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          // Ícone de Lembrete (NOVO)
                          if (hasReminder) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.notifications_active_outlined,
                                size: 11, color: AppColors.primary),
                          ],
                          // Ícone de Recorrência
                          if (isRecurrent) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.repeat_rounded,
                                size: 11, color: Color(0xFF8B5CF6)),
                          ],
                          // Ícone de Meta
                          if (journeyTitle != null &&
                              journeyTitle.toString().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.flag_outlined,
                                size: 11, color: Color(0xFF06B6D4)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Personal day badge (VibrationPill Corrected)
                if (personalDay != null && personalDay > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: VibrationPill(
                      vibrationNumber: personalDay,
                      type: VibrationPillType.compact, // 24x24 size
                    ),
                  ),

                // Arrow
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NOVO: Toggle de conclusão da tarefa
  void _toggleTaskComplete(
      BuildContext context, Map<String, dynamic> taskData) async {
    final taskId = taskData['id'];
    if (taskId == null) return;

    final newCompleted = !(taskData['completed'] == true);

    try {
      await Supabase.instance.client
          .from('tasks')
          .update({'completed': newCompleted}).eq('id', taskId);

      // Feedback visual
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(newCompleted ? '✅ Tarefa concluída!' : '↩️ Tarefa reaberta'),
          duration: const Duration(seconds: 1),
          backgroundColor: newCompleted ? AppColors.success : AppColors.primary,
        ),
      );
    } catch (e) {
      debugPrint('[ChatMessageItem] Error toggling task: $e');
    }
  }

  // NOVO: Abrir modal de detalhes da tarefa
  void _openTaskDetail(BuildContext context, Map<String, dynamic> taskData) {
    // Verifica se userData está disponível
    if (userData == null) {
      debugPrint(
          '[ChatMessageItem] userData is null, cannot open TaskDetailModal');
      return;
    }

    // Converter string para RecurrenceType enum
    RecurrenceType recurrenceType = RecurrenceType.none;
    final recurrenceStr = taskData['recurrence_type']?.toString().toLowerCase();
    if (recurrenceStr == 'daily') {
      recurrenceType = RecurrenceType.daily;
    } else if (recurrenceStr == 'weekly')
      recurrenceType = RecurrenceType.weekly;
    else if (recurrenceStr == 'monthly')
      recurrenceType = RecurrenceType.monthly;

    // Criar TaskModel a partir do Map
    final task = TaskModel(
      id: taskData['id'] ?? '',
      text: taskData['text'] ?? '',
      completed: taskData['completed'] == true,
      dueDate: taskData['due_date'] != null
          ? DateTime.tryParse(taskData['due_date'])
          : null,
      personalDay: taskData['personal_day'],
      journeyId: taskData['journey_id'],
      journeyTitle: taskData['journey_title'],
      tags: taskData['tags'] != null ? List<String>.from(taskData['tags']) : [],
      recurrenceType: recurrenceType,
      recurrenceDaysOfWeek: taskData['recurrence_days_of_week'] != null
          ? List<int>.from(taskData['recurrence_days_of_week'])
          : [],
      reminderAt: taskData['reminder_at'] != null
          ? DateTime.tryParse(taskData['reminder_at'])
          : null,
      createdAt: DateTime.now(), // Fallback para tasks do N8n
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TaskDetailModal(
        task: task,
        userData: userData!,
      ),
    );
  }
}
