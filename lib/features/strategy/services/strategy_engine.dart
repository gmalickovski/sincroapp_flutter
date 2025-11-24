import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';
import 'package:sincro_app_flutter/features/strategy/models/strategy_recommendation.dart';

class StrategyEngine {
  static StrategyRecommendation getRecommendation(int personalDay) {
    switch (personalDay) {
      case 1:
        return const StrategyRecommendation(
          mode: StrategyMode.focus,
          methodologyName: "The One Thing",
          reason: "Dia de novos inícios e liderança. A energia está alta para começar, mas dispersão pode ser fatal.",
          tips: [
            "Escolha APENAS UMA grande meta para hoje.",
            "Evite multitarefa. Comece o que é mais importante.",
            "Diga 'não' para distrações que não iniciam algo novo."
          ],
        );
      case 2:
        return const StrategyRecommendation(
          mode: StrategyMode.flow,
          methodologyName: "Gestão Emocional / Pomodoro Suave",
          reason: "Dia de parcerias e paciência. As coisas podem andar mais devagar. Não force a barra.",
          tips: [
            "Trabalhe em colaboração, não isolado.",
            "Use a intuição para decidir o timing das ações.",
            "Se sentir bloqueio, pare e respire. A força bruta não funciona hoje."
          ],
        );
      case 3:
        return const StrategyRecommendation(
          mode: StrategyMode.grounding,
          methodologyName: "GTD (Getting Things Done)",
          reason: "Dia de criatividade e comunicação. Sua mente estará cheia de ideias, o que pode gerar ansiedade.",
          tips: [
            "Tire tudo da cabeça: anote cada ideia imediatamente.",
            "Faça listas antes de agir.",
            "Cuidado para não começar 10 coisas e não terminar nenhuma."
          ],
        );
      case 4:
        return const StrategyRecommendation(
          mode: StrategyMode.focus,
          methodologyName: "Deep Work (Trabalho Focado)",
          reason: "Dia de trabalho duro, ordem e construção. A energia pede disciplina e rotina.",
          tips: [
            "Organize seu espaço físico antes de começar.",
            "Siga um cronograma rígido hoje.",
            "Foque nos detalhes e na qualidade, não na velocidade."
          ],
        );
      case 5:
        return const StrategyRecommendation(
          mode: StrategyMode.grounding,
          methodologyName: "Gestão de Imprevistos",
          reason: "Dia de mudanças e liberdade. O inesperado vai acontecer. Rigidez vai te quebrar.",
          tips: [
            "Deixe espaços vazios na agenda para imprevistos.",
            "Seja flexível. Se o plano mudar, adapte-se rápido.",
            "Use listas curtas para não se perder no caos."
          ],
        );
      case 6:
        return const StrategyRecommendation(
          mode: StrategyMode.flow,
          methodologyName: "Harmonia & Responsabilidade",
          reason: "Dia voltado para família, casa e responsabilidades. O foco está nas pessoas, não nas tarefas.",
          tips: [
            "Resolva pendências domésticas ou familiares primeiro.",
            "Trabalhe em um ambiente harmonioso e bonito.",
            "Ajude alguém hoje. A energia flui através do serviço."
          ],
        );
      case 7:
        return const StrategyRecommendation(
          mode: StrategyMode.rescue,
          methodologyName: "Mini Habits (Mini Hábitos)",
          reason: "Dia de introspecção e análise. A energia física pode estar baixa. Não se cobre produtividade excessiva.",
          tips: [
            "Faça o mínimo essencial. Metas ridículas (ex: 'ler 1 página').",
            "Tire tempo para ficar sozinho e pensar.",
            "Evite decisões financeiras ou materiais importantes."
          ],
        );
      case 8:
        return const StrategyRecommendation(
          mode: StrategyMode.focus,
          methodologyName: "Execução de Alto Impacto",
          reason: "Dia de poder e resultados materiais. É hora de colher o que plantou e focar no lucro/sucesso.",
          tips: [
            "Foque nas tarefas que trazem retorno financeiro ou visibilidade.",
            "Comporte-se como um executivo: delegue o que puder.",
            "Vista-se para o sucesso, mesmo em casa."
          ],
        );
      case 9:
        return const StrategyRecommendation(
          mode: StrategyMode.flow,
          methodologyName: "Limpeza & Conclusão",
          reason: "Dia de encerramentos. Não comece nada novo. Termine o que está pendente e limpe o terreno.",
          tips: [
            "Faça uma faxina (física ou digital).",
            "Termine tarefas pendentes há tempos.",
            "Doe o que não usa mais. Abra espaço para o novo (que vem no dia 1)."
          ],
        );
      case 11:
      case 22:
        return const StrategyRecommendation(
          mode: StrategyMode.rescue,
          methodologyName: "Gestão de Energia (Mestre)",
          reason: "Dia Mestre. Alta voltagem espiritual e nervosa. Grande potencial, mas risco de burnout.",
          tips: [
            "Mantenha os pés no chão. Respire fundo.",
            "Use sua intuição para guiar grandes visões.",
            "Se sentir sobrecarregado, pare tudo e medite por 5 minutos."
          ],
        );
      default:
        // Fallback para dia 1 se algo der errado
        return const StrategyRecommendation(
          mode: StrategyMode.focus,
          methodologyName: "The One Thing",
          reason: "Dia de focar no essencial.",
          tips: ["Escolha uma prioridade e vá em frente."],
        );
    }
  }
}
