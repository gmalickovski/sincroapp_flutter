import 'package:flutter/material.dart';
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

  bool _expanded = false;
  bool _isSimpleButton = false;
  late double _expandedWidth;
  double _screenWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _isSimpleButton = widget.onPrimary == null;
    _calculateWidths();

    _rotationAnim = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isInputMode && _textController.text.isEmpty && !_isListening) {
        // Se perder o foco e estiver vazio, fecha o input mode
        // Delay para permitir clique no botão de enviar
        Future.delayed(const Duration(milliseconds: 200), () {
           if (mounted && !_focusNode.hasFocus && _isInputMode) {
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
    // Largura normal expandida (menu)
    final int actionsCount = 1 + (widget.onPrimary != null ? 1 : 0);
    _expandedWidth = _kFabHeight + _kOuterPad + (actionsCount * _kIconSlot) + ((actionsCount > 0 ? actionsCount - 1 : 0) * _kGap);
    
    // Largura total para Input Mode (tela toda menos margens)
    // Se estiver em InputMode, anima para largura total
    // Se estiver em MenuMode, anima para _expandedWidth
    // Se estiver fechado, anima para _kFabHeight
    
    _updateAnimation();
  }

  void _updateAnimation() {
    double targetWidth = _kFabHeight;
    if (_isInputMode) {
      // Largura total menos margens laterais (assumindo FAB com margem de 16)
      targetWidth = _screenWidth - 32; 
    } else if (_expanded) {
      targetWidth = _expandedWidth;
    }

    _widthAnim = Tween<double>(begin: _kFabHeight, end: targetWidth).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
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
      _expanded = false; // Fecha o menu se estiver aberto (logicamente)
    });
    _updateAnimation();
    _controller.forward(from: 0.0);
    
    // Foca no input após a animação iniciar
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }
  
  void _closeInputMode() {
    _textController.clear();
    _focusNode.unfocus();
    setState(() {
      _isInputMode = false;
      _isListening = false;
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
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (!_speechAvailable) {
        bool available = await _speech.initialize(
          onStatus: (status) {
            if (status == 'notListening' || status == 'done') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (error) => debugPrint('Speech error: $error'),
        );
        if (mounted) setState(() => _speechAvailable = available);
        if (!available) return;
      }

      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _textController.text = result.recognizedWords;
              // Move cursor to end
              _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
            });
            
            // Se for resultado final e tiver texto, pode enviar automaticamente ou esperar o usuário?
            // O usuário pediu "botão de audio que se transforma em botão de enviar"
            // Vamos manter o fluxo manual de enviar por enquanto para evitar envios acidentais
          }
        },
        localeId: 'pt_BR',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se for botão simples e não estiver em modo input, renderiza o FAB simples
    // Mas agora o FAB simples ao clicar deve virar Input Mode
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: _widthAnim.value,
          height: _kFabHeight,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent,
            borderRadius: BorderRadius.circular(28), // Mais arredondado para parecer barra de pesquisa
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
        // Botão de Fechar (X) na esquerda
        IconButton(
          onPressed: _closeInputMode,
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: 'Cancelar',
        ),
        
        // Campo de Texto
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
        
        // Botão de Ação (Mic ou Enviar)
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _textController,
          builder: (context, value, child) {
            final hasText = value.text.trim().isNotEmpty;
            
            return IconButton(
              onPressed: hasText ? _handleSend : _toggleListening,
              icon: Icon(
                hasText ? Icons.send : (_isListening ? Icons.mic_off : Icons.mic),
                color: Colors.white,
              ),
              tooltip: hasText ? 'Enviar' : 'Falar',
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuContent() {
    // Lógica original do menu, mas adaptada
    final int actionsCount = 1 + (widget.onPrimary != null ? 1 : 0);
    final double actionsWidth = actionsCount > 0
        ? (actionsCount * _kIconSlot) + ((actionsCount - 1) * _kGap)
        : 0.0;
    final double availableContentWidth = _widthAnim.value - _kFabHeight - _kOuterPad;
    final bool showActions = _expanded && availableContentWidth >= actionsWidth;

    return Stack(
      children: [
        // Ícones extras (Menu expandido)
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
                      // Botão da IA no menu expandido -> Abre Input Mode
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
          
        // Botão Principal (Toggle ou Ação Direta)
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

class _ExpandingAssistantFabState extends State<ExpandingAssistantFab>
    with SingleTickerProviderStateMixin {
  static const double _kFabHeight = 56.0; // altura e largura do botão de toggle
  static const double _kIconSlot = 48.0; // largura dedicada a cada ação
  static const double _kGap = 8.0; // espaçamento entre ações
  static const double _kOuterPad = 12.0; // padding esquerdo interno
  late AnimationController _controller;
  late Animation<double> _widthAnim;
  late Animation<double> _rotationAnim;
  bool _expanded = false;
  bool _isSimpleButton = false;
  late double _expandedWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // --- INÍCIO DA MUDANÇA: Lógica para botão simples ---
    // Se apenas onOpenAssistant for fornecido, ele se torna um botão simples.
    _isSimpleButton = widget.onPrimary == null;

    // Calcula largura expandida baseada na quantidade de ações
    final int actionsCount = 1 + // chat
        (widget.onPrimary != null ? 1 : 0); // [primary]
    _expandedWidth = _kFabHeight + // espaço do toggle (+/x)
        _kOuterPad + // padding esquerdo
        (actionsCount * _kIconSlot) +
        ((actionsCount > 0 ? actionsCount - 1 : 0) * _kGap);

    _widthAnim = Tween<double>(begin: _kFabHeight, end: _expandedWidth).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Animação de rotação: + vira x (45 graus)
    _rotationAnim = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    // --- FIM DA MUDANÇA ---
  }

  @override
  void didUpdateWidget(covariant ExpandingAssistantFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalcula se o botão é simples ou não quando o widget é atualizado
    _isSimpleButton = widget.onPrimary == null;

    if (oldWidget.onPrimary != widget.onPrimary) {
      final int actionsCount = 1 +
          (widget.onPrimary != null ? 1 : 0);
      _expandedWidth = _kFabHeight +
          _kOuterPad +
          (actionsCount * _kIconSlot) +
          ((actionsCount > 0 ? actionsCount - 1 : 0) * _kGap);

      // Recria a animação com os novos valores
      _widthAnim =
          Tween<double>(begin: _kFabHeight, end: _expandedWidth).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );

      // Se estava expandido, recalcula a posição atual
      if (_expanded) {
        _controller.forward(from: _controller.value);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    // --- INÍCIO DA MUDANÇA: Ação direta para botão simples ---
    if (_isSimpleButton) {
      widget.onOpenAssistant();
      return;
    }
    // --- FIM DA MUDANÇA ---
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- INÍCIO DA MUDANÇA: Renderização do botão simples ---
    if (_isSimpleButton) {
      return SizedBox(
        width: _kFabHeight,
        height: _kFabHeight,
        child: FloatingActionButton(
          onPressed: widget.onOpenAssistant,
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tooltip: 'Abrir Sincro IA',
          heroTag:
              'simple_assistant_fab', // Tag única para evitar conflitos de Hero
          child: SvgPicture.asset(
            'assets/images/icon-ia-sincroapp-branco-v1.svg',
            width: 28,
            height: 28,
          ),
        ),
      );
    }
    // --- FIM DA MUDANÇA ---

    // O código abaixo só será executado se NÃO for um botão simples.
    return _buildExpandingWidget();
  }

  /// Constrói o widget expansível original.
  /// O código original do `build` foi movido para cá.
  Widget _buildExpandingWidget() {
    // Para garantir que o FAB muda conforme a página, cada tela deve instanciar com props diferentes
    // e não usar uma key fixa compartilhada.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Cálculo de disponibilidade de largura para evitar overflow do Row durante a animação
        final int actionsCount = 1 +
            (widget.onPrimary != null ? 1 : 0);
        final double actionsWidth = actionsCount > 0
            ? (actionsCount * _kIconSlot) + ((actionsCount - 1) * _kGap)
            : 0.0;
        final double availableContentWidth = _widthAnim.value -
            _kFabHeight - // largura do toggle
            _kOuterPad; // total - toggle - padding esquerdo
        final bool showActions = _expanded &&
            availableContentWidth >= actionsWidth; // só mostra quando cabe

        return Container(
          width: _widthAnim.value,
          height: _kFabHeight,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior:
              Clip.hardEdge, // garante que nada vaze visualmente nas transições
          child: Stack(
            children: [
              // Ícones extras animados (fade + slide)
              Positioned.fill(
                child: Padding(
                  // Reserva espaço para o botão de toggle à direita
                  padding: const EdgeInsets.only(
                    right: _kFabHeight, // 56
                    left: _kOuterPad, // 12
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mostra os slots de ação apenas quando houver espaço suficiente
                        if (showActions) ...[
                          if (widget.onPrimary != null &&
                              widget.primaryIcon != null) ...[
                            _AnimatedActionSlot(
                              controller: _controller,
                              tooltip: widget.primaryTooltip,
                              icon: widget.primaryIcon!,
                              onPressed: () {
                                _toggle();
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
                            onPressed: () {
                              _toggle();
                              widget.onOpenAssistant();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Botão principal sempre visível na ponta direita
              Align(
                alignment: Alignment.centerRight,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggle,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: _kFabHeight,
                      height: _kFabHeight,
                      alignment: Alignment.center,
                      child: RotationTransition(
                        turns: _rotationAnim,
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
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
}

// Slot fixo para uma ação (garante alinhamento e não sobreposição)
class _AnimatedActionSlot extends StatelessWidget {
  final AnimationController controller;
  final String tooltip;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onPressed;

  static const double _slotWidth = _ExpandingAssistantFabState._kIconSlot;
  static const double _slotHeight = _ExpandingAssistantFabState._kFabHeight;

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
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.2, 0),
            end: Offset.zero,
          ).animate(controller),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: _slotWidth,
              height: _slotHeight,
            ),
            icon: iconWidget ?? Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
