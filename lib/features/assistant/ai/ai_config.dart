// lib/features/assistant/ai/ai_config.dart
//
// Configuração centralizada do sistema de IA do SincroApp.
// Lê provedor, modelo, temperatura e limites do arquivo .env.
// Troque AI_PROVIDER=groq → AI_PROVIDER=openai para produção.

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Provedor de IA suportado.
enum AiProviderType { groq, openai }

/// Configuração central de IA. Lida uma vez e cacheada.
class AiConfig {
  AiConfig._(); // Singleton via factory estático

  // ---------------------------------------------------------------------------
  // Provedor ativo (lido do .env)
  // ---------------------------------------------------------------------------
  static AiProviderType get provider {
    final raw = dotenv.env['AI_PROVIDER']?.toLowerCase().trim() ?? 'groq';
    return raw == 'openai' ? AiProviderType.openai : AiProviderType.groq;
  }

  // ---------------------------------------------------------------------------
  // Credenciais e modelo por provedor
  // ---------------------------------------------------------------------------
  static String get groqApiKey =>
      dotenv.env['GROQ_API_KEY'] ?? '';

  static String get groqModel =>
      dotenv.env['GROQ_MODEL'] ?? 'llama-3.3-70b-versatile';

  static String get openAiApiKey =>
      dotenv.env['OPENAI_API_KEY'] ?? '';

  static String get openAiModel =>
      dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o-mini';

  /// Modelo ativo com base no provedor configurado.
  static String get activeModel =>
      provider == AiProviderType.openai ? openAiModel : groqModel;

  // ---------------------------------------------------------------------------
  // Parâmetros de geração
  // ---------------------------------------------------------------------------
  static double get temperature =>
      double.tryParse(dotenv.env['AI_TEMPERATURE'] ?? '0.7') ?? 0.7;

  static int get maxTokens =>
      int.tryParse(dotenv.env['AI_MAX_TOKENS'] ?? '1024') ?? 1024;

  /// Número máximo de iterações de ferramentas por resposta.
  /// Proteção anti-loop: se ultrapassar, a IA retorna mensagem de erro amigável.
  static int get maxIterations =>
      int.tryParse(dotenv.env['AI_MAX_ITERATIONS'] ?? '5') ?? 5;

  // ---------------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------------
  static const String groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static const String openAiEndpoint =
      'https://api.openai.com/v1/chat/completions';

  static String get activeEndpoint =>
      provider == AiProviderType.openai ? openAiEndpoint : groqEndpoint;

  static String get activeApiKey =>
      provider == AiProviderType.openai ? openAiApiKey : groqApiKey;

  // ---------------------------------------------------------------------------
  // Definições de ferramentas (Function Calling / Tool Use)
  // OTIMIZADO: Descrições compactas para economizar ~400 tokens/chamada.
  // ---------------------------------------------------------------------------
  static List<Map<String, dynamic>> get toolDefinitions => [
        {
          'type': 'function',
          'function': {
            'name': 'buscar_tarefas_e_marcos',
            'description':
                'Busca tarefas, agendamentos e marcos do usuário.',
            'parameters': {
              'type': 'object',
              'properties': {
                'termo_busca': {
                  'type': 'string',
                  'description': 'Filtro por nome (opcional).'
                },
                'tipo_busca': {
                  'type': 'string',
                  'enum': ['tarefas', 'agendamentos', 'recorrentes', 'marcos', 'foco_do_dia', 'foco', 'todos'],
                  'description':
                      'tarefas=sem data, agendamentos=com data, recorrentes=repetitivas, marcos=metas de jornada, foco_do_dia=visão completa do dia, foco=is_focus, todos=geral.',
                },
                'data_inicio': {
                  'type': 'string',
                  'description': 'ISO 8601. Para agendamentos atrasados: deixe VAZIO.',
                },
                'data_fim': {
                  'type': 'string',
                  'description': 'ISO 8601. Para atrasados: use data/hora atual.',
                },
                'apenas_pendentes': {
                  'type': 'boolean',
                  'description': 'Apenas não concluídas. Padrão: true.',
                },
              },
              'required': ['tipo_busca'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'calcular_numerologia',
            'description':
                'Calcula perfil numerológico completo (Destino, Expressão, Motivação, etc).',
            'parameters': {
              'type': 'object',
              'properties': {
                'nome_completo': {
                  'type': 'string',
                  'description': 'Nome completo.',
                },
                'data_nascimento': {
                  'type': 'string',
                  'description': 'DD/MM/AAAA.',
                },
              },
              'required': ['nome_completo', 'data_nascimento'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'calcular_harmonia_conjugal',
            'description': 'Compatibilidade amorosa entre duas pessoas.',
            'parameters': {
              'type': 'object',
              'properties': {
                'nome_a': {'type': 'string', 'description': 'Nome pessoa A.'},
                'data_nasc_a': {'type': 'string', 'description': 'DD/MM/AAAA pessoa A.'},
                'nome_b': {'type': 'string', 'description': 'Nome pessoa B.'},
                'data_nasc_b': {'type': 'string', 'description': 'DD/MM/AAAA pessoa B.'},
              },
              'required': ['nome_a', 'data_nasc_a', 'nome_b', 'data_nasc_b'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'buscar_conhecimento_sincro',
            'description': 'Busca significado de número ou conceito numerológico.',
            'parameters': {
              'type': 'object',
              'properties': {
                'query': {
                  'type': 'string',
                  'description': 'Tema ou número. Ex: "número 8", "dívida cármica 13".',
                },
                'numero': {
                  'type': 'integer',
                  'description': 'Número 1-22 (omita se não específico).',
                },
              },
              'required': ['query'],
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'buscar_relatorios_evolucao',
            'description': 'Busca relatórios de progresso do usuário.',
            'parameters': {
              'type': 'object',
              'properties': {
                'limite': {
                  'type': 'integer',
                  'description': 'Máx relatórios (padrão: 5).',
                },
              },
            },
          },
        },
      ];
}
