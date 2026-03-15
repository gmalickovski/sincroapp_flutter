// lib/features/assistant/ai/ai_tool_handler.dart
//
// Executa as ferramentas ("function calls") solicitadas pela IA.
// Cada método corresponde a um function name definido em AiConfig.toolDefinitions.
// Retorna Map<String, dynamic> que é serializado e devolvido ao LLM.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/services/harmony_service.dart';
import 'package:sincro_app_flutter/features/assistant/ai/content_data_lookup.dart';
import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';
import 'package:sincro_app_flutter/features/strategy/services/strategy_engine.dart';

class AiToolHandler {
  final String _userId;
  static final _harmonyService = HarmonyService();

  AiToolHandler({required String userId}) : _userId = userId;

  /// Despacha a chamada de ferramenta pelo nome recebido da IA.
  Future<Map<String, dynamic>> dispatch(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    debugPrint('[AiToolHandler] Executando ferramenta: $toolName | args=$args');
    try {
      switch (toolName) {
        case 'buscar_tarefas_e_marcos':
          return await _buscarTarefasEMarcos(args);
        case 'calcular_numerologia':
          return _calcularNumerologia(args);
        case 'calcular_harmonia_conjugal':
          return _calcularHarmoniaConjugal(args);
        case 'buscar_conhecimento_sincro':
          return _buscarConhecimentoSincro(args);
        case 'buscar_relatorios_evolucao':
          return await _buscarRelatoriosEvolucao(args);
        case 'calcular_datas_favoraveis':
          return _calcularDatasFavoraveis(args);
        default:
          return {'error': 'Ferramenta desconhecida: $toolName'};
      }
    } catch (e, stack) {
      debugPrint('[AiToolHandler] ❌ Erro em $toolName: $e\n$stack');
      return {
        'error': 'Erro ao executar $toolName: $e',
        'tool': toolName,
      };
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FERRAMENTA 1: Buscar tarefas, agendamentos e marcos
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _buscarTarefasEMarcos(
    Map<String, dynamic> args,
  ) async {
    final tipoBusca = args['tipo_busca']?.toString() ?? 'todos';
    final termoBusca = (args['termo_busca']?.toString() ?? '').trim();
    final dataInicioStr = args['data_inicio']?.toString() ?? '';
    final dataFimStr = args['data_fim']?.toString() ?? '';
    final apenasPendentes = args['apenas_pendentes'] != false; // default true

    final supabase = Supabase.instance.client;

    // Select apenas colunas relevantes para a IA (otimiza tokens)
    var query = supabase
        .schema('sincroapp')
        .from('tasks')
        .select('id, text, completed, due_date, start_date, tags, '
            'journey_id, journey_title, goal_id, '
            'recurrence_type, recurrence_category, recurrence_interval, recurrence_days_of_week, '
            'task_type, reminder_at, duration_minutes, is_focus, completed_at')
        .eq('user_id', _userId);

    // Filtro de conclusão
    if (apenasPendentes) {
      query = query.eq('completed', false);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // foco_do_dia é tratado com lógica especial (múltiplas queries)
    // Os demais usam query única com filtros encadeados
    // ═══════════════════════════════════════════════════════════════════════
    if (tipoBusca == 'foco_do_dia') {
      return _buscarFocoDoDia(supabase, apenasPendentes);
    }

    // Filtro por tipo
    switch (tipoBusca) {
      case 'tarefas':
        // Tarefas sem data — excluindo flow templates (que são moldes, não tarefas)
        query = query
            .isFilter('due_date', null)
            .or('recurrence_category.is.null,recurrence_category.neq.flow');
        break;

      case 'agendamentos':
        // Compromissos COM data definida
        query = query.not('due_date', 'is', null);
        // Excluir flow_instance do filtro de agendamentos (são histórico)
        query = query.or('recurrence_category.is.null,recurrence_category.neq.flow_instance');
        if (dataInicioStr.isNotEmpty) {
          query = query.gte('due_date', dataInicioStr);
        }
        if (dataFimStr.isNotEmpty) {
          query = query.lte('due_date', dataFimStr);
        }
        break;

      case 'recorrentes':
        // Apenas tarefas com recorrência real (commitment ou flow)
        query = query.or('recurrence_category.eq.commitment,recurrence_category.eq.flow,recurrence_type.neq.none');
        break;

      case 'tarefas_recorrentes':
        query = query.or('recurrence_category.eq.commitment,recurrence_category.eq.flow,recurrence_type.neq.none')
                     .isFilter('due_date', null);
        break;

      case 'agendamentos_recorrentes':
        query = query.or('recurrence_category.eq.commitment,recurrence_category.eq.flow,recurrence_type.neq.none')
                     .not('due_date', 'is', null);
        break;

      case 'marcos':
        // Metas vinculadas a uma Jornada (goal_id preenchido)
        query = query.not('goal_id', 'is', null);
        if (termoBusca.isNotEmpty) {
          query = query.ilike('journey_title', '%$termoBusca%');
        }
        if (dataInicioStr.isNotEmpty) {
          query = query.gte('due_date', dataInicioStr);
        }
        if (dataFimStr.isNotEmpty) {
          query = query.lte('due_date', dataFimStr);
        }
        break;

      case 'foco':
        // Tarefas marcadas como foco do dia (is_focus flag)
        query = query.eq('is_focus', true);
        break;

      case 'todos':
      default:
        // Sem filtro extra — mas excluir flow templates e flow_instances
        query = query.or('recurrence_category.is.null,recurrence_category.eq.commitment');
        if (dataInicioStr.isNotEmpty) {
          query = query.gte('due_date', dataInicioStr);
        }
        if (dataFimStr.isNotEmpty) {
          query = query.lte('due_date', dataFimStr);
        }
        break;
    }

    final response = await query.order('due_date', ascending: true, nullsFirst: false).limit(12);

    final List<Map<String, dynamic>> tasks = [];
    for (final row in (response as List)) {
      tasks.add(_mapRow(row));
    }

    debugPrint('[AiToolHandler] buscar_tarefas_e_marcos → ${tasks.length} resultados');
    return {
      'tipo_busca': tipoBusca,
      'total': tasks.length,
      'tasks': tasks,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Foco do Dia — espelha a lógica de foco_do_dia_screen._filterTasks('foco')
  // Combina: is_focus + agendamentos de hoje + atrasados commitment + flow do dia
  // ═══════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> _buscarFocoDoDia(
    SupabaseClient supabase,
    bool apenasPendentes,
  ) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final todayIso = todayStart.toUtc().toIso8601String();
    final tomorrowIso = tomorrowStart.toUtc().toIso8601String();

    const selectCols =
        'id, text, completed, due_date, start_date, tags, '
        'journey_id, journey_title, goal_id, '
        'recurrence_type, recurrence_category, recurrence_interval, recurrence_days_of_week, '
        'task_type, reminder_at, duration_minutes, is_focus, completed_at';

    final List<Map<String, dynamic>> allTasks = [];

    // 1) Tarefas marcadas como foco (ignora se tem due_date ou não, is_focus prevalece)
    final focusTasks = await supabase
        .schema('sincroapp')
        .from('tasks')
        .select(selectCols)
        .eq('user_id', _userId)
        .eq('completed', false)
        .eq('is_focus', true)
        .limit(15);

    for (final row in (focusTasks as List)) {
      allTasks.add(_mapRow(row, grupo: 'foco'));
    }

    // 2) Agendamentos de hoje (due_date = hoje, qualquer categoria exceto flow puro)
    final todayTasks = await supabase
        .schema('sincroapp')
        .from('tasks')
        .select(selectCols)
        .eq('user_id', _userId)
        .eq('completed', false)
        .gte('due_date', todayIso)
        .lt('due_date', tomorrowIso)
        .or('recurrence_category.is.null,recurrence_category.neq.flow')
        .limit(15);

    for (final row in (todayTasks as List)) {
      final id = row['id'];
      if (!allTasks.any((t) => t['id'] == id)) {
        allTasks.add(_mapRow(row, grupo: 'hoje'));
      }
    }

    // 3) Atrasados (commitments com due_date < hoje, excluindo flow/flow_instance)
    final overdueTasks = await supabase
        .schema('sincroapp')
        .from('tasks')
        .select(selectCols)
        .eq('user_id', _userId)
        .eq('completed', false)
        .lt('due_date', todayIso)
        .or('recurrence_category.is.null,recurrence_category.eq.commitment')
        .limit(10);

    for (final row in (overdueTasks as List)) {
      final id = row['id'];
      if (!allTasks.any((t) => t['id'] == id)) {
        allTasks.add(_mapRow(row, grupo: 'atrasado'));
      }
    }

    // 4) Flow templates cujo dia da semana bate com hoje
    final flowTemplates = await supabase
        .schema('sincroapp')
        .from('tasks')
        .select(selectCols)
        .eq('user_id', _userId)
        .eq('completed', false)
        .eq('recurrence_category', 'flow')
        .not('recurrence_type', 'is', null)
        .neq('recurrence_type', 'RecurrenceType.none')
        .limit(20);

    final int todayWeekday = now.weekday; // 1=Mon .. 7=Sun
    for (final row in (flowTemplates as List)) {
      final recType = row['recurrence_type']?.toString() ?? '';
      final daysOfWeek = (row['recurrence_days_of_week'] as List?)?.cast<int>() ?? [];
      final interval = (row['recurrence_interval'] as int?) ?? 1;

      bool matches = false;
      if (recType.contains('daily')) {
        // Diário: checar intervalo (se intervalo=1, sempre bate)
        if (interval == 1) {
          matches = true;
        } else {
          final startStr = row['start_date']?.toString();
          if (startStr != null) {
            final start = DateTime.tryParse(startStr);
            if (start != null) {
              final diff = todayStart.difference(DateTime(start.year, start.month, start.day)).inDays;
              matches = diff >= 0 && diff % interval == 0;
            }
          } else {
            matches = true; // sem start_date, assume que bate
          }
        }
      } else if (recType.contains('weekly')) {
        // Semanal: verificar se hoje está nos daysOfWeek
        if (daysOfWeek.isEmpty) {
          matches = true; // sem dias específicos = todos os dias da semana
        } else {
          matches = daysOfWeek.contains(todayWeekday);
        }
      } else if (recType.contains('monthly')) {
        // Mensal: verificar se o dia do mês bate com o start_date
        final startStr = row['start_date']?.toString();
        if (startStr != null) {
          final start = DateTime.tryParse(startStr);
          if (start != null) {
            matches = now.day == start.day;
          }
        }
      }

      if (matches) {
        final id = row['id'];
        if (!allTasks.any((t) => t['id'] == id)) {
          allTasks.add(_mapRow(row, grupo: 'ritual_do_dia'));
        }
      }
    }

    debugPrint('[AiToolHandler] foco_do_dia → ${allTasks.length} resultados');
    return {
      'tipo_busca': 'foco_do_dia',
      'total': allTasks.length,
      'tasks': allTasks,
    };
  }

  /// Helper to map a DB row to the standardized task map for AI consumption.
  /// Optimized to omit null or less useful fields, drastically reducing AI tokens.
  Map<String, dynamic> _mapRow(Map<String, dynamic> row, {String? grupo}) {
    final map = <String, dynamic>{
      'id': row['id'],
      'title': row['text'],
      'completed': row['completed'],
    };

    if (row['due_date'] != null) map['due_date'] = row['due_date'];
    if (row['start_date'] != null) map['start_date'] = row['start_date'];
    if (row['task_type'] != null && row['task_type'] != 'TaskType.oneTime') map['task_type'] = row['task_type'];
    if (row['journey_title'] != null) map['journey_title'] = row['journey_title'];
    if (row['recurrence_type'] != null && row['recurrence_type'] != 'RecurrenceType.none') {
      map['recurrence_type'] = row['recurrence_type'];
      map['recurrence_category'] = row['recurrence_category'];
    }
    if (row['is_focus'] == true) map['is_focus'] = true;
    if (grupo != null) map['grupo'] = grupo;

    return map;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FERRAMENTA 2: Calcular numerologia
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _calcularNumerologia(Map<String, dynamic> args) {
    final nome = args['nome_completo']?.toString() ?? '';
    final dataNasc = args['data_nascimento']?.toString() ?? '';

    if (nome.isEmpty || dataNasc.isEmpty) {
      return {'error': 'nome_completo e data_nascimento são obrigatórios.'};
    }

    final engine = NumerologyEngine(
      nomeCompleto: nome,
      dataNascimento: dataNasc,
    );

    // calcular() retorna o perfil completo incluindo diaPessoal/mesPessoal/anoPessoal
    final result = engine.calcular();
    if (result == null) {
      return {'error': 'Não foi possível calcular a numerologia. Verifique o nome e data de nascimento.'};
    }
    debugPrint('[AiToolHandler] calcular_numerologia → ${result.numeros}');
    return result.toJson();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FERRAMENTA 3: Calcular harmonia conjugal
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _calcularHarmoniaConjugal(Map<String, dynamic> args) {
    final nomeA = args['nome_a']?.toString() ?? '';
    final dataNascA = args['data_nasc_a']?.toString() ?? '';
    final nomeB = args['nome_b']?.toString() ?? '';
    final dataNascB = args['data_nasc_b']?.toString() ?? '';

    if (nomeA.isEmpty || dataNascA.isEmpty || nomeB.isEmpty || dataNascB.isEmpty) {
      return {
        'error': 'Todos os campos (nome_a, data_nasc_a, nome_b, data_nasc_b) são obrigatórios.'
      };
    }

    final engineA = NumerologyEngine(
      nomeCompleto: nomeA,
      dataNascimento: dataNascA,
    );
    final engineB = NumerologyEngine(
      nomeCompleto: nomeB,
      dataNascimento: dataNascB,
    );

    final profileA = engineA.calculateProfile();
    final profileB = engineB.calculateProfile();

    final synastry = _harmonyService.calculateSynastry(
      profileA: profileA,
      profileB: profileB,
    );

    debugPrint('[AiToolHandler] calcular_harmonia_conjugal → score=${synastry['score']}');
    return {
      'score': synastry['score'],
      'status': synastry['status'],
      'description': synastry['description'],
      'pessoa_a': {
        'nome': nomeA,
        'harmonia_conjugal': profileA.numeros['harmoniaConjugal'],
        'destino': profileA.numeros['destino'],
        'expressao': profileA.numeros['expressao'],
      },
      'pessoa_b': {
        'nome': nomeB,
        'harmonia_conjugal': profileB.numeros['harmoniaConjugal'],
        'destino': profileB.numeros['destino'],
        'expressao': profileB.numeros['expressao'],
      },
      'details': synastry['details'],
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FERRAMENTA 6: Calcular Datas Favoráveis (SincroFlow)
  // Usa NumerologyEngine + SincroFlow para calcular o Dia Pessoal e o Modo
  // Estratégico de cada data, cruzando com os Dias Favoráveis pessoais do usuário.
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _calcularDatasFavoraveis(Map<String, dynamic> args) {
    final atividade = args['atividade']?.toString() ?? '';
    final dataNasc = args['data_nascimento']?.toString() ?? '';
    final dataInicioStr = args['data_inicio']?.toString() ?? '';
    final dataFimStr = args['data_fim']?.toString() ?? '';
    final quantidade = (args['quantidade'] as int?)?.clamp(1, 3) ?? 3;

    if (dataNasc.isEmpty) {
      return {'error': 'data_nascimento é obrigatório.'};
    }

    final now = DateTime.now();
    final inicio = dataInicioStr.isNotEmpty
        ? DateTime.tryParse(dataInicioStr) ?? now.add(const Duration(days: 1))
        : now.add(const Duration(days: 1));
    final fim = dataFimStr.isNotEmpty
        ? DateTime.tryParse(dataFimStr) ?? now.add(const Duration(days: 30))
        : inicio.add(const Duration(days: 30));

    // Dias favoráveis pessoais do usuário (números de 1-31 do mês)
    final engine = NumerologyEngine(nomeCompleto: '', dataNascimento: dataNasc);
    final diasFavoraveis = engine.calcularDiasFavoraveis();

    final atividadeLower = atividade.toLowerCase();
    final candidatos = <Map<String, dynamic>>[];

    var current = DateTime(inicio.year, inicio.month, inicio.day);
    while (!current.isAfter(fim) && candidatos.length < 90) {
      final personalDay = NumerologyEngine.calculatePersonalDay(current, dataNasc);
      final mode = StrategyEngine.calculateMode(personalDay);
      final isDiaFavoravel = diasFavoraveis.contains(current.day);

      // Pontuação base pelo alinhamento do Modo SincroFlow com a atividade
      double score = _scoreSincroFlowForActivity(mode, atividadeLower);

      // Bônus forte se cair nos Dias Favoráveis pessoais do usuário
      if (isDiaFavoravel) score += 0.3;

      if (score > 0.4) {
        final day = current.day.toString().padLeft(2, '0');
        final month = current.month.toString().padLeft(2, '0');
        candidatos.add({
          'data': '$day/$month/${current.year}',
          'data_iso': DateTime(current.year, current.month, current.day, 9, 0).toUtc().toIso8601String(),
          'dia_pessoal': personalDay,
          'modo_sincroflow': StrategyEngine.getModeTitle(mode),
          'modo_descricao': StrategyEngine.getModeDescription(mode),
          'dia_favoravel_pessoal': isDiaFavoravel,
          '_score': score,
        });
      }
      current = current.add(const Duration(days: 1));
    }

    // Ordenar por score desc → pegar top N → reordenar cronologicamente
    candidatos.sort((a, b) => (b['_score'] as double).compareTo(a['_score'] as double));
    final top = candidatos.take(quantidade).toList()
      ..sort((a, b) => (a['data_iso'] as String).compareTo(b['data_iso'] as String));

    for (final d in top) {
      d.remove('_score');
    }

    debugPrint('[AiToolHandler] calcular_datas_favoraveis (SincroFlow) → ${top.length} datas para "$atividade"');
    return {
      'atividade': atividade,
      'quantidade': top.length,
      'datas_favoraveis': top,
    };
  }

  /// Pontua o alinhamento entre um Modo SincroFlow e a atividade descrita.
  /// Retorna 0.9 se a atividade é compatível com o modo, 0.5 (neutro) caso contrário.
  double _scoreSincroFlowForActivity(StrategyMode mode, String atividade) {
    const modeKeywords = <StrategyMode, List<String>>{
      StrategyMode.focus: [
        'negóci', 'reunião', 'contrato', 'decisão', 'trabalho', 'financ', 'comprar',
        'vender', 'investimento', 'emprego', 'entrevista', 'apresentação', 'meta',
        'objetivo', 'projeto', 'liderança', 'execução', 'resultado',
      ],
      StrategyMode.flow: [
        'família', 'relacionamento', 'casamento', 'conversa', 'parceria', 'colabor',
        'social', 'evento', 'aniversário', 'encontro', 'confraterniz', 'concluir',
        'finaliz', 'harmoniz', 'amigo', 'amor',
      ],
      StrategyMode.grounding: [
        'viagem', 'criativ', 'comunicação', 'comunicar', 'escrever', 'arte',
        'aventura', 'mudança', 'explorar', 'venda', 'palestra', 'flexiv', 'passeio',
      ],
      StrategyMode.rescue: [
        'médico', 'consulta', 'cirurgia', 'hospital', 'saúde', 'exame', 'análise',
        'estudo', 'meditação', 'espiritualid', 'planejar', 'planejamento', 'reflexão',
        'terapia', 'descanso', 'retiro',
      ],
    };

    final keywords = modeKeywords[mode] ?? [];
    final hasMatch = keywords.any((k) => atividade.contains(k));
    return hasMatch ? 0.9 : 0.5;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FERRAMENTA 4: Buscar Conhecimento Sincro (Dados Locais)
  // Usa ContentDataLookup em vez de Supabase para evitar 403 e reduzir latência.
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _buscarConhecimentoSincro(
    Map<String, dynamic> args,
  ) {
    final query = args['query']?.toString() ?? '';
    final numero = args['numero'] is int
        ? args['numero'] as int
        : int.tryParse(args['numero']?.toString() ?? '');

    if (query.isEmpty) {
      return {'error': 'O campo query é obrigatório.'};
    }

    final result = ContentDataLookup.search(query: query, numero: numero);
    debugPrint('[AiToolHandler] buscar_conhecimento("$query", num=$numero) → ${result['total']} resultados (local)');
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FERRAMENTA 5: Buscar Relatórios de Evolução
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _buscarRelatoriosEvolucao(
    Map<String, dynamic> args,
  ) async {
    final limite = args['limite'] as int? ?? 5;
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .schema('sincroapp')
          .from('evolution_reports')
          .select('id, created_at, period_start, period_end, summary, highlights, blockers')
          .eq('user_id', _userId)
          .order('created_at', ascending: false)
          .limit(limite);

      final List<Map<String, dynamic>> relatorios = [];
      for (final row in (response as List)) {
        relatorios.add(row as Map<String, dynamic>);
      }

      debugPrint('[AiToolHandler] buscar_relatorios_evolucao → \${relatorios.length} resultados');

      return {
        'status': 'success',
        'count': relatorios.length,
        'relatorios': relatorios,
      };
    } catch (e) {
      debugPrint('[AiToolHandler] buscar_relatorios_evolucao — erro: \$e');
      return {
        'status': 'error',
        'message': 'Não foi possível buscar os relatórios de evolução. Erro: \$e',
      };
    }
  }
}
