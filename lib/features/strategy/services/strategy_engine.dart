import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';
import 'package:sincro_app_flutter/features/strategy/models/strategy_recommendation.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';

class StrategyEngine {
  static StrategyRecommendation getRecommendation(int personalDay) {
    // Busca o conteúdo da Bússola para o dia (ou fallback para dia 1 se não encontrar)
    final bussola = ContentData.bussolaAtividades[personalDay] ??
        ContentData.bussolaAtividades[1]!;

    switch (personalDay) {
      case 1:
        return StrategyRecommendation(
          mode: StrategyMode.focus,
          methodologyName: "The One Thing",
          reason: "Dia de novos inícios e liderança. A energia está alta para começar, mas dispersão pode ser fatal.",
          tips: [
            "Escolha APENAS UMA grande meta para hoje.",
            "Evite multitarefa. Comece o que é mais importante.",
            "Diga 'não' para distrações que não iniciam algo novo."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      case 2:
        return StrategyRecommendation(
          mode: StrategyMode.flow,
          methodologyName: "Gestão Emocional / Pomodoro Suave",
          reason: "Dia de parcerias e paciência. As coisas podem andar mais devagar. Não force a barra.",
          tips: [
            "Trabalhe em colaboração, não isolado.",
            "Use a intuição para decidir o timing das ações.",
            "Se sentir bloqueio, pare e respire. A força bruta não funciona hoje."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      case 3:
        return StrategyRecommendation(
          mode: StrategyMode.grounding,
          methodologyName: "GTD (Getting Things Done)",
          reason: "Dia de criatividade e comunicação. Sua mente estará cheia de ideias, o que pode gerar ansiedade.",
          tips: [
            "Tire tudo da cabeça: anote cada ideia imediatamente.",
            "Faça listas antes de agir.",
            "Cuidado para não começar 10 coisas e não terminar nenhuma."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      case 4:
        return StrategyRecommendation(
          mode: StrategyMode.focus,
          methodologyName: "Deep Work (Trabalho Focado)",
          reason: "Dia de trabalho duro, ordem e construção. A energia pede disciplina e rotina.",
          tips: [
            "Organize seu espaço físico antes de começar.",
            "Siga um cronograma rígido hoje.",
            "Foque nos detalhes e na qualidade, não na velocidade."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      case 5:
        return StrategyRecommendation(
          mode: StrategyMode.grounding,
          methodologyName: "Gestão de Imprevistos",
          reason: "Dia de mudanças e liberdade. O inesperado vai acontecer. Rigidez vai te quebrar.",
          tips: [
            "Deixe espaços vazios na agenda para imprevistos.",
            "Seja flexível. Se o plano mudar, adapte-se rápido.",
            "Use listas curtas para não se perder no caos."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      case 6:
        return StrategyRecommendation(
          mode: StrategyMode.flow,
          methodologyName: "Harmonia & Responsabilidade",
          reason: "Dia voltado para família, casa e responsabilidades. O foco está nas pessoas, não nas tarefas.",
          tips: [
            "Resolva pendências domésticas ou familiares primeiro.",
            "Trabalhe em um ambiente harmonioso e bonito.",
            "Ajude alguém hoje. A energia flui através do serviço."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      case 7:
        return StrategyRecommendation(
          mode: StrategyMode.rescue,
          methodologyName: "Mini Habits (Mini Hábitos)",
          reason: "Dia de introspecção e análise. A energia física pode estar baixa. Não se cobre produtividade excessiva.",
          tips: [
            "Faça o mínimo essencial. Metas ridículas (ex: 'ler 1 página').",
            "Tire tempo para ficar sozinho e pensar.",
            "Evite decisões financeiras ou materiais importantes."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      case 8:
        return StrategyRecommendation(
          mode: StrategyMode.focus,
          methodologyName: "Execução de Alto Impacto",
          reason: "Dia de poder e resultados materiais. É hora de colher o que plantou e focar no lucro/sucesso.",
          tips: [
            "Foque nas tarefas que trazem retorno financeiro ou visibilidade.",
            "Comporte-se como um executivo: delegue o que puder.",
            "Vista-se para o sucesso, mesmo em casa."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      case 9:
        return StrategyRecommendation(
          mode: StrategyMode.flow,
          methodologyName: "Limpeza & Conclusão",
          reason: "Dia de encerramentos. Não comece nada novo. Termine o que está pendente e limpe o terreno.",
          tips: [
            "Faça uma faxina (física ou digital).",
            "Termine tarefas pendentes há tempos.",
            "Doe o que não usa mais. Abra espaço para o novo (que vem no dia 1)."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      case 11:
      case 22:
        return StrategyRecommendation(
          mode: StrategyMode.rescue,
          methodologyName: "Gestão de Energia (Mestre)",
          reason: "Dia Mestre. Alta voltagem espiritual e nervosa. Grande potencial, mas risco de burnout.",
          tips: [
            "Mantenha os pés no chão. Respire fundo.",
            "Use sua intuição para guiar grandes visões.",
            "Se sentir sobrecarregado, pare tudo e medite por 5 minutos."
          ],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
      default:
        // Fallback para dia 1 se algo der errado
        return StrategyRecommendation(
          mode: StrategyMode.focus,
          methodologyName: "The One Thing",
          reason: "Dia de focar no essencial.",
          tips: ["Escolha uma prioridade e vá em frente."],
          potencializar: bussola.potencializar,
          atencao: bussola.atencao,
        );
    }
  }

  // Helper method to calculate mode from personal day (for AI prompts)
  static StrategyMode calculateMode(int personalDay) {
    final recommendation = getRecommendation(personalDay);
    return recommendation.mode;
  }

  // Helper method to get mode title
  static String getModeTitle(StrategyMode mode) {
    switch (mode) {
      case StrategyMode.focus:
        return "Foco Máximo";
      case StrategyMode.flow:
        return "Fluxo Intuitivo";
      case StrategyMode.grounding:
        return "Aterramento";
      case StrategyMode.rescue:
        return "Modo Resgate";
    }
  }

  // Helper method to get mode description
  static String getModeDescription(StrategyMode mode) {
    switch (mode) {
      case StrategyMode.focus:
        return "Energia de execução alta. Priorize UMA tarefa de alto impacto.";
      case StrategyMode.flow:
        return "Dia de conexões e criatividade. Siga sua intuição.";
      case StrategyMode.grounding:
        return "Organize, estruture e limpe pendências.";
      case StrategyMode.rescue:
        return "Energia baixa. Foque em mini-hábitos e autocuidado.";
    }
  }
}
