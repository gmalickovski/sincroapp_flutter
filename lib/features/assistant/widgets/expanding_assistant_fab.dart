import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';

class ExpandingAssistantFab extends StatefulWidget {
  final VoidCallback? onPrimary; // ação principal (ex.: nova tarefa/anotação/meta) - opcional
  final IconData? primaryIcon; // ícone da ação principal - opcional
  final String primaryTooltip; // dica da ação principal
  final Function(String?) onOpenAssistant; // abrir chat da IA (agora aceita mensagem opcional)

  const ExpandingAssistantFab({
    super.key,
    this.onPrimary,
    this.primaryIcon,
    this.primaryTooltip = 'Ação',
    required this.onOpenAssistant,
  });

  @override
  State<ExpandingAssistantFab> createState() => _ExpandingAssistantFabState();
}

class _ExpandingAssistantFabState extends State<ExpandingAssistantFab>
    with SingleTickerProviderStateMixin {
  static const double _kFabHeight = 56.0;
  static const double _kIconSlot = 48.0;
  static const double _kGap = 8.0;
  static const double _kOuterPad = 12.0;
  
  late AnimationController _controller;
  late Animation<double> _widthAnim;
  late Animation<double> _rotationAnim;
  
  // State for Input Mode
  bool _isInputMode = false;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  // Speech
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  Timer? _silenceTimer;

  bool _expanded = false;
  bool _isSimpleButton = false;
  late double _expandedWidth;
  double _screenWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Mais lento e fluido
      reverseDuration: const Duration(milliseconds: 600),
    );

    _isSimpleButton = widget.onPrimary == null;
    _calculateWidths();

    _rotationAnim = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubicEmphasized),
    );
    
    _focusNode.addListener(() {
      // Se perder o foco, estiver vazio e NÃO estiver ouvindo, fecha.
      if (!_focusNode.hasFocus && _isInputMode && _textController.text.isEmpty && !_isListening) {
        Future.delayed(const Duration(milliseconds: 200), () {
           if (mounted && !_focusNode.hasFocus && _isInputMode && !_isListening) {
             _closeInputMode();
           }
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.of(context).size.width;
    _calculateWidths();
  }

  void _calculateWidths() {
    final int actionsCount = 1 + (widget.onPrimary != null ? 1 : 0);
    _expandedWidth = _kFabHeight + _kOuterPad + (actionsCount * _kIconSlot) + ((actionsCount > 0 ? actionsCount - 1 : 0) * _kGap);
    _updateAnimation();
  }

  void _updateAnimation() {
    double targetWidth = _kFabHeight;
    if (_isInputMode) {
      // Desktop: 1/3 da tela ou max 600px. Mobile: tela toda - 32.
      if (_screenWidth > 768) {
        targetWidth = (_screenWidth / 3).clamp(400.0, 600.0);
      } else {
        targetWidth = _screenWidth - 32; 
      }
    } else if (_expanded) {
      targetWidth = _expandedWidth;
    }

    _widthAnim = Tween<double>(begin: _kFabHeight, end: targetWidth).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubicEmphasized),
    );
  }

  @override
  void didUpdateWidget(covariant ExpandingAssistantFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isSimpleButton = widget.onPrimary == null;
    if (oldWidget.onPrimary != widget.onPrimary) {
      _calculateWidths();
      if (_expanded) {
        _controller.forward(from: _controller.value);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _silenceTimer?.cancel();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isInputMode) return;
    
    setState(() => _expanded = !_expanded);
    _updateAnimation();
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }
  
  void _openInputMode() {
    setState(() {
      _isInputMode = true;
      _expanded = false; 
    });
    _updateAnimation();
    _controller.forward(from: 0.0);
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }
  
  void _closeInputMode() {
    _textController.clear();
    _focusNode.unfocus();
    _stopListening(); // Garante que pare de ouvir
    setState(() {
      _isInputMode = false;
    });
    _updateAnimation();
    _controller.reverse();
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onOpenAssistant(text);
      _closeInputMode();
    }
  }
  
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
             // O plugin parou nativamente (ex: timeout nativo ou erro)
             if (mounted && _isListening) {
               _stopListening();
             }
          }
        },
        onError: (error) => debugPrint('Speech error: $error'),
      );
      if (mounted) setState(() => _speechAvailable = available);
      if (!available) return;
    }

    setState(() => _isListening = true);
    
    // Inicia timer de silêncio manual (fallback)
    _resetSilenceTimer();

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _textController.text = result.recognizedWords;
            _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
          });
          
          // Reinicia timer a cada palavra reconhecida
          _resetSilenceTimer();
        }
      },
      localeId: 'pt_BR',
      cancelOnError: true,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3), // Pausa nativa
    );
  }

  Future<void> _stopListening() async {
    _silenceTimer?.cancel();
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 2), () {
      // Se silêncio por 2s, para de ouvir
      if (mounted && _isListening) {
        _stopListening();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSimpleButton && !_isInputMode) { // Correção: só mostra botão simples se NÃO estiver em input mode
       return SizedBox(
        width: _kFabHeight,
        height: _kFabHeight,
        child: FloatingActionButton(
          onPressed: _openInputMode, // Botão simples agora abre input mode
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28), // Arredondado igual ao expandido
          ),
          tooltip: 'Abrir Sincro IA',
          heroTag: 'simple_assistant_fab',
          child: SvgPicture.asset(
            'assets/images/icon-ia-sincroapp-branco-v1.svg',
            width: 28,
            height: 28,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: _widthAnim.value,
          height: _kFabHeight,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: _isInputMode ? _buildInputContent() : _buildMenuContent(),
        );
      },
    );
  }
  
  Widget _buildInputContent() {
    return Row(
      children: [
        IconButton(
          onPressed: _closeInputMode,
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: 'Cancelar',
        ),
        
        Expanded(
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Como posso ajudar?',
              hintStyle: TextStyle(color: Colors.white54),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
            onSubmitted: (_) => _handleSend(),
            textInputAction: TextInputAction.send,
          ),
        ),
        
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _textController,
          builder: (context, value, child) {
            final hasText = value.text.trim().isNotEmpty;
            // Se tem texto, mostra Enviar.
            // Se não tem texto e está ouvindo, mostra Mic Ativo (pode clicar para parar).
            // Se não tem texto e não está ouvindo, mostra Mic Inativo.
            
            return IconButton(
              onPressed: hasText ? _handleSend : _toggleListening,
              icon: Icon(
                hasText ? Icons.send : Icons.mic,
                color: (hasText || _isListening) ? Colors.white : Colors.white70,
              ),
              // Animação de pulso ou cor para indicar gravando
              style: _isListening && !hasText ? IconButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.8),
                hoverColor: Colors.redAccent,
              ) : null,
              tooltip: hasText ? 'Enviar' : (_isListening ? 'Parar' : 'Falar'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuContent() {
    final int actionsCount = 1 + (widget.onPrimary != null ? 1 : 0);
    final double actionsWidth = actionsCount > 0
        ? (actionsCount * _kIconSlot) + ((actionsCount - 1) * _kGap)
        : 0.0;
    final double availableContentWidth = _widthAnim.value - _kFabHeight - _kOuterPad;
    final bool showActions = _expanded && availableContentWidth >= actionsWidth;

    return Stack(
      children: [
        if (!_isSimpleButton)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(right: _kFabHeight, left: _kOuterPad),
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showActions) ...[
                      if (widget.onPrimary != null && widget.primaryIcon != null) ...[
                        _AnimatedActionSlot(
                          controller: _controller,
                          tooltip: widget.primaryTooltip,
                          icon: widget.primaryIcon!,
                          onPressed: () {
                            _toggleMenu();
                            widget.onPrimary!();
                          },
                        ),
                        const SizedBox(width: _kGap),
                      ],
                      _AnimatedActionSlot(
                        controller: _controller,
                        tooltip: 'Assistente IA',
                        iconWidget: SvgPicture.asset(
                          'assets/images/icon-ia-sincroapp-branco-v1.svg',
                          width: 24,
                          height: 24,
                        ),
                        onPressed: _openInputMode,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
        Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSimpleButton ? _openInputMode : _toggleMenu,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: _kFabHeight,
                height: _kFabHeight,
                alignment: Alignment.center,
                child: _isSimpleButton 
                  ? SvgPicture.asset(
                      'assets/images/icon-ia-sincroapp-branco-v1.svg',
                      width: 28,
                      height: 28,
                    )
                  : RotationTransition(
                      turns: _rotationAnim,
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedActionSlot extends StatelessWidget {
  final AnimationController controller;
  final String tooltip;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onPressed;

  static const double _slotWidth = 48.0;
  static const double _slotHeight = 56.0;

  const _AnimatedActionSlot({
    required this.controller,
    required this.tooltip,
    this.icon,
    this.iconWidget,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _slotWidth,
      height: _slotHeight,
      child: AnimatedOpacity(
        opacity: controller.value,
        duration: const Duration(milliseconds: 150),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: _slotWidth, height: _slotHeight),
          icon: iconWidget ?? Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}


