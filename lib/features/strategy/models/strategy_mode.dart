import 'package:flutter/material.dart';

enum StrategyMode {
  grounding, // Aterramento (GTD)
  focus, // Foco (One Thing)
  flow, // Fluxo (Intuitivo)
  rescue; // Resgate (Mini Habits)

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

  String get detailedDescription {
    switch (this) {
      case StrategyMode.focus:
        return "Este modo é ativado em dias de energia 1, 4 ou 8. A vibração do dia favorece a liderança, a construção e a execução material. É o momento ideal para avançar em grandes projetos, tomar decisões difíceis e focar na qualidade do seu trabalho. Evite dispersões e multitarefas; o sucesso hoje vem da profundidade e da disciplina.";
      case StrategyMode.flow:
        return "Este modo é ativado em dias de energia 2, 6 ou 9. A vibração favorece a intuição, os relacionamentos e a conclusão de ciclos. Não é um dia para forçar portas fechadas, mas sim para navegar com a correnteza. Priorize a diplomacia, o cuidado com o próximo e a finalização de pendências. A produtividade hoje é fluida e emocional.";
      case StrategyMode.grounding:
        return "Este modo é ativado em dias de energia 3 ou 5. A vibração é de movimento, criatividade e, por vezes, instabilidade. O desafio hoje é manter o foco em meio ao caos criativo ou às mudanças inesperadas. Use listas para se organizar, mas esteja aberto ao novo. É um dia excelente para comunicação e vendas, desde que você mantenha os pés no chão.";
      case StrategyMode.rescue:
        return "Este modo é ativado em dias de energia 7, 11 ou 22. A energia física pode estar mais baixa, voltando-se para o mental e o espiritual. Não se cobre uma produtividade mecânica. É um dia para análise, planejamento estratégico e grandes insights. Respeite seu ritmo, faça pausas e use sua intuição para resolver problemas complexos.";
    }
  }
}
