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

    // Arcanos descontinuados: removido o branch que buscava 'arcanos'.
    if (type == 'ciclosDeVida') {
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

    // --- 2. O TEMPLATE DO PROMPT (v8 - Baseado no JS - MELHORADO) ---
    return """
Você é um Coach de Produtividade e Estrategista Pessoal com expertise em numerologia pitagórica.
Sua missão é criar marcos estratégicos NOVOS, ESPECÍFICOS e COMPLEMENTARES para quebrar uma meta em etapas acionáveis.

═══════════════════════════════════════════════════════════════════
📋 DOSSIÊ COMPLETO DO USUÁRIO
═══════════════════════════════════════════════════════════════════

**1. A META PRINCIPAL:**
- Título: "${goal.title}"
- Descrição/Motivação: "${goal.description.isNotEmpty ? goal.description : "Não fornecida"}"
${goal.targetDate != null ? '- Prazo Final Desejado: ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)}' : '- Prazo: Não definido'}
- Contexto Adicional: "${additionalInfo.isNotEmpty ? additionalInfo : "Nenhum"}"

**2. MARCOS JÁ CRIADOS (NÃO REPITA):**
$milestonesContext
${existingSubTasks.isNotEmpty ? '\n⚠️ CRÍTICO: Suas sugestões devem ser DIFERENTES e COMPLEMENTARES aos marcos acima.' : '✓ Primeira vez criando marcos para esta meta.'}

**3. PERFIL NUMEROLÓGICO DO USUÁRIO:**
${user.nomeAnalise.isNotEmpty ? '- Nome de Análise: ${user.nomeAnalise}' : ''}
- Data de Nascimento: ${user.dataNasc}
- $anoPessoalContext
- $mesPessoalContext
- **Ciclos de Vida:**
$cicloDeVidaContext

**4. CONTEXTO DE ATIVIDADES RECENTES:**
$tasksContext

**5. GUIA DE VIBRAÇÕES DOS DIAS PESSOAIS:**
(Use para escolher as melhores datas para cada tipo de ação)
$diaPessoalContext

═══════════════════════════════════════════════════════════════════
🎯 INSTRUÇÕES ESTRATÉGICAS
═══════════════════════════════════════════════════════════════════

**PASSO 1 - ANÁLISE CONTEXTUAL:**
- Leia TODOS os marcos existentes e identifique qual fase da jornada já foi coberta
- Identifique lacunas: O que falta para completar a meta?
- Considere o Ano e Mês Pessoal para definir o tom (expansão? consolidação? transformação?)

**PASSO 2 - CRIE MARCOS ESTRATÉGICOS:**
Crie exatamente **5 a 7 marcos NOVOS** que:
- Sejam específicos e acionáveis (não genéricos)
- Representem os PRÓXIMOS PASSOS lógicos após os marcos existentes
- Cubram diferentes aspectos da meta (planejamento → execução → validação → ajuste)
- Sejam progressivos (do mais simples ao mais complexo, ou vice-versa se fizer sentido)
- Tenham títulos claros que comecem com VERBOS DE AÇÃO

**PASSO 3 - ATRIBUA DATAS INTELIGENTES:**
Para cada marco:
1. Calcule o Dia Pessoal de datas futuras usando a data de nascimento (${user.dataNasc})
2. Escolha datas que tenham vibrações alinhadas com o tipo de ação:
   - Dia 1: Inícios, lançamentos, primeiros passos
   - Dia 2: Cooperação, parcerias, networking
   - Dia 3: Comunicação, apresentações, criatividade
   - Dia 4: Planejamento, estruturação, organização
   - Dia 5: Mudanças, testes, experimentação
   - Dia 6: Conclusão, responsabilidade, entrega de resultados
   - Dia 7: Reflexão, análise, estudo profundo
   - Dia 8: Realização material, execução prática
   - Dia 9: Finalização, encerramento de ciclos
   - Dia 11: Inspiração, visão, projetos maiores
   - Dia 22: Grandes realizações, projetos de impacto

3. Espalhe os marcos ao longo de pelo menos 30-60 dias (não concentre tudo em 1 semana)
4. Datas devem ser **sempre futuras**, começando de $formattedStartDate

**PASSO 4 - VALIDAÇÃO FINAL:**
Antes de responder, certifique-se que:
- ✓ Nenhum marco repete os já existentes
- ✓ Títulos são específicos (não "Executar tarefa" mas "Validar hipótese X com 10 usuários")
- ✓ Todas as datas estão no formato YYYY-MM-DD
- ✓ As datas fazem sentido cronologicamente
- ✓ Cada marco tem uma vibração adequada ao seu propósito

═══════════════════════════════════════════════════════════════════
📤 FORMATO DE RESPOSTA (OBRIGATÓRIO)
═══════════════════════════════════════════════════════════════════

Responda APENAS com um array JSON válido. NÃO inclua:
- A palavra "json" ou marcadores de código (\`\`\`)
- Explicações ou texto adicional
- Quebras de linha desnecessárias

**Estrutura Exata:**
[
  {"title": "Verbo + ação específica e mensurável", "date": "YYYY-MM-DD"},
  {"title": "Outro verbo + ação clara", "date": "YYYY-MM-DD"}
]

**Exemplo Correto:**
[
  {"title": "Definir 3 indicadores-chave de sucesso para a meta", "date": "2025-11-10"},
  {"title": "Criar protótipo inicial e validar com 5 pessoas", "date": "2025-11-18"},
  {"title": "Analisar feedback e ajustar estratégia", "date": "2025-11-25"},
  {"title": "Executar primeira versão completa do plano", "date": "2025-12-02"},
  {"title": "Apresentar resultados e coletar aprendizados", "date": "2025-12-09"}
]
""";
  }
}
