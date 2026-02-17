import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

// --- WRAPPER DE ROLAGEM PARA MOBILE ---

class ScrollableToolbarWrapper extends StatefulWidget {
  final Widget child;
  final bool isMobile;

  const ScrollableToolbarWrapper({
    super.key,
    required this.child,
    required this.isMobile,
  });

  @override
  State<ScrollableToolbarWrapper> createState() =>
      _ScrollableToolbarWrapperState();
}

class _ScrollableToolbarWrapperState extends State<ScrollableToolbarWrapper> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = true; // Assume initially there's content to scroll

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
    // Verificar estado inicial após renderização
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateArrows);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    // Se nÃ£o hÃ¡ nada para rolar
    if (maxScroll <= 0) {
      if (_showLeftArrow || _showRightArrow) {
        setState(() {
          _showLeftArrow = false;
          _showRightArrow = false;
        });
      }
      return;
    }

    final showLeft = currentScroll > 0;
    final showRight = currentScroll < maxScroll - 5; // TolerÃ¢ncia pequena

    if (showLeft != _showLeftArrow || showRight != _showRightArrow) {
      setState(() {
        _showLeftArrow = showLeft;
        _showRightArrow = showRight;
      });
    }
  }

  void _scroll(bool right) {
    if (!_scrollController.hasClients) return;
    const double scrollAmount = 150.0;
    final current = _scrollController.offset;
    final target = right ? current + scrollAmount : current - scrollAmount;

    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMobile) {
      // Desktop: Wrap normal, sem setas de rolagem forÃ§ada (ou usa padrÃ£o)
      return widget.child;
    }

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Seta Esquerda (Animada)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _showLeftArrow ? 32.0 : 0.0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showLeftArrow ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.cardBackground,
                      AppColors.cardBackground.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: _ToolbarScrollArrow(
                  icon: Icons.arrow_back_ios,
                  onPressed: () => _scroll(false),
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: widget.child,
            ),
          ),

          // Seta Direita (Animada)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _showRightArrow ? 32.0 : 0.0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showRightArrow ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.cardBackground.withValues(alpha: 0.0),
                      AppColors.cardBackground,
                    ],
                  ),
                ),
                child: _ToolbarScrollArrow(
                  icon: Icons.arrow_forward_ios,
                  onPressed: () => _scroll(true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SETA DE ROLAGEM PERSONALIZADA (sem fundo, hover roxo) ---

class _ToolbarScrollArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ToolbarScrollArrow({
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_ToolbarScrollArrow> createState() => _ToolbarScrollArrowState();
}

class _ToolbarScrollArrowState extends State<_ToolbarScrollArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Icon(
              widget.icon,
              size: 16,
              color: _isHovered ? AppColors.primary : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

// --- BOTÃO DE SELEÇÃO DE COR COM OVERLAY ---

class ColorSelectionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isBackground;
  final QuillController controller;
  final List<Color> customColors;
  final Color? initialColor; // Cor atualmente selecionada (externa)

  const ColorSelectionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isBackground,
    required this.controller,
    required this.customColors,
    this.initialColor,
  });

  @override
  State<ColorSelectionButton> createState() => _ColorSelectionButtonState();
}

class _ColorSelectionButtonState extends State<ColorSelectionButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Color? _selectedColor; // Estado local para UI feedback imediato

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  void didUpdateWidget(covariant ColorSelectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialColor != oldWidget.initialColor) {
      _selectedColor = widget.initialColor;
    }
  }

  void _toggleOverlay() {
    if (_overlayEntry == null) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Full screen detector to close overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Positioned Overlay
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 8, // 8px de espaçamento
            width: 320, // Largura máxima do popup
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: AppColors.cardBackground,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isBackground ? 'Cor de Fundo' : 'Cor do Texto',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Opção "Sem Cor"
                        _buildColorOption(null),
                        // Opções de Cor
                        ...widget.customColors.map((c) => _buildColorOption(c)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorOption(Color? color) {
    final bool isSelected =
        _selectedColor?.toARGB32() == color?.toARGB32(); // Compara valor (null safe)

    return GestureDetector(
      onTap: () {
        _applyColor(color);
        _hideOverlay();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color ?? Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: color == null
              ? const Center(
                  child: Icon(Icons.format_color_reset,
                      size: 16, color: AppColors.secondaryText),
                )
              : null,
        ),
      ),
    );
  }

  void _applyColor(Color? color) {
    setState(() {
      _selectedColor = color;
    });

    String hex = '';
    if (color != null) {
      hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    }

    if (widget.isBackground) {
      if (color == null) {
        widget.controller
            .formatSelection(Attribute.clone(Attribute.background, null));
      } else {
        widget.controller
            .formatSelection(Attribute.clone(Attribute.background, hex));
      }
    } else {
      if (color == null) {
        widget.controller
            .formatSelection(Attribute.clone(Attribute.color, null));
      } else {
        widget.controller
            .formatSelection(Attribute.clone(Attribute.color, hex));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        icon: Icon(widget.icon,
            color: _selectedColor ??
                AppColors.secondaryText), // Feedback visual no ícone
        tooltip: widget.tooltip,
        onPressed: _toggleOverlay,
      ),
    );
  }
}
