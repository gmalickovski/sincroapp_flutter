import 'dart:convert';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';

class AssistantPromptBuilder {
  // Helper para determinar saudação baseada no horário
  static String _getSaudacao(String nome, DateTime agora) {
    final hora = agora.hour;
    String periodo;
    if (hora >= 5 && hora < 12) {
      periodo = 'Bom dia';
    } else if (hora >= 12 && hora < 18) {
      periodo = 'Boa tarde';
    } else {
      periodo = 'Boa noite';
    }
    return nome.isNotEmpty ? '$periodo, $nome' : periodo;
  }

  static String build({
    required String question,
    required UserModel user,
    required NumerologyResult numerology,
    required List<TaskModel> tasks,
    required List<Goal> goals,
    required List<JournalEntry> recentJournal,
    bool isFirstMessageOfDay = false, // Novo parâmetro para controlar saudação
    List<AssistantMessage> chatHistory = const [],
  }) {
    final tasksCompact = tasks.take(30).map((t) => {
          'id': t.id,
          'title': t.text,
          'dueDate': t.dueDate?.toIso8601String().split('T').first,
          'goalId': t.journeyId,
          'goalTitle': t.journeyTitle,
          'completed': t.completed,
        });

    final goalsCompact = goals.take(20).map((g) => {
          'id': g.id,
          'title': g.title,
          'progress': g.progress,
          'targetDate': g.targetDate?.toIso8601String().split('T').first,
          'subTasks': g.subTasks.map((st) => st.title).toList(),
        });

    final journalCompact = recentJournal.take(10).map((j) => {
          'id': j.id,
          'createdAt': j.createdAt.toIso8601String(),
          'personalDay': j.personalDay,
          'mood': j.mood,
          'text': j.content,
        });

    // Numerologia COMPLETA (incluindo novos cálculos)
    final numerologySummary = {
      'diaPessoal': numerology.numeros['diaPessoal'],
      'mesPessoal': numerology.numeros['mesPessoal'],
      'anoPessoal': numerology.numeros['anoPessoal'],
      'destino': numerology.numeros['destino'],
      'expressao': numerology.numeros['expressao'],
      'motivacao': numerology.numeros['motivacao'],
      'impressao': numerology.numeros['impressao'],
      'missao': numerology.numeros['missao'],
      'talentoOculto': numerology.numeros['talentoOculto'],
      'respostaSubconsciente': numerology.numeros['respostaSubconsciente'],
      'cicloDeVidaAtual': numerology.estruturas['cicloDeVidaAtual'],
      'licoesCarmicas': numerology.listas['licoesCarmicas'],
      'debitosCarmicos': numerology.listas['debitosCarmicos'],
      'tendenciasOcultas': numerology.listas['tendenciasOcultas'],
      'harmoniaConjugal': numerology.estruturas['harmoniaConjugal'],
      // Aptidões Profissionais: utilizamos o número de Expressão como base
      'aptidoesProfissionais': numerology.numeros['aptidoesProfissionais'],
      'desafio': numerology.numeros['desafio'],
      // Desafios detalhados
      'desafiosMapa': numerology.estruturas['desafios'],
      // Momentos decisivos + atual
      'momentosDecisivos': numerology.estruturas['momentosDecisivos'],
      'momentoDecisivoAtual': numerology.estruturas['momentoDecisivoAtual'],
    };

    // Pré-calcula Dia Pessoal para os próximos 30 dias (hoje + 29)
    final now = DateTime.now();
    final personalDaysNext30 = List.generate(30, (i) {
      final d =
          DateTime.utc(now.year, now.month, now.day).add(Duration(days: i));
      final n = NumerologyEngine(
              nomeCompleto:
                  numerology.idade >= 0 ? user.nomeAnalise : user.nomeAnalise,
              dataNascimento: user.dataNasc)
          .calculatePersonalDayForDate(d);
      return {
        'date': d.toIso8601String().split('T').first,
        'diaPessoal': n,
      };
    });

    final contextObj = {
      'user': {
        'nomeAnalise': user.nomeAnalise,
        'primeiroNome': user.primeiroNome,
        'dataNasc': user.dataNasc,
        'idade': numerology.idade,
      },
      'numerologyToday': numerologySummary,
      'personalDaysNext30': personalDaysNext30,
      'tasks': tasksCompact.toList(),
      'goals': goalsCompact.toList(),
      'recentJournal': journalCompact.toList(),
      // Estatísticas agregadas para personalização
      'stats': {
        'tasksTotal': tasks.length,
        'tasksCompletedToday': tasks.where((t) => t.completed).length,
        'goalsActive': goals.length,
        'journalEntriesRecent': recentJournal.length,
        'progressAvg': goals.isEmpty
            ? 0
            : (goals.map((g) => g.progress).reduce((a, b) => a + b) /
                goals.length),
      },
      'chatHistory': chatHistory
          .take(8)
          .map((m) => {
                'role': m.role,
                'content': m.content,
                'time': m.time.toIso8601String(),
              })
          .toList(),
    };

    final contextJson = const JsonEncoder.withIndent('  ').convert(contextObj);

    // Determina a saudação (só se for primeira mensagem do dia)
    final saudacao = isFirstMessageOfDay
        ? '${_getSaudacao(user.primeiroNome, DateTime.now())}! 😊\n\n'
        : '';

    return '''
Você é um assistente pessoal de produtividade e autoconhecimento chamado **Sincro AI**, especializado em **Numerologia Cabalística** e ciência da vibração energética.

**PERSONALIDADE E TOM:**
${isFirstMessageOfDay ? '- Inicie a conversa com: "$saudacao"' : '- Continue a conversa de forma natural, sem repetir saudações'}

**EMBASAMENTO TÉCNICO (CRUCIAL):**

**DÉBITOS KÁRMICOS (se aplicável):**
${numerologySummary['debitosCarmicos'].isNotEmpty ? '''
⚠️ O usuário possui débitos kármicos nos números ${numerologySummary['debitosCarmicos'].join(', ')}. 
Use esses insights quando relevante para a conversa.
''' : ''}

**INSTRUÇÕES DE RESPOSTA:**
Responda à pergunta do usuário e retorne um JSON ÚNICO no seguinte formato:
{
  "answer": "mensagem de resposta ao usuário (calorosa, inspiradora e baseada em numerologia)",
  "actions": [
    {
      "type": "schedule" | "create_task" | "create_goal",
      "title": "título da tarefa/meta/evento",
      "date": "YYYY-MM-DD",        // para ações pontuais; para create_goal use como targetDate
      "startDate": "YYYY-MM-DD",   // para intervalos (opcional)
      "endDate": "YYYY-MM-DD",     // para intervalos (opcional)
      "subtasks": ["opcional, lista de subtarefas para metas"],
      "description": "quando type=create_goal, descrição resumida (motivação)"
    }
  ]
}

**REGRAS IMPORTANTES:**

**FLUXO PARA AGENDAMENTOS (compromissos com data/hora):**
1. Se o usuário pedir para agendar em uma data específica (ex.: "agendar 12/11 às 14h para consulta"), avalie a data pedida usando os dados em personalDaysNext30 (campo do contexto). Compare o Dia Pessoal da data solicitada com alternativas nos próximos dias.
2. Se a data solicitada NÃO for das mais favoráveis para o contexto do compromisso, sugira a PRÓXIMA data mais favorável dentro dos próximos 30 dias e explique o porquê (ex.: "Dia Pessoal 3 favorece comunicação; 8 favorece negócios e resultados").
3. No JSON, retorne DUAS actions "schedule":
  - uma para a data original pedida (respeito à preferência do usuário)
  - outra para a data sugerida (alternativa otimizada)
  Em "answer", pergunte: "Prefere alterar para <data sugerida> ou manter <data original>?" e aguarde confirmação.
4. Se o usuário fornecer HORA, inclua a hora no campo "title" de forma humana (ex.: "Consulta – 14:00"), mas mantenha "date" em YYYY-MM-DD (o sistema armazena somente a data).
5. Se o usuário não especificar data, sugira 1–3 datas favoráveis (com justificativa) e inclua as respectivas actions "schedule".

Observação de referência numerológica para agendamentos (guia, não rígido):

**FLUXO PARA CRIAÇÃO DE METAS:**
Se o usuário pedir para criar uma meta:
1. SEMPRE pergunte primeiro: "Por que essa meta é importante para você?" e "Qual é a data alvo (YYYY-MM-DD)?" — mesmo que o usuário já tenha dado um título. Não retorne actions nesse primeiro passo.
2. Aguarde a próxima mensagem do usuário (o histórico está em chatHistory) e, quando houver as 3 informações OBRIGATÓRIAS — (a) título, (b) motivação/descrição, (c) data alvo — então retorne a action "create_goal" no formato abaixo (use o campo "date" como data alvo):
   {
     "answer": "Entendi! Vou criar essa meta para você...",
     "actions": [{
       "type": "create_goal",
       "title": "título da meta",
       "description": "resumo compilado da motivação do usuário",
       "date": "YYYY-MM-DD",
       "subtasks": ["marco 1", "marco 2", ..., "marco 5-10"]
     }]
   }
3. Os marcos (subtasks) devem ser 5-10 passos práticos e progressivos para alcançar a meta.

**FLUXO PARA ANÁLISE DE HARMONIA CONJUGAL:**
Se o usuário perguntar sobre compatibilidade/harmonia conjugal com alguém (marido, esposa, namorado, namorada, parceiro, etc.):
1. SEMPRE pergunte: "Para calcular a harmonia conjugal, preciso do nome completo de nascimento e data de nascimento (DD/MM/AAAA) da pessoa. Pode me fornecer?"
2. NÃO retorne actions nesse primeiro passo.
3. Aguarde a próxima mensagem com os dados (verifique chatHistory).
4. Quando tiver nome completo E data de nascimento, retorne action especial:
   {
     "answer": "Analisando a harmonia conjugal entre vocês...",
     "actions": [{
       "type": "analyze_harmony",
       "title": "nome completo do parceiro",
       "date": "YYYY-MM-DD"
     }]
   }
5. IMPORTANTE: Cálculos de terceiros são permitidos APENAS para harmonia conjugal. Não calcule outros aspectos numerológicos de terceiros.

**CONTEXTO DO USUÁRIO (JSON):**
$contextJson

**PERGUNTA DO USUÁRIO:**
"""
$question
"""
''';
  }
}
