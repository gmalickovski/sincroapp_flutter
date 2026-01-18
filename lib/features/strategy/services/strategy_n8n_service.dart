import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class StrategyN8NService {
  static const String _webhookEnvKey = 'SINCROFLOW_WEBHOOK';

  /// Fetches strategy recommendations from N8N webhook.
  /// Returns a list of strings (suggestions) or throws an exception.
  static Future<List<String>> fetchStrategyRecommendation({
    required UserModel user,
    required int personalDay,
    required StrategyMode mode,
    required List<Map<String, dynamic>> tasksCompact,
    required String modeTitle,
    required String modeDescription,
  }) async {
    final webhookUrl = dotenv.env[_webhookEnvKey];

    if (webhookUrl == null || webhookUrl.isEmpty) {
      debugPrint('⚠️ N8N Webhook URL not found in .env ($_webhookEnvKey)');
      throw Exception('Configuration Error: N8N Webhook URL missing.');
    }

    // Construct the Structured Payload (Sincroflow expects this at root)
    final payload = {
      'user': {
        'name': user.primeiroNome,
        'id': user.uid,
        'numerology': {
          'personalDay': personalDay,
          'mode': mode.name,
        }
      },
      'tasks': tasksCompact,
      'context': {
        'modeTitle': modeTitle,
        'modeDescription': modeDescription,
        'timestamp': DateTime.now().toIso8601String(),
      }
    };

    try {
      debugPrint('🚀 Sending Strategy Request to N8N: $webhookUrl');
      
      // REVERTED: Send payload directly to body (no chatInput wrapper)
      // This is the format that was working on January 15th commit.
      final encodedPayload = jsonEncode(payload);
      print('--- STRATEGY AI PAYLOAD ---');
      print(encodedPayload);
      print('---------------------------');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: encodedPayload,
      ).timeout(const Duration(seconds: 45)); // N8N might take time with AI

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Expecting { "suggestions": ["Suggestion 1", "Suggestion 2"] }
        if (data.containsKey('suggestions') && data['suggestions'] is List) {
          final List<dynamic> rawSuggestions = data['suggestions'];
          return rawSuggestions.map((e) => e.toString()).toList();
        } else if (data.containsKey('output') && data['output'] is String) {
           // Fallback if N8N returns a single string (try to parse or wrap)
           return [data['output'].toString()];
        } else {
           debugPrint('⚠️ Unexpected N8N response format: ${response.body}');
           throw Exception('Invalid response format from N8N.');
        }
      } else {
        debugPrint('❌ N8N Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to communicate with N8N (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Error contacting N8N: $e');
      rethrow;
    }
  }

  /// Analyzes professional compatibility using AI via N8N.
  static Future<String> analyzeProfessionCompatibility({
    required UserModel user,
    required NumerologyResult profile,
    required String professionName,
  }) async {
    final webhookUrl = dotenv.env['PROFESSIONAL_APTITUDE_WEBHOOK'];

    if (webhookUrl == null || webhookUrl.isEmpty) {
      debugPrint('⚠️ Professional Aptitude Webhook URL not found in .env');
      throw Exception('Configuration Error: Webhook URL missing.');
    }

    final payload = {
      'user': {
        'name': user.primeiroNome,
        'numerology': {
          'expression': NumerologyEngine.reduceNumber(profile.numeros['expressao'] ?? 0, mestre: true),
          'destiny': NumerologyEngine.reduceNumber(profile.numeros['destino'] ?? 0, mestre: true),
          'path': NumerologyEngine.reduceNumber(profile.numeros['missao'] ?? 0, mestre: true), // Mission (Correctly Reduced)
        }
      },
      'profession': professionName,
      'formatting_instructions': '''
Você é um especialista em Numerologia Aplicada a Carreiras. Analise a compatibilidade numerológica do usuário com a profissão.

DADOS DO USUÁRIO:
- Número de Expressão: ${NumerologyEngine.reduceNumber(profile.numeros['expressao'] ?? 0, mestre: true)}
- Número de Destino: ${NumerologyEngine.reduceNumber(profile.numeros['destino'] ?? 0, mestre: true)}
- Número de Missão: ${NumerologyEngine.reduceNumber(profile.numeros['missao'] ?? 0, mestre: true)}
- Profissão Solicitada: $professionName

TABELA DE HARMONIZAÇÃO (use para calcular o score base):
| Destino | Expressão Favorável (+30%) | Expressão Desfavorável (-20%) |
|---------|---------------------------|------------------------------|
| 1 | 3, 5, 9 | 6 |
| 2 | 2, 4, 6, 7 | 5, 9 |
| 3 | 1, 3, 5, 6 | 4, 7, 8 |
| 4 | 2, 6, 8 | 3, 5, 7, 9 |
| 5 | 1, 3, 5, 7, 9 | 2, 4, 6, 8 |
| 6 | 2, 3, 4, 8, 9 | 1, 5, 7 |
| 7 | 2, 5, 7 | 3, 4, 6, 8, 9 |
| 8 | 4, 6 | 3, 5, 7, 8, 9 |
| 9 | 1, 5, 6, 9 | 2, 4, 7, 8 |

REGRAS DE CÁLCULO DO SCORE (Ajuste Fino de 5%):
1. **Base:** Comece com 50%.
2. **Matriz:**
   - Se Expressão está na coluna FAVORÁVEL do Destino: +30%
   - Se Expressão está na coluna DESFAVORÁVEL do Destino: -20%
3. **Afinidade Natural da Profissão:**
   - Se a profissão tem TUDO a ver com a Expressão (ex: Expressão 1 e "Líder/Empresário"): +15%
   - Se tem "muito" a ver: +10%
   - Se tem "pouco" a ver: +5%
   - Se é oposta (ex: Expressão 1 e "Subordinado/Rotina"): -10%
4. **Alinhamento com Missão/Destino:**
   - Se a profissão ajuda a cumprir a Missão: +5% a +10%

**IMPORTANTE:** O resultado final DEVE ser arredondado para múltiplos de 5 (Ex: 55%, 60%, 85%, 95%, 100%). Evite scores redondos apenas de 10 em 10 se a nuance pedir 5%.

FORMATO DA RESPOSTA (Markdown):

## 🎯 Análise de Compatibilidade
Escreva um parágrafo introdutório usando SEGUNDA PESSOA (você, seu, sua). Exemplo: "A sua compatibilidade com a profissão de [X] revela..." NUNCA use o nome do usuário nem terceira pessoa.

### Pontos Fortes 🌟
- Seu **Número de Expressão ${NumerologyEngine.reduceNumber(profile.numeros['expressao'] ?? 0, mestre: true)}** indica que você [explicação]
- O seu **Destino ${NumerologyEngine.reduceNumber(profile.numeros['destino'] ?? 0, mestre: true)}** sugere que você tem [explicação]
- A sua **Missão ${NumerologyEngine.reduceNumber(profile.numeros['missao'] ?? 0, mestre: true)}** revela que você [explicação]

### Desafios ⚠️
- [Desafio relacionado ao perfil]
- [Outro desafio]

### Score de Compatibilidade 📊
Com base na Tabela de Harmonização, sua compatibilidade é de **XX%**. [Justificativa breve do cálculo]

> "Frase inspiradora como mantra final"

---
## 🏆 Profissões Ideais para Você
**CONDICIONAL: SÓ INCLUA ESTA SEÇÃO SE O SCORE FOR MENOR QUE 90%.**
(Se o score for 90%, 95% ou 100%, não mostre esta seção).

**Quantidade de Sugestões:**
- **Se Score < 90%:** Liste **3** profissões que teriam compatibilidade de **90% a 100%** com o perfil numerológico (Expressão ${NumerologyEngine.reduceNumber(profile.numeros['expressao'] ?? 0, mestre: true)} e Destino ${NumerologyEngine.reduceNumber(profile.numeros['destino'] ?? 0, mestre: true)}).
- **IMPORTANTE:** As profissões sugeridas DEVEM ser calculadas para ter um Score ALTO (>= 90%). Não sugira algo que resultaria em 70%.

**Critério de Escolha:**
Misture profissões próximas à área solicitada (se possível) com profissões distintas que tenham alta compatibilidade com o Mapa Numerológico.

1. **Profissão 1:** [Explicação]
2. **Profissão 2:** [Explicação]
3. **Profissão 3:** [Explicação]
...

REGRAS OBRIGATÓRIAS:
1. Use SEMPRE segunda pessoa (você, seu, sua).
2. Use **negrito** (cor Âmbar) nos termos numerológicos.
3. O mantra final DEVE começar com > e estar entre aspas.
4. O score DEVE ser calculado usando a lógica de 5%.
5. **OBEDECER RIGOROSAMENTE AS REGRAS CONDICIONAIS DE SUGESTÃO DE PROFISÃO.**
''',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      debugPrint('🚀 Sending Professional Aptitude Request to N8N: $webhookUrl');
      
      // REVERTED: Send payload directly to body (no chatInput wrapper)
      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data.containsKey('analysis') && data['analysis'] is String) {
          return data['analysis'];
        } else if (data.containsKey('output') && data['output'] is String) {
           return data['output'];
        } else {
           debugPrint('⚠️ Unexpected N8N response format: ${response.body}');
           throw Exception('Invalid response format from AI.');
        }
      } else {
        debugPrint('❌ N8N Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to communicate with N8N (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Error contacting N8N: $e');
      rethrow;
    }
  }
}
