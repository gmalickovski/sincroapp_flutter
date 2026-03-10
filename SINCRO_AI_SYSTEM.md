# SincroApp — Sistema de IA (Documentação)

> **Última atualização**: 10/03/2026
> **Versão**: 2.0 (Migração do N8N para IA Direta)

## Visão Geral

O SincroApp possui um assistente de IA integrado ("Sincro IA") que atua como mentora de evolução pessoal e guru de numerologia. A partir da **v2.0**, todas as chamadas de IA são feitas **diretamente dentro do app Flutter**, eliminando a dependência do N8N como intermediário.

### Fluxo Simplificado

```
Pergunta do Usuário
       │
       ▼
AssistantService.ask()
       │
       ├─ Monta contexto (nome, dataNasc, dia da semana, hora)
       ├─ Injeta System Prompt (AiPrompts.systemPrompt)
       ├─ Envia mensagens ao LLM (AiProvider → Groq/OpenAI)
       │
       ├─── LLM solicita ferramenta? (Function Calling)
       │    ├─ SIM → AiToolHandler.dispatch() executa
       │    │        ├─ buscar_tarefas_e_marcos → Supabase
       │    │        ├─ calcular_numerologia → NumerologyEngine
       │    │        ├─ calcular_harmonia_conjugal → HarmonyService
       │    │        └─ buscar_conhecimento_sincro → Supabase
       │    │    Resultado volta ao LLM → novo ciclo
       │    └─ NÃO → Resposta final de texto
       │
       ├─ AiLoopGuard: max 5 iterações (anti-loop)
       ├─ Log de tokens reais no Supabase (usage_logs)
       └─ Retorna AssistantAnswer (JSON: answer + tasks + actions)
```

---

## Estrutura de Arquivos

### `lib/features/assistant/ai/` — Módulo IA

| Arquivo | Responsabilidade |
|---------|------------------|
| `ai_config.dart` | Configuração central: provedor, modelo, temperatura, maxTokens, maxIterations, endpoints, tool definitions |
| `ai_prompts.dart` | TODOS os prompts do sistema: system prompt, regras de ferramentas, formato de saída, exemplos few-shot |
| `ai_provider.dart` | Camada HTTP: chamadas ao Groq/OpenAI (API OpenAI-compatible), parse de tool calls e tokens |
| `ai_tool_handler.dart` | Execução de ferramentas: busca tarefas, numerologia, harmonia, conhecimento |
| `ai_loop_guard.dart` | Proteção anti-loop: conta iterações por sessão, lança AiLoopException se > limite |

### `lib/features/assistant/services/`

| Arquivo | Responsabilidade |
|---------|------------------|
| `assistant_service.dart` | Orquestrador principal: monta contexto → LLM → ferramentas → resposta. Também gerencia histórico e conversas no Supabase |

### `lib/features/assistant/models/`

| Arquivo | Responsabilidade |
|---------|------------------|
| `assistant_models.dart` | Modelos: `AssistantAction`, `AssistantAnswer`, `AssistantMessage`, `AssistantConversation` |

---

## Configuração (.env)

```ini
AI_PROVIDER=groq            # "groq" (teste) ou "openai" (produção)
GROQ_API_KEY=gsk_...        # Chave da API Groq
GROQ_MODEL=llama-3.3-70b-versatile
OPENAI_API_KEY=sk-...       # Chave da API OpenAI
OPENAI_MODEL=gpt-4o-mini
AI_TEMPERATURE=0.7
AI_MAX_TOKENS=1500
AI_MAX_ITERATIONS=5          # Limite anti-loop
```

Para trocar de Groq → OpenAI: mude `AI_PROVIDER=openai` e configure a `OPENAI_API_KEY`.

---

## Tipos de Tarefa (Para o Assistente)

| Tipo | Característica | tipo_busca na IA |
|------|---------------|------------------|
| Marco | `goal_id` preenchido | `"marcos"` |
| Agendamento | `due_date` definida, `task_type='appointment'` | `"agendamentos"` com datas |
| Tarefa livre | `due_date` NULA, sem recorrência | `"tarefas"` sem datas |
| Recorrente Commitment | `recurrence_category='commitment'` | `"agendamentos"` (tem data) |
| Recorrente Flow | `recurrence_category='flow'` | `"tarefas"` (sem data fixa) |

---

## Anti-Loop (AiLoopGuard)

- Cada chamada `ask()` cria um `AiLoopGuard` com `sessionId` único
- A cada tool call executada, `guard.tick(toolName)` incrementa o contador
- Se ultrapassar `maxIterations` (padrão: 5): lança `AiLoopException`
- O `AssistantService` captura a exceção e retorna mensagem amigável ao usuário
- Reset automático a cada nova pergunta

---

## Rastreamento de Tokens

- Cada chamada ao LLM retorna `prompt_tokens`, `completion_tokens`, `total_tokens`
- O `AiProvider` acumula tokens de TODAS as iterações (incluindo tool calls)
- Ao final, `_logUsage()` grava na tabela `sincroapp.usage_logs`:
  - `user_id`, `tokens_total`, `tokens_input`, `tokens_output`, `model_name`, `created_at`
- O painel Admin exibe via `getAdminStats()` e `getUserTokenUsageMap()`

---

## Formato de Resposta (JSON)

A IA SEMPRE retorna:

```json
{
  "answer": "Texto empático com **negritos** e emojis 🌟",
  "tasks": [
    {"id": "...", "title": "...", "due_date": "...", "completed": false}
  ],
  "actions": {
    "type": "create_task",
    "title": "...",
    "suggestedDates": ["2026-03-10T00:00:00.000Z"]
  }
}
```

- `tasks[]` — renderiza lista de tarefas no chat
- `actions{}` — renderiza modal de sugestão de datas / criar tarefa
- O `AssistantAnswer.fromJson()` parseia este formato
