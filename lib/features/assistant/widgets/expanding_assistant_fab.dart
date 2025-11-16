import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

class ExpandingAssistantFab extends StatefulWidget {
  final VoidCallback?
      onPrimary; // ação principal (ex.: nova tarefa/anotação/meta) - opcional
  final IconData? primaryIcon; // ícone da ação principal - opcional
  final String primaryTooltip; // dica da ação principal
  final VoidCallback onOpenAssistant; // abrir chat da IA
  final VoidCallback onMic; // entrada por voz

  const ExpandingAssistantFab({
    super.key,
    this.onPrimary,
    this.primaryIcon,
    this.primaryTooltip = 'Ação',
    required this.onOpenAssistant,
    required this.onMic,
  });

  @override
  State<ExpandingAssistantFab> createState() => _ExpandingAssistantFabState();
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
  late double _expandedWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Calcula largura expandida baseada na quantidade de ações
    final int actionsCount =
        2 + (widget.onPrimary != null ? 1 : 0); // chat, mic, [primary]
    _expandedWidth = _kFabHeight + // espaço do toggle (+/x)
        _kOuterPad +
        (actionsCount * _kIconSlot) +
        ((actionsCount > 0 ? actionsCount - 1 : 0) * _kGap);

    _widthAnim = Tween<double>(begin: _kFabHeight, end: _expandedWidth).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Animação de rotação: + vira x (45 graus)
    _rotationAnim = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant ExpandingAssistantFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onPrimary != widget.onPrimary) {
      final int actionsCount = 2 + (widget.onPrimary != null ? 1 : 0);
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
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Para garantir que o FAB muda conforme a página, cada tela deve instanciar com props diferentes
    // e não usar uma key fixa compartilhada.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Cálculo de disponibilidade de largura para evitar overflow do Row durante a animação
        final int actionsCount = 2 + (widget.onPrimary != null ? 1 : 0);
        final double actionsWidth = actionsCount > 0
            ? (actionsCount * _kIconSlot) + ((actionsCount - 1) * _kGap)
            : 0.0;
        final double availableContentWidth = _widthAnim.value -
            _kFabHeight -
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
                            icon: Icons.chat_bubble_outline,
                            onPressed: () {
                              _toggle();
                              widget.onOpenAssistant();
                            },
                          ),
                          const SizedBox(width: _kGap),
                          _AnimatedActionSlot(
                            controller: _controller,
                            tooltip: 'Entrada por voz',
                            icon: Icons.mic_none,
                            onPressed: () {
                              _toggle();
                              widget.onMic();
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
  final IconData icon;
  final VoidCallback onPressed;

  static const double _slotWidth = _ExpandingAssistantFabState._kIconSlot;
  static const double _slotHeight = _ExpandingAssistantFabState._kFabHeight;

  const _AnimatedActionSlot({
    required this.controller,
    required this.tooltip,
    required this.icon,
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
            icon: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
