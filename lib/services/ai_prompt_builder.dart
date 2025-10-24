// lib/services/ai_prompt_builder.dart
// (ARQUIVO COMPLETO ATUALIZADO v8 - Corrigido com goal_model.dart)

import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
// Importa o SubTask junto com o Goal
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class AIPromptBuilder {
  // Helper _getDesc (Mantido - é o 'getDesc' do seu Dart)
  static String _getDesc(String type, int? number) {
    if (number == null) return "Não disponível.";
    VibrationContent? content;
    Map<dynamic, VibrationContent>? sourceMap;

    if (type == 'arcanoRegente' || type == 'arcanoAtual') {
      sourceMap = ContentData.vibracoes['arcanos'];
    } else if (type == 'ciclosDeVida') {
      sourceMap = ContentData.textosCiclosDeVida;
    } else {
      sourceMap = ContentData.vibracoes[type];
    }

    if (sourceMap == null) return "Tipo de vibração desconhecido: $type";
    content = sourceMap[number] ?? sourceMap[number.toString()];
    if (content == null) return "Descrição não encontrada para $type $number.";
    // Usamos o .descricaoCompleta que parece ser o padrão no seu app
    return "${content.titulo}: ${content.descricaoCompleta}";
  }

  // --- MÉTODO buildTaskSuggestionPrompt (PROMPT v8 - Corrigido) ---
  static String buildTaskSuggestionPrompt({
    required Goal goal,
    required UserModel user,
    required String additionalInfo,
    required List<TaskModel> userTasks,
    required NumerologyResult numerologyResult,
    required List<SubTask> existingSubTasks, // CORREÇÃO (v8)
  }) {
    // --- 1. Preparação dos Dados para o Prompt (do JS) ---

    // Guia do Dia Pessoal (do JS)
    final diaPessoalContext =
        ContentData.vibracoes['diaPessoal']!.entries.map((entry) {
      final day = entry.key;
      final content = entry.value;
      return "Dia Pessoal $day (${content.titulo}): ${content.descricaoCompleta}";
    }).join('\n');

    // Contexto de Numerologia (do JS)
    final int? anoPessoal = numerologyResult.numeros['anoPessoal'];
    final int? mesPessoal = numerologyResult.numeros['mesPessoal'];

    // Pega os regentes de CADA ciclo (do JS)
    final int? ciclo1Regente =
        numerologyResult.estruturas['ciclosDeVida']?['ciclo1']?['regente'];
    final int? ciclo2Regente =
        numerologyResult.estruturas['ciclosDeVida']?['ciclo2']?['regente'];
    final int? ciclo3Regente =
        numerologyResult.estruturas['ciclosDeVida']?['ciclo3']?['regente'];

    final anoPessoalContext =
        "Ano Pessoal ${anoPessoal ?? '-'}: ${_getDesc('anoPessoal', anoPessoal)}";
    final mesPessoalContext =
        "Mês Pessoal ${mesPessoal ?? '-'}: ${_getDesc('mesPessoal', mesPessoal)}";

    final cicloDeVidaContext = """
    - Primeiro Ciclo de Vida (Formação): Vibração ${ciclo1Regente ?? '-'} - ${_getDesc('ciclosDeVida', ciclo1Regente)}
    - Segundo Ciclo de Vida (Produção): Vibração ${ciclo2Regente ?? '-'} - ${_getDesc('ciclosDeVida', ciclo2Regente)}
    - Terceiro Ciclo de Vida (Colheita): Vibração ${ciclo3Regente ?? '-'} - ${_getDesc('ciclosDeVida', ciclo3Regente)}
    """;

    // Data de Início (do JS)
    final formattedStartDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Contexto de Tarefas (do JS)
    final tasksContext = userTasks.isNotEmpty
        ? userTasks
            .map((task) =>
                "- [${task.completed ? 'X' : ' '}] ${task.text} (Meta: ${task.journeyTitle ?? 'N/A'})")
            .join('\n')
        : "Nenhuma tarefa recente registrada.";

    // --- CORREÇÃO (v8): Contexto dos marcos existentes (subTasks) ---
    final milestonesContext = existingSubTasks.isNotEmpty
        ? existingSubTasks
            // Acessa a propriedade .title do objeto SubTask
            .map((task) => "- ${task.title}")
            .join('\n')
        : "Nenhum marco foi criado para esta meta ainda.";
    // --- FIM DA CORREÇÃO ---

    // --- 2. O TEMPLATE DO PROMPT (v8 - Baseado no JS) ---
    // Este prompt pede à IA para CALCULAR as datas
    return """
    Você é um Coach de Produtividade e Estrategista Pessoal, com profundo conhecimento em numerologia.
    Sua missão é criar um plano de ação estratégico, quebrando uma meta principal em 5 a 7 marcos NOVOS e COMPLEMENTARES, atribuindo a data ideal para cada um.

    **DOSSIÊ DO USUÁRIO:**

    **1. A META:**
    - Meta Principal: "${goal.title}"
    - Motivação/Descrição: "${goal.description.isNotEmpty ? goal.description : "Não fornecida"}"
    - Informações Adicionais do Usuário: "${additionalInfo.isNotEmpty ? additionalInfo : "Nenhuma"}"

    **2. MARCOS JÁ EXISTENTES NA META (para evitar repetição):**
    $milestonesContext

    **3. CONTEXTO DE LONGO PRAZO (O CENÁRIO GERAL):**
    - $anoPessoalContext
    - $mesPessoalContext
    - Ciclos de Vida: $cicloDeVidaContext
    
    **4. CONTEXTO DE CURTO PRAZO (ATIVIDADES RECENTES):**
    - Últimas Tarefas do Usuário (em todas as metas): $tasksContext

    **5. FERRAMENTA PARA DATAS (A VIBRAÇÃO DO DIA):**
    - Data de Início do Planejamento: $formattedStartDate
    - Data de Nascimento do Usuário: ${user.dataNasc} (formato dd/MM/yyyy. use para calcular o dia pessoal de datas futuras)
    - Guia do Dia Pessoal (Use para escolher a vibração): 
    $diaPessoalContext

    ---
    **SUA TAREFA ESTRATÉGICA:**

    1.  **ANÁLISE:** Primeiro, leia os "MARCOS JÁ EXISTENTES". Sua principal prioridade é NÃO sugerir marcos que sejam redundantes ou muito similares aos que já estão listados. Suas sugestões devem ser os PRÓXIMOS PASSOS lógicos.

    2.  **SÍNTESE DO MOMENTO:** Analise o restante do dossiê (Ano Pessoal, Mês, Ciclos) para definir o **TEMA** do plano. O usuário está num ano de inícios? De finalizações? Use isso para guiar o tom das sugestões.

    3.  **CRIE MARCOS NOVOS E COMPLEMENTARES:** Crie de 5 a 7 marcos que continuem o trabalho já feito. Se os marcos existentes são sobre "planejamento", sugira marcos sobre "execução". Se já existem marcos de "criação", sugira sobre "divulgação" ou "análise".
    
    4.  **ATRIBUA DATAS INTELIGENTES:** Para cada novo marco, encontre a data futura ideal (a partir de $formattedStartDate) usando o **Dia Pessoal** (calculado com a Data de Nascimento ${user.dataNasc}) e o **Guia do Dia Pessoal**. (Ex: Planejamento em Dia 4, Lançamento em Dia 1, Conclusão em Dia 9).

    5.  **FORMATO DA RESPOSTA:** Responda **APENAS** com um array de objetos JSON. Não inclua a palavra "json" ou marcadores de código ```. Cada objeto deve ter as chaves "title" (string) e "date" (string no formato "YYYY-MM-DD").

    **Exemplo de Resposta Esperada (APENAS O ARRAY):**
    [
      {"title": "Executar a primeira fase do plano de ação", "date": "2025-10-27"},
      {"title": "Analisar os resultados iniciais e ajustar a estratégia", "date": "2025-11-04"},
      {"title": "Iniciar a divulgação nas redes sociais (Dia 1)", "date": "2025-11-07"}
    ]
    """;
  }
}
