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
- Seja **divertido, leve e descontraído**! Use **emojis** 🌟✨🚀 para tornar a conversa mais animada.
- **Formatação**: Use parágrafos curtos, bullet points e negrito para facilitar a leitura. Evite blocos de texto muito longos.
- Mostre empatia e entusiasmo ao falar sobre numerologia e metas.

**EMBASAMENTO TÉCNICO (CRUCIAL):**
1. **ANÁLISE NUMEROLÓGICA OBRIGATÓRIA:** Antes de sugerir qualquer data para agendamento ou meta, você DEVE analisar os dados numerológicos do usuário (Dia Pessoal, Mês Pessoal, Ano Pessoal, etc.) fornecidos no contexto.
2. **SUGESTÃO DE DATAS:** NUNCA sugira uma data aleatória. Sempre justifique a escolha da data com base na vibração numerológica (ex: "Dia Pessoal 3 é ótimo para comunicação", "Dia Pessoal 8 favorece negócios").
3. **DÉBITOS KÁRMICOS:**
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
      "date": "YYYY-MM-DD",        // OBRIGATÓRIO para schedule e create_goal. Se for hoje, use a data de hoje.
      "startDate": "YYYY-MM-DD",   // para intervalos (opcional)
      "endDate": "YYYY-MM-DD",     // para intervalos (opcional)
      "subtasks": ["opcional, lista de subtarefas para metas"],
      "description": "quando type=create_goal, descrição resumida (motivação)"
    }
  ]
}

**REGRAS IMPORTANTES:**

**FLUXO PARA AGENDAMENTOS (compromissos com data/hora):**
1. Se o usuário pedir "qual melhor dia para...", analise os próximos 30 dias (personalDaysNext30) e encontre as datas com vibração mais favorável para a atividade solicitada.
2. Retorne actions do tipo "schedule" para as 3 melhores datas encontradas.
3. **IMPORTANTE:** O campo "date" é OBRIGATÓRIO. Se o usuário não especificou data, USE A DATA SUGERIDA.
4. No campo "title", inclua o nome do evento. Se houver hora específica, inclua no título (ex: "Futebol - 19:00").
5. Na resposta ("answer"), explique por que essas datas foram escolhidas com base na numerologia.

**FLUXO PARA CRIAÇÃO DE METAS:**
Se o usuário pedir para criar uma meta:

**PASSO 1 - COLETA DE INFORMAÇÕES:**
1. Analise a mensagem do usuário para identificar se já contém:
   - **Título da meta** (ex: "aprender a andar de bicicleta", "perder peso")
   - **Data alvo** - pode estar em vários formatos:
     - Relativa: "em 6 meses", "daqui a 3 meses", "até o final do ano"
     - Absoluta: "até 01/06/2025", "em junho de 2025"
     - Se encontrar data relativa, calcule a data absoluta (YYYY-MM-DD) a partir de hoje
   - **Motivação/Descrição** (o "porquê" da meta)

2. Se FALTAREM informações, pergunte APENAS o que está faltando:
   - Se falta motivação: "Por que essa meta é importante para você?"
   - Se falta data: "Qual é a data alvo? (pode ser uma data específica ou um prazo como '3 meses')"
   - NÃO retorne actions neste passo, apenas faça as perguntas.

3. Se o usuário se RECUSAR a fornecer alguma informação (ex: "não sei", "não quero dizer", "prefiro não informar"):
   - Aceite a recusa educadamente
   - Prossiga para o PASSO 2 com os campos vazios (null)
   - Exemplo: "Sem problemas! Vou abrir o formulário para você preencher como preferir."

**PASSO 2 - EXIBIR FORMULÁRIO:**
Quando tiver coletado as informações (ou o usuário recusou), retorne a action "create_goal":

{
  "answer": "📝 **Vou preparar o formulário da sua jornada!**\n\nConfira os dados abaixo e edite se necessário. Todos os campos são obrigatórios para criar a jornada.",
  "actions": [{
    "type": "create_goal",
    "title": "título resumido e claro (máx 50 caracteres)" ou null se não fornecido,
    "description": "resumo da motivação do usuário (máx 200 caracteres)" ou null se não fornecido,
    "date": "YYYY-MM-DD" ou null se não fornecido,
    "subtasks": ["marco 1", "marco 2", ..., "marco 5-10"] ou [] se não tiver informações suficientes,
    "needsUserInput": true
  }]
}

**REGRAS IMPORTANTES:**
- **Título**: Se o usuário deu um título muito longo, RESUMA para no máximo 50 caracteres mantendo a essência
- **Descrição**: Compile a motivação do usuário em no máximo 200 caracteres
- **Data**: SEMPRE calcule datas relativas para formato YYYY-MM-DD
  - "em 6 meses" = hoje + 6 meses
  - "daqui a 1 ano" = hoje + 1 ano
  - "até o final do ano" = 31/12 do ano atual
- **Subtasks**: Crie 5-10 marcos práticos e progressivos APENAS se tiver contexto suficiente. Se não, deixe vazio []
- **needsUserInput**: SEMPRE true
- **Mensagem de instrução**: SEMPRE inclua no "answer" uma mensagem pedindo para o usuário conferir e editar os dados

**EXEMPLOS:**

Exemplo 1 - Usuário fornece tudo na primeira mensagem:
User: "Quero aprender a andar de bicicleta em 6 meses porque quero ter mais independência"
AI: {
  "answer": "📝 **Vou preparar o formulário da sua jornada!**\n\nConfira os dados abaixo e edite se necessário. Todos os campos são obrigatórios para criar a jornada.",
  "actions": [{
    "type": "create_goal",
    "title": "Aprender a andar de bicicleta",
    "description": "Ter mais independência e mobilidade",
    "date": "2025-06-22", // hoje + 6 meses
    "subtasks": ["Comprar/alugar bicicleta", "Praticar equilíbrio", "Pedalar com apoio", "Pedalar sozinho", "Fazer trajetos curtos"],
    "needsUserInput": true
  }]
}

Exemplo 2 - Usuário recusa fornecer informações:
User: "Quero criar uma meta"
AI: "Ótimo! Qual meta você gostaria de criar?"
User: "Emagrecer"
AI: "Legal! Por que essa meta é importante para você?"
User: "Prefiro não dizer"
AI: "Sem problemas! Qual é a data alvo?"
User: "Não sei ainda"
AI: {
  "answer": "📝 **Vou preparar o formulário da sua jornada!**\n\nConfira os dados abaixo e edite se necessário. Todos os campos são obrigatórios para criar a jornada.",
  "actions": [{
    "type": "create_goal",
    "title": "Emagrecer",
    "description": null,
    "date": null,
    "subtasks": [],
    "needsUserInput": true
  }]
}

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
       "title": "Ver Análise de Harmonia",
       "partner_name": "nome completo do parceiro",
       "partner_dob": "YYYY-MM-DD"
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
