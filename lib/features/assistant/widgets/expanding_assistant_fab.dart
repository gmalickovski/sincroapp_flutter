import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
import 'package:sincro_app_flutter/features/assistant/services/speech_service.dart';

class ExpandingAssistantFab extends StatefulWidget {
  final VoidCallback?
      onPrimary; // ação principal (ex.: nova tarefa/anotação/meta) - opcional
  final IconData? primaryIcon; // ícone da ação principal - opcional
  final String primaryTooltip; // dica da ação principal
  final Function(String?)
      onOpenAssistant; // abrir chat da IA (agora aceita mensagem opcional)
  final IconData? fabIcon; // ícone do botão flutuante (opcional, default é add)

  const ExpandingAssistantFab({
    super.key,
    this.onPrimary,
    this.primaryIcon,
    this.primaryTooltip = 'Ação',
    required this.onOpenAssistant,
    this.fabIcon,
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
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;

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
      CurvedAnimation(
          parent: _controller, curve: Curves.easeInOutCubicEmphasized),
    );

    _focusNode.addListener(() {
      // Se perder o foco, estiver vazio e NÃO estiver ouvindo, fecha.
      if (!_focusNode.hasFocus &&
          _isInputMode &&
          _textController.text.isEmpty &&
          !_isListening) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted &&
              !_focusNode.hasFocus &&
              _isInputMode &&
              !_isListening) {
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
    _expandedWidth = _kFabHeight +
        _kOuterPad +
        (actionsCount * _kIconSlot) +
        ((actionsCount > 0 ? actionsCount - 1 : 0) * _kGap);
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
      CurvedAnimation(
          parent: _controller, curve: Curves.easeInOutCubicEmphasized),
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
    _speechService.stop();
    super.dispose();
  }

  void _toggleMenu() async {
    if (_isInputMode) return;

    if (_expanded) {
      // Closing: Reverse animation first, then update state
      await _controller.reverse();
      if (mounted) {
        setState(() => _expanded = false);
        _updateAnimation();
      }
    } else {
      // Opening: Update state first, then forward animation
      setState(() => _expanded = true);
      _updateAnimation();
      _controller.forward();
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

  void _closeInputMode() async {
    _textController.clear();
    _focusNode.unfocus();
    _stopListening();

    // Reverse animation first
    await _controller.reverse();

    // Then update state to switch back to simple button (if applicable)
    if (mounted) {
      setState(() {
        _isInputMode = false;
      });
      _updateAnimation();
    }
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
    final available = await _speechService.init();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Reconhecimento de voz indisponível.'),
            backgroundColor: Colors.redAccent));
      }
      return;
    }

    setState(() => _isListening = true);

    await _speechService.start(onResult: (text) {
      if (mounted) {
        setState(() {
          _textController.text = text;
          _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length));
        });
      }
    }, onDone: () {
      if (mounted && _isListening) {
        _stopListening();
      }
    });
  }

  Future<void> _stopListening() async {
    await _speechService.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show simple static button if:
    // 1. It is a simple button (no primary action)
    // 2. Not in input mode
    // 3. Not expanded (menu open)
    // 4. Not animating (forward or reverse)
    if (_isSimpleButton &&
        !_isInputMode &&
        !_expanded &&
        !_controller.isAnimating) {
      return SizedBox(
        width: _kFabHeight,
        height: _kFabHeight,
        child: FloatingActionButton(
          onPressed: _openInputMode,
          backgroundColor: AppColors.primaryAccent,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
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
        // Fix 1: Add padding to move FAB up when keyboard is open (only in input mode)
        final bottomPadding =
            _isInputMode ? MediaQuery.of(context).viewInsets.bottom : 0.0;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Container(
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
          ),
        );
      },
    );
  }

  Widget _buildInputContent() {
    // Animate X to + (Rotation)
    // Refined: Use a FadeTransition combined with Rotation for smoother effect
    final iconRotation = Tween<double>(begin: 0.125, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    final iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 1.0, curve: Curves.easeIn)),
    );

    return Row(
      children: [
        FadeTransition(
          opacity: iconOpacity,
          child: RotationTransition(
            turns: iconRotation,
            child: IconButton(
              onPressed: _closeInputMode,
              icon: const Icon(Icons.close, color: Colors.white70),
              tooltip: 'Cancelar',
            ),
          ),
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

            return IconButton(
              onPressed: hasText ? _handleSend : _toggleListening,
              icon: Icon(
                hasText ? Icons.send : Icons.mic,
                color:
                    (hasText || _isListening) ? Colors.white : Colors.white70,
              ),
              style: _isListening && !hasText
                  ? IconButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.8),
                      hoverColor: Colors.redAccent,
                    )
                  : null,
              tooltip: hasText ? 'Enviar' : (_isListening ? 'Parar' : 'Falar'),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuContent() {
    return Stack(
      children: [
        if (!_isSimpleButton)
          Positioned.fill(
            child: Padding(
              padding:
                  const EdgeInsets.only(right: _kFabHeight, left: _kOuterPad),
              child: Align(
                alignment: Alignment.centerRight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onPrimary != null &&
                          widget.primaryIcon != null) ...[
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
                  ),
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
                        child: Icon(widget.fabIcon ?? Icons.add,
                            color: Colors.white, size: 28),
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
    // Fix 2: Use Interval for delayed opacity to prevent "sliding in" effect
    final opacityAnim = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    return SizedBox(
      width: _slotWidth,
      height: _slotHeight,
      child: FadeTransition(
        opacity: opacityAnim,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(
              width: _slotWidth, height: _slotHeight),
          icon: iconWidget ?? Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
