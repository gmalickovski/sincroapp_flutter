// lib/features/calendar/presentation/widgets/calendar_fab.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';
// import 'dart:math' as math; // Não é mais necessário

class CalendarFab extends StatefulWidget {
  final VoidCallback onAddTask;
  final VoidCallback onAddJournalEntry;

  const CalendarFab({
    super.key,
    required this.onAddTask,
    required this.onAddJournalEntry,
  });

  @override
  State<CalendarFab> createState() => _CalendarFabState();
}

class _CalendarFabState extends State<CalendarFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotateAnimation;
  late Animation<double> _translateAnimation;
  bool _isOpen = false;

  // Constantes de Layout (Ajuste Fino Espaço A > Espaço B)
  static const double _fabSize = 56.0;
  static const double _smallFabSize = 40.0;
  static const double _horizontalOffset =
      (_fabSize - _smallFabSize) / 2; // = 8.0
  static const double _gapBetweenSmallFabs = 50.0;
  static const double _button1TargetOffset = 70.0;
  static const double _button2TargetOffset =
      _button1TargetOffset + _gapBetweenSmallFabs; // = 120.0

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _translateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double offsetButton1 =
            _translateAnimation.value * _button1TargetOffset;
        final double offsetButton2 =
            _translateAnimation.value * _button2TargetOffset;

        return Stack(
          alignment: Alignment.bottomRight,
          clipBehavior: Clip.none,
          children: [
            // --- INÍCIO DA CORREÇÃO (Inverter Ordem) ---
            // Colocamos o FAB Principal PRIMEIRO para que ele fique por baixo
            FloatingActionButton(
              onPressed: _toggle,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              heroTag: 'calendar_main_fab', // Tag principal
              child: RotationTransition(
                turns: _rotateAnimation,
                child: const Icon(Icons.add),
              ),
            ),

            // Botão Secundário 2 (Anotação) - Fica por cima do principal
            Transform.translate(
              offset: Offset(-_horizontalOffset, -offsetButton2),
              child: _buildSecondaryButton(
                Icons.book_outlined,
                "Nova Anotação",
                () {
                  widget.onAddJournalEntry();
                  _toggle();
                },
                animationValue: _translateAnimation.value,
                heroTag: 'fab_journal_secondary', // Tag única
              ),
            ),

            // Botão Secundário 1 (Tarefa) - Fica por cima do principal e do botão 2
            Transform.translate(
              offset: Offset(-_horizontalOffset, -offsetButton1),
              child: _buildSecondaryButton(
                Icons.check_box_outlined,
                "Nova Tarefa",
                () {
                  widget.onAddTask();
                  _toggle();
                },
                animationValue: _translateAnimation.value,
                heroTag: 'fab_task_secondary', // Tag única
              ),
            ),
            // --- FIM DA CORREÇÃO ---
          ],
        );
      },
    );
  }

  // O _buildSecondaryButton permanece o mesmo da última versão (com MouseRegion)
  Widget _buildSecondaryButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    required double animationValue,
    required String heroTag, // Recebe a tag única
  }) {
    final bool isVisibleAndClickable = animationValue > 0.0;

    return Opacity(
      opacity: animationValue,
      child: MouseRegion(
        // Mantém o MouseRegion para o cursor
        cursor: isVisibleAndClickable
            ? SystemMouseCursors.click // Mostra a "mãozinha"
            : SystemMouseCursors.basic, // Cursor padrão se não clicável
        child: FloatingActionButton.small(
          tooltip: tooltip,
          // A lógica do onPressed já impede o clique quando não visível
          onPressed: isVisibleAndClickable ? onPressed : null,
          backgroundColor: Colors.white.withOpacity(0.1),
          foregroundColor: Colors.purple.shade200,
          heroTag: heroTag, // Usa a tag recebida
          child: Icon(icon),
        ),
      ),
    );
  }
}
