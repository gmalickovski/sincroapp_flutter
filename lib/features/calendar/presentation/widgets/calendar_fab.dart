// lib/features/calendar/presentation/widgets/calendar_fab.dart

import 'package:flutter/material.dart';
import 'package:sincro_app_flutter/common/constants/app_colors.dart';

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
    _translateAnimation = Tween<double>(begin: 0.0, end: 65.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (mounted) {
      if (_isOpen) {
        _animationController.reverse();
      } else {
        _animationController.forward();
      }
      setState(() => _isOpen = !_isOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      // *** CORREÇÃO APLICADA AQUI ***
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: Offset(0, -_translateAnimation.value * 2),
          child: _buildSecondaryButton(
            Icons.book_outlined,
            "Nova Anotação",
            () {
              widget.onAddJournalEntry();
              _toggle();
            },
          ),
        ),
        Transform.translate(
          offset: Offset(0, -_translateAnimation.value),
          child: _buildSecondaryButton(
            Icons.check_box_outlined,
            "Nova Tarefa",
            () {
              widget.onAddTask();
              _toggle();
            },
          ),
        ),
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          heroTag: 'calendar_main_fab',
          child: RotationTransition(
            turns: _rotateAnimation,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryButton(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _isOpen ? 1.0 : 0.0,
      child: FloatingActionButton.small(
        tooltip: tooltip,
        onPressed: _isOpen ? onPressed : null,
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.purple.shade200,
        heroTag: tooltip,
        child: Icon(icon),
      ),
    );
  }
}
