import 'package:flutter/material.dart';

enum StrategyMode {
  grounding, // Aterramento (GTD)
  focus,     // Foco (One Thing)
  flow,      // Fluxo (Intuitivo)
  rescue;    // Resgate (Mini Habits)

  String get title {
    switch (this) {
      case StrategyMode.grounding:
        return 'Modo Aterramento';
      case StrategyMode.focus:
        return 'Modo Foco Total';
      case StrategyMode.flow:
        return 'Modo Fluxo';
      case StrategyMode.rescue:
        return 'Modo Resgate';
    }
  }

  String get subtitle {
    switch (this) {
      case StrategyMode.grounding:
        return 'Organize o caos mental';
      case StrategyMode.focus:
        return 'Uma coisa de cada vez';
      case StrategyMode.flow:
        return 'Siga sua intuição';
      case StrategyMode.rescue:
        return 'Pequenos passos contam';
    }
  }

  IconData get icon {
    switch (this) {
      case StrategyMode.grounding:
        return Icons.anchor; // Ou list_alt
      case StrategyMode.focus:
        return Icons.center_focus_strong; // Ou track_changes
      case StrategyMode.flow:
        return Icons.waves; // Ou water_drop
      case StrategyMode.rescue:
        return Icons.spa; // Ou healing
    }
  }

  Color get color {
    switch (this) {
      case StrategyMode.grounding:
        return const Color(0xFF8D6E63); // Brown-ish
      case StrategyMode.focus:
        return const Color(0xFFE57373); // Red-ish
      case StrategyMode.flow:
        return const Color(0xFF64B5F6); // Blue-ish
      case StrategyMode.rescue:
        return const Color(0xFFBA68C8); // Purple-ish
    }
  }
  
  List<Color> get gradient {
    switch (this) {
      case StrategyMode.grounding:
        return [const Color(0xFF8D6E63), const Color(0xFF6D4C41)];
      case StrategyMode.focus:
        return [const Color(0xFFEF5350), const Color(0xFFC62828)];
      case StrategyMode.flow:
        return [const Color(0xFF42A5F5), const Color(0xFF1565C0)];
      case StrategyMode.rescue:
        return [const Color(0xFFAB47BC), const Color(0xFF7B1FA2)];
    }
  }
}
