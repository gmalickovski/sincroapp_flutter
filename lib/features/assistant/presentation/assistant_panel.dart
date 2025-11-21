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

  // ... (Logic methods remain same until _buildHarmonyAnalysis)

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

      final userExp = userNumerology.mapa['expressao']?['numero'] ?? 0;
      final partnerExp = partnerNumerology.mapa['expressao']?['numero'] ?? 0;
      final userDest = userNumerology.mapa['destino']?['numero'] ?? 0;
      final partnerDest = partnerNumerology.mapa['destino']?['numero'] ?? 0;

      return "Compreendido, ${widget.userData.nome.split(' ').first}! Analisando as vibrações energéticas de vocês dois:\n\n"
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

  // ... (UI Components)

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
                        controller: scrollController,
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
                controller: _scrollController,
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
